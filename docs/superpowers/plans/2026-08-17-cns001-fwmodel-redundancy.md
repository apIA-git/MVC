# CNS001 - Eliminar Redundância REST vs FWModel Nativo - Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fazer as 6 operações de escrita do módulo Chamados no REST intraweb (`CNS001.tlpp`) persistirem via `FWLoadModel` nativo do Protheus (`CNSA001`, `CNSA003`, `CNSAZA2VIEW`) em vez de `RecLock` manual, eliminando redundância e corrigindo gatilhos SX7 que hoje nunca disparam.

**Architecture:** Cada função de escrita em `CNS001.tlpp` passa a instanciar o Model correspondente (`FWLoadModel` → `SetOperation` → `Activate` → `SetValue` → `VldData`/`CommitData` → `DeActivate`), no lugar do `RecLock` direto. Uma flag `Public lCnsaViaRest` sinaliza pro `CNSA_APOSCOMMIT` (Pós-Validação do Model, em `CNSA001.PRW`) que a chamada é headless (sem tela), pulando o `MsgYesNo` de agendamento. Pra Excluir (sem Model-delete nativo reaproveitável), cria-se um núcleo novo compartilhado (`CNSA_EXCLUINUCLEO`) chamado pelos dois lados (tela clássica e REST).

**Tech Stack:** AdvPL/TLPP, Protheus MVC (`MPFormModel`/`FWFormModel`), TLPP REST annotations (`@Post`), Oracle via `BeginSql`/`%Table%`/`%Exp%`.

## Global Constraints

- Contrato JSON dos 6 endpoints REST não muda - mesma URL, mesmos parâmetros de entrada, mesmo formato de resposta (spec: `docs/superpowers/specs/2026-08-17-cns001-incluir-fwmodel-design.md`).
- `lCnsaViaRest` é `Public`, seta `.T.` antes do `Activate()`, limpa `:= .F.` no fim de cada função (sucesso **e** erro - inclusive dentro do `Recover`).
- Todo arquivo `.PRW`/`.tlpp` editado por este plano precisa ser convertido de UTF-8 pra CP1252 antes de compilar - usar skill `utf8-to-cp1252-conversion` depois de cada edição, antes do passo de compilação.
- Compilação via skill `advpl-tlpp-compile` é o critério de "passou" de cada task (não há framework de teste automatizado nesse código AdvPL/TLPP) - depois da compilação, valida-se com uma chamada `curl` no endpoint REST e o retorno JSON esperado.
- Nenhum arquivo além de `Codigos apia intraweb henrique/CNS001.tlpp` e `Fontes cnshub/CNSA001.PRW` é criado ou modificado.

---

## Task 1: Flag headless no `CNSA_APOSCOMMIT` (pré-requisito de Incluir/Alterar/Assumir)

**Files:**
- Modify: `Fontes cnshub/CNSA001.PRW` (função `Static Function CNSA_APOSCOMMIT`, declarações `Local` no topo + bloco `If MsgYesNo(cPergAgenda, "Agendar Chamado")`)

**Interfaces:**
- Produces: contrato "se a variável `Public lCnsaViaRest` existir e for `.T.` no momento do commit, `CNSA_APOSCOMMIT` cria a agenda automaticamente sem perguntar" - usado pelas Tasks 2, 3 e 4.

- [ ] **Step 1: Adicionar declaração da flag**

Na lista de `Local` no topo de `CNSA_APOSCOMMIT` (depois de `Local nCham := 0`), adicionar:

```advpl
    Local lViaRest    := (Type("lCnsaViaRest") == "L" .And. lCnsaViaRest)
```

- [ ] **Step 2: Trocar a condição do `MsgYesNo`**

Localizar (dentro do bloco `If nOper == 3 .Or. nOper == 4` → `If !Empty(cTecnicoAp)`):

```advpl
            If MsgYesNo(cPergAgenda, "Agendar Chamado")
```

Substituir por:

```advpl
            If lViaRest .Or. MsgYesNo(cPergAgenda, "Agendar Chamado")
```

O restante do bloco (captura de `cClienteAp`/`cLojaAp`/etc e chamada a `CNSA_CRIAAGENDA_INT`) não muda.

- [ ] **Step 3: Converter encoding e compilar**

Usar skill `utf8-to-cp1252-conversion` em `Fontes cnshub/CNSA001.PRW`, depois skill `advpl-tlpp-compile` pra esse fonte. Esperado: compila sem erro (a variável `lCnsaViaRest` não precisa existir em lugar nenhum - `Type()` trata variável não declarada retornando `"U"`, cobrindo o fluxo da tela clássica sem quebrar).

- [ ] **Step 4: Commit**

```bash
git add "Fontes cnshub/CNSA001.PRW"
git commit -m "feat: adiciona flag headless lCnsaViaRest no CNSA_APOSCOMMIT pra pular MsgYesNo de agendamento via REST"
```

---

## Task 2: `CNSA_INCLUIR` via `FWLoadModel("CNSA001")`

**Files:**
- Modify: `Codigos apia intraweb henrique/CNS001.tlpp` (função `Static Function CNSA_INCLUIR`)

**Interfaces:**
- Consumes: flag `lCnsaViaRest` da Task 1; `CNSA_DISPARA_DESIGNACAO(cIdCh, cCodConsultorNovo)` (já existe no mesmo arquivo, assinatura inalterada); `CNSA_JSONESC`/`EncodeUtf8` (já existem).
- Produces: `Static Function CNSA_INCLUIR(cAssunto, cDtAbertura, cTipo, cCodCliente, cLojaCliente, cEmailCliente, cCodConsultor, cProjeto, cTarefa)` retornando `{nStatusHttp, cCorpoJson}` - assinatura e contrato inalterados (mesmos usados pelo `CNSA_CHAMADOS_INCLUIR`, não precisa tocar nesse wrapper).

- [ ] **Step 1: Substituir o miolo de gravação**

Localizar o trecho (dentro de `Static Function CNSA_INCLUIR`, depois dos `If Empty(...)` de validação e do `Default cLojaCliente := "01"` / cálculo de `cDtAbertura`/`cCodConsultor`):

