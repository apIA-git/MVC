# CNSA002 FWModel REST Endpoints Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add 3 TLPP-annotated REST endpoints (`@Post`, `@Put`, `@Delete`) to `Fontes cnshub\CNSA002.PRW` that create/update/delete an Ordem de Serviço (SZ1) through the existing `FWLoadModel("CNSA002")` model, and move field-required validation into the model's `FSZ1PosValid` hook so both the classic MVC screen and the new REST endpoints share one validation path.

**Architecture:** All 3 endpoints follow the same shape: load the model with `FWLoadModel("CNSA002")`, set the operation (`MODEL_OPERATION_INSERT`/`UPDATE`/`DELETE`), `Activate()`, apply field values via `oModel:SetValue("SZ1MASTER", cField, xValue)` (confirmed call shape — see `Fontes cnshub\CNSA001.PRW:677-688`, the only in-repo `FWLoadModel`+`SetValue` precedent), then `VldData()` → `CommitData()` → `DeActivate()`. Update/Delete require the SZ1 record to already be positioned in the workarea before `Activate()` — FWModel loads the current row's values, it does not seek by itself.

**Tech Stack:** AdvPL/TLPP, Protheus MVC (`FWMVCDEF.CH`), TLPP REST annotations (`tlpp-rest.th`), `oRest` global object.

## Global Constraints

- File touched: `Fontes cnshub\CNSA002.PRW` only. Do not touch `Codigos apia intraweb henrique\POUICNSA002.PRW` or anything under `apia_consultoria\pouios` (explicitly out of scope per spec).
- Header-only (SZ1) — no SZ2 grid (Horas Contratadas) fields in any of the 3 endpoints.
- Response contract: `{"sucesso":bool, "os":"...", "mensagem":"..."}` on success, `{"sucesso":false,"erro":"..."}` on error. Status 201 (incluir), 200 (alterar/excluir), 400 (validação), 404 (OS não encontrada), 500 (erro inesperado).
- Route path syntax is `:paramName`, not `{paramName}` — the spec doc used `{os}` as shorthand; the real TLPP syntax (confirmed against `tlpp-rest-endpoint-generator` skill reference) is `:os`, read via `oRest:getPathParamsRequest()["os"]`.
- `SZ1->(DbSetOrder(1))` is assumed to be `Z1_FILIAL+Z1_OS` (same assumption already flagged in `POUICNSA002.PRW`, unconfirmed). If wrong, `DbSeek` just fails and the endpoint returns 404 — it will not corrupt data.
- No automated test suite exists anywhere in this codebase (confirmed — neither `Fontes cnshub` nor `Codigos apia intraweb henrige` have any `.prw`/`.tlpp` test files). "Test" in every task below means: compile, then call the endpoint with `curl`/Postman and check the JSON/status against the contract above. This mirrors how every other endpoint in this codebase has been validated.

---

### Task 1: Move required-field validation into `FSZ1PosValid`

**Files:**
- Modify: `Fontes cnshub\CNSA002.PRW:133-136` (the `FSZ1PosValid` stub)

**Interfaces:**
- Consumes: nothing new — `FSZ1PosValid(p_oField, p_sAcao, p_sCampo, p_vValor)` is already wired into `ModelDef` at line 113 (`{|_f,_a,_c,_v| FSZ1PosValid(_f,_a,_c,_v)}`).
- Produces: `FSZ1PosValid` now returns `.F.` when a required SZ1 field is empty. Every task after this one relies on this to make `oModel:VldData()` actually fail on missing required fields (today it always returns `.T.`, so `VldData()` can never fail for a required-field reason).

- [ ] **Step 1: Write the failing check (manual, via the classic screen)**

Before changing the code, confirm today's stub behavior: open Protheus SmartClient → CNSA002 → Incluir → leave "Cliente" blank → try to confirm. Expected today: the screen lets you save (or fails for an unrelated DB reason), because `FSZ1PosValid` always returns `.T.`. Write down what you see — this is the "before" baseline.

- [ ] **Step 2: Implement the validation**

Replace the stub body:

