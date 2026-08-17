# CNS001 - Incluir Chamado via FWModel do CNSA001 (elimina redundância)

## Contexto

`CNS001.tlpp` (Codigos apia intraweb henrique) expõe a API REST do portal `apia.com.br/intraweb` pra Chamados (ZA1), migrada de WSRESTFUL pra anotações TLPP. Hoje o endpoint de inclusão (`@Post /CNSACHAMADOSINCLUIR`, função `CNSA_CHAMADOS_INCLUIR` → `Static Function CNSA_INCLUIR`) reimplementa a gravação na mão: `GetSxeNum("ZA1","ZA1_IDCH")` + `RecLock("ZA1",.T.)` com atribuição campo a campo + `ConfirmSX8()`.

Separadamente, `CNSA001.PRW` (Fontes cnshub) é a tela clássica Protheus do mesmo cadastro (ZA1), com `ModelDef`/`ViewDef`/`MenuDef` MVC completo (`MPFormModel` `FCNSA001`, grids ZA2DETAIL/SZ6DETAIL). A inclusão pela tela clássica passa pelo commit padrão do FWModel, incluindo a Pós-Validação `CNSA_APOSCOMMIT`, que dispara e-mails de designação e - em Inclusão/Alteração (`nOper == 3 .Or. 4`) - um `MsgYesNo` perguntando se o usuário quer criar um agendamento pro chamado.

Motivação (pedido do usuário): a inclusão via REST não deveria reimplementar a gravação - deveria chamar a mesma lógica nativa do Protheus (`CNSA001.PRW`) que já existe, evitando redundância. Referência de padrão já usada no próprio projeto: `CNSA003REST.tlpp` (`cnsa003inc`), que grava agendamento (SZ6) via `FWLoadModel("CNSA003")` + `SetOperation(MODEL_OPERATION_INSERT)` + `SetValue` + `VldData()`/`CommitData()`, em vez de `RecLock` manual - documentado ali como alternativa ao endpoint genérico `/rest/FwModel/agenda` do `PUBLISH MODEL REST`, que não executa os gatilhos SX7.

## Escopo

**Dentro**: `CNSA_INCLUIR` (dentro de `CNS001.tlpp`) passa a gravar o chamado via `FWLoadModel("CNSA001")` em vez de `RecLock` manual - mesmo padrão do `cnsa003inc`. Ajuste pontual em `CNSA_APOSCOMMIT` (`CNSA001.PRW`) pra não travar o `MsgYesNo` quando o commit vier de contexto headless (REST).

**Fora**: `CNSA_CHAMADOS_ALTERAR`, `CNSA_ASSUMIR`, `CNSA_EXCLUIR` e `CNSA_CHAMADOS_AGENDAR` (todos em `CNS001.tlpp`) continuam gravando direto na ZA1/SZ6 como estão hoje - não migram pro FWModel nesta rodada. Podem virar spec separada depois, seguindo o mesmo padrão validado aqui. Contrato JSON do endpoint (`/CNSACHAMADOSINCLUIR`) não muda - mesma URL, mesmos parâmetros de entrada, mesmo formato de resposta.

## Arquitetura

Dois arquivos tocados:

- `Codigos apia intraweb henrique/CNS001.tlpp` - reescreve o miolo de `Static Function CNSA_INCLUIR`.
- `Fontes cnshub/CNSA001.PRW` - ajuste pontual em `CNSA_APOSCOMMIT` (trecho do `MsgYesNo` de agendamento).

### Fluxo novo do `CNSA_INCLUIR`