```advpl
        cIdCh := GetSxeNum("ZA1", "ZA1_IDCH")

        RecLock("ZA1", .T.)
            ZA1->ZA1_FILIAL := xFilial("ZA1")
            ZA1->ZA1_IDCH   := cIdCh
            ZA1->ZA1_ASSUNT := cAssunto
            ZA1->ZA1_DATA   := STOD(cDtAbertura)
            ZA1->ZA1_STATUS := "1"
            ZA1->ZA1_TIPO   := cTipo
            ZA1->ZA1_CLIENT := cCodCliente
            ZA1->ZA1_LOJA   := cLojaCliente
            ZA1->ZA1_EMAIL  := cEmailCliente
            ZA1->ZA1_CONSUL := cCodConsultor
            ZA1->ZA1_PROJ   := cProjeto
            ZA1->ZA1_TAREFA := cTarefa
            ZA1->ZA1_MOD    := Date()
        ZA1->(MsUnlock())

        ConfirmSX8()

        CNSA_DISPARA_DESIGNACAO(cIdCh, cCodConsultor)

        oJson['sucesso']  := .T.
        oJson['idCh']     := cIdCh
        oJson['mensagem'] := "Chamado incluido com sucesso."

        Return {200, oJson:ToJson()}

    Recover Using oErro
        RollBackSX8()
        Return {500, '{"erro":"' + CNSA_JSONESC(EncodeUtf8(oErro:Description)) + '"}'}
    End Sequence
```

Substituir por:

```advpl
        cIdCh := GetSxeNum("ZA1", "ZA1_IDCH")

        Public lCnsaViaRest := .T.

        oModel    := FWLoadModel("CNSA001")
        oModel:SetOperation(MODEL_OPERATION_INSERT)
        oModel:Activate()
        oModelZA1 := oModel:GetModel("ZA1MASTER")

        oModelZA1:SetValue("ZA1_FILIAL", xFilial("ZA1"))
        oModelZA1:SetValue("ZA1_IDCH",   cIdCh)
        oModelZA1:SetValue("ZA1_ASSUNT", cAssunto)
        oModelZA1:SetValue("ZA1_DATA",   STOD(cDtAbertura))
        oModelZA1:SetValue("ZA1_STATUS", "1")
        oModelZA1:SetValue("ZA1_TIPO",   cTipo)
        oModelZA1:SetValue("ZA1_CLIENT", cCodCliente)
        oModelZA1:SetValue("ZA1_LOJA",   cLojaCliente)
        oModelZA1:SetValue("ZA1_EMAIL",  cEmailCliente)
        oModelZA1:SetValue("ZA1_CONSUL", cCodConsultor)
        oModelZA1:SetValue("ZA1_PROJ",   cProjeto)
        oModelZA1:SetValue("ZA1_TAREFA", cTarefa)
        oModelZA1:SetValue("ZA1_MOD",    Date())

        If oModel:VldData()
            lOk := oModel:CommitData()
        EndIf

        If !lOk
            cErroModel := oModel:GetErrorMessage()
            Do Case
                Case ValType(cErroModel) == "C"
                    cErro := cErroModel
                Case ValType(cErroModel) == "O"
                    cErro := cErroModel:GetMessage()
                Case ValType(cErroModel) == "A"
                    cErro := FwJsonSerialize(cErroModel)
                Otherwise
                    cErro := "Falha ao validar/gravar o chamado."
            EndCase
        EndIf

        oModel:DeActivate(lOk)
        lCnsaViaRest := .F.

        If !lOk
            ConfirmSX8(.F.)
            Return {400, '{"erro":"' + CNSA_JSONESC(EncodeUtf8(cErro)) + '"}'}
        EndIf

        ConfirmSX8()

        CNSA_DISPARA_DESIGNACAO(cIdCh, cCodConsultor)

        oJson['sucesso']  := .T.
        oJson['idCh']     := cIdCh
        oJson['mensagem'] := "Chamado incluido com sucesso."

        Return {200, oJson:ToJson()}

    Recover Using oErro
        lCnsaViaRest := .F.
        RollBackSX8()
        Return {500, '{"erro":"' + CNSA_JSONESC(EncodeUtf8(oErro:Description)) + '"}'}
    End Sequence
```

- [ ] **Step 2: Adicionar as novas `Local` no topo da função**

No topo de `Static Function CNSA_INCLUIR`, junto das `Local` já existentes (`cIdCh`, `oJson`, `oErro`), adicionar:

```advpl
    Local oModel    := Nil
    Local oModelZA1 := Nil
    Local lOk       := .F.
    Local cErro     := ""
    Local cErroModel := Nil
```

- [ ] **Step 3: Converter encoding e compilar**

Skill `utf8-to-cp1252-conversion` em `Codigos apia intraweb henrique/CNS001.tlpp`, depois skill `advpl-tlpp-compile`.

- [ ] **Step 4: Testar via curl**

```bash
curl -X POST "http://<servidor>:<porta>/rest/CNSACHAMADOSINCLUIR?assunto=Teste%20FWModel&tipo=1&projeto=000001&tarefa=001"
```

Esperado: `{"sucesso":true,"idCh":"NNNNNN","mensagem":"Chamado incluido com sucesso."}`, status 200. Confirmar no banco (`SELECT ZA1_NOME, ZA1_NOMTEC FROM ZA1 WHERE ZA1_IDCH = 'NNNNNN'`) que `ZA1_NOME`/`ZA1_NOMTEC` vieram preenchidos se `codCliente`/`codConsultor` tiverem sido informados (confirma que o gatilho disparou).

- [ ] **Step 5: Commit**

```bash
git add "Codigos apia intraweb henrique/CNS001.tlpp"
git commit -m "feat: CNSA_INCLUIR passa a gravar chamado via FWLoadModel(CNSA001) em vez de RecLock manual"
```

---

## Task 3: `CNSA_ALTERAR` via `FWLoadModel("CNSA001")` + `MODEL_OPERATION_UPDATE`

**Files:**
- Modify: `Codigos apia intraweb henrique/CNS001.tlpp` (função `Static Function CNSA_ALTERAR`)

**Interfaces:**
- Consumes: flag `lCnsaViaRest` (Task 1).
- Produces: assinatura inalterada - `Static Function CNSA_ALTERAR(cIdCh, cAssunto, cDtAbertura, cTipo, cCodCliente, cLojaCliente, cEmailCliente, cCodConsultor, cProjeto, cTarefa, lLimparCliente, lLimparConsultor)` retornando `{nStatusHttp, cCorpoJson}`.

- [ ] **Step 1: Substituir o miolo de gravação**

Localizar:

```advpl
        cConsultorAnterior := AllTrim(ZA1->ZA1_CONSUL)

        RecLock("ZA1", .F.)
            If !Empty(cAssunto)
                ZA1->ZA1_ASSUNT := cAssunto
            EndIf
            If !Empty(cDtAbertura)
                ZA1->ZA1_DATA := STOD(StrTran(cDtAbertura, "-", ""))
            EndIf
            If !Empty(cTipo)
                ZA1->ZA1_TIPO := cTipo
            EndIf
            If lLimparCliente
                ZA1->ZA1_CLIENT := ""
                ZA1->ZA1_LOJA   := ""
            ElseIf !Empty(cCodCliente)
                ZA1->ZA1_CLIENT := cCodCliente
                ZA1->ZA1_LOJA   := If(Empty(cLojaCliente), "01", cLojaCliente)
            EndIf
            If !Empty(cEmailCliente)
                ZA1->ZA1_EMAIL := cEmailCliente
            EndIf
            If lLimparConsultor
                ZA1->ZA1_CONSUL := ""
            ElseIf !Empty(cCodConsultor)
                ZA1->ZA1_CONSUL := cCodConsultor
            EndIf
            If !Empty(cProjeto)
                ZA1->ZA1_PROJ := cProjeto
            EndIf
            If !Empty(cTarefa)
                ZA1->ZA1_TAREFA := cTarefa
            EndIf
            ZA1->ZA1_MOD := Date()
        ZA1->(MsUnlock())

        // Redesignacao: so dispara e-mail se o consultor mudou de verdade
        // (evita reenviar e-mail toda vez que o formulario e salvo sem
        // trocar o tecnico).
        If !Empty(cCodConsultor) .And. cCodConsultor <> cConsultorAnterior
            CNSA_DISPARA_DESIGNACAO(cIdCh, cCodConsultor)
        EndIf

        oJson['sucesso']  := .T.
        oJson['idCh']     := cIdCh
        oJson['mensagem'] := "Chamado alterado com sucesso."

        Return {200, oJson:ToJson()}

    Recover Using oErro
        Return {500, '{"erro":"' + CNSA_JSONESC(EncodeUtf8(oErro:Description)) + '"}'}
    End Sequence
```

Substituir por:

```advpl
        cConsultorAnterior := AllTrim(ZA1->ZA1_CONSUL)

        Public lCnsaViaRest := .T.

        oModel    := FWLoadModel("CNSA001")
        oModel:SetOperation(MODEL_OPERATION_UPDATE)
        oModel:Activate()
        oModelZA1 := oModel:GetModel("ZA1MASTER")

        If !Empty(cAssunto)
            oModelZA1:SetValue("ZA1_ASSUNT", cAssunto)
        EndIf
        If !Empty(cDtAbertura)
            oModelZA1:SetValue("ZA1_DATA", STOD(StrTran(cDtAbertura, "-", "")))
        EndIf
        If !Empty(cTipo)
            oModelZA1:SetValue("ZA1_TIPO", cTipo)
        EndIf
        If lLimparCliente
            oModelZA1:SetValue("ZA1_CLIENT", "")
            oModelZA1:SetValue("ZA1_LOJA", "")
        ElseIf !Empty(cCodCliente)
            oModelZA1:SetValue("ZA1_CLIENT", cCodCliente)
            oModelZA1:SetValue("ZA1_LOJA", If(Empty(cLojaCliente), "01", cLojaCliente))
        EndIf
        If !Empty(cEmailCliente)
            oModelZA1:SetValue("ZA1_EMAIL", cEmailCliente)
        EndIf
        If lLimparConsultor
            oModelZA1:SetValue("ZA1_CONSUL", "")
        ElseIf !Empty(cCodConsultor)
            oModelZA1:SetValue("ZA1_CONSUL", cCodConsultor)
        EndIf
        If !Empty(cProjeto)
            oModelZA1:SetValue("ZA1_PROJ", cProjeto)
        EndIf
        If !Empty(cTarefa)
            oModelZA1:SetValue("ZA1_TAREFA", cTarefa)
        EndIf
        oModelZA1:SetValue("ZA1_MOD", Date())

        If oModel:VldData()
            lOk := oModel:CommitData()
        EndIf

        If !lOk
            cErroModel := oModel:GetErrorMessage()
            Do Case
                Case ValType(cErroModel) == "C"
                    cErro := cErroModel
                Case ValType(cErroModel) == "O"
                    cErro := cErroModel:GetMessage()
                Case ValType(cErroModel) == "A"
                    cErro := FwJsonSerialize(cErroModel)
                Otherwise
                    cErro := "Falha ao validar/gravar a alteracao."
            EndCase
        EndIf

        oModel:DeActivate(lOk)
        lCnsaViaRest := .F.

        If !lOk
            Return {400, '{"erro":"' + CNSA_JSONESC(EncodeUtf8(cErro)) + '"}'}
        EndIf

        // CNSA_DISPARA_DESIGNACAO nao e mais chamada aqui - CNSA_APOSCOMMIT
        // (nOper==4, CNSA001.PRW) ja dispara e-mail de redesignacao nativo
        // quando ZA1_CONSUL muda no commit do Model.

        oJson['sucesso']  := .T.
        oJson['idCh']     := cIdCh
        oJson['mensagem'] := "Chamado alterado com sucesso."

        Return {200, oJson:ToJson()}

    Recover Using oErro
        lCnsaViaRest := .F.
        Return {500, '{"erro":"' + CNSA_JSONESC(EncodeUtf8(oErro:Description)) + '"}'}
    End Sequence
```

- [ ] **Step 2: Adicionar as novas `Local` no topo da função**

Junto das `Local` já existentes de `CNSA_ALTERAR`, adicionar:

```advpl
    Local oModel      := Nil
    Local oModelZA1   := Nil
    Local lOk         := .F.
    Local cErro       := ""
    Local cErroModel  := Nil
```

- [ ] **Step 3: Converter encoding e compilar**

Skill `utf8-to-cp1252-conversion` + skill `advpl-tlpp-compile` em `CNS001.tlpp`.

- [ ] **Step 4: Testar via curl**

```bash
curl -X POST "http://<servidor>:<porta>/rest/CNSACHAMADOSALTERAR?idCh=NNNNNN&assunto=Teste%20Alterado"
```

Esperado: `{"sucesso":true,"idCh":"NNNNNN","mensagem":"Chamado alterado com sucesso."}`, status 200. Repetir com `codConsultor=<outro tecnico diferente do atual>` e confirmar que chega e-mail de redesignação (via `CNSA_APOSCOMMIT`, não mais via `CNSA_DISPARA_DESIGNACAO`) e que uma nova linha SZ6 foi criada automaticamente (auto-agenda).

- [ ] **Step 5: Commit**

```bash
git add "Codigos apia intraweb henrique/CNS001.tlpp"
git commit -m "feat: CNSA_ALTERAR passa a gravar chamado via FWLoadModel(CNSA001)/MODEL_OPERATION_UPDATE, remove CNSA_DISPARA_DESIGNACAO redundante"
```