```advpl
Static Function FSZ1PosValid(p_oField, p_sAcao, p_sCampo, p_vValor)
    Local l_bOk := .T.
    Local aObrigatorios := {"Z1_CLI", "Z1_LOJA", "Z1_USR", "Z1_MODULO", "Z1_MOTIV", ;
        "Z1_SERV", "Z1_TIPO", "Z1_DTOS", "Z1_INI", "Z1_FIM", "Z1_TOTAL", "Z1_TEC"}

    If AScan(aObrigatorios, p_sCampo) > 0 .And. Empty(p_vValor)
        l_bOk := .F.
    EndIf

Return l_bOk
```

- [ ] **Step 3: Compile**

Use the `advpl-tlpp-compile` skill (or your usual TDS compile flow) to rebuild `CNSA002.PRW`. Expected: compiles clean, no syntax errors (this is a pure AdvPL change, no new includes).

- [ ] **Step 4: Verify against the classic screen**

Repeat Step 1's manual check: CNSA002 → Incluir → leave "Cliente" blank → try to confirm. Expected now: the record is rejected — some validation message appears (exact wording depends on what the framework shows by default for a `.F.` return from `PosValidate`; note down what actually appears, since the framework's default message text is not confirmed ahead of time). If nothing is rejected, `p_sCampo`/`p_vValor` are not what their names suggest for this callback signature — stop and inspect the actual values received (temporary `FWLogMsg("INFO", , "MVC", "FSZ1PosValid", , "01", p_sCampo + "=" + cValToChar(p_vValor), 0, 0, {})` at the top of the function, retry, check the log, then remove the log line once confirmed).

- [ ] **Step 5: Commit**

```bash
git add "Fontes cnshub/CNSA002.PRW"
git commit -m "feat: valida campos obrigatorios da OS em FSZ1PosValid"
```

---

### Task 2: `@Post /cnsaos` — Incluir OS

**Files:**
- Modify: `Fontes cnshub\CNSA002.PRW` — add `#INCLUDE 'tlpp-rest.th'` near the top (after the existing includes), add 3 new shared helper `Static Function`s and the new `User Function` at the end of the file.

**Interfaces:**
- Consumes: `FSZ1PosValid` from Task 1 (indirectly, via `oModel:VldData()`).
- Produces (used by Tasks 3 and 4):
  - `Static Function CNSA002_ISODATA(cIso as Character) as Date` — converts `"YYYY-MM-DD"` to a `Date`, empty string → `CToD("")`.
  - `Static Function CNSA002_JSONNUM(jBody as Json, cCampo as Character) as Numeric` — returns `0` if `jBody[cCampo]` is `Nil`, else `Val(cValToChar(jBody[cCampo]))`.
  - `Static Function CNSA002_ERROMODEL(oModel as Object) as Character` — joins `oModel:GetErrorMessage()` into one string.
  - `Static Function CNSA002_RESPOK(cOs as Character, cMsg as Character) as Character` — builds `{"sucesso":true,"os":cOs,"mensagem":cMsg}`.
  - `Static Function CNSA002_RESPERRO(cErro as Character) as Character` — builds `{"sucesso":false,"erro":cErro}`.

- [ ] **Step 1: Write the failing test**

Before touching the file, this route does not exist. Run:

```bash
curl -i -X POST http://<appserver-host>:<rest-port>/rest/cnsaos \
  -H "Content-Type: application/json" \
  -d '{"codCliente":"000001","lojaCliente":"01","usuario":"Henrique","modulo":"01","motivo":"01","descricao":"Teste plano","codServico":"0001","dataOs":"2026-08-13","horaInicialDec":8,"horaFinalDec":12,"horasTiDec":4,"codAnalista":"000001"}'
```

Expected: connection refused, or 404 — route not registered yet (module not even compiled with the new annotation).

- [ ] **Step 2: Add the include**

At the top of `Fontes cnshub\CNSA002.PRW`, after the existing `#include "COLORS.CH"` line, add:

```advpl
#INCLUDE 'tlpp-rest.th'
```

- [ ] **Step 3: Add the shared helpers**

Append at the end of the file:

