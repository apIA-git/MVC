# CNS001 - Eliminar redundância entre REST (intraweb) e Protheus nativo (CNSA001/CNSA003/CNSAZA2VIEW)

## Contexto

`CNS001.tlpp` (Codigos apia intraweb henrique) expõe a API REST do portal `apia.com.br/intraweb` pra Chamados (ZA1), migrada de WSRESTFUL pra anotações TLPP. Hoje **todas** as operações de escrita (Incluir, Alterar, Assumir, Excluir, Agendar, Anotar) reimplementam a gravação na mão (`RecLock`/`DbDelete` direto), em paralelo à lógica nativa do Protheus:

- `CNSA001.PRW` (Fontes cnshub) - tela clássica de Chamados (ZA1), MVC completo (`ModelDef`/`ViewDef`/`MenuDef`, `MPFormModel` `FCNSA001`, grids ZA2DETAIL/SZ6DETAIL).
- `CNSA003.prw` + `CNSA003REST.tlpp` (agenda/SZ6) - já resolvido nesse padrão: `cnsa003inc` (`@Post("/cnsa003inc")`) grava via `FWLoadModel("CNSA003")` + `SetOperation(MODEL_OPERATION_INSERT)` + `SetValue` + `VldData()`/`CommitData()`, em vez de `RecLock` manual - documentado ali como alternativa ao endpoint genérico `/rest/FwModel/agenda` do `PUBLISH MODEL REST`, que **não executa os gatilhos SX7**.
- `CNSAZA2VIEW.PRW` - Model filho do chamado (ZA1), tela de anotações (ZA2), aberta via `FWExecView` a partir de `CNSA_INTERAGIR` (`CNSA001.PRW`).

Motivação (pedido do usuário): eliminar toda essa redundância - tudo que for possível fazer chamando a lógica nativa do Protheus (Model/gatilho) deve ser feito assim; o que não existir de forma reaproveitável deve ser **criado** no lado nativo e então chamado pelos dois lados (tela clássica e REST).

Durante a investigação, confirmamos 2 gatilhos SX7 reais na ZA1 (`CNSA_CLIENTE` → preenche `ZA1_NOME`, `CNSA_TECNICO` → preenche `ZA1_NOMTEC`) e 3 na SZ6 (`CNS003NTec`, `CNS003NCli`, `CNS003DtLg`, já usados por `cnsa003inc`) - nenhum deles dispara hoje nas gravações via `RecLock` manual do REST, e alguns nem disparam nas próprias rotinas nativas que também bypassam o Model (`CNSA_ASSUMIR` e `CNSA_EXCLUIR`, ambas em `CNSA001.PRW`, fazem `RecLock` direto). Ou seja: parte da redundância é REST-vs-nativo, parte é um problema que já existe no nativo e o REST só copiou.

## Escopo

**Dentro**: as 6 operações de escrita do módulo Chamados no REST intraweb passam a persistir via Model nativo sempre que possível:

| Operação | Endpoint REST | Model usado |
|---|---|---|
| Incluir | `@Post /CNSACHAMADOSINCLUIR` | `FWLoadModel("CNSA001")` |
| Alterar | `@Post /CNSACHAMADOSALTERAR` | `FWLoadModel("CNSA001")` |
| Assumir | `@Post /CNSACHAMADOSASSUMIR` | `FWLoadModel("CNSA001")` |
| Excluir | `@Post /CNSACHAMADOSEXCLUIR` | núcleo novo em `CNSA001.PRW` (ver seção Excluir) |
| Anotar | `@Post /CNSACHAMADOSANOTACOESINCLUIR` | `FWLoadModel("CNSAZA2VIEW")` |
| Agendar | `@Post /CNSACHAMADOSAGENDAR` | `FWLoadModel("CNSA003")` (só o insert de cada dia - orquestração TLPP mantida) |

Contrato JSON de todos os 6 endpoints não muda - mesma URL, mesmos parâmetros de entrada, mesmo formato de resposta.

