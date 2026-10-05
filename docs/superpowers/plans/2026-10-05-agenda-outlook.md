# Agendamento no calendário do Outlook — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Todo agendamento (SZ6) cria/atualiza/apaga um evento no calendário do Outlook do técnico, já salvo, sem convite.

**Architecture:** Funções globais de Outlook (Microsoft Graph) no final do `cnslib.tlpp`; um evento de modelo (`FWModelEvent`) no `cnsa003.prw` chama essas funções depois de gravar (incluir/alterar/excluir) — todos os caminhos que gravam SZ6 passam por esse modelo; a exclusão do chamado (CNSA001, `DbDelete` direto) apaga o evento antes de apagar o registro.

**Tech Stack:** ADVPL/TLPP (Protheus 12.1.2510, Oracle), Microsoft Graph v1.0 (`/users/{email}/events`), `HttpQuote`, `JsonObject`.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-10-05-agenda-outlook-design.md` (onde ela citar `CNSOUTLOOK.tlpp`, vale `cnslib.tlpp` — decisão do usuário em 05/10/2026: sem fonte novo).
- Fontes em CP1252 (latin-1) com CRLF — editar preservando encoding; sem acento em código/comentário ADVPL.
- Credenciais Graph: parâmetros `MV_CNSATEN` (tenant), `MV_CNSACLI` (client id), `MV_CNSASEC` (secret).
- Fuso do evento: `E. South America Standard Time`. Lembrete 15 min, `showAs` = `busy`, sem `attendees`.
- Campo de vínculo: `Z6_IDOUTL` (C, 200) — criado pelo usuário no Configurador.
- Falha do Outlook **nunca** impede gravar o agendamento: só `ConOut("CNSOUTLOOK: ...")`.
- Compilação é feita pelo usuário (nunca pedir/ver senha). Sem framework de teste automatizado: testes são manuais, roteiro em cada task.
- Fluxo git: branch `feature/henrique-05-10` → commit → push → PR → merge → pull (repo `apIA-git/MVC`, base `main`). Não commitar `.vscode/`.

---

### Task 1: Funções de Outlook no `cnslib.tlpp`

**Files:**
- Modify: `Fontes MVC e Site/cnslib.tlpp` (acrescentar no FINAL do arquivo, depois de `User Function CNSA_TECNICO()`)

**Interfaces:**
- Produces:
  - `U_CNSOUTL_SALVAR(cEmailTec As Character, cIdEvento As Character, dData As Date, cHrIni As Character, cHrFim As Character, cAssunto As Character, cCorpo As Character) -> cIdEvento As Character` — cria (id vazio) ou atualiza (PATCH; 404 recria) o evento; `""` em falha de criação.
  - `U_CNSOUTL_EXCLUIR(cEmailTec As Character, cIdEvento As Character) -> lOk As Logical` — DELETE; 204/404 = `.T.`; id vazio = `.T.` (nada a fazer).

- [ ] **Step 1: Acrescentar o bloco abaixo no final de `cnslib.tlpp`** (CRLF, CP1252)

```
////////////////////////////////////////////////////////////////////////////////
// Calendario do Outlook do tecnico (Microsoft Graph) - spec
// docs/superpowers/specs/2026-10-05-agenda-outlook-design.md
// Henrique - 05/10/2026 - funcoes globais (sem namespace), chamadas pelo
//   evento de modelo do CNSA003 (incluir/alterar/excluir agendamento) e pela
//   exclusao do chamado (CNSA001). Grava o evento DIRETO no calendario do
//   tecnico (POST /users/{email}/events, permissao de aplicativo
//   Calendars.ReadWrite) - sem convite, sem aceitar. Nunca lancam erro:
//   falha vai pro console e devolve vazio/.F. (o Outlook nao pode impedir
//   gravar o agendamento).
////////////////////////////////////////////////////////////////////////////////

