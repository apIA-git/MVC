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
    Private aRotina := MenuDef()
    Private cConsultor := ""
    cConsultor := Posicione("AA1",4,xFilial("AA1")+__cUserId,"AA1_CODTEC")

    // Verifica emails novos no suporte ao abrir o menu
    U_CheckEmailSuporte()

	l_oBrowse := FWMBrowse():New()
	If l_oBrowse <> Nil

		l_oBrowse:SetDescription("Registro de Chamados - OS") 
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

User Function CheckEmailSuporte()

    Local oIMAP    := Nil
    Local nMsgs    := 0
    Local cServer  := "10.0.0.3"      // servidor interno de email
    Local nPort    := 143             // IMAP sem SSL (interno)
    Local cEmail   := "suporte@apia.com.br"
    Local cAuth    := GetMV("MV_EMAILPWD") // configure no Configurador > Parametros > MV_EMAILPWD

    oIMAP := tIMAP():New()

    If oIMAP:Connect(cServer, nPort, cEmail, cAuth, .F.) // .F. = sem SSL (interno)
        nMsgs := oIMAP:GetUnseen()
        oIMAP:Disconnect()

        If nMsgs > 0
            MsgAlert("Voce tem " + cValToChar(nMsgs) + " email(s) nao lido(s) no suporte!", ;
                     "Novo Email - Suporte")
        EndIf
    Else
        // Falha silenciosa — nao interrompe o fluxo do usuario
    EndIf

Return

User Function SHOW_LEG()

    BrwLegenda("Legenda de Status", "Status do Chamado", ;
        { ;
            { "BR_VERDE",     "Aberto"        }, ;
            { "BR_AMARELO",   "Pendente Apia" }, ;
            { "BR_LARANJA",   "Pendente Cli." }, ;
            { "BR_VERMELHO",  "Fechado"       }  ;
        })

Return