**Fora**: `CNSA_ASSUMIR` e `CNSA_EXCLUIR` nativos (tela clássica, `CNSA001.PRW`) - exceto a extração do núcleo compartilhado de Excluir (ver seção Excluir) - não são reescritos pra usar o Model; o comportamento visual/dialogs da tela clássica não muda. Listagem (`CNSA_CHAMADOS_LISTAR`, `@Get`) não entra - é leitura, sem redundância de gravação a eliminar, decisão já documentada no próprio arquivo (SQL direto por performance/joins). `CNSA_FIXEMAILUTF8` (utilitário pontual de correção de encoding) não entra.

## Flag headless (`lCnsaViaRest`) - compartilhada por Incluir/Alterar/Assumir

`CNSA_APOSCOMMIT` (`CNSA001.PRW`, Pós-Validação do Model, bloco `nOper == 3 .Or. nOper == 4`) sempre chama `MsgYesNo` perguntando se quer criar um agendamento quando o chamado tem técnico definido - modal de UI, não pode rodar num job REST sem tela.

**Decisão confirmada com o usuário**: no REST, todas as 3 operações que passam por esse bloco (Incluir, Alterar, Assumir) devem responder "sim" automaticamente, sem perguntar - mesmo em edições triviais que não tocam o técnico. É uma decisão consciente (não um bug): o Model nativo já pergunta isso em toda Inclusão/Alteração com técnico definido, então herdar o mesmo comportamento (só que sem modal) é consistente com o nativo, ainda que gere um novo registro SZ6 a cada save.

```advpl
// Em CNSA_APOSCOMMIT, no lugar do "If MsgYesNo(cPergAgenda, "Agendar Chamado")":
Local lViaRest := (Type("lCnsaViaRest") == "L" .And. lCnsaViaRest)

If lViaRest .Or. MsgYesNo(cPergAgenda, "Agendar Chamado")
    // ... corpo que já existe, sem alteração ...
EndIf
```

`lCnsaViaRest` é `Public`, setada como `.T.` no início de `CNSA_INCLUIR`/`CNSA_ALTERAR`/`CNSA_ASSUMIR` (dentro de `CNS001.tlpp`) antes do `Activate()`, e limpa (`:= .F.`) no fim de cada uma (sucesso ou erro) pra não vazar estado entre requisições na mesma sessão/thread. Não existe no fluxo da tela clássica - `Type("lCnsaViaRest") == "L"` cobre esse caso (variável nunca declarada → comportamento antigo, pergunta normal).

**Risco conhecido**: `Public` é mecanismo simples mas frágil nesse ponto - **assunção a validar na implementação**: confirmar se cada request REST roda em thread/sessão isolada (nesse caso o risco de vazamento é baixo) ou se pode haver reentrância problemática.

## Incluir

1. Validações de entrada continuam iguais (`Empty(cAssunto)`, `Empty(cTipo)`, `Empty(cProjeto)`, `Empty(cTarefa)` → 400), assim como os defaults (`cLojaCliente:="01"`, `cDtAbertura` default hoje, `cCodConsultor` auto-preenchido pelo técnico da sessão se vazio).
2. `Public lCnsaViaRest := .T.`
3. `oModel := FWLoadModel("CNSA001")` → `SetOperation(MODEL_OPERATION_INSERT)` → `Activate()`.
4. `oModelZA1 := oModel:GetModel("ZA1MASTER")` → `SetValue(...)` pra cada campo (tabela de mapeamento abaixo). `ZA1_IDCH` só é setado manualmente se a numeração **não** for automática no SX3 (ver seção Numeração).
5. `If oModel:VldData() ; lOk := oModel:CommitData() ; EndIf`
6. Se `!lOk`: erro a partir de `oModel:GetErrorMessage()` (tratamento C/O/A igual ao `cnsa003inc`), retorna `{400,...}`.
7. Se `lOk`: recupera `cIdCh` via `oModelZA1:GetValue("ZA1_IDCH")`, chama `CNSA_DISPARA_DESIGNACAO(cIdCh, cCodConsultor)` (mantido explícito - ver observação abaixo), retorna `{200,...}` no formato de hoje.
8. `oModel:DeActivate(lOk)`; `lCnsaViaRest := .F.`.
9. `Begin Sequence`/`Recover Using oErro` mantido - erro inesperado retorna 500.