//-------------------------------------------------------------------
/*/{Protheus.doc} CNSOUTL_SALVAR
Cria ou atualiza o evento do agendamento no calendario do tecnico.
@param  cEmailTec  E-mail do tecnico (AA1_EMAIL) - calendario de destino
@param  cIdEvento  Id do evento ja criado (Z6_IDOUTL) - vazio = criar
@param  dData      Data do agendamento
@param  cHrIni     Hora inicial (HH:MM)
@param  cHrFim     Hora final (HH:MM)
@param  cAssunto   Assunto do evento
@param  cCorpo     Corpo HTML do evento
@return cId        Id do evento (vazio se nao conseguiu criar)
@author Henrique
@since 05/10/2026
@version P12
/*/
//-------------------------------------------------------------------
User Function CNSOUTL_SALVAR(cEmailTec, cIdEvento, dData, cHrIni, cHrFim, cAssunto, cCorpo)
    Local cToken := ""
    Local cJson  := ""
    Local aResp  := {}
    Local cId    := ""

    cEmailTec := AllTrim(cEmailTec)
    cIdEvento := AllTrim(cIdEvento)

    If Empty(cEmailTec)
        ConOut("CNSOUTLOOK: tecnico sem e-mail (AA1_EMAIL) - evento nao gravado no Outlook.")
        Return cIdEvento
    EndIf

    cToken := CNSOUTL_TOKEN()
    If Empty(cToken)
        Return cIdEvento
    EndIf

    cJson := CNSOUTL_JSONEVENTO(dData, cHrIni, cHrFim, cAssunto, cCorpo)

    If !Empty(cIdEvento)
        aResp := CNSOUTL_HTTP("PATCH", "/v1.0/users/" + cEmailTec + "/events/" + cIdEvento, cJson, cToken)
        If aResp[1] == 200
            Return cIdEvento
        EndIf
        If aResp[1] != 404
            ConOut("CNSOUTLOOK: falha ao atualizar evento de " + cEmailTec + " (HTTP " + cValToChar(aResp[1]) + "): " + aResp[2])
            Return cIdEvento
        EndIf
        // 404: evento apagado direto no Outlook - cria de novo abaixo.
    EndIf

    aResp := CNSOUTL_HTTP("POST", "/v1.0/users/" + cEmailTec + "/events", cJson, cToken)
    If aResp[1] == 201
        cId := CNSOUTL_IDRESPOSTA(aResp[2])
    Else
        ConOut("CNSOUTLOOK: falha ao criar evento para " + cEmailTec + " (HTTP " + cValToChar(aResp[1]) + "): " + aResp[2])
    EndIf

Return cId

//-------------------------------------------------------------------
/*/{Protheus.doc} CNSOUTL_EXCLUIR
Apaga o evento do agendamento do calendario do tecnico.
@param  cEmailTec  E-mail do tecnico (AA1_EMAIL)
@param  cIdEvento  Id do evento (Z6_IDOUTL)
@return lOk        .T. se apagou, ja nao existia (404) ou nao havia evento
@author Henrique
@since 05/10/2026
@version P12
/*/
//-------------------------------------------------------------------
User Function CNSOUTL_EXCLUIR(cEmailTec, cIdEvento)
    Local cToken := ""
    Local aResp  := {}
    Local lOk    := .F.

    cEmailTec := AllTrim(cEmailTec)
    cIdEvento := AllTrim(cIdEvento)

    If Empty(cIdEvento)
        Return .T.
    EndIf
    If Empty(cEmailTec)
        ConOut("CNSOUTLOOK: tecnico sem e-mail (AA1_EMAIL) - evento " + cIdEvento + " nao apagado do Outlook.")
        Return .F.
    EndIf

    cToken := CNSOUTL_TOKEN()
    If Empty(cToken)
        Return .F.
    EndIf

    aResp := CNSOUTL_HTTP("DELETE", "/v1.0/users/" + cEmailTec + "/events/" + cIdEvento, "", cToken)
    lOk   := (aResp[1] == 204 .Or. aResp[1] == 404)
    If !lOk
        ConOut("CNSOUTLOOK: falha ao apagar evento de " + cEmailTec + " (HTTP " + cValToChar(aResp[1]) + "): " + aResp[2])
    EndIf

Return lOk