```advpl
////////////////////////////////////////////////////////////////////////////////
// Helpers compartilhados pelos endpoints REST (Incluir/Alterar/Excluir OS).
////////////////////////////////////////////////////////////////////////////////
Static Function CNSA002_ISODATA(cIso)
    If Empty(cIso)
        Return CToD("")
    EndIf
Return StoD(StrTran(cIso, "-", ""))

Static Function CNSA002_JSONNUM(jBody, cCampo)
    Local xVal := jBody[cCampo]
    If xVal == Nil
        Return 0
    EndIf
Return Val(cValToChar(xVal))

Static Function CNSA002_ERROMODEL(oModel)
    Local aErros := oModel:GetErrorMessage()
    Local cMsg   := ""
    Local nI     := 0

    If ValType(aErros) == "A"
        For nI := 1 To Len(aErros)
            If ValType(aErros[nI]) == "A" .And. Len(aErros[nI]) >= 6 .And. !Empty(aErros[nI][6])
                cMsg += aErros[nI][6] + "; "
            EndIf
        Next nI
    EndIf

    If Empty(cMsg)
        cMsg := "Erro de validacao no registro."
    ElseIf Right(cMsg, 2) == "; "
        cMsg := Left(cMsg, Len(cMsg) - 2)
    EndIf

Return cMsg

Static Function CNSA002_RESPOK(cOs, cMsg)
    Local oJson := JsonObject():New()
    oJson["sucesso"]  := .T.
    oJson["os"]       := cOs
    oJson["mensagem"] := cMsg
Return oJson:ToJson()

Static Function CNSA002_RESPERRO(cErro)
    Local oJson := JsonObject():New()
    oJson["sucesso"] := .F.
    oJson["erro"]    := cErro
Return oJson:ToJson()
```

- [ ] **Step 4: Add the Incluir endpoint**

Append after the helpers:

```advpl
////////////////////////////////////////////////////////////////////////////////
// POST /cnsaos - Inclui uma nova OS (SZ1) via FWModel("CNSA002").
////////////////////////////////////////////////////////////////////////////////
@Post("/cnsaos")
User Function CNSA002_INCLUIR_OS() As Logical
    Local cBody  := oRest:getBodyRequest() As Character
    Local jBody  := JsonObject():New() As Json
    Local oModel := Nil
    Local cOs    := ""
    Local cErro  := ""

    oRest:setKeyHeaderResponse("Content-Type", "application/json")

    If jBody:fromJson(cBody) <> Nil
        Return oRest:setStatusResponse(400, CNSA002_RESPERRO("Body JSON invalido."))
    EndIf

    Try
        cOs := GetSxeNum("SZ1", "Z1_OS")

        oModel := FWLoadModel("CNSA002")
        oModel:SetOperation(MODEL_OPERATION_INSERT)
        oModel:Activate()

        oModel:SetValue("SZ1MASTER", "Z1_OS",      cOs)
        oModel:SetValue("SZ1MASTER", "Z1_CLI",     jBody:GetJsonText("codCliente"))
        oModel:SetValue("SZ1MASTER", "Z1_LOJA",    jBody:GetJsonText("lojaCliente"))
        oModel:SetValue("SZ1MASTER", "Z1_USR",     jBody:GetJsonText("usuario"))
        oModel:SetValue("SZ1MASTER", "Z1_MODULO",  jBody:GetJsonText("modulo"))
        oModel:SetValue("SZ1MASTER", "Z1_MOTIV",   jBody:GetJsonText("motivo"))
        oModel:SetValue("SZ1MASTER", "Z1_SERV",    DecodeUTF8(jBody:GetJsonText("descricao")))
        oModel:SetValue("SZ1MASTER", "Z1_TIPO",    jBody:GetJsonText("codServico"))
        oModel:SetValue("SZ1MASTER", "Z1_DTOS",    CNSA002_ISODATA(jBody:GetJsonText("dataOs")))
        oModel:SetValue("SZ1MASTER", "Z1_INI",     CNSA002_JSONNUM(jBody, "horaInicialDec"))
        oModel:SetValue("SZ1MASTER", "Z1_FIM",     CNSA002_JSONNUM(jBody, "horaFinalDec"))
        oModel:SetValue("SZ1MASTER", "Z1_TOTAL",   CNSA002_JSONNUM(jBody, "horasTiDec"))
        oModel:SetValue("SZ1MASTER", "Z1_TEC",     jBody:GetJsonText("codAnalista"))
        oModel:SetValue("SZ1MASTER", "Z1_DTDIGIT", If(Empty(jBody:GetJsonText("dtDigitacao")), Date(), CNSA002_ISODATA(jBody:GetJsonText("dtDigitacao"))))
        oModel:SetValue("SZ1MASTER", "Z1_INTERNO", If(Empty(jBody:GetJsonText("osInterna")), "N", jBody:GetJsonText("osInterna")))
        oModel:SetValue("SZ1MASTER", "Z1_TRANS",   CNSA002_JSONNUM(jBody, "horasTranDec"))
        oModel:SetValue("SZ1MASTER", "Z1_PREVIST", If(Empty(jBody:GetJsonText("prevPmt")), "N", jBody:GetJsonText("prevPmt")))
        oModel:SetValue("SZ1MASTER", "Z1_NUMPRO",  jBody:GetJsonText("numProposta"))
        oModel:SetValue("SZ1MASTER", "Z1_PV",      jBody:GetJsonText("pedVenda"))
        oModel:SetValue("SZ1MASTER", "Z1_ALMOCO",  CNSA002_JSONNUM(jBody, "hrAlmoco"))
        oModel:SetValue("SZ1MASTER", "Z1_PROJET",  jBody:GetJsonText("projeto"))
        oModel:SetValue("SZ1MASTER", "Z1_REVISA",  jBody:GetJsonText("revisao"))
        oModel:SetValue("SZ1MASTER", "Z1_TAREFA",  jBody:GetJsonText("tarefa"))
        oModel:SetValue("SZ1MASTER", "Z1_CHPSD",   jBody:GetJsonText("chamadoHpsd"))
        oModel:SetValue("SZ1MASTER", "Z1_CHHDK",   CNSA002_JSONNUM(jBody, "chamado"))
        oModel:SetValue("SZ1MASTER", "Z1_OSDESE",  If(Empty(jBody:GetJsonText("osDesenv")), "N", jBody:GetJsonText("osDesenv")))
        oModel:SetValue("SZ1MASTER", "Z1_LIN",     jBody:GetJsonText("linhaPv"))
        oModel:SetValue("SZ1MASTER", "Z1_VLRHR",   CNSA002_JSONNUM(jBody, "valorHora"))
        oModel:SetValue("SZ1MASTER", "Z1_APROVAD", "N")
        oModel:SetValue("SZ1MASTER", "Z1_FATURAR", "N")

        If !oModel:VldData()
            cErro := CNSA002_ERROMODEL(oModel)
            oModel:DeActivate()
            RollBackSX8()
            Return oRest:setStatusResponse(400, CNSA002_RESPERRO(cErro))
        EndIf

        If !oModel:CommitData()
            cErro := CNSA002_ERROMODEL(oModel)
            oModel:DeActivate()
            RollBackSX8()
            Return oRest:setStatusResponse(500, CNSA002_RESPERRO(cErro))
        EndIf

        oModel:DeActivate()
        ConfirmSX8()

    Catch oErro
        If oModel <> Nil
            oModel:DeActivate()
        EndIf
        RollBackSX8()
        FWLogMsg("ERROR", , "REST", "CNSA002_INCLUIR_OS", , "01", oErro:Description, 0, 0, {})
        Return oRest:setStatusResponse(500, CNSA002_RESPERRO(oErro:Description))
    EndTry

Return oRest:setStatusResponse(201, CNSA002_RESPOK(cOs, "OS incluida com sucesso."))
```

- [ ] **Step 5: Compile**

Use `advpl-tlpp-compile`. Expected: compiles clean. If `tlpp-rest.th` fails to resolve, confirm the TLPP compiler/include path is configured for this workspace the same way it is for `wsportlsb.tlpp` (which uses the same include successfully).