**Observação confirmada**: `CNSA_APOSCOMMIT` só dispara e-mail de designação de técnico dentro do bloco `If nOper == 4` (Alteração) - **não** existe esse envio em `nOper == 3` (Inclusão) hoje. Por isso `CNSA_DISPARA_DESIGNACAO` continua sendo chamada explicitamente pelo REST após o `CommitData()` do Incluir - não é redundância, é a única fonte desse e-mail nesse fluxo.

### Mapeamento de campos (Incluir)

| Campo ZA1 | Origem |
|---|---|
| `ZA1_FILIAL` | `xFilial("ZA1")` |
| `ZA1_IDCH` | `GetSxeNum`/model auto - ver Numeração |
| `ZA1_ASSUNT` | `cAssunto` |
| `ZA1_DATA` | `STOD(cDtAbertura)` |
| `ZA1_STATUS` | fixo `"1"` |
| `ZA1_TIPO` | `cTipo` |
| `ZA1_CLIENT` | `cCodCliente` |
| `ZA1_LOJA` | `cLojaCliente` (default "01") |
| `ZA1_EMAIL` | `cEmailCliente` |
| `ZA1_CONSUL` | `cCodConsultor` (auto-preenchido se vazio) |
| `ZA1_PROJ` | `cProjeto` |
| `ZA1_TAREFA` | `cTarefa` |
| `ZA1_MOD` | `Date()` |

Gatilhos `CNSA_CLIENTE`/`CNSA_TECNICO` disparam automaticamente no `CommitData()`, preenchendo `ZA1_NOME`/`ZA1_NOMTEC` - **corrige bug de dados real**: hoje esses 2 campos ficam em branco nos chamados criados via REST (só existiam preenchidos nos criados pela tela clássica).

### Numeração `ZA1_IDCH`

Não confirmado nesta rodada (sem acesso a consulta SQL no dicionário de dados) se `ZA1_IDCH` tem numeração automática no SX3. **Assunção a validar na implementação**:

- Se for automática: remove `GetSxeNum`/`ConfirmSX8` do REST, deixa o model gerar, recupera via `oModelZA1:GetValue("ZA1_IDCH")` após `CommitData()`.
- Se não for: mantém `cIdCh := GetSxeNum("ZA1","ZA1_IDCH")` antes do `SetValue`, e chama `ConfirmSX8()` depois do `CommitData()` bem-sucedido (`RollBackSX8()` no `Recover`).

## Alterar

1. Validações de entrada continuam (`Empty(cIdCh)` → 400, `lTemAlgumCampo` → 400 se nenhum campo veio).
2. Posiciona ZA1 **antes** de ativar o model (UPDATE exige registro já posicionado - o Model carrega os valores da posição atual da workarea): `dbSelectArea("ZA1")` → `DbSetOrder(1)` → `DbSeek(xFilial+cIdCh)` → 404 se não achar.
3. Pré-check mantido: `ZA1->ZA1_STATUS == "4"` → 400 "chamado fechado não pode ser alterado" (regra exclusiva do REST - a tela clássica não tem esse bloqueio hoje, então não é redundância a eliminar, fica como está).
4. Captura `cConsultorAnterior := AllTrim(ZA1->ZA1_CONSUL)` antes de tocar no model (mesma lógica de hoje, pra decidir se dispara e-mail).
5. `Public lCnsaViaRest := .T.` → `oModel := FWLoadModel("CNSA001")` → `SetOperation(MODEL_OPERATION_UPDATE)` → `Activate()`.
6. `SetValue` só nos campos que vieram preenchidos (mesma lógica parcial atual), incluindo `lLimparCliente`/`lLimparConsultor` (`SetValue(...,"")` explícito quando a flag vier true).
7. `VldData()`/`CommitData()` - erro vira 400; sucesso vira 200 no formato de hoje.
8. `oModel:DeActivate(lOk)`; `lCnsaViaRest := .F.`.
9. **Remove** a chamada própria a `CNSA_DISPARA_DESIGNACAO` - `CNSA_APOSCOMMIT` (`nOper==4`) já dispara e-mail de redesignação nativamente quando `ZA1_CONSUL` muda; chamar os dois seria e-mail duplicado.