//-------------------------------------------------------------------
/*/{Protheus.doc} CNSOUTL_HTTP
Chamada ao Microsoft Graph com qualquer verbo (HttpQuote - FWRest nao tem
PATCH). Devolve o status HTTP lido da 1a linha do cabecalho de resposta.
@return aResp  {nStatus, cCorpoResposta}
@author Henrique
@since 05/10/2026
@version P12
/*/
//-------------------------------------------------------------------
Static Function CNSOUTL_HTTP(cMetodo, cPath, cCorpo, cToken)
    Local aHeader  := {"Authorization: Bearer " + cToken, "Content-Type: application/json; charset=utf-8"}
    Local cHeadRet := ""
    Local cResp    := ""
    Local nStatus  := 0
    Local nPos     := 0

    cResp := HttpQuote("https://graph.microsoft.com" + cPath, cMetodo, "", cCorpo, 60, aHeader, @cHeadRet)
    If ValType(cResp) != "C"
        cResp := ""
    EndIf
    // 1a linha do cabecalho: "HTTP/1.1 201 Created"
    If ValType(cHeadRet) == "C"
        nPos := At(" ", cHeadRet)
        If nPos > 0
            nStatus := Val(SubStr(cHeadRet, nPos + 1, 3))
        EndIf
    EndIf

Return {nStatus, cResp}

//-------------------------------------------------------------------
/*/{Protheus.doc} CNSOUTL_JSONEVENTO
Monta o JSON do evento (JsonObject cuida do escape) em UTF-8.
@return cJson  JSON do evento
@author Henrique
@since 05/10/2026
@version P12
/*/
//-------------------------------------------------------------------
Static Function CNSOUTL_JSONEVENTO(dData, cHrIni, cHrFim, cAssunto, cCorpo)
    Local oJson := JsonObject():New()
    Local cDia  := DToS(dData)
    Local cJson := ""
    Local xUtf8 := Nil

    cDia := Left(cDia, 4) + "-" + SubStr(cDia, 5, 2) + "-" + Right(cDia, 2)

    oJson['subject'] := cAssunto
    oJson['body']    := JsonObject():New()
    oJson['body']['contentType'] := "HTML"
    oJson['body']['content']     := cCorpo
    oJson['start']   := JsonObject():New()
    oJson['start']['dateTime']   := cDia + "T" + CNSOUTL_HORA(cHrIni) + ":00"
    oJson['start']['timeZone']   := "E. South America Standard Time"
    oJson['end']     := JsonObject():New()
    oJson['end']['dateTime']     := cDia + "T" + CNSOUTL_HORA(cHrFim) + ":00"
    oJson['end']['timeZone']     := "E. South America Standard Time"
    oJson['showAs']  := "busy"
    oJson['isReminderOn'] := .T.
    oJson['reminderMinutesBeforeStart'] := 15

    cJson := oJson:ToJson()
    FreeObj(oJson)

    // Fonte/base em CP1252 - Graph espera UTF-8 (acento em nome de cliente etc.)
    xUtf8 := EncodeUTF8(cJson)

Return If(ValType(xUtf8) == "C", xUtf8, cJson)

// "8:00" / "0800" / "08:00" -> "08:00"
Static Function CNSOUTL_HORA(cHora)
    Local cDig := ""
    Local nI   := 0

    cHora := AllTrim(cHora)
    For nI := 1 To Len(cHora)
        If IsDigit(SubStr(cHora, nI, 1))
            cDig += SubStr(cHora, nI, 1)
        EndIf
    Next nI
    cDig := PadL(Left(cDig, 4), 4, "0")

Return Left(cDig, 2) + ":" + Right(cDig, 2)

// Id do evento na resposta do POST
Static Function CNSOUTL_IDRESPOSTA(cResp)
    Local oJson := JsonObject():New()
    Local cId   := ""

    If Empty(oJson:FromJson(cResp)) .And. ValType(oJson['id']) == "C"
        cId := oJson['id']
    EndIf
    FreeObj(oJson)

Return cId