---

## Task 4: `CNSA_ASSUMIR` via `FWLoadModel("CNSA001")` + `MODEL_OPERATION_UPDATE`

**Files:**
- Modify: `Codigos apia intraweb henrique/CNS001.tlpp` (função `Static Function CNSA_ASSUMIR`)

**Interfaces:**
- Consumes: flag `lCnsaViaRest` (Task 1).
- Produces: assinatura inalterada - `Static Function CNSA_ASSUMIR(cIdCh)` retornando `{nStatusHttp, cCorpoJson}`.

- [ ] **Step 1: Substituir o miolo de gravação**

Localizar (depois de todas as pré-validações de negócio, que **não mudam**):

```advpl
        RecLock("ZA1", .F.)
            ZA1->ZA1_CONSUL := cConsultorSessao
            ZA1->ZA1_STATUS := "2"
            ZA1->ZA1_MOD    := Date()
        ZA1->(MsUnlock())

        // E-mail de designacao pro proprio tecnico que assumiu (auto-atribuicao).
        // Regra unificada com Incluir/Alterar - ver CNSA_DISPARA_DESIGNACAO.
        cNomeTec := AllTrim(Posicione("AA1", 1, xFilial("AA1") + cConsultorSessao, "AA1_NOMTEC"))
        CNSA_DISPARA_DESIGNACAO(cIdCh, cConsultorSessao)

        oJson['sucesso'] := .T.
        oJson['idCh']    := cIdCh
        oJson['status']  := "2"
        oJson['tecnico'] := EncodeUtf8(cNomeTec)

        Return {200, oJson:ToJson()}

    Recover Using oErro
        Return {500, '{"erro":"' + CNSA_JSONESC(EncodeUtf8(oErro:Description)) + '"}'}
    End Sequence
```

Substituir por:

```advpl
        Public lCnsaViaRest := .T.

        oModel    := FWLoadModel("CNSA001")
        oModel:SetOperation(MODEL_OPERATION_UPDATE)
        oModel:Activate()
        oModelZA1 := oModel:GetModel("ZA1MASTER")

        oModelZA1:SetValue("ZA1_CONSUL", cConsultorSessao)
        oModelZA1:SetValue("ZA1_STATUS", "2")
        oModelZA1:SetValue("ZA1_MOD",    Date())

        If oModel:VldData()
            lOk := oModel:CommitData()
        EndIf

        If !lOk
            cErroModel := oModel:GetErrorMessage()
            Do Case
                Case ValType(cErroModel) == "C"
                    cErro := cErroModel
                Case ValType(cErroModel) == "O"
                    cErro := cErroModel:GetMessage()
                Case ValType(cErroModel) == "A"
                    cErro := FwJsonSerialize(cErroModel)
                Otherwise
                    cErro := "Falha ao validar/gravar a designacao."
            EndCase
        EndIf

        oModel:DeActivate(lOk)
        lCnsaViaRest := .F.

        If !lOk
            Return {400, '{"erro":"' + CNSA_JSONESC(EncodeUtf8(cErro)) + '"}'}
        EndIf

        // CNSA_DISPARA_DESIGNACAO nao e mais chamada aqui - CNSA_APOSCOMMIT
        // (nOper==4) ja dispara e-mail de designacao nativo (ZA1_CONSUL
        // mudou de vazio pra preenchido no commit do Model).
        cNomeTec := AllTrim(Posicione("AA1", 1, xFilial("AA1") + cConsultorSessao, "AA1_NOMTEC"))

        oJson['sucesso'] := .T.
        oJson['idCh']    := cIdCh
        oJson['status']  := "2"
        oJson['tecnico'] := EncodeUtf8(cNomeTec)

        Return {200, oJson:ToJson()}

    Recover Using oErro
        lCnsaViaRest := .F.
        Return {500, '{"erro":"' + CNSA_JSONESC(EncodeUtf8(oErro:Description)) + '"}'}
    End Sequence
```

- [ ] **Step 2: Adicionar as novas `Local` no topo da função**

```advpl
    Local oModel      := Nil
    Local oModelZA1   := Nil
    Local lOk         := .F.
    Local cErro       := ""
    Local cErroModel  := Nil
```

- [ ] **Step 3: Converter encoding e compilar**

Skill `utf8-to-cp1252-conversion` + skill `advpl-tlpp-compile` em `CNS001.tlpp`.

- [ ] **Step 4: Testar via curl**

```bash
curl -X POST "http://<servidor>:<porta>/rest/CNSACHAMADOSASSUMIR?idCh=NNNNNN"
```

Esperado: `{"sucesso":true,"idCh":"NNNNNN","status":"2","tecnico":"<nome>"}`, status 200. Confirmar `ZA1_NOMTEC` preenchido no banco (gatilho `CNSA_TECNICO` disparando, correção sobre o comportamento antigo).

- [ ] **Step 5: Commit**

```bash
git add "Codigos apia intraweb henrique/CNS001.tlpp"
git commit -m "feat: CNSA_ASSUMIR passa a gravar via FWLoadModel(CNSA001)/MODEL_OPERATION_UPDATE, corrige gatilho ZA1_NOMTEC"
```

---

## Task 5: Núcleo compartilhado `CNSA_EXCLUINUCLEO` em `CNSA001.PRW`

**Files:**
- Modify: `Fontes cnshub/CNSA001.PRW` (adiciona nova `User Function CNSA_EXCLUINUCLEO`, no fim do arquivo)

**Interfaces:**
- Consumes: `CNSA_CANCEL_FRONT` e `CNSA_ENVIAEMAIL` (já existem no mesmo arquivo, `Static Function`, chamáveis por estarem no mesmo fonte); `CNSA_REMOVEAGENDA` (já existe, usada só quando `lConfirmarPorAgenda == .T.`).
- Produces: `User Function CNSA_EXCLUINUCLEO(cIdCh, cMotivo, lConfirmarPorAgenda)` retornando array `{lOk, cErro}` - `lOk` lógico, `cErro` string vazia em sucesso ou mensagem de erro. `lConfirmarPorAgenda` é opcional (`Default .F.`): `.F.` apaga todos os agendamentos vinculados sem perguntar (usado pelo REST, comportamento que já existia lá); `.T.` pergunta agendamento por agendamento via `CNSA_REMOVEAGENDA` (usado pela tela clássica, preserva comportamento atual dela). Usado pelas Tasks 6 e 7.

- [ ] **Step 1: Adicionar a função no fim de `CNSA001.PRW`**