Gatilhos `CNSA_CLIENTE`/`CNSA_TECNICO` também disparam aqui (mesma correção de `ZA1_NOME`/`ZA1_NOMTEC` do Incluir, agora valendo pra alteração).

## Assumir

1. Pré-validações de negócio mantidas como estão (não existem em nenhum outro lugar reaproveitável - nem no Model, nem limpo na tela clássica): `Empty(cIdCh)` → 400, técnico da sessão vinculado (`AA1`) → 400 se não, chamado existe (404), sem consultor já designado → 400, status não é "4"/"2"/"3" → 400, cliente/projeto/tarefa definidos → 400, projeto em fase "03" → 400.
2. Depois do pré-check passar, ZA1 já está posicionado no registro certo (pelo `DbSeek` do pré-check). `Public lCnsaViaRest := .T.` → `oModel := FWLoadModel("CNSA001")` → `SetOperation(MODEL_OPERATION_UPDATE)` → `Activate()`.
3. `SetValue("ZA1_CONSUL", cConsultorSessao)`, `SetValue("ZA1_STATUS", "2")`.
4. `VldData()`/`CommitData()` → erro 400/sucesso 200 (mesmo formato de hoje: `sucesso`, `idCh`, `status`, `tecnico`).
5. `oModel:DeActivate(lOk)`; `lCnsaViaRest := .F.`.
6. **Remove** a chamada própria a `CNSA_DISPARA_DESIGNACAO` - `CNSA_APOSCOMMIT` (`nOper==4`) dispara e-mail de designação nativamente (`ZA1_CONSUL` mudou de vazio pra preenchido).

Gatilho `CNSA_TECNICO` dispara (`ZA1_NOMTEC` passa a ser preenchido) - correção que nem a tela clássica tem hoje, já que `CNSA_ASSUMIR` nativo (`CNSA001.PRW`) também faz `RecLock` direto, bypassando o Model. Essa spec **não** toca a rotina nativa `CNSA_ASSUMIR` (fora de escopo) - só o lado REST passa a usar o Model.

## Excluir

Não existe núcleo nativo Model-driven reaproveitável: nem a tela clássica usa `MODEL_OPERATION_DELETE` (`CNSA_CAN`, o Cancel do Model, é stub - só `Return .T.`) - `CNSA_EXCLUIR` (PRW, UI) e `CNSA_POSCOMMIT_EXCLUIR` (PRW) fazem `RecLock`/`DbDelete` direto, e o REST (`Static Function CNSA_EXCLUIR` em `CNS001.tlpp`) reimplementa a mesma cascata separadamente.

**Solução**: criar `User Function CNSA_EXCLUINUCLEO(cIdCh, cMotivo)` em `CNSA001.PRW` - parâmetros explícitos, sem `Public`, sem `MsgYesNo`/`MsgAlert`. Consolida a cascata hoje duplicada nos 2 lados:

1. Busca ZA1 por `cIdCh` (`DbSeek`) - se não achar, retorna erro estruturado (`{lOk:.F., cErro:"Chamado nao encontrado."}` ou equivalente - formato exato a definir na implementação, compatível com os 2 chamadores).
2. Captura `cConsulAnterior`/`cClienteAnterior`/`cLojaAnterior` antes de apagar.
3. Se `!Empty(cConsulAnterior) .And. Empty(cMotivo)` → erro "motivo obrigatório quando tem técnico designado" (regra já existente nos 2 lados hoje).
4. Busca data/horário do agendamento mais recente (contexto do e-mail) - mesma lógica de `CNSA_POSCOMMIT_EXCLUIR`/`Static Function CNSA_EXCLUIR` (TLPP) hoje.
5. `RecLock("ZA1",.F.)` → `DbDelete()` → `MsUnlock()` (mantém `RecLock` direto - criar um `MODEL_OPERATION_DELETE` de verdade exigiria implementar `CNSA_CAN`/regras de cancelamento no Model, escopo maior que o pedido atual).
6. Remove cascata de agendamentos (SZ6) vinculados - mesma query/`RecLock` de hoje.
7. Se tinha técnico designado, envia e-mail de cancelamento (`CNSA_CANCEL_FRONT` + `CNSA_ENVIAEMAIL`, ambas já existem no PRW).
8. Retorna sucesso.