//-------------------------------------------------------------------
/*/{Protheus.doc} CNSOUTL_TOKEN
Token do Graph (client credentials) - mesma logica do CH_TOKENGRAPH
(CNSA001, Static em namespace - nao da pra chamar daqui).
@return cToken  Access token ou vazio
@author Henrique
@since 05/10/2026
@version P12
/*/
//-------------------------------------------------------------------
Static Function CNSOUTL_TOKEN()
    Local cTenant := AllTrim(GetMV("MV_CNSATEN"))
    Local cClient := AllTrim(GetMV("MV_CNSACLI"))
    Local cSecret := AllTrim(GetMV("MV_CNSASEC"))
    Local oRest   := Nil
    Local oJson   := Nil
    Local cBody   := ""
    Local cToken  := ""

    If Empty(cTenant) .Or. Empty(cClient) .Or. Empty(cSecret)
        ConOut("CNSOUTLOOK: MV_CNSATEN/MV_CNSACLI/MV_CNSASEC nao configurados - Outlook nao atualizado.")
        Return ""
    EndIf

    cBody := "grant_type=client_credentials"
    cBody += "&client_id="     + CNSOUTL_URL(cClient)
    cBody += "&client_secret=" + CNSOUTL_URL(cSecret)
    cBody += "&scope="         + CNSOUTL_URL("https://graph.microsoft.com/.default")

    oRest := FWRest():New("https://login.microsoftonline.com")
    oRest:setPath("/" + cTenant + "/oauth2/v2.0/token")
    oRest:SetPostParams(cBody)
    If !oRest:Post({"Content-Type: application/x-www-form-urlencoded"})
        ConOut("CNSOUTLOOK: falha no POST de token (Azure AD): " + oRest:GetLastError())
        FreeObj(oRest)
        Return ""
    EndIf

    oJson := JsonObject():New()
    If Empty(oJson:FromJson(oRest:GetResult())) .And. ValType(oJson["access_token"]) == "C"
        cToken := oJson["access_token"]
    Else
        ConOut("CNSOUTLOOK: resposta do Azure AD sem access_token: " + oRest:GetResult())
    EndIf
    FreeObj(oJson)
    FreeObj(oRest)

Return cToken

// Percent-encoding (x-www-form-urlencoded) do corpo do token
Static Function CNSOUTL_URL(cTexto)
    Local cRet := ""
    Local cHex := "0123456789ABCDEF"
    Local cCh  := ""
    Local nAsc := 0
    Local nI   := 0

    For nI := 1 To Len(cTexto)
        cCh := SubStr(cTexto, nI, 1)
        If IsAlpha(cCh) .Or. IsDigit(cCh) .Or. cCh $ "-_.~"
            cRet += cCh
        Else
            nAsc := Asc(cCh)
            cRet += "%" + SubStr(cHex, Int(nAsc / 16) + 1, 1) + SubStr(cHex, (nAsc % 16) + 1, 1)
        EndIf
    Next nI

Return cRet
```

- [ ] **Step 2: Conferir encoding e fim de linha**

Run: `python -c "s=open(r'Fontes MVC e Site/cnslib.tlpp','rb').read(); s.decode('cp1252'); print(s.count(b'\r\n')>0, b'\n' not in s.replace(b'\r\n',b''))"`
Expected: `True True`

- [ ] **Step 3: Compilar (usuário)** `cnslib.tlpp` no ambiente do REST. Expected: compila sem erro (warnings de variável não usada = corrigir).

- [ ] **Step 4: Teste manual isolado** — só depois da Task 2 há quem chame as funções; o teste real é o roteiro da Task 2. Aqui conferir só que o console não mostra erro de compilação/carga do `cnslib`.

- [ ] **Step 5: Commit**

```bash
git add "Fontes MVC e Site/cnslib.tlpp"
git commit -m "feat: funcoes de calendario do Outlook (Graph) no cnslib"
```

---

### Task 2: Evento de modelo no CNSA003 (incluir/alterar/excluir)

**Files:**
- Modify: `Fontes MVC e Site/cnsa003.prw` — `ModelDef` (linha ~62, depois do `MPFormModel():New`) e novo bloco antes de `Static Function ViewDef()` (linha ~79)

**Interfaces:**
- Consumes: `U_CNSOUTL_SALVAR(cEmailTec, cIdEvento, dData, cHrIni, cHrFim, cAssunto, cCorpo) -> cId`, `U_CNSOUTL_EXCLUIR(cEmailTec, cIdEvento) -> lOk` (Task 1).
- Produces: classe `CNS003OUTL` (evento do modelo `ModelSZ6`), campo `Z6_IDOUTL` preenchido.

- [ ] **Step 1: Instalar o evento no `ModelDef`** — logo depois da linha `oModel:=MPFormModel():New('ModelSZ6', ...)`:

```
// Calendario do Outlook do tecnico: cria/atualiza/apaga o evento depois de
// gravar (CNS003OUTL) - vale pra toda tela que grava SZ6 por este modelo.
oModel:InstallEvent("CNS003OUTL", /*cOwner*/, CNS003OUTL():New())
```

- [ ] **Step 2: Acrescentar a classe e as funções de apoio** antes de `Static Function ViewDef()`:

```
//-------------------------------------------------------------------
/*/{Protheus.doc} CNS003OUTL
Evento do modelo da Agenda: mantem o agendamento no calendario do Outlook
do tecnico (spec docs/superpowers/specs/2026-10-05-agenda-outlook-design.md).
BeforeTTS guarda tecnico/id do evento ANTES de gravar (alterar/excluir);
AfterTTS (depois do commit) cria, atualiza, troca de calendario ou apaga
via U_CNSOUTL_SALVAR / U_CNSOUTL_EXCLUIR (cnslib.tlpp). Falha do Outlook
nunca impede a gravacao.
@author Henrique
@since 05/10/2026
@version P12
/*/
//-------------------------------------------------------------------
Class CNS003OUTL From FWModelEvent
    Data cTecAnt
    Data cIdAnt
    Method New() Constructor
    Method BeforeTTS()
    Method AfterTTS()
