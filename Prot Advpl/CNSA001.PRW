#include "PROTHEUS.CH"
#include "RWMAKE.CH"
#include "TOPCONN.CH"
#include "TOTVS.CH"
#include "FWMBROWSE.CH"
#include "FWMVCDEF.CH"
#include "COLORS.CH"

////////////////////////////////////////////////////////////////////////////////////////////
//FUNCAO PRINCIPAL
User Function CNSA001()

    Local l_oBrowse := Nil
    Local nCriados  := 0
    Private aRotina := MenuDef()
    Private cConsultor := ""
    cConsultor := Posicione("AA1",4,xFilial("AA1")+__cUserId,"AA1_CODTEC")

    nCriados := CNSA_GERACHAM()
    If nCriados < 0
        MsgAlert("Nao foi possivel verificar a caixa apia@apia.com.br no momento.", "E-mails")
    ElseIf nCriados == 0
        MsgInfo("Sem e-mails novos em apia@apia.com.br.", "E-mails")
    Else
        MsgAlert("Foram abertos " + cValToChar(nCriados) + " chamado(s) a partir de e-mail(s) novo(s).", "Novos Chamados")
    EndIf

    l_oBrowse := FWMBrowse():New()
    If l_oBrowse <> Nil

        l_oBrowse:SetDescription("Registro de Chamados - OS")
        l_oBrowse:SetAlias("ZA1")

        l_oBrowse:AddLegend( "ZA1->ZA1_STATUS == '1'", "GREEN",  "Aberto" )
        l_oBrowse:AddLegend( "ZA1->ZA1_STATUS == '2'", "YELLOW", "Pendente Apia" )
        l_oBrowse:AddLegend( "ZA1->ZA1_STATUS == '3'", "ORANGE", "Pendente Cli." )
        l_oBrowse:AddLegend( "ZA1->ZA1_STATUS == '4'", "RED",    "Fechado" )

        l_oBrowse:AddFilter("Meus","ZA1_CONSUL == cConsultor")
        l_oBrowse:AddFilter("Nao Assumidos", "ZA1_CONSUL == ' '")

        l_oBrowse:Activate()

    EndIf

Return

///////////////////////////////////////////////////////////////////////////////////
//ROTINA MENU
Static Function MenuDef()

Local aRotina := {}

    ADD OPTION aRotina TITLE "Pesquisar"       ACTION "AxPesqui"          OPERATION 1 ACCESS 0
    ADD OPTION aRotina TITLE "Visualizar"      ACTION "VIEWDEF.CNSA001"   OPERATION 2 ACCESS 0
    ADD OPTION aRotina TITLE "Incluir"         ACTION "VIEWDEF.CNSA001"   OPERATION 3 ACCESS 0
    ADD OPTION aRotina TITLE "Alterar"         ACTION "VIEWDEF.CNSA001"   OPERATION 4 ACCESS 0
    ADD OPTION aRotina TITLE "Excluir"         ACTION "VIEWDEF.CNSA001"   OPERATION 5 ACCESS 0
    ADD OPTION aRotina TITLE "Assumir Chamado" ACTION "U_CNSA_ASSUMIR"    OPERATION 0 ACCESS 0
    ADD OPTION aRotina TITLE "Legenda"         ACTION "U_CNSA_LEG"        OPERATION 0 ACCESS 0

Return aRotina

//////////////////////////////////////////////////////////////////////////////////////////////
Static Function ViewDef()

    Local l_oView    := Nil
    Local l_oModel   := FWLoadModel("CNSA001")
    Local l_oStruZA1 := FWFormStruct(2, "ZA1")
    Local l_oStruZA2 := FWFormStruct(2, "ZA2")

    If l_oModel == Nil
        MsgStop("Erro: O Modelo (ModelDef) nao foi carregado.", "Erro")
        Return Nil
    EndIf

    l_oView := FWFormView():New()
    l_oView:SetModel(l_oModel)

    l_oView:AddField("VIEW_ZA1", l_oStruZA1, "ZA1MASTER")
    l_oView:AddGrid("VIEW_ZA2",  l_oStruZA2, "ZA2DETAIL")

    l_oView:CreateHorizontalBox("CABEC", 60)
    l_oView:CreateHorizontalBox("GRID",  40)

    l_oView:SetOwnerView("VIEW_ZA1", "CABEC")
    l_oView:SetOwnerView("VIEW_ZA2", "GRID")

    l_oView:EnableTitleView("VIEW_ZA1", "Dados do Chamado")
    l_oView:EnableTitleView("VIEW_ZA2", "Interacoes")

    l_oView:SetCloseOnOk({||.T.})