**Chamadores depois da mudança**:
- Tela clássica `CNSA_EXCLUIR` (PRW) - mantém o `MSDIALOG` de motivo (UI), e no OK chama `CNSA_EXCLUINUCLEO(cIdChAnterior, cMotivoExclusao)` em vez de `RecLock`+`CNSA_POSCOMMIT_EXCLUIR` inline.
- REST `CNSA_CHAMADOS_EXCLUIR`/`Static Function CNSA_EXCLUIR` (`CNS001.tlpp`) - valida `idCh`/`motivo` básicos (400 se faltar) e chama `CNSA_EXCLUINUCLEO(cIdCh, cMotivo)`, traduzindo o retorno pro `{status, json}` do padrão REST atual.

`CNSA_EMAIL_FRONT`/`CNSA_CANCEL_FRONT`/`CNSA_ENVIAEMAIL`/`CNSA_JSONESC` já existem duplicadas entre PRW e TLPP (cada lado tem sua cópia) - **fora de escopo** consolidar essas (são helpers de template/e-mail, não persistência; risco de quebrar algo em cada lado por pouco ganho). Só a cascata de negócio (validar/apagar/notificar) é consolidada.

## Anotar (ZA2)

`CNSAZA2VIEW.PRW` é um Model filho do chamado (ZA1) - tela de anotações, sem `PreValidacao`/`PosValidacao`/gatilho nenhum (tudo `NIL` no `ModelDef`). Não há bug de gatilho a corrigir aqui - a mudança é só consistência de caminho (mesmo Model que a tela clássica usa via `FWExecView`, sem o dialog).

`CNSA_ZA2_GRAVAR(nChamN, cConsultor, cTexto)` (compartilhada entre a inclusão manual de anotação e o import automático de e-mail em `CNSA_GERACHAM`) troca:

1. Sequência (`ZA2_IDGRID`) continua calculada como hoje (`MAX(ZA2_IDGRID)+1` via SQL) - não é gatilho SX7, é cálculo manual mesmo na tela clássica (via `GETIDGRID`, chamado antes do `FWExecView`).
2. `oModel := FWLoadModel("CNSAZA2VIEW")` → `SetOperation(MODEL_OPERATION_INSERT)` → `Activate()`.
3. `oModel:GetModel("ZA2MASTER"):SetValue(...)` pra `ZA2_FILIAL`, `ZA2_IDCH`, `ZA2_IDGRID`, `ZA2_CONSUL`, `ZA2_DATA`, `ZA2_HORA`, `ZA2_DESCRI`.
4. `VldData()`/`CommitData()`/`DeActivate(lOk)` - erro vira `.F.`/mensagem (mesma assinatura de retorno de hoje, `StrZero(nSeq,3)` em caso de sucesso).

Sem flag headless necessária (esse Model não tem `MsgYesNo`/dialog nenhum).

## Agendar (híbrido)

`CNSA_AGENDAR` tem orquestração própria que **não existe na tela clássica** - intervalo de datas (1 registro SZ6 por dia), lock por técnico (`LockByName`/`UnLockByName`), checagem de sobreposição de horário (`CNSA_VERIFICASOBREPOSICAO`), retry de 3 tentativas em caso de chave duplicada. Isso é valor agregado do REST, não redundância - **mantido 100% como está**.

**Nota**: o comentário no código referencia um spec anterior (`2026-07-30-agendamento-sequence-race-fix-design.md`) que documentaria esse desenho de lock/retry - procurado em todos os branches do repositório e não encontrado (provavelmente nunca foi commitado). Esta spec não contradiz nada dele porque não foi possível localizá-lo - a lógica de lock/retry é tratada aqui só pela leitura direta do código atual.