- [ ] **Step 6: Run the test from Step 1 again**

```bash
curl -i -X POST http://<appserver-host>:<rest-port>/rest/cnsaos \
  -H "Content-Type: application/json" \
  -d '{"codCliente":"000001","lojaCliente":"01","usuario":"Henrique","modulo":"01","motivo":"01","descricao":"Teste plano","codServico":"0001","dataOs":"2026-08-13","horaInicialDec":8,"horaFinalDec":12,"horasTiDec":4,"codAnalista":"000001"}'
```

Expected: `201`, body `{"sucesso":true,"os":"<numero gerado>","mensagem":"OS incluida com sucesso."}`. Adjust `codCliente`/`lojaCliente`/`modulo`/`motivo`/`codServico`/`codAnalista` to real codes that exist in your test base if this specific set 404s/fails on a foreign-key-style validation inside `CommitData()`.

- [ ] **Step 7: Run the validation-failure case**

```bash
curl -i -X POST http://<appserver-host>:<rest-port>/rest/cnsaos \
  -H "Content-Type: application/json" \
  -d '{"codCliente":"000001"}'
```

Expected: `400`, body `{"sucesso":false,"erro":"..."}` with some non-empty message (confirms Task 1's `FSZ1PosValid` is actually being hit through `VldData()`, and confirms whether `CNSA002_ERROMODEL`'s index `6` is the real message position — if `erro` comes back as the fallback `"Erro de validacao no registro."` instead of a specific field message, `GetErrorMessage()`'s array shape differs from what's assumed here; log `FWLogMsg("INFO", , "REST", "CNSA002_INCLUIR_OS", , "01", cValToChar(oModel:GetErrorMessage()), 0, 0, {})` right before the `400` return, retry, inspect the log, and fix the index in `CNSA002_ERROMODEL`).

- [ ] **Step 8: Commit**

```bash
git add "Fontes cnshub/CNSA002.PRW"
git commit -m "feat: adiciona endpoint @Post /cnsaos (incluir OS via FWModel)"
```

---

### Task 3: `@Put /cnsaos/:os` — Alterar OS

