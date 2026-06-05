#INCLUDE "PROTHEUS.CH"
#include "RWMAKE.CH"
#INCLUDE "TOPCONN.CH"
#include "TOTVS.CH"
#INCLUDE "FWMBROWSE.CH"
#include "FWMVCDEF.CH"
#include "COLORS.CH"

////////////////////////////////////////////////////////////////////////////////////////////
//FUNCAO PRINCIPAL
User Function CNSA001()

    Local l_oBrowse := Nil
    Local nUnread   := 0
    Local cDesc     := ""
    Private aRotina := MenuDef()
    Private cConsultor := ""
    cConsultor := Posicione("AA1",4,xFilial("AA1")+__cUserId,"AA1_CODTEC")


	l_oBrowse := FWMBrowse():New()
	If l_oBrowse <> Nil

        nUnread := CNS_CHKMAIL()
        cDesc   := "Registro de Chamados - OS"
        If nUnread > 0
            cDesc += " | " + cValToChar(nUnread) + " e-mail(s) nao lido(s) em suporte@apia"
        ElseIf nUnread == 0
            cDesc += " | Sem e-mails novos em suporte@apia"
        EndIf
        // nUnread < 0: erro de conexao - exibe descricao sem status de e-mail

		l_oBrowse:SetDescription(cDesc)
        l_oBrowse:SetAlias("ZA1")
	
		l_oBrowse:AddLegend( "ZA1->ZA1_STATUS == '1'", "GREEN",  "Aberto" )
        l_oBrowse:AddLegend( "ZA1->ZA1_STATUS == '2'", "YELLOW", "Pendente Apia" )
        l_oBrowse:AddLegend( "ZA1->ZA1_STATUS == '3'", "ORANGE", "Pendente Cli." )
        l_oBrowse:AddLegend( "ZA1->ZA1_STATUS == '4'", "RED",    "Fechado" )

        l_oBrowse:AddFilter("Meus","ZA1_CONSULT == cConsultor") 
        l_oBrowse:AddFilter("Nao Assumidos", "ZA1_CONSULT == ' '") 

		l_oBrowse:Activate()

	EndIf

Return

///////////////////////////////////////////////////////////////////////////////////
//ROTINA MENU
Static Function MenuDef()

Local aRotina  := {}

	ADD OPTION aRotina TITLE "Pesquisar"    ACTION "AxPesqui"           OPERATION 1 ACCESS 0
	ADD OPTION aRotina TITLE "Visualizar"   ACTION "VIEWDEF.CNSA001"    OPERATION 2 ACCESS 0
    ADD OPTION aRotina TITLE "Incluir"      ACTION "VIEWDEF.CNSA001"    OPERATION 3 ACCESS 0
	ADD OPTION aRotina TITLE "Alterar"      ACTION "VIEWDEF.CNSA001"    OPERATION 4 ACCESS 0
	ADD OPTION aRotina TITLE "Excluir"      ACTION "VIEWDEF.CNSA001"    OPERATION 5 ACCESS 0
    ADD OPTION aRotina TITLE "Legenda"      ACTION "U_SHOW_LEG"         OPERATION 0 ACCESS 0

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

    // 60% cabecalho chamado + 40% grid interacoes
    l_oView:CreateHorizontalBox("CABEC", 60)
    l_oView:CreateHorizontalBox("GRID",  40)

    l_oView:SetOwnerView("VIEW_ZA1", "CABEC")
    l_oView:SetOwnerView("VIEW_ZA2", "GRID")

    l_oView:EnableTitleView("VIEW_ZA1", "Dados do Chamado")
    l_oView:EnableTitleView("VIEW_ZA2", "Interacoes")

    l_oView:SetCloseOnOk({||.T.})

Return l_oView
///////////////////////////////////////////////////////////////////////////////////////////////////
//MODELA��O
Static Function ModelDef()

    Local l_oModel  := Nil
    Local l_oStrZA1 := FWFormStruct(1, "ZA1")
    Local l_oStrZA2 := FWFormStruct(1, "ZA2")
    Local aRelZA2   := {}

    l_oModel := MPFormModel():New(;
        "FCNSA001",;
        {|oModel| FZA1TOK(oModel)},;
        {|oModel| FZA1CAN(oModel)})

    // Tabela pai: ZA1 (Chamado)
    l_oModel:AddFields(;
        "ZA1MASTER",;
        NIL,;
        l_oStrZA1,;
        {|_f,_a,_c,_v| ZA1PosValid(_f,_a,_c,_v)},;
        NIL)

    // Tabela filha: ZA2 (Interacoes do chamado) - obrigatorio
    l_oModel:AddGrid("ZA2DETAIL", "ZA1MASTER", l_oStrZA2)

    aAdd(aRelZA2, {"ZA2_IDCH",   "ZA1_IDCH"})
    l_oModel:SetRelation("ZA2DETAIL", aRelZA2, ZA2->(IndexKey(3)))

    l_oModel:SetPrimaryKey({"ZA1_FILIAL","ZA1_IDCH"})