Troca **só o bloco de gravação individual** (dentro do retry, hoje um `RecLock("SZ6",...)` de ~20 campos) por:

1. `cSeq := CNSA_PROXSEQ_SZ6(cCodTecnico, dAtual)` (mantido - já calcula a sequência antes do bloco).
2. `oModel := FWLoadModel("CNSA003")` → `SetOperation(MODEL_OPERATION_INSERT)` → `Activate()`.
3. `oModel:GetModel("ModelSZ6_Main"):SetValue(...)` pra todos os campos hoje setados via `RecLock` (`Z6_FILIAL`, `Z6_CHAMADO`, `Z6_DTAGE`, `Z6_TECNICO`, `Z6_SEQ` com o `cSeq` já calculado, `Z6_HMINI`, `Z6_HMFIM`, `Z6_CLIENTE`, `Z6_LOJA`, `Z6_SERVICO`, `Z6_CONFIRM`, `Z6_TURNO`, `Z6_INTERNO`, `Z6_COBRAR`, `Z6_TIPOAG`, `Z6_PROJET`, `Z6_REVISA`, `Z6_TAREFA`, `Z6_TIPO_HR`, `Z6_QGRAVOU`).
4. `If oModel:VldData() ; lOk := oModel:CommitData() ; EndIf` → `oModel:DeActivate(lOk)`.
5. Falha (chave duplicada ou outra) continua caindo no `Recover Using oErroDia` do laço de retry existente, recalculando `cSeq` na próxima tentativa - mesma estrutura de hoje, só troca o corpo de dentro do `Begin Sequence`.

Não chama o gatilho `U_CNS003Seq()` (como o `cnsa003inc` faz) porque `cSeq` já vem calculado por `CNSA_PROXSEQ_SZ6` (cálculo equivalente, MAX+1, só que via `%Table:SZ6%` embedded SQL em vez de `DbSeek`/`DbSkip`) - evita calcular a mesma coisa duas vezes. Gatilhos `CNS003NTec`/`CNS003NCli`/`CNS003DtLg` disparam normalmente no `CommitData()` (dependem de `Z6_TECNICO`/`Z6_CLIENTE`/`Z6_LOJA`/`Z6_DTAGE`, não de `Z6_SEQ`) - **corrige bug de dados real**: hoje `Z6_NOMTEC`/`Z6_NOMCLI`/`Z6_DATA` (legado) ficam em branco nos agendamentos criados via REST.

## Fora de escopo / riscos conhecidos

- `CNSA_ASSUMIR` nativo (`CNSA001.PRW`, tela clássica) continua com `RecLock` direto - não é tocado nesta spec. Só o lado REST passa a usar o Model.
- Numeração automática de `ZA1_IDCH` não confirmada no dicionário de dados nesta rodada - **precisa ser confirmada antes ou durante a implementação**.
- `lCnsaViaRest` como `Public` - risco de vazamento de estado entre chamadas na mesma sessão/thread se a limpeza no fim de cada função falhar (ex: exceção não tratada antes do `:= .F.`). Mitigação: colocar a limpeza também dentro do `Recover`, não só no caminho de sucesso.
- Toda Alteração/Assumir com técnico definido passa a criar uma agenda SZ6 nova automaticamente (decisão confirmada) - pode gerar múltiplos registros se o usuário salvar várias vezes seguidas. Comportamento aceito conscientemente.
- `CNSA_EMAIL_FRONT`/`CNSA_CANCEL_FRONT`/`CNSA_ENVIAEMAIL`/`CNSA_JSONESC` continuam duplicadas entre PRW e TLPP - fora de escopo consolidar (ver seção Excluir).
- Spec de agendamento (`2026-07-30-agendamento-sequence-race-fix-design.md`) referenciada no código não foi encontrada em nenhum branch - tratado como não-existente para efeitos desta spec.
- Sem checagem de autenticação/token adicional em nenhum dos 6 endpoints - mesma situação de tudo que já existe no módulo CNSA hoje (não é regressão).