```advpl
////////////////////////////////////////////////////////////////////////////////
// Nucleo compartilhado de exclusao de chamado (ZA1) - usado pela tela
// classica (CNSA_EXCLUIR, apos o dialog de motivo) e pelo REST
// (CNS001.tlpp, CNSA_CHAMADOS_EXCLUIR). Sem Public, sem MsgAlert - so
// logica de negocio, parametros explicitos, retorno estruturado.
//
// lConfirmarPorAgenda (Default .F.): .F. apaga TODOS os agendamentos
// vinculados sem perguntar (comportamento do REST); .T. pergunta
// agendamento por agendamento via CNSA_REMOVEAGENDA (comportamento da
// tela classica, preservado).
//
// Retorno: array {lOk, cErro} - lOk .T. e cErro "" em sucesso; lOk .F. e
// cErro com a mensagem em caso de falha.
////////////////////////////////////////////////////////////////////////////////
User Function CNSA_EXCLUINUCLEO(cIdCh, cMotivo, lConfirmarPorAgenda)
    Local cConsulAnterior  := ""
    Local cClienteAnterior := ""
    Local cLojaAnterior    := ""
    Local cNomeCli         := ""
    Local cNomeTec         := ""
    Local cEmailTec        := ""
    Local cExclPor         := ""
    Local cDataAge         := DToC(Date())
    Local cHmini           := "00:00"
    Local cHmfim           := "00:00"
    Local cCorpo           := ""
    Local cAlias           := ""
    Local nCham            := 0
    Local oErro            := Nil

    Default lConfirmarPorAgenda := .F.

    Begin Sequence

        If Empty(cIdCh)
            Return {.F., "Informe o idCh do chamado."}
        EndIf

        dbSelectArea("ZA1")
        ZA1->(DbSetOrder(1))
        If !ZA1->(DbSeek(xFilial("ZA1") + cIdCh))
            Return {.F., "Chamado nao encontrado."}
        EndIf

        cConsulAnterior  := AllTrim(ZA1->ZA1_CONSUL)
        cClienteAnterior := AllTrim(ZA1->ZA1_CLIENT)
        cLojaAnterior    := AllTrim(ZA1->ZA1_LOJA)

        If !Empty(cConsulAnterior) .And. Empty(cMotivo)
            Return {.F., "Informe o motivo do cancelamento - obrigatorio quando o chamado tem tecnico designado."}
        EndIf

        cExclPor := AllTrim(Posicione("AA1", 4, xFilial("AA1") + __cUserId, "AA1_NOMTEC"))
        cNomeCli := AllTrim(Posicione("SA1", 1, xFilial("SA1") + cClienteAnterior + cLojaAnterior, "A1_NOME"))

        nCham  := Val(cIdCh)
        cAlias := GetNextAlias()
        BeginSql Alias cAlias
            SELECT Z6_DTAGE, Z6_HMINI, Z6_HMFIM
            FROM %Table:SZ6% SZ6
            WHERE Z6_FILIAL  = %xFilial:SZ6%
              AND Z6_CHAMADO = %Exp:nCham%
              AND %NotDel%
        EndSql
        If !(cAlias)->(Eof())
            If ValType((cAlias)->Z6_DTAGE) == "D"
                cDataAge := DToC((cAlias)->Z6_DTAGE)
            Else
                cDataAge := AllTrim((cAlias)->Z6_DTAGE)
                If Len(cDataAge) == 8
                    cDataAge := SubStr(cDataAge,7,2) + "/" + SubStr(cDataAge,5,2) + "/" + SubStr(cDataAge,1,4)
                EndIf
            EndIf
            cHmini := AllTrim((cAlias)->Z6_HMINI)
            cHmfim := AllTrim((cAlias)->Z6_HMFIM)
        EndIf
        (cAlias)->(DbCloseArea())

        If Empty(cHmini) ; cHmini := "00:00" ; EndIf
        If Empty(cHmfim) ; cHmfim := "00:00" ; EndIf

        RecLock("ZA1", .F.)
            ZA1->(DbDelete())
        ZA1->(MsUnlock())

        If lConfirmarPorAgenda
            // Comportamento da tela classica - pergunta agendamento por
            // agendamento (CNSA_REMOVEAGENDA ja existe nesse arquivo).
            CNSA_REMOVEAGENDA(cIdCh)
        Else
            // Comportamento do REST - apaga TODOS sem perguntar (nao ha
            // como perguntar no meio de uma chamada headless).
            cAlias := GetNextAlias()
            BeginSql Alias cAlias
                SELECT SZ6.R_E_C_N_O_ RECNO
                FROM %Table:SZ6% SZ6
                WHERE SZ6.Z6_FILIAL  = %xFilial:SZ6%
                  AND SZ6.Z6_CHAMADO = %Exp:nCham%
                  AND %NotDel%
            EndSql
            dbSelectArea("SZ6")
            While !(cAlias)->(Eof())
                SZ6->(DbGoto((cAlias)->RECNO))
                If !SZ6->(Eof())
                    RecLock("SZ6", .F.)
                        SZ6->(DbDelete())
                    SZ6->(MsUnlock())
                EndIf
                (cAlias)->(DbSkip())
            EndDo
            (cAlias)->(DbCloseArea())
        EndIf

        If !Empty(cConsulAnterior)
            cNomeTec  := AllTrim(Posicione("AA1", 1, xFilial("AA1") + cConsulAnterior, "AA1_NOMTEC"))
            cEmailTec := AllTrim(Posicione("AA1", 1, xFilial("AA1") + cConsulAnterior, "AA1_EMAIL"))

            If !Empty(cEmailTec)
                cCorpo := CNSA_CANCEL_FRONT(cNomeCli, cDataAge, cHmini, cHmfim, cIdCh, cMotivo, cExclPor)
                CNSA_ENVIAEMAIL(cEmailTec, "Cancelamento do Chamado " + cIdCh, cCorpo, "apia@apia.com.br")
            Else
                ConOut("CNSA_EXCLUINUCLEO: tecnico " + cConsulAnterior + " sem AA1_EMAIL cadastrado - e-mail de cancelamento nao enviado.")
            EndIf
        EndIf

        Return {.T., ""}

    Recover Using oErro
        Return {.F., oErro:Description}
    End Sequence

Return {.F., "Erro desconhecido."}
```

- [ ] **Step 2: Converter encoding e compilar**

Skill `utf8-to-cp1252-conversion` + skill `advpl-tlpp-compile` em `CNSA001.PRW`.

- [ ] **Step 3: Commit**