1. Validações de entrada continuam iguais (`Empty(cAssunto)`, `Empty(cTipo)`, `Empty(cProjeto)`, `Empty(cTarefa)` → 400), assim como os defaults (`cLojaCliente:="01"`, `cDtAbertura` default hoje, `cCodConsultor` auto-preenchido pelo técnico da sessão se vazio).
2. Seta a flag headless antes de ativar o model: `Public lCnsaViaRest := .T.` (ver seção "Flag headless" abaixo).
3. `oModel := FWLoadModel("CNSA001")`
4. `oModel:SetOperation(MODEL_OPERATION_INSERT)`
5. `oModel:Activate()`
6. `oModelZA1 := oModel:GetModel("ZA1MASTER")`
7. `oModelZA1:SetValue(...)` pra cada campo (ver tabela de mapeamento abaixo). `ZA1_IDCH` só é setado manualmente se a numeração **não** for automática no SX3 (ver seção "Numeração ZA1_IDCH").
8. `If oModel:VldData() ; lOk := oModel:CommitData() ; EndIf`
9. Se `!lOk`: monta erro a partir de `oModel:GetErrorMessage()` (mesmo tratamento C/O/A do `cnsa003inc` - trata string, objeto com `GetMessage()`, ou array via `FwJsonSerialize`), retorna `{400, ...}`.
10. Se `lOk`: recupera `cIdCh` gravado (via `oModelZA1:GetValue("ZA1_IDCH")`, já que pode ter sido auto-gerado pelo model), retorna `{200, ...}` no mesmo formato de hoje (`sucesso`, `idCh`, `mensagem`).
11. `oModel:DeActivate(lOk)` sempre no fim (sucesso ou erro).
12. `Begin Sequence`/`Recover Using oErro` mantido ao redor de tudo, igual ao padrão atual do arquivo - erro inesperado retorna 500.

`CNSA_DISPARA_DESIGNACAO(cIdCh, cCodConsultor)` (disparo de e-mail de designação, hoje chamado manualmente depois do `RecLock`) deixa de ser chamado à parte - passa a ser responsabilidade do próprio commit do model, já que `CNSA_APOSCOMMIT` (Pós-Validação) já cobre esse e-mail para o fluxo de Alteração; **assunção a validar na implementação**: confirmar se `CNSA_APOSCOMMIT` também dispara e-mail de designação em Inclusão (`nOper==3`) hoje, ou se essa parte do e-mail continua precisando ser chamada explicitamente pelo REST após o `CommitData()` bem-sucedido, reaproveitando a função `CNSA_DISPARA_DESIGNACAO` que já existe em `CNS001.tlpp`.

### Flag headless (resolve o `MsgYesNo` de agendamento)

`CNSA_APOSCOMMIT` (`CNSA001.PRW`, bloco `nOper == 3 .Or. nOper == 4`, por volta da linha 497) hoje sempre chama `MsgYesNo` perguntando se quer criar agendamento, e só chama `CNSA_CRIAAGENDA_INT` se o usuário confirmar. Isso é modal de UI - não pode rodar num job REST sem tela.

Solução (decisão do usuário: no REST, cria a agenda automático, sem perguntar):

```advpl
// Em CNSA_APOSCOMMIT, no lugar do "If MsgYesNo(cPergAgenda, "Agendar Chamado")":
Local lViaRest := (Type("lCnsaViaRest") == "L" .And. lCnsaViaRest)

If lViaRest .Or. MsgYesNo(cPergAgenda, "Agendar Chamado")
    // ... corpo que já existe, sem alteração ...
EndIf
```

`lCnsaViaRest` é declarada como `Public` dentro de `CNSA_INCLUIR` (`CNS001.tlpp`) antes do `Activate()`, e não existe no fluxo da tela clássica - por isso o `Type("lCnsaViaRest") == "L"` cobre o caso de não estar declarada (tela clássica: comportamento antigo, pergunta normal) e o caso de estar declarada e `.F.` (não deveria acontecer no fluxo REST, mas cai em segurança pro `MsgYesNo`).

**Risco conhecido**: `Public` fica visível pra qualquer código que rodar na mesma sessão/thread depois do `CNSA_INCLUIR` retornar, se não for limpa. Mitigação: `lCnsaViaRest := .F.` no fim de `CNSA_INCLUIR` (ou usar `Private` com `RestUsrRPC()`/thread isolada do job REST, se confirmado que cada request roda em thread própria - **assunção a validar na implementação**, comparar com o isolamento de contexto que `CNSA003REST.tlpp` já assume implicitamente ao usar `Public`/`Private` em `MenuDef`/`ModelDef`).

### Mapeamento de campos (`SetValue` no `ZA1MASTER`)