Return l_oModel
//////////////////////////////////////////////////////////////////////////////////////////
// Valida os campos do cabecalho (tabela ZA1)
Static Function ZA1PosValid(p_oModel, p_sAcao, p_sCampo, p_vValor)
    Local l_bOk := .T.
Return l_bOk

Static Function FZA1TOK(p_oModel)
    Local l_bOk := .T.
Return l_bOk

Static Function FZA1CAN(p_oModel)

Return .T.

User Function GETIDGRID()

    Local oModel := FWModelActive()
    Local l_oZA2 := oModel:GetModel("ZA2DETAIL")
    Local nLines := l_oZA2:Length()
    Local nI     := 0
    Local nSeq   := 1

    For nI := 1 To nLines
        l_oZA2:GoLine(nI)
        If !l_oZA2:IsDeleted()
            nSeq++
        EndIf
    Next nI

Return StrZero(nSeq, 3)

User Function SHOW_LEG()

    BrwLegenda("Legenda de Status", "Status do Chamado", ;
        { ;
            { "BR_VERDE",     "Aberto"        }, ;
            { "BR_AMARELO",   "Pendente Apia" }, ;
            { "BR_LARANJA",   "Pendente Cli." }, ;
            { "BR_VERMELHO",  "Fechado"       }  ;
        })

Return

////////////////////////////////////////////////////////////////////////////////////////////
// VERIFICACAO DE EMAIL (IMAP)
// Retorno: > 0 emails nao lidos | = 0 sem novos | -1 falha conexao | -2 falha autenticacao
////////////////////////////////////////////////////////////////////////////////////////////
Static Function CNS_CHKMAIL()

    Local cServer := "10.0.0.3"
    Local nPort   := 143
    Local cUser   := "suporte@apia.com.br"
    Local cPass   := "xptonk25@1900"

Return _ImapGetUnseen(cServer, nPort, cUser, cPass)

Static Function _ImapGetUnseen(cServer, nPort, cUser, cPass)

    Local hSock   := HB_InetCreate()
    Local cResp   := ""
    Local nUnread := 0
    Local nLen    := 0
    Local cUIDs   := ""
    Local nPos    := 0

    HB_InetSetTimeout(hSock, 5000)
    HB_InetConnect(cServer, nPort, hSock)

    If HB_InetErrorCode(hSock) != 0
        HB_InetClose(hSock)
        Return -1
    EndIf

    HB_InetRecvLine(hSock, @nLen, 512)  // consome banner de boas-vindas

    _ImapSend(hSock, 'T1 LOGIN "' + cUser + '" "' + cPass + '"')
    cResp := _ImapRead(hSock, "T1")
    If !("T1 OK" $ cResp)
        _ImapSend(hSock, "T4 LOGOUT")
        HB_InetClose(hSock)
        Return -2
    EndIf

    _ImapSend(hSock, "T2 SELECT INBOX")
    _ImapRead(hSock, "T2")

    _ImapSend(hSock, "T3 SEARCH UNSEEN")
    cResp := _ImapRead(hSock, "T3")

    // Resposta: "* SEARCH 1 5 12" -> conta os UIDs
    nPos := At("* SEARCH", cResp)
    If nPos > 0
        cUIDs := SubStr(cResp, nPos + 9)
        cUIDs := Left(cUIDs, At(Chr(10), cUIDs + Chr(10)) - 1)
        cUIDs := AllTrim(StrTran(cUIDs, Chr(13), ""))
        If !Empty(cUIDs)
            nUnread := Len(HB_ATokens(cUIDs, " "))
        EndIf
    EndIf

    _ImapSend(hSock, "T4 LOGOUT")
    HB_InetClose(hSock)

Return nUnread

Static Function _ImapSend(hSock, cCmd)
    HB_InetSendAll(hSock, cCmd + Chr(13) + Chr(10))
Return Nil

Static Function _ImapRead(hSock, cTag)

    Local cAll  := ""
    Local cLine := ""
    Local nLen  := 0
    Local n     := 0

    Do While n < 50
        cLine := HB_InetRecvLine(hSock, @nLen, 2048)
        If nLen <= 0 .And. HB_InetErrorCode(hSock) != 0
            Exit
        EndIf
        cAll += cLine + Chr(13) + Chr(10)
        If cTag + " OK"  $ cLine .Or. ;
           cTag + " NO"  $ cLine .Or. ;
           cTag + " BAD" $ cLine
            Exit
        EndIf
        n++
    EndDo

Return cAll