```bash
git add "Fontes cnshub/CNSA001.PRW"
git commit -m "feat: adiciona CNSA_EXCLUINUCLEO - nucleo compartilhado de exclusao de chamado (tela classica + REST)"
```

---

## Task 6: Rewire da tela clássica (`CNSA_EXCLUIR`, PRW) pra chamar `CNSA_EXCLUINUCLEO`

**Files:**
- Modify: `Fontes cnshub/CNSA001.PRW` (função `User Function CNSA_EXCLUIR`)

**Interfaces:**
- Consumes: `CNSA_EXCLUINUCLEO(cIdCh, cMotivo, lConfirmarPorAgenda)` (Task 5).
- Produces: comportamento visual da tela clássica inalterado (mesmo dialog de motivo, mesmo `MsgAlert` em caso de erro).

- [ ] **Step 1: Substituir o branch "sem técnico" (early return)**

Localizar:

```advpl
    // Se nao tem tecnico, nao precisa de modal, vai direto
    // (mesmo sem tecnico, pode haver agendamentos orfaos vinculados, entao verifica)
    If Empty(cConsulAnterior)
        CNSA_REMOVEAGENDA(cIdChAnterior)
        RecLock("ZA1", .F.)
            ZA1->(DbDelete())
        ZA1->(MsUnlock())
        Return
    EndIf
```

Substituir por:

```advpl
    // Se nao tem tecnico, nao precisa de modal, vai direto
    If Empty(cConsulAnterior)
        aResultado := CNSA_EXCLUINUCLEO(cIdChAnterior, "", .T.)
        If !aResultado[1]
            MsgAlert(aResultado[2], "Excluir")
        EndIf
        Return
    EndIf
```

- [ ] **Step 2: Substituir o trecho final (depois da confirmação do dialog)**

Localizar:

```advpl
    lExclusaoConfirm := .T.

    // Executa o delete diretamente
    RecLock("ZA1", .F.)
        ZA1->(DbDelete())
    ZA1->(MsUnlock())

    // Chama o poscommit manualmente
    CNSA_POSCOMMIT_EXCLUIR()

Return
```

Substituir por:

```advpl
    lExclusaoConfirm := .T.

    aResultado := CNSA_EXCLUINUCLEO(cIdChAnterior, cMotivoExclusao, .T.)
    If !aResultado[1]
        MsgAlert(aResultado[2], "Excluir")
    EndIf

Return
```

- [ ] **Step 3: Adicionar `Local aResultado` no topo de `CNSA_EXCLUIR`**

```advpl
    Local aResultado := {}
```

- [ ] **Step 4: Remover `CNSA_POSCOMMIT_EXCLUIR` (função agora sem chamador)**

Apagar a `Static Function CNSA_POSCOMMIT_EXCLUIR` inteira (linhas originais ~256-314) - a lógica dela foi absorvida por `CNSA_EXCLUINUCLEO` (Task 5).

- [ ] **Step 5: Converter encoding e compilar**

Skill `utf8-to-cp1252-conversion` + skill `advpl-tlpp-compile` em `CNSA001.PRW`. Esperado: compila sem erro (nenhuma outra função chama `CNSA_POSCOMMIT_EXCLUIR`).

- [ ] **Step 6: Testar manualmente na tela clássica**

Abrir `CNSA001` no SmartClient, selecionar um chamado com técnico designado, Excluir, confirmar motivo no dialog. Esperado: mesmo comportamento visual de antes (pergunta agendamento por agendamento se houver, envia e-mail de cancelamento, apaga o chamado). Repetir com um chamado sem técnico (early-return branch).

- [ ] **Step 7: Commit**

```bash
git add "Fontes cnshub/CNSA001.PRW"
git commit -m "refactor: CNSA_EXCLUIR (tela classica) passa a chamar CNSA_EXCLUINUCLEO, remove CNSA_POSCOMMIT_EXCLUIR duplicado"
```

---

## Task 7: REST `CNSA_EXCLUIR` (TLPP) passa a chamar `CNSA_EXCLUINUCLEO`

**Files:**
- Modify: `Codigos apia intraweb henrique/CNS001.tlpp` (função `Static Function CNSA_EXCLUIR`)

**Interfaces:**
- Consumes: `CNSA_EXCLUINUCLEO(cIdCh, cMotivo, lConfirmarPorAgenda)` (Task 5) - chamada com `lConfirmarPorAgenda == .F.` (mesmo comportamento em lote que o REST já tinha).
- Produces: assinatura inalterada - `Static Function CNSA_EXCLUIR(cIdCh, cMotivo)` retornando `{nStatusHttp, cCorpoJson}`.

- [ ] **Step 1: Substituir o corpo da função inteira**

Localizar toda a `Static Function CNSA_EXCLUIR(cIdCh, cMotivo)` (do `Local cConsulAnterior` até o `Return {500, '{"erro":"Erro desconhecido."}'}` final) e substituir por:

```advpl
Static Function CNSA_EXCLUIR(cIdCh, cMotivo)
    Local aResultado := {}
    Local oJson       := JsonObject():New()

    If Empty(cIdCh)
        Return {400, '{"erro":"Informe o idCh do chamado (?idCh=000031)."}'}
    EndIf

    aResultado := CNSA_EXCLUINUCLEO(cIdCh, cMotivo, .F.)

    If !aResultado[1]
        Return {If("nao encontrado" $ aResultado[2], 404, 400), '{"erro":"' + CNSA_JSONESC(EncodeUtf8(aResultado[2])) + '"}'}
    EndIf

    oJson['sucesso']  := .T.
    oJson['idCh']     := cIdCh
    oJson['mensagem'] := "Chamado excluido com sucesso."

Return {200, oJson:ToJson()}
```

- [ ] **Step 2: Converter encoding e compilar**

Skill `utf8-to-cp1252-conversion` + skill `advpl-tlpp-compile` em `CNS001.tlpp`.

- [ ] **Step 3: Testar via curl**

```bash
curl -X POST "http://<servidor>:<porta>/rest/CNSACHAMADOSEXCLUIR?idCh=NNNNNN&motivo=Teste"
```

Esperado: `{"sucesso":true,"idCh":"NNNNNN","mensagem":"Chamado excluido com sucesso."}`, status 200. Testar também `idCh` inexistente (espera 404) e chamado com técnico sem `motivo` (espera 400).

- [ ] **Step 4: Commit**

```bash
git add "Codigos apia intraweb henrique/CNS001.tlpp"
git commit -m "refactor: REST CNSA_EXCLUIR passa a chamar CNSA_EXCLUINUCLEO em vez de reimplementar a cascata"
```