| Campo ZA1 | Origem | Observação |
|---|---|---|
| `ZA1_FILIAL` | `xFilial("ZA1")` | igual a hoje |
| `ZA1_IDCH` | `GetSxeNum`/model auto | ver seção Numeração |
| `ZA1_ASSUNT` | `cAssunto` | igual a hoje |
| `ZA1_DATA` | `STOD(cDtAbertura)` | igual a hoje |
| `ZA1_STATUS` | fixo `"1"` | igual a hoje |
| `ZA1_TIPO` | `cTipo` | nome já confirmado em uso (`CNSA_CHAMADOS_LISTAR`, mesmo arquivo) |
| `ZA1_CLIENT` | `cCodCliente` | igual a hoje |
| `ZA1_LOJA` | `cLojaCliente` (default "01") | igual a hoje |
| `ZA1_EMAIL` | `cEmailCliente` | nome já confirmado em uso (`CNSA_CHAMADOS_LISTAR`, mesmo arquivo) |
| `ZA1_CONSUL` | `cCodConsultor` (auto-preenchido se vazio) | igual a hoje |
| `ZA1_PROJ` | `cProjeto` | igual a hoje |
| `ZA1_TAREFA` | `cTarefa` | igual a hoje |
| `ZA1_MOD` | `Date()` | igual a hoje |

### Numeração `ZA1_IDCH`

Não confirmado nesta rodada (sem acesso a consulta SQL no dicionário de dados durante o brainstorm) se `ZA1_IDCH` tem numeração automática configurada no SX3 (nesse caso o próprio `CommitData()` gera o código, sem precisar de `GetSxeNum`/`ConfirmSX8` manual) ou se depende só do código hoje presente no REST. **Assunção a validar na implementação** (mesma cautela que já existia no comentário original de `CNSA_INCLUIR`):

- Se for automática: remove `GetSxeNum`/`ConfirmSX8` do REST, deixa o model gerar, recupera o valor gerado via `oModelZA1:GetValue("ZA1_IDCH")` após o `CommitData()`.
- Se não for: mantém `cIdCh := GetSxeNum("ZA1","ZA1_IDCH")` antes do `SetValue`, seta `ZA1_IDCH` explicitamente, e ainda chama `ConfirmSX8()` depois do `CommitData()` bem-sucedido (mesmo padrão manual que `CNS001.tlpp` já usa hoje) - `RollBackSX8()` no `Recover` se der erro antes de confirmar.

## Contrato JSON

Sem mudança em relação ao que já existe hoje - mesma URL (`POST /CNSACHAMADOSINCLUIR`), mesmos parâmetros de entrada (querystring: `assunto`, `dtAbertura`, `tipo`, `codCliente`, `lojaCliente`, `emailCliente`, `codConsultor`, `projeto`, `tarefa`), mesmo formato de resposta:

**Sucesso** (200):
```json
{"sucesso": true, "idCh": "000123", "mensagem": "Chamado incluido com sucesso."}
```

**Erro de validação** (400) - agora inclui também falhas de validação do próprio Model (`FSZ1PosValid`-equivalente do CNSA001, ou lógica de `CNSA_POSVAL`/`CNSA_TOK` do PRW), além das validações que já existiam no REST:
```json
{"erro": "<mensagem de CNSA_JSONESC(EncodeUtf8(...)) ou de oModel:GetErrorMessage()>"}
```

**Erro inesperado** (500):
```json
{"erro": "<descrição da exceção>"}
```

## Fora de escopo / riscos conhecidos

- `CNSA_CHAMADOS_ALTERAR`, `CNSA_ASSUMIR`, `CNSA_EXCLUIR`, `CNSA_CHAMADOS_AGENDAR` continuam com gravação manual (`RecLock`) - não entram nesta rodada.
- `lCnsaViaRest` como `Public` é um mecanismo simples mas frágil (risco de vazar estado entre chamadas na mesma sessão/thread) - ver mitigação na seção "Flag headless". Se o time preferir, pode virar parâmetro explícito de uma nova função (`CNSA_APOSCOMMIT(p_oModel, lViaRest)`) em vez de variável global - decisão de implementação, não bloqueia o design.
- Numeração automática de `ZA1_IDCH` não confirmada no dicionário de dados nesta rodada - **precisa ser confirmada antes ou durante a implementação** (consulta SX3, ou teste direto em ambiente de homologação).
- `CNSA_APOSCOMMIT` também dispara e-mail de designação de técnico na Alteração (`nOper==4`) - não confirmado se o mesmo acontece na Inclusão (`nOper==3`) hoje; se não acontecer, o REST continua chamando `CNSA_DISPARA_DESIGNACAO` explicitamente após o `CommitData()`, como já faz hoje.
- Sem checagem de autenticação/token adicional neste endpoint - mesma situação de tudo que já existe no módulo CNSA hoje (não é regressão).