Return l_oView

///////////////////////////////////////////////////////////////////////////////////////////////////
//MODELACAO
Static Function ModelDef()

    Local l_oModel  := Nil
    Local l_oStrZA1 := FWFormStruct(1, "ZA1")
    Local l_oStrZA2 := FWFormStruct(1, "ZA2")
    Local aRelZA2   := {}

    l_oModel := MPFormModel():New(;
        "FCNSA001",;
        {|oModel| CNSA_TOK(oModel)},;
        {|oModel| CNSA_CAN(oModel)})

    l_oModel:AddFields(;
        "ZA1MASTER",;
        NIL,;
        l_oStrZA1,;
        {|_f,_a,_c,_v| CNSA_POSVAL(_f,_a,_c,_v)},;
        NIL)

    l_oModel:AddGrid("ZA2DETAIL", "ZA1MASTER", l_oStrZA2)

    aAdd(aRelZA2, {"ZA2_IDCH",   "ZA1_IDCH"})
    l_oModel:SetRelation("ZA2DETAIL", aRelZA2, ZA2->(IndexKey(3)))

    l_oModel:SetPrimaryKey({"ZA1_FILIAL","ZA1_IDCH"})

Return l_oModel

//////////////////////////////////////////////////////////////////////////////////////////
Static Function CNSA_POSVAL(p_oModel, p_sAcao, p_sCampo, p_vValor)
    Local l_bOk := .T.
Return l_bOk

Static Function CNSA_TOK(p_oModel)
    Local l_bOk := .T.
Return l_bOk

Static Function CNSA_CAN(p_oModel)
Return .T.

User Function GETIDGRID()
    Local oModel  := FWModelActive()
    Local l_oZA2  := oModel:GetModel("ZA2DETAIL")
    Local nLines  := l_oZA2:Length()
    Local nLinAtu := l_oZA2:GetLine()
    Local nI := 0
    Local nSeq := 1

    For nI := 1 To nLines
        l_oZA2:GoLine(nI)
        If !l_oZA2:IsDeleted()
            nSeq++
        EndIf
    Next nI

    l_oZA2:GoLine(nLinAtu)
Return StrZero(nSeq, 3)

User Function CNSA_LEG()
    BrwLegenda("Legenda de Status", "Status do Chamado", ;
        { ;
            { "BR_VERDE",     "Aberto"        }, ;
            { "BR_AMARELO",   "Pendente Apia" }, ;
            { "BR_LARANJA",   "Pendente Cli." }, ;
            { "BR_VERMELHO",  "Fechado"       }  ;
        })
Return

////////////////////////////////////////////////////////////////////////////////////////////
User Function CNSA_ASSUMIR()

    Local cConsultor     := ""
    Local cNomeConsultor := ""
    Local cFase          := ""

    cConsultor := Posicione("AA1",4,xFilial("AA1")+__cUserId,"AA1_CODTEC")

    If Empty(cConsultor)
        MsgAlert("Seu usuario nao esta vinculado a nenhum consultor (AA1).", "Assumir Chamado")
        Return
    EndIf

    If ZA1->(Eof()) .Or. ZA1->(Bof())
        MsgAlert("Nenhum chamado selecionado.", "Assumir Chamado")
        Return
    EndIf

    If AllTrim(ZA1->ZA1_CONSUL) == AllTrim(cConsultor)
        MsgAlert("Voce ja e o responsavel por este chamado.", "Assumir Chamado")
        Return
    EndIf

    If !Empty(AllTrim(ZA1->ZA1_CONSUL))
        cNomeConsultor := Posicione("AA1",1,xFilial("AA1")+AllTrim(ZA1->ZA1_CONSUL),"AA1_NOME")
        MsgAlert("Este chamado ja foi assumido por: " + cNomeConsultor + ".", "Assumir Chamado")
        Return
    EndIf

    If ZA1->ZA1_STATUS == "4"
        MsgAlert("Chamado fechado nao pode ser assumido.", "Assumir Chamado")
        Return
    EndIf

    If ZA1->ZA1_STATUS == "2" .Or. ZA1->ZA1_STATUS == "3"
        MsgAlert("Chamado pendente nao pode ser assumido.", "Assumir Chamado")
        Return
    EndIf

    If Empty(AllTrim(ZA1->ZA1_CLIENT))
        MsgAlert("O chamado precisa ter um cliente definido antes de ser assumido.", "Assumir Chamado")
        Return
    EndIf

    If Empty(AllTrim(ZA1->ZA1_PROJ))
        MsgAlert("O chamado precisa ter um projeto definido antes de ser assumido.", "Assumir Chamado")
        Return
    EndIf

    cFase := Posicione("AF8", 1, xFilial("AF8") + AllTrim(ZA1->ZA1_PROJ), "AF8_FASE")
    If AllTrim(cFase) <> "03"
        MsgAlert("O chamado so pode ser assumido com projeto em execucao (fase 03).", "Assumir Chamado")
        Return
    EndIf

    If Empty(AllTrim(ZA1->ZA1_TAREFA))
        MsgAlert("O chamado precisa ter uma tarefa definida antes de ser assumido.", "Assumir Chamado")
        Return
    EndIf

    If !MsgYesNo("Deseja assumir o chamado " + AllTrim(ZA1->ZA1_IDCH) + "?", "Assumir Chamado")
        Return
    EndIf

    RecLock("ZA1", .F.)
        ZA1->ZA1_CONSUL  := cConsultor
        ZA1->ZA1_STATUS  := "2"
    ZA1->(MsUnlock())

    MsgInfo("Chamado assumido com sucesso!", "Assumir Chamado")