---

## Task 8: `CNSA_ZA2_GRAVAR` via `FWLoadModel("CNSAZA2VIEW")`

**Files:**
- Modify: `Codigos apia intraweb henrique/CNS001.tlpp` (função `Static Function CNSA_ZA2_GRAVAR`)

**Interfaces:**
- Consumes: nenhuma dependência nova (Model `CNSAZA2VIEW` sem gatilho/validação - `PreValidacao`/`PosValidacao`/`Commit`/`Cancel` todos `NIL`).
- Produces: assinatura inalterada - `Static Function CNSA_ZA2_GRAVAR(nChamN, cConsultor, cTexto)` retornando `StrZero(nSeq, 3)` (string da sequência gravada), usada por `CNSA_ZA2INCLUIR` (anotação manual) e `CNSA_GERACHAM` (import automático de e-mail) - **nenhuma dessas duas chamadoras muda**.

- [ ] **Step 1: Substituir o miolo de gravação**

Localizar:

```advpl
    RecLock("ZA2", .T.)
        ZA2->ZA2_FILIAL := xFilial("ZA2")
        ZA2->ZA2_IDCH   := nChamN
        ZA2->ZA2_IDGRID := StrZero(nSeq, 3)
        ZA2->ZA2_CONSUL := cConsultor
        ZA2->ZA2_DATA   := Date()
        ZA2->ZA2_HORA   := Left(Time(), 5)
        ZA2->ZA2_DESCRI := cTexto
    ZA2->(MsUnlock())

Return StrZero(nSeq, 3)
```

Substituir por:

```advpl
    oModel    := FWLoadModel("CNSAZA2VIEW")
    oModel:SetOperation(MODEL_OPERATION_INSERT)
    oModel:Activate()
    oModelZA2 := oModel:GetModel("ZA2MASTER")

    oModelZA2:SetValue("ZA2_FILIAL", xFilial("ZA2"))
    oModelZA2:SetValue("ZA2_IDCH",   nChamN)
    oModelZA2:SetValue("ZA2_IDGRID", StrZero(nSeq, 3))
    oModelZA2:SetValue("ZA2_CONSUL", cConsultor)
    oModelZA2:SetValue("ZA2_DATA",   Date())
    oModelZA2:SetValue("ZA2_HORA",   Left(Time(), 5))
    oModelZA2:SetValue("ZA2_DESCRI", cTexto)

    If oModel:VldData()
        lOk := oModel:CommitData()
    EndIf

    oModel:DeActivate(lOk)

    If !lOk
        ConOut("CNSA_ZA2_GRAVAR: falha ao gravar anotacao via FWLoadModel(CNSAZA2VIEW) - chamado " + AllTrim(Str(nChamN)))
        Return ""
    EndIf

Return StrZero(nSeq, 3)
```

- [ ] **Step 2: Adicionar as novas `Local` no topo da função**

```advpl
    Local oModel    := Nil
    Local oModelZA2 := Nil
    Local lOk       := .F.
```

- [ ] **Step 3: Converter encoding e compilar**

Skill `utf8-to-cp1252-conversion` + skill `advpl-tlpp-compile` em `CNS001.tlpp`.

- [ ] **Step 4: Testar via curl**

```bash
curl -X POST "http://<servidor>:<porta>/rest/CNSACHAMADOSANOTACOESINCLUIR?idCh=NNNNNN&texto=Anotacao%20de%20teste"
```

Esperado: `{"sucesso":true,"idCh":"NNNNNN","seq":"NNN","mensagem":"Anotacao adicionada com sucesso."}`, status 200.

- [ ] **Step 5: Commit**

```bash
git add "Codigos apia intraweb henrique/CNS001.tlpp"
git commit -m "feat: CNSA_ZA2_GRAVAR passa a gravar anotacao via FWLoadModel(CNSAZA2VIEW) em vez de RecLock manual"
```

---

## Task 9: `CNSA_AGENDAR` - troca o miolo do retry por `FWLoadModel("CNSA003")`

**Files:**
- Modify: `Codigos apia intraweb henrique/CNS001.tlpp` (função `Static Function CNSA_AGENDAR`, só o bloco de gravação dentro do retry)

**Interfaces:**
- Consumes: nenhuma dependência nova (`CNSA_PROXSEQ_SZ6`, `CNSA_VERIFICASOBREPOSICAO`, `LockByName`/`UnLockByName` continuam exatamente como estão).
- Produces: assinatura inalterada - `Static Function CNSA_AGENDAR(...)` retornando `{nStatusHttp, cCorpoJson}`. A orquestração externa (loop de datas, lock, sobreposição, retry) não muda em nada - só o corpo de dentro do `For nTentativa := 1 To 3`.

- [ ] **Step 1: Substituir o bloco de gravação dentro do retry**

Localizar (dentro do `For nTentativa := 1 To 3` → `Begin Sequence`):

```advpl
                    Begin Sequence
                        cSeq := CNSA_PROXSEQ_SZ6(cCodTecnico, dAtual)

                        RecLock("SZ6", .T.)
                            SZ6->Z6_FILIAL  := xFilial("SZ6")
                            SZ6->Z6_CHAMADO := nCham
                            SZ6->Z6_DTAGE   := dAtual
                            SZ6->Z6_TECNICO := cCodTecnico
                            SZ6->Z6_SEQ     := cSeq
                            SZ6->Z6_HMINI   := cHoraIni
                            SZ6->Z6_HMFIM   := cHoraFim
                            SZ6->Z6_CLIENTE := cCodCliente
                            SZ6->Z6_LOJA    := cLojaCliente
                            SZ6->Z6_SERVICO := cDescricao
                            SZ6->Z6_CONFIRM := If(Empty(cConfirmacao), "NAO", cConfirmacao)
                            SZ6->Z6_TURNO   := Val(cTurno)
                            SZ6->Z6_INTERNO := If(Empty(cAgInterna), "NAO", cAgInterna)
                            SZ6->Z6_COBRAR  := If(Empty(cAgCobravel), "NAO", cAgCobravel)
                            SZ6->Z6_TIPOAG  := cTipoAgenda
                            SZ6->Z6_PROJET  := cProjeto
                            SZ6->Z6_REVISA  := cRevisao
                            SZ6->Z6_TAREFA  := cTarefa
                            SZ6->Z6_TIPO_HR := cTipoHora
                            SZ6->Z6_QGRAVOU := cCodAgendador
                        SZ6->(MsUnlock())

                        lGravouDia := .T.
                    Recover Using oErroDia
                        // Erro de chave duplicada (ou outro) - tenta de novo
                        // no proximo loop de nTentativa, com sequencia
                        // recalculada.
                    End Sequence
```

