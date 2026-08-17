# CNS002 (Ordem de Serviço) - FWModel leve pro REST + rename anti-duplicidade

## Contexto

Mesmo padrão de redundância REST-vs-nativo do módulo Chamados (CNS001/CNSA001), agora no módulo de Ordem de Serviço: `CNS002.tlpp` (ex `Apia-OS.tlpp`, ex `POUICNSA002.prw`) grava a SZ1 direto via `RecLock`/`GetSxeNum`, em paralelo ao `CNSA002.PRW` (tela clássica, MVC completo, Model `FCNSA002`).

**Diferença crítica em relação ao Chamados**: o `ModelDef()` do `CNSA002.PRW` tem um grid filho (`SZ2DETAIL`, "Horas Contratadas") relacionado por **CLIENTE** (`Z2_CODCLI+Z2_LOJA = Z1_CLI+Z1_LOJA`), não por OS. O próprio código de `CNS002.tlpp` já documenta, nos 4 endpoints de escrita, a decisão consciente de **não usar esse Model** - `FWLoadModel("CNSA002")` cascatearia no grid SZ2, que é compartilhado entre todas as OS's do mesmo cliente, arriscando alterar/apagar linhas de Horas Contratadas de OS's diferentes da que está sendo editada/excluída.

**Decisão confirmada com o usuário**: em vez de reusar o Model da tela clássica (arriscado) ou remover o grid do `ModelDef` compartilhado (afetaria a aba "Horas Contratadas" da tela clássica, fora de escopo), criar um **Model leve novo, só com a SZ1 (sem grid nenhum), vivendo dentro do próprio `CNS002.tlpp`** - zero alteração no `CNSA002.PRW`, zero risco de cascata (não existe grid pra cascatear).

Além disso, investigação confirmou (via histórico git: `POUICNSA002.tlpp` → `Apia-OS.tlpp` → `CNS002.tlpp`) o mesmo padrão de risco já visto no Chamados - provável arquivo `Apia-OS.tlpp` remanescente no ambiente real de compilação do usuário, duplicando as funções `CNSA_OS_*` que hoje vivem em `CNS002.tlpp`. Mesma solução preventiva: renomear.

## Escopo

**Dentro**:
1. Renomear as 5 `User Function CNSA_OS_*`/relacionadas em `CNS002.tlpp` pra `CNS002_*` (mesmo esquema do `CNS001_*` já aplicado no Chamados).
2. Nova `Static Function CNS002_MODELREST()` em `CNS002.tlpp` - Model leve (`MPFormModel`, só `SZ1MASTER`, sem grid) usado pelos 4 endpoints de escrita.
3. `CNSA_OS_INCLUIR`/`ALTERAR`/`EXCLUIR`/`COPIAR` passam a usar esse Model (`SetOperation`+`Activate`+`SetValue`+`VldData`/`CommitData`+`DeActivate`) em vez de `RecLock`/`GetSxeNum`/`FieldPut` direto.

**Fora**: `CNSA002.PRW` (tela clássica) **não é tocado** - `ModelDef`/`ViewDef`/`MenuDef`/`FSZ1PosValid`/`FSZ1TOK`/`FSZ1CAN`/`COPIAR_OS`/`LEGENDA` continuam exatamente como estão. `CNSA_OS_LISTAR` (leitura, `@Get`) não muda - sem redundância de gravação a resolver. Contrato JSON dos 4 endpoints de escrita não muda - mesma URL/parâmetros/formato de resposta.

## Renomeação (todas em `CNS002.tlpp`)

| Atual | Novo |
|---|---|
| `CNSA_OS_LISTAR` | `CNS002_OS_LISTAR` |
| `CNSA_OS_INCLUIR` | `CNS002_OS_INCLUIR` |
| `CNSA_OS_ALTERAR` | `CNS002_OS_ALTERAR` |
| `CNSA_OS_EXCLUIR` | `CNS002_OS_EXCLUIR` |
| `CNSA_OS_COPIAR` | `CNS002_OS_COPIAR` |

Nenhuma rota `@Get`/`@Post` muda de URL - dispatch é por anotação, não por nome de função (mesma lógica já confirmada no Chamados).

## `CNS002_MODELREST()` - Model leve

```advpl
Static Function CNS002_MODELREST()
    Local oModel  := Nil
    Local oStrSZ1 := FWFormStruct(1, "SZ1")

    oModel := MPFormModel():New("FCNS002REST", NIL, NIL, NIL, NIL)
    oModel:AddFields("SZ1MASTER", NIL, oStrSZ1, NIL, NIL)
    oModel:SetPrimaryKey({"Z1_FILIAL", "Z1_OS"})

Return oModel
```

Sem `AddGrid`/`SetRelation` pro SZ2 - não existe grid nenhum pra cascatear, garantia estrutural (não depende de "cuidado" no código de cada endpoint). Sem `FSZ1PosValid` reaproveitado (é `Static Function`, escopo de arquivo - não visível fora de `CNSA002.PRW`) - sem perda real, já que os 4 endpoints REST já fazem validação de campo obrigatório inline (mesma lista de campos), redundante com `FSZ1PosValid` mas já existente.

## Fluxo por operação

**Incluir**: `oModel:SetOperation(MODEL_OPERATION_INSERT)` → `Activate()` → `SetValue` em cada campo (mesma lista de hoje) → `VldData()`/`CommitData()` → erro vira 400, sucesso vira 200 (mesmo formato `CNSA002_RESPOK`).

**Alterar**: posiciona SZ1 antes (`DbSeek`, 404 se não achar - mantido) → `MODEL_OPERATION_UPDATE` → `Activate()` → `SetValue` só nos campos que vierem preenchidos (mantém parcial) → `VldData()`/`CommitData()`.

**Excluir**: posiciona SZ1 antes (mantido) → `MODEL_OPERATION_DELETE` → `Activate()` → `VldData()`/`CommitData()` (sem `SetValue` nenhum, só confirma o delete).

**Copiar**: posiciona SZ1 origem (mantido) → captura todos os campos via `FieldName`/`FieldGet` (mantido) → `MODEL_OPERATION_INSERT` no Model leve → `SetValue` em loop pra cada campo capturado + os campos fixos de reset (`Z1_OS` novo, `Z1_DTDIGIT`, `Z1_APROVAD:="N"`, etc, mesma lista de hoje) → `VldData()`/`CommitData()`.

Todos os 4: erro de `VldData()`/`CommitData()` monta mensagem via `oModel:GetErrorMessage()` (mesmo tratamento C/O/A já usado no Chamados) → 400/500; `DeActivate(lOk)` sempre no fim.

## Riscos / observações

- Numeração `Z1_OS` (`GetSxeNum`) mantida manual antes do `SetValue` - mesma cautela do Chamados (não confirmado se SX3 tem numeração automática configurada; se tiver, o Model geraria sozinho).
- `CNSA002.PRW` fica com **dois caminhos de gravação coexistindo** pra mesma tabela SZ1: tela clássica via Model completo (com grid), REST via Model leve (sem grid) - ambos gravam a mesma tabela física, sem conflito de dados (cada um só toca os campos que já tocava antes), só a ferramenta de gravação mudou do lado REST.