Return

////////////////////////////////////////////////////////////////////////////////
Static Function CNSA_TOKEN()
    Local cTenant := "148b1301-21e9-4477-9897-64d9cf905086"
    Local cClient := "b0b341b5-009f-474a-834a-8839b0c984cd"
    Local cSecret := "SEU_CLIENT_SECRET"   // <- substitua pelo secret atual
    Local oRest, oJson, cBody, cToken := ""

    cBody := "grant_type=client_credentials"
    cBody += "&client_id="     + CNSA_URLENC(cClient)
    cBody += "&client_secret=" + CNSA_URLENC(cSecret)
    cBody += "&scope="         + CNSA_URLENC("https://graph.microsoft.com/.default")

    oRest := FWRest():New("https://login.microsoftonline.com")
    oRest:setPath("/" + cTenant + "/oauth2/v2.0/token")
    oRest:SetPostParams(cBody)
    If !oRest:Post({"Content-Type: application/x-www-form-urlencoded"})
        Return ""
    EndIf

    oJson := JsonObject():New()
    If Empty(oJson:FromJson(oRest:GetResult())) .And. ValType(oJson["access_token"]) == "C"
        cToken := oJson["access_token"]
    EndIf
    FreeObj(oJson)
Return cToken

////////////////////////////////////////////////////////////////////////////////
Static Function CNSA_GERACHAM()
    Local cToken := CNSA_TOKEN()
    Local oRest, oJson, oArr, oMsg, oFrom, oEnd
    Local cPath, cId, cAssunto, cNome, cEmail, cNewId
    Local nI, nCriados := 0
    Local cDec     := ""
    Local cDecNome := ""
    Local aCliente := {}
    Local cCodCli  := ""
    Local cLojaCli := ""

    If Empty(cToken)
        Return -1
    EndIf

    cPath := "/v1.0/users/apia@apia.com.br/mailFolders/inbox/messages"
    cPath += "?$filter=isRead%20eq%20false"
    cPath += "&$select=id,subject,from,receivedDateTime"
    cPath += "&$top=50"

    oRest := FWRest():New("https://graph.microsoft.com")
    oRest:setPath(cPath)
    If !oRest:Get({"Authorization: Bearer " + cToken, "Accept: application/json"})
        Return -1
    EndIf

    oJson := JsonObject():New()
    If !Empty(oJson:FromJson(oRest:GetResult()))
        FreeObj(oJson)
        Return -1
    EndIf

    oArr := oJson:GetJsonObject("value")
    If ValType(oArr) <> "A"
        FreeObj(oJson)
        Return -1
    EndIf

    For nI := 1 To Len(oArr)
        oMsg     := oArr[nI]
        cId      := ""
        cAssunto := "(sem assunto)"
        cNome    := ""
        cEmail   := ""
        cCodCli  := ""
        cLojaCli := ""

        If ValType(oMsg:GetJsonObject("id")) == "C"
            cId := oMsg:GetJsonObject("id")
        EndIf

        If ValType(oMsg:GetJsonObject("subject")) == "C"
            cAssunto := oMsg:GetJsonObject("subject")
            cDec     := DecodeUTF8(cAssunto)
            If ValType(cDec) == "C" .And. !Empty(cDec)
                cAssunto := cDec
            EndIf
            cAssunto := AllTrim(cAssunto)
            While .T.
                If Upper(Left(cAssunto, 4)) == "RES:" .Or. Upper(Left(cAssunto, 4)) == "ENC:" .Or. Upper(Left(cAssunto, 4)) == "FWD:"
                    cAssunto := AllTrim(SubStr(cAssunto, 5))
                ElseIf Upper(Left(cAssunto, 3)) == "RE:" .Or. Upper(Left(cAssunto, 3)) == "FW:"
                    cAssunto := AllTrim(SubStr(cAssunto, 4))
                Else
                    Exit
                EndIf
            EndDo
        EndIf

        oFrom := Nil
        oEnd  := Nil
        oFrom := oMsg:GetJsonObject("from")
        If ValType(oFrom) $ "O|J"
            oEnd := oFrom:GetJsonObject("emailAddress")
            If ValType(oEnd) $ "O|J"
                If ValType(oEnd:GetJsonObject("name")) == "C"
                    cDecNome := DecodeUTF8(oEnd:GetJsonObject("name"))
                    If ValType(cDecNome) == "C" .And. !Empty(cDecNome)
                        cNome := cDecNome
                    Else
                        cNome := oEnd:GetJsonObject("name")
                    EndIf
                EndIf
                If ValType(oEnd:GetJsonObject("address")) == "C"
                    cEmail := oEnd:GetJsonObject("address")
                EndIf
                aCliente := CNSA_BUSCACLI(cEmail)
                cCodCli  := aCliente[1]
                cLojaCli := aCliente[2]
            EndIf
        EndIf

        If Empty(cId) .Or. CNSA_CHEXIST(cId)
            Loop
        EndIf

        cNewId := GetSXENum("ZA1", "ZA1_IDCH")

        RecLock("ZA1", .T.)
            ZA1->ZA1_FILIAL  := xFilial("ZA1")
            ZA1->ZA1_IDCH    := cNewId
            ZA1->ZA1_STATUS  := "1"
            ZA1->ZA1_CONSUL  := ""
            ZA1->ZA1_CLIENT  := IIf(!Empty(cCodCli), cCodCli, cNome)
            ZA1->ZA1_LOJA    := cLojaCli
            ZA1->ZA1_EMAIL   := cEmail
            ZA1->ZA1_ASSUNT  := cAssunto
            ZA1->ZA1_DATA    := Date()
            ZA1->ZA1_MAILID  := cId
        ZA1->(MsUnlock())

        ConfirmSX8()
        nCriados++
    Next nI

    FreeObj(oJson)