EndClass

Method New() Class CNS003OUTL
    ::cTecAnt := ""
    ::cIdAnt  := ""
Return Self

Method BeforeTTS(oModel, cModelId) Class CNS003OUTL
    Local nOper := oModel:GetOperation()

    ::cTecAnt := ""
    ::cIdAnt  := ""
    // Alterar/Excluir: SZ6 posicionado no registro que vai ser gravado.
    If nOper == MODEL_OPERATION_UPDATE .Or. nOper == MODEL_OPERATION_DELETE
        ::cTecAnt := AllTrim(SZ6->Z6_TECNICO)
        ::cIdAnt  := AllTrim(SZ6->Z6_IDOUTL)
    EndIf
Return

Method AfterTTS(oModel, cModelId) Class CNS003OUTL
    Local nOper  := oModel:GetOperation()
    Local oSZ6   := oModel:GetModel('ModelSZ6_Main')
    Local bErro  := ErrorBlock({|e| Break(e)})
    Local cTec   := ""
    Local cId    := ""
    Local aTexto := {}
    Local oErro  := Nil

    Begin Sequence
        If nOper == MODEL_OPERATION_DELETE
            U_CNSOUTL_EXCLUIR(CNS003EmTec(::cTecAnt), ::cIdAnt)
            Break
        EndIf
        If nOper != MODEL_OPERATION_INSERT .And. nOper != MODEL_OPERATION_UPDATE
            Break
        EndIf

        cTec := AllTrim(oSZ6:GetValue('Z6_TECNICO'))
        cId  := ::cIdAnt

        // Trocou o tecnico: sai do calendario do antigo, entra no do novo.
        If nOper == MODEL_OPERATION_UPDATE .And. !Empty(cId) .And. ::cTecAnt != cTec
            U_CNSOUTL_EXCLUIR(CNS003EmTec(::cTecAnt), cId)
            cId := ""
        EndIf

        aTexto := CNS003OutTx(oSZ6)
        cId    := U_CNSOUTL_SALVAR(CNS003EmTec(cTec), cId, oSZ6:GetValue('Z6_DTAGE'), ;
                    oSZ6:GetValue('Z6_HMINI'), oSZ6:GetValue('Z6_HMFIM'), aTexto[1], aTexto[2])

        If AllTrim(cId) != ::cIdAnt
            CNS003GrvId(oSZ6, cId)
        EndIf
    Recover Using oErro
        If oErro != Nil
            ConOut("CNSOUTLOOK: erro no evento do CNSA003: " + oErro:Description)
        EndIf
    End Sequence

    ErrorBlock(bErro)
Return

// E-mail do tecnico (AA1_EMAIL) - calendario do Outlook
Static Function CNS003EmTec(cTec)
    If Empty(cTec)
        Return ""
    EndIf
Return AllTrim(Posicione("AA1", 1, xFilial("AA1") + cTec, "AA1_EMAIL"))