Substituir por:

```advpl
                    Begin Sequence
                        cSeq := CNSA_PROXSEQ_SZ6(cCodTecnico, dAtual)

                        oModelSZ6Agend := FWLoadModel("CNSA003")
                        oModelSZ6Agend:SetOperation(MODEL_OPERATION_INSERT)
                        oModelSZ6Agend:Activate()
                        oModelSZ6Main := oModelSZ6Agend:GetModel("ModelSZ6_Main")

                        oModelSZ6Main:SetValue("Z6_FILIAL",  xFilial("SZ6"))
                        oModelSZ6Main:SetValue("Z6_CHAMADO", nCham)
                        oModelSZ6Main:SetValue("Z6_DTAGE",   dAtual)
                        oModelSZ6Main:SetValue("Z6_TECNICO", cCodTecnico)
                        oModelSZ6Main:SetValue("Z6_SEQ",     cSeq)
                        oModelSZ6Main:SetValue("Z6_HMINI",   cHoraIni)
                        oModelSZ6Main:SetValue("Z6_HMFIM",   cHoraFim)
                        oModelSZ6Main:SetValue("Z6_CLIENTE", cCodCliente)
                        oModelSZ6Main:SetValue("Z6_LOJA",    cLojaCliente)
                        oModelSZ6Main:SetValue("Z6_SERVICO", cDescricao)
                        oModelSZ6Main:SetValue("Z6_CONFIRM", If(Empty(cConfirmacao), "NAO", cConfirmacao))
                        oModelSZ6Main:SetValue("Z6_TURNO",   Val(cTurno))
                        oModelSZ6Main:SetValue("Z6_INTERNO", If(Empty(cAgInterna), "NAO", cAgInterna))
                        oModelSZ6Main:SetValue("Z6_COBRAR",  If(Empty(cAgCobravel), "NAO", cAgCobravel))
                        oModelSZ6Main:SetValue("Z6_TIPOAG",  cTipoAgenda)
                        oModelSZ6Main:SetValue("Z6_PROJET",  cProjeto)
                        oModelSZ6Main:SetValue("Z6_REVISA",  cRevisao)
                        oModelSZ6Main:SetValue("Z6_TAREFA",  cTarefa)
                        oModelSZ6Main:SetValue("Z6_TIPO_HR", cTipoHora)
                        oModelSZ6Main:SetValue("Z6_QGRAVOU", cCodAgendador)

                        lGravouDia := .F.
                        If oModelSZ6Agend:VldData()
                            lGravouDia := oModelSZ6Agend:CommitData()
                        EndIf

                        oModelSZ6Agend:DeActivate(lGravouDia)

                        If !lGravouDia
                            // Forca cair no Recover abaixo, igual a um erro
                            // de RecLock, pra manter o retry de 3 tentativas.
                            UserException("Falha ao validar/gravar agendamento via Model - tentativa " + AllTrim(Str(nTentativa)))
                        EndIf
                    Recover Using oErroDia
                        // Erro de chave duplicada (ou outro) - tenta de novo
                        // no proximo loop de nTentativa, com sequencia
                        // recalculada.
                    End Sequence
```

- [ ] **Step 2: Adicionar as novas `Local` no topo da função**

Junto das `Local` já existentes de `CNSA_AGENDAR`, adicionar:

```advpl
    Local oModelSZ6Agend := Nil
    Local oModelSZ6Main  := Nil
```

- [ ] **Step 3: Converter encoding e compilar**

Skill `utf8-to-cp1252-conversion` + skill `advpl-tlpp-compile` em `CNS001.tlpp`.

- [ ] **Step 4: Testar via curl**

```bash
curl -X POST "http://<servidor>:<porta>/rest/CNSACHAMADOSAGENDAR?idCh=NNNNNN&dataInicio=2026-08-20&codTecnico=<cod>&horaInicio=08:00&horaFim=09:00&codCliente=<cod>&descricao=Teste"
```

Esperado: `{"sucesso":true,"idCh":"NNNNNN","quantidade":1,"falhas":[],"mensagem":"1 de 1 dia(s) criado(s) com sucesso."}`, status 200. Confirmar no banco que `Z6_NOMTEC`/`Z6_NOMCLI` vieram preenchidos (gatilhos `CNS003NTec`/`CNS003NCli` disparando). Testar também um intervalo de 2 dias (`dataFim` diferente) e confirmar 2 registros SZ6 criados, e um horário sobreposto no mesmo técnico/dia (espera entrar em `aFalhas`).

- [ ] **Step 5: Commit**

```bash
git add "Codigos apia intraweb henrique/CNS001.tlpp"
git commit -m "feat: CNSA_AGENDAR grava cada dia via FWLoadModel(CNSA003) em vez de RecLock manual, mantem orquestracao de intervalo/lock/retry"
```

---

## Self-Review (verificação contra a spec)

**Cobertura da spec** (`docs/superpowers/specs/2026-08-17-cns001-incluir-fwmodel-design.md`):
- Incluir → Task 2. Alterar → Task 3. Assumir → Task 4. Excluir → Tasks 5/6/7. Anotar → Task 8. Agendar → Task 9. Flag headless → Task 1. Todas as 6 operações da tabela do Escopo da spec têm task correspondente.

**Placeholder scan**: nenhum "TBD"/"implementar depois" - todo bloco de código é completo e compilável como escrito (assumindo os nomes de campo confirmados na spec).

**Consistência de tipos/assinaturas**: `CNSA_EXCLUINUCLEO(cIdCh, cMotivo, lConfirmarPorAgenda)` usado identicamente nas Tasks 6 e 7 (`{lOk, cErro}`). `lCnsaViaRest` usado identicamente nas Tasks 1, 2, 3 e 4. Todas as `Static Function` mantêm a mesma assinatura de entrada/saída que os wrappers `@Post` (não listados nas tasks) já esperam - nenhum wrapper precisa ser tocado.

**Risco não resolvido, propagado da spec**: numeração automática de `ZA1_IDCH` (SX3) não confirmada - a Task 2 mantém `GetSxeNum`/`ConfirmSX8` explícito (opção conservadora da spec, já que não foi possível confirmar se é automática). Se na Task 2 o `oModel:CommitData()` reclamar de `ZA1_IDCH` duplicado/gerado automaticamente, ajustar removendo o `GetSxeNum`/`ConfirmSX8` manual e lendo `oModelZA1:GetValue("ZA1_IDCH")` depois do commit.