Return nCriados

////////////////////////////////////////////////////////////////////////////////
Static Function CNSA_CHEXIST(cMailId)
    Local lExiste := .F.
    Local cAlias  := GetNextAlias()

    BeginSql Alias cAlias
        SELECT ZA1_IDCH
        FROM %Table:ZA1% ZA1
        WHERE ZA1_FILIAL = %xFilial:ZA1%
          AND ZA1_MAILID = %Exp:cMailId%
          AND %NotDel%
    EndSql

    lExiste := !(cAlias)->(Eof())
    (cAlias)->(DbCloseArea())
Return lExiste

////////////////////////////////////////////////////////////////////////////////
// Busca o cliente pelo e-mail do remetente.
// 1) SU5 -> AC8 -> SA1
// 2) Fallback: SA1 por e-mail exato
// 3) Fallback: SA1 por dominio
////////////////////////////////////////////////////////////////////////////////
Static Function CNSA_BUSCACLI(cEmail)
    Local cAlias   := GetNextAlias()
    Local cCod     := ""
    Local cLoja    := ""
    Local cContat  := ""
    Local cDominio := ""
    Local nPos     := 0

    BeginSql Alias cAlias
        SELECT U5_CODCONT
        FROM %Table:SU5% SU5
        WHERE U5_EMAIL = %Exp:cEmail%
          AND %NotDel%
    EndSql
    If !(cAlias)->(Eof())
        cContat := AllTrim((cAlias)->U5_CODCONT)
    EndIf
    (cAlias)->(DbCloseArea())

    If !Empty(cContat)
        cAlias := GetNextAlias()
        BeginSql Alias cAlias
            SELECT AC8_CODENT
            FROM %Table:AC8% AC8
            WHERE AC8_FILIAL = %xFilial:AC8%
              AND AC8_CODCON = %Exp:cContat%
              AND AC8_ENTIDA = 'SA1'
              AND %NotDel%
        EndSql
        If !(cAlias)->(Eof())
            cCod  := Left(AllTrim((cAlias)->AC8_CODENT), 6)
            cLoja := Right(AllTrim((cAlias)->AC8_CODENT), 2)
        EndIf
        (cAlias)->(DbCloseArea())

        If !Empty(cCod)
            Return {cCod, cLoja}
        EndIf
    EndIf

    cAlias := GetNextAlias()
    BeginSql Alias cAlias
        SELECT A1_COD, A1_LOJA
        FROM %Table:SA1% SA1
        WHERE A1_FILIAL = %xFilial:SA1%
          AND A1_EMAIL  = %Exp:cEmail%
          AND %NotDel%
        ORDER BY A1_COD, A1_LOJA
    EndSql
    If !(cAlias)->(Eof())
        cCod  := AllTrim((cAlias)->A1_COD)
        cLoja := AllTrim((cAlias)->A1_LOJA)
    EndIf
    (cAlias)->(DbCloseArea())

    If !Empty(cCod)
        Return {cCod, cLoja}
    EndIf

    nPos := At("@", cEmail)
    If nPos == 0
        Return {"", ""}
    EndIf
    cDominio := "%" + SubStr(cEmail, nPos)

    cAlias := GetNextAlias()
    BeginSql Alias cAlias
        SELECT A1_COD, A1_LOJA
        FROM %Table:SA1% SA1
        WHERE A1_FILIAL = %xFilial:SA1%
          AND A1_EMAIL  LIKE %Exp:cDominio%
          AND %NotDel%
        ORDER BY A1_COD, A1_LOJA
    EndSql
    If !(cAlias)->(Eof())
        cCod  := AllTrim((cAlias)->A1_COD)
        cLoja := AllTrim((cAlias)->A1_LOJA)
    EndIf
    (cAlias)->(DbCloseArea())