// {cAssunto, cCorpoHtml} do evento
Static Function CNS003OutTx(oSZ6)
    Local cCli     := AllTrim(oSZ6:GetValue('Z6_CLIENTE'))
    Local cLoja    := AllTrim(oSZ6:GetValue('Z6_LOJA'))
    Local nCham    := oSZ6:GetValue('Z6_CHAMADO')
    Local cNomCli  := ""
    Local cAssunto := "Agendamento"
    Local cCorpo   := ""

    If !Empty(cCli)
        cNomCli := AllTrim(Posicione("SA1", 1, xFilial("SA1") + cCli + cLoja, "A1_NREDUZ"))
    EndIf
    If !Empty(cNomCli)
        cAssunto += " - " + cNomCli
    EndIf
    If ValType(nCham) == "N" .And. nCham > 0
        cAssunto += " - Chamado #" + StrZero(nCham, 6)
    EndIf

    cCorpo := "<p><b>Cliente:</b> " + cNomCli + "</p>"
    If !Empty(oSZ6:GetValue('Z6_PROJET'))
        cCorpo += "<p><b>Projeto/Tarefa:</b> " + AllTrim(oSZ6:GetValue('Z6_PROJET')) + " / " + AllTrim(oSZ6:GetValue('Z6_TAREFA')) + "</p>"
    EndIf
    If !Empty(oSZ6:GetValue('Z6_SERVICO'))
        cCorpo += "<p><b>Servi&ccedil;o:</b> " + AllTrim(oSZ6:GetValue('Z6_SERVICO')) + "</p>"
    EndIf
    If !Empty(oSZ6:GetValue('Z6_QGRAVOU'))
        cCorpo += "<p><b>Agendado por:</b> " + AllTrim(oSZ6:GetValue('Z6_QGRAVOU')) + "</p>"
    EndIf

Return {cAssunto, cCorpo}

// Grava o id do evento no SZ6 recem-gravado (localizado pela chave do modelo).
Static Function CNS003GrvId(oSZ6, cId)
    Local aArea  := SZ6->(GetArea())
    Local cAlias := GetNextAlias()
    Local cData  := DToS(oSZ6:GetValue('Z6_DTAGE'))
    Local cTec   := oSZ6:GetValue('Z6_TECNICO')
    Local xSeq   := oSZ6:GetValue('Z6_SEQ')

    BeginSql Alias cAlias
        SELECT SZ6.R_E_C_N_O_ RECNO
        FROM %Table:SZ6% SZ6
        WHERE Z6_FILIAL  = %xFilial:SZ6%
          AND Z6_DTAGE   = %Exp:cData%
          AND Z6_TECNICO = %Exp:cTec%
          AND Z6_SEQ     = %Exp:xSeq%
          AND %NotDel%
    EndSql
    If !(cAlias)->(Eof())
        SZ6->(DbGoTo((cAlias)->RECNO))
        RecLock("SZ6", .F.)
            SZ6->Z6_IDOUTL := cId
        SZ6->(MsUnlock())
    Else
        ConOut("CNSOUTLOOK: agendamento nao localizado pra gravar Z6_IDOUTL (" + cData + "/" + AllTrim(cTec) + ").")
    EndIf
    (cAlias)->(DbCloseArea())
    RestArea(aArea)