**Files:**
- Modify: `Fontes cnshub\CNSA002.PRW` — add the new `User Function` at the end of the file (after Task 2's code).

**Interfaces:**
- Consumes: `CNSA002_ISODATA`, `CNSA002_JSONNUM`, `CNSA002_ERROMODEL`, `CNSA002_RESPOK`, `CNSA002_RESPERRO` from Task 2.
- Produces: nothing new consumed by later tasks.

- [ ] **Step 1: Write the failing test**

Run against an OS number you know exists (e.g. the one created in Task 2's Step 6, call it `<os-criada>`):

```bash
curl -i -X PUT http://<appserver-host>:<rest-port>/rest/cnsaos/<os-criada> \
  -H "Content-Type: application/json" \
  -d '{"descricao":"Descricao alterada pelo plano"}'
```

Expected: 404 or connection error — route doesn't exist yet.

- [ ] **Step 2: Add the Alterar endpoint**

Append at the end of the file:

```advpl
////////////////////////////////////////////////////////////////////////////////
// PUT /cnsaos/:os - Altera uma OS (SZ1) existente via FWModel("CNSA002").
// Alteracao PARCIAL - so grava o campo que vier no body (presenca detectada
// por jBody[campo] <> Nil, nao por Empty() - permite mandar 0 de verdade em
// campo numerico, diferente do POUICNSA002.PRW atual que usa Empty()).
////////////////////////////////////////////////////////////////////////////////
@Put("/cnsaos/:os")
User Function CNSA002_ALTERAR_OS() As Logical
    Local jParams := oRest:getPathParamsRequest() As Json
    Local cOs     := AllTrim(jParams["os"]) As Character
    Local cBody   := oRest:getBodyRequest() As Character
    Local jBody   := JsonObject():New() As Json
    Local oModel  := Nil
    Local cErro   := ""

    oRest:setKeyHeaderResponse("Content-Type", "application/json")

    If jBody:fromJson(cBody) <> Nil
        Return oRest:setStatusResponse(400, CNSA002_RESPERRO("Body JSON invalido."))
    EndIf

    DbSelectArea("SZ1")
    SZ1->(DbSetOrder(1))
    If !SZ1->(DbSeek(xFilial("SZ1") + cOs))
        Return oRest:setStatusResponse(404, CNSA002_RESPERRO("OS nao encontrada."))
    EndIf

    Try
        oModel := FWLoadModel("CNSA002")
        oModel:SetOperation(MODEL_OPERATION_UPDATE)
        oModel:Activate()

        If jBody["codCliente"] <> Nil
            oModel:SetValue("SZ1MASTER", "Z1_CLI", jBody:GetJsonText("codCliente"))
        EndIf
        If jBody["lojaCliente"] <> Nil
            oModel:SetValue("SZ1MASTER", "Z1_LOJA", jBody:GetJsonText("lojaCliente"))
        EndIf
        If jBody["usuario"] <> Nil
            oModel:SetValue("SZ1MASTER", "Z1_USR", jBody:GetJsonText("usuario"))
        EndIf
        If jBody["modulo"] <> Nil
            oModel:SetValue("SZ1MASTER", "Z1_MODULO", jBody:GetJsonText("modulo"))
        EndIf
        If jBody["motivo"] <> Nil
            oModel:SetValue("SZ1MASTER", "Z1_MOTIV", jBody:GetJsonText("motivo"))
        EndIf
        If jBody["descricao"] <> Nil
            oModel:SetValue("SZ1MASTER", "Z1_SERV", DecodeUTF8(jBody:GetJsonText("descricao")))
        EndIf
        If jBody["codServico"] <> Nil
            oModel:SetValue("SZ1MASTER", "Z1_TIPO", jBody:GetJsonText("codServico"))
        EndIf
        If jBody["dataOs"] <> Nil
            oModel:SetValue("SZ1MASTER", "Z1_DTOS", CNSA002_ISODATA(jBody:GetJsonText("dataOs")))
        EndIf
        If jBody["horaInicialDec"] <> Nil
            oModel:SetValue("SZ1MASTER", "Z1_INI", CNSA002_JSONNUM(jBody, "horaInicialDec"))
        EndIf
        If jBody["horaFinalDec"] <> Nil
            oModel:SetValue("SZ1MASTER", "Z1_FIM", CNSA002_JSONNUM(jBody, "horaFinalDec"))
        EndIf
        If jBody["horasTranDec"] <> Nil
            oModel:SetValue("SZ1MASTER", "Z1_TRANS", CNSA002_JSONNUM(jBody, "horasTranDec"))
        EndIf
        If jBody["horasTiDec"] <> Nil
            oModel:SetValue("SZ1MASTER", "Z1_TOTAL", CNSA002_JSONNUM(jBody, "horasTiDec"))
        EndIf
        If jBody["codAnalista"] <> Nil
            oModel:SetValue("SZ1MASTER", "Z1_TEC", jBody:GetJsonText("codAnalista"))
        EndIf
        If jBody["osInterna"] <> Nil
            oModel:SetValue("SZ1MASTER", "Z1_INTERNO", jBody:GetJsonText("osInterna"))
        EndIf
        If jBody["prevPmt"] <> Nil
            oModel:SetValue("SZ1MASTER", "Z1_PREVIST", jBody:GetJsonText("prevPmt"))
        EndIf
        If jBody["numProposta"] <> Nil
            oModel:SetValue("SZ1MASTER", "Z1_NUMPRO", jBody:GetJsonText("numProposta"))
        EndIf
        If jBody["pedVenda"] <> Nil
            oModel:SetValue("SZ1MASTER", "Z1_PV", jBody:GetJsonText("pedVenda"))
        EndIf
        If jBody["hrAlmoco"] <> Nil
            oModel:SetValue("SZ1MASTER", "Z1_ALMOCO", CNSA002_JSONNUM(jBody, "hrAlmoco"))
        EndIf
        If jBody["projeto"] <> Nil
            oModel:SetValue("SZ1MASTER", "Z1_PROJET", jBody:GetJsonText("projeto"))
        EndIf
        If jBody["revisao"] <> Nil
            oModel:SetValue("SZ1MASTER", "Z1_REVISA", jBody:GetJsonText("revisao"))
        EndIf
        If jBody["tarefa"] <> Nil
            oModel:SetValue("SZ1MASTER", "Z1_TAREFA", jBody:GetJsonText("tarefa"))
        EndIf
        If jBody["chamadoHpsd"] <> Nil
            oModel:SetValue("SZ1MASTER", "Z1_CHPSD", jBody:GetJsonText("chamadoHpsd"))
        EndIf
        If jBody["chamado"] <> Nil
            oModel:SetValue("SZ1MASTER", "Z1_CHHDK", CNSA002_JSONNUM(jBody, "chamado"))
        EndIf
        If jBody["osDesenv"] <> Nil
            oModel:SetValue("SZ1MASTER", "Z1_OSDESE", jBody:GetJsonText("osDesenv"))
        EndIf
        If jBody["linhaPv"] <> Nil
            oModel:SetValue("SZ1MASTER", "Z1_LIN", jBody:GetJsonText("linhaPv"))
        EndIf
        If jBody["valorHora"] <> Nil
            oModel:SetValue("SZ1MASTER", "Z1_VLRHR", CNSA002_JSONNUM(jBody, "valorHora"))
        EndIf

        If !oModel:VldData()
            cErro := CNSA002_ERROMODEL(oModel)
            oModel:DeActivate()
            Return oRest:setStatusResponse(400, CNSA002_RESPERRO(cErro))
        EndIf

        If !oModel:CommitData()
            cErro := CNSA002_ERROMODEL(oModel)
            oModel:DeActivate()
            Return oRest:setStatusResponse(500, CNSA002_RESPERRO(cErro))
        EndIf

        oModel:DeActivate()

    Catch oErro
        If oModel <> Nil
            oModel:DeActivate()
        EndIf
        FWLogMsg("ERROR", , "REST", "CNSA002_ALTERAR_OS", , "01", oErro:Description, 0, 0, {})
        Return oRest:setStatusResponse(500, CNSA002_RESPERRO(oErro:Description))
    EndTry

Return oRest:setStatusResponse(200, CNSA002_RESPOK(cOs, "OS alterada com sucesso."))
```

- [ ] **Step 3: Compile**

Use `advpl-tlpp-compile`. Expected: compiles clean.

- [ ] **Step 4: Run the test from Step 1 again**

```bash
curl -i -X PUT http://<appserver-host>:<rest-port>/rest/cnsaos/<os-criada> \
  -H "Content-Type: application/json" \
  -d '{"descricao":"Descricao alterada pelo plano"}'
```

Expected: `200`, `{"sucesso":true,"os":"<os-criada>","mensagem":"OS alterada com sucesso."}`. Then `GET /rest/CNSAOS?os=<os-criada>` (existing WSRESTFUL, unchanged) to confirm the description actually changed.

- [ ] **Step 5: Run the 404 case**

```bash
curl -i -X PUT http://<appserver-host>:<rest-port>/rest/cnsaos/999999999 \
  -H "Content-Type: application/json" \
  -d '{"descricao":"x"}'
```

Expected: `404`, `{"sucesso":false,"erro":"OS nao encontrada."}`.

- [ ] **Step 6: Commit**

```bash
git add "Fontes cnshub/CNSA002.PRW"
git commit -m "feat: adiciona endpoint @Put /cnsaos/:os (alterar OS via FWModel)"
```

---

### Task 4: `@Delete /cnsaos/:os` — Excluir OS

**Files:**
- Modify: `Fontes cnshub\CNSA002.PRW` — add the new `User Function` at the end of the file (after Task 3's code).

**Interfaces:**
- Consumes: `CNSA002_ERROMODEL`, `CNSA002_RESPOK`, `CNSA002_RESPERRO` from Task 2.
- Produces: nothing new consumed by later tasks (last task in this plan).

- [ ] **Step 1: Write the failing test**

Create a throwaway OS first via Task 2's endpoint (`POST /cnsaos`) so you have a safe-to-delete `<os-descartavel>`, then:

```bash
curl -i -X DELETE http://<appserver-host>:<rest-port>/rest/cnsaos/<os-descartavel>
```

Expected: 404 or connection error — route doesn't exist yet.

- [ ] **Step 2: Add the Excluir endpoint**

Append at the end of the file:

```advpl
////////////////////////////////////////////////////////////////////////////////
// DELETE /cnsaos/:os - Exclui uma OS (SZ1) via FWModel("CNSA002").
////////////////////////////////////////////////////////////////////////////////
@Delete("/cnsaos/:os")
User Function CNSA002_EXCLUIR_OS() As Logical
    Local jParams := oRest:getPathParamsRequest() As Json
    Local cOs     := AllTrim(jParams["os"]) As Character
    Local oModel  := Nil
    Local cErro   := ""

    oRest:setKeyHeaderResponse("Content-Type", "application/json")

    DbSelectArea("SZ1")
    SZ1->(DbSetOrder(1))
    If !SZ1->(DbSeek(xFilial("SZ1") + cOs))
        Return oRest:setStatusResponse(404, CNSA002_RESPERRO("OS nao encontrada."))
    EndIf

    Try
        oModel := FWLoadModel("CNSA002")
        oModel:SetOperation(MODEL_OPERATION_DELETE)
        oModel:Activate()

        If !oModel:VldData()
            cErro := CNSA002_ERROMODEL(oModel)
            oModel:DeActivate()
            Return oRest:setStatusResponse(400, CNSA002_RESPERRO(cErro))
        EndIf

        If !oModel:CommitData()
            cErro := CNSA002_ERROMODEL(oModel)
            oModel:DeActivate()
            Return oRest:setStatusResponse(500, CNSA002_RESPERRO(cErro))
        EndIf

        oModel:DeActivate()

    Catch oErro
        If oModel <> Nil
            oModel:DeActivate()
        EndIf
        FWLogMsg("ERROR", , "REST", "CNSA002_EXCLUIR_OS", , "01", oErro:Description, 0, 0, {})
        Return oRest:setStatusResponse(500, CNSA002_RESPERRO(oErro:Description))
    EndTry

Return oRest:setStatusResponse(200, CNSA002_RESPOK(cOs, "OS excluida com sucesso."))
```

- [ ] **Step 3: Compile**

Use `advpl-tlpp-compile`. Expected: compiles clean.

- [ ] **Step 4: Run the test from Step 1 again**

```bash
curl -i -X DELETE http://<appserver-host>:<rest-port>/rest/cnsaos/<os-descartavel>
```

Expected: `200`, `{"sucesso":true,"os":"<os-descartavel>","mensagem":"OS excluida com sucesso."}`. Then `GET /rest/CNSAOS?os=<os-descartavel>` to confirm it's actually gone (`items` empty).

- [ ] **Step 5: Run the 404 case**

```bash
curl -i -X DELETE http://<appserver-host>:<rest-port>/rest/cnsaos/999999999
```

Expected: `404`, `{"sucesso":false,"erro":"OS nao encontrada."}`.

- [ ] **Step 6: Commit**

```bash
git add "Fontes cnshub/CNSA002.PRW"
git commit -m "feat: adiciona endpoint @Delete /cnsaos/:os (excluir OS via FWModel)"
```

---

## Post-plan open items (not blocking, tracked for a future pass)

- `CNSA002_ERROMODEL`'s index `6` for the error message inside `oModel:GetErrorMessage()`'s array is based on the commonly-documented TOTVS `FWFormModel` error-array shape, not on an in-repo confirmed example — Task 2 Step 7 is the first real confirmation point. If wrong, only that one helper function needs a one-line index fix.
- No auth/token check on any of the 3 new endpoints, matching every other endpoint in this module today (`POUICNSA002.PRW`, `wsportlsb.tlpp`) — not a regression, but also not solved here.
- Wiring these endpoints into the `pouios` Angular app (`os.service.ts`) is explicitly deferred — out of scope per the design spec.