Return {cCod, cLoja}

//////////////////////////////////////////////////////////////////////////////////
Static Function CNSA_URLENC(cTexto)
    Local cRet := ""
    Local nI   := 0
    Local cCh  := ""

    For nI := 1 To Len(cTexto)
        cCh := SubStr(cTexto, nI, 1)
        If (cCh >= "A" .And. cCh <= "Z") .Or. ;
           (cCh >= "a" .And. cCh <= "z") .Or. ;
           (cCh >= "0" .And. cCh <= "9") .Or. ;
           (cCh $ "-_.~")
            cRet += cCh
        Else
            cRet += "%" + CNSA_HEX2(Asc(cCh))
        EndIf
    Next nI
Return cRet

//////////////////////////////////////////////////////////////////////////////////
Static Function CNSA_HEX2(nVal)
    Local cHex := "0123456789ABCDEF"
Return SubStr(cHex, Int(nVal/16)+1, 1) + SubStr(cHex, (nVal % 16)+1, 1)

////////////////////////////////////////////////////////////////////////////////
// Preenche ZA1_NOME via modelo MVC. Chamada pelo gatilho do ZA1_LOJA.
// NOME DO CLIENTE
////////////////////////////////////////////////////////////////////////////////
User Function CNSA_CLIENTE()
    Local oModel := FWModelActive()
    Local cCod   := ""
    Local cLoja  := ""
    Local cNome  := ""

    cCod  := AllTrim(oModel:GetValue("ZA1MASTER", "ZA1_CLIENT"))
    cLoja := AllTrim(oModel:GetValue("ZA1MASTER", "ZA1_LOJA"))
    cNome := Posicione("SA1", 1, xFilial("SA1") + cCod + cLoja, "A1_NOME")

    oModel:SetValue("ZA1MASTER", "ZA1_NOME", SubStr(cNome, 1, TamSX3("ZA1_NOME")[1]))

Return cNome

////////////////////////////////////////////////////////////////////////////////
// Preenche ZA1_NOMTEC via modelo MVC. Chamada pelo gatilho do ZA1_CONSUL.
// NOME DO TECNICO
////////////////////////////////////////////////////////////////////////////////
User Function CNSA_TECNICO()
    Local oModel := FWModelActive()
    Local cCod   := ""
    Local cNome  := ""

    cCod  := AllTrim(oModel:GetValue("ZA1MASTER", "ZA1_CONSUL"))
    cNome := Posicione("AA1", 1, xFilial("AA1") + cCod, "AA1_NOMTEC")

    oModel:SetValue("ZA1MASTER", "ZA1_NOMTEC", SubStr(cNome, 1, TamSX3("ZA1_NOMTEC")[1]))

Return cNome