Return
```

- [ ] **Step 3: Conferir encoding/CRLF do `cnsa003.prw`** (mesmo comando da Task 1, Step 2, com o caminho do `cnsa003.prw`). Expected: `True True`.

- [ ] **Step 4: Pré-requisitos do usuário** — `Z6_IDOUTL` criado; `Calendars.ReadWrite` liberado no Azure.

- [ ] **Step 5: Compilar (usuário)** `cnsa003.prw` (e `cnslib.tlpp` se ainda não).

- [ ] **Step 6: Roteiro de teste manual**

1. Chamado com técnico (que tenha `AA1_EMAIL`) → tela clássica "Agendar" → confirmar. Expected: evento no calendário do técnico, já salvo, sem e-mail de convite; `Z6_IDOUTL` preenchido.
2. Portal → Chamado → "Criar Agenda" com 2 dias. Expected: 2 eventos.
3. Agenda (portal cns009) → alterar horário. Expected: mesmo evento, horário novo.
4. Agenda → trocar técnico. Expected: some do antigo, aparece no novo; `Z6_IDOUTL` novo.
5. Agenda → excluir. Expected: evento some.
6. Técnico sem e-mail → agendar. Expected: agendamento grava; console `CNSOUTLOOK: tecnico sem e-mail`.

Se o passo 1 der 403 no console → falta `Calendars.ReadWrite`/consentimento no Azure.

- [ ] **Step 7: Commit**

```bash
git add "Fontes MVC e Site/cnsa003.prw"
git commit -m "feat: agendamento sincroniza com o calendario do Outlook do tecnico (CNSA003)"
```

---

### Task 3: Exclusão do chamado apaga os eventos (CNSA001)

**Files:**
- Modify: `Fontes MVC e Site/CNSA001.TLPP:2016-2021` (loop que apaga SZ6 do chamado, `RecLock("SZ6", .F.)` / `DbDelete()`)

**Interfaces:**
- Consumes: `U_CNSOUTL_EXCLUIR(cEmailTec, cIdEvento) -> lOk` (Task 1).

- [ ] **Step 1: Antes do `RecLock("SZ6", .F.)` desse loop, inserir:**

```
                // Calendario do Outlook do tecnico (spec agenda-outlook): apaga o
                // evento antes do registro - esta exclusao nao passa pelo modelo
                // do CNSA003 (evento CNS003OUTL).
                If !Empty(AllTrim(SZ6->Z6_IDOUTL))
                    U_CNSOUTL_EXCLUIR(AllTrim(Posicione("AA1", 1, xFilial("AA1") + SZ6->Z6_TECNICO, "AA1_EMAIL")), SZ6->Z6_IDOUTL)
                EndIf
```

- [ ] **Step 2: Compilar (usuário)** `CNSA001.TLPP`. Se der erro de função não encontrada por causa do `Namespace apia.cnsa001` (a chamada resolver só no namespace), trocar a linha da chamada por macro, que resolve no escopo global em tempo de execução:

```
                    &("U_CNSOUTL_EXCLUIR")(AllTrim(Posicione("AA1", 1, xFilial("AA1") + SZ6->Z6_TECNICO, "AA1_EMAIL")), SZ6->Z6_IDOUTL)
```

- [ ] **Step 3: Teste manual** — chamado com agendamento já no Outlook → excluir/encerrar o chamado (portal ou tela). Expected: eventos somem do calendário do técnico.

- [ ] **Step 4: Commit**

```bash
git add "Fontes MVC e Site/CNSA001.TLPP"
git commit -m "feat: excluir chamado apaga os eventos do Outlook dos agendamentos"
```

---

### Task 4: Ajustar a spec e publicar

**Files:**
- Modify: `docs/superpowers/specs/2026-10-05-agenda-outlook-design.md` (trocar `CNSOUTLOOK.tlpp` por "final do `cnslib.tlpp`")

- [ ] **Step 1: Atualizar a spec** — seção "Arquitetura": título `### Funções de Outlook no final do cnslib.tlpp (sem fonte novo)`; "Pré-requisitos" item 3: compilar `cnslib.tlpp`, `cnsa003.prw` e `CNSA001.TLPP`.

- [ ] **Step 2: Commit, push, PR e merge**

```bash
git add docs/superpowers/specs/2026-10-05-agenda-outlook-design.md docs/superpowers/plans/2026-10-05-agenda-outlook.md
git commit -m "docs: spec/plano agenda-outlook - funcoes no cnslib"
git push -u origin feature/henrique-05-10
gh pr create -R apIA-git/MVC -B main -H feature/henrique-05-10 -t "feat: agendamento no calendario do Outlook do tecnico" -b "$(printf -- '- Funcoes de Outlook (Graph) no cnslib\n- Evento de modelo no CNSA003: incluir/alterar/excluir agendamento mantem o calendario do tecnico\n- Exclusao do chamado apaga os eventos\n\n🤖 Generated with [Claude Code](https://claude.com/claude-code)')"
gh pr merge -R apIA-git/MVC feature/henrique-05-10 --merge
git checkout main && git pull
```

Sem deploy do portal (nenhuma mudança no apia-po-cnshub).
