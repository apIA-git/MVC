#INCLUDE "protheus.ch"
#include "rwmake.ch"
#INCLUDE "TOPCONN.CH"
#include "TOTVS.CH"
#INCLUDE "FWMBROWSE.CH"
#include "FWMVCDEF.CH"

#define CRLF (chr(13)+chr(10))
#define FORM_MODEL       "FCADZA1"
#define LOAD_MODEL       "CADZA1"
#define ID_VIEW_DEF_MENU "VIEWDEF.CADZA1"
#define ID_MASTER        "ZA1MASTER"
#define ID_VIEW_ZA1      "VIEW_ZA1"
#define ID_TELA_ZA1      "TELA_ZA1"
///////////////////////////////////////////////////////////////////////////////////////
User Function CADZA1()
	Local l_oBrowse := Nil
	Local l_aInfApo := {}
	Private aRotina := MenuDef()
	Private  cCadastro := "Manutencao de Segmentos"

	RpcSetEnv("01", "01")
	// Inicializa conexão com o banco se não estiver ativa
    If !TCIsConnected()
        TCLink()
    EndIf
	//inicalizacao de privates para evitar erros de compilacao
	If Type("cEmpAnt") == "U"
    	Private cEmpAnt := ""
	EndIf
	If Type("cFilAnt") == "U"
    	Private cFilAnt := ""
	EndIf
	If Type("cAcesso") == "U"
    	Private cAcesso := ""
	EndIf
	If Type("cUsuario") == "U"
        Private cUsuario := ""
    EndIf
    If Type("cNomeUsr") == "U"
        Private cNomeUsr := ""
    EndIf

	l_aInfApo := GetApoInfo("CADZA1.PRW")

	//faz a abertura da tebal antes dela ser chamada no model para evitar erros de compilacao
	If Select("ZA1") == 0
        DbUseArea(.T., "TOPCONN", RetSQLName("ZA1"), "ZA1", .T., .F.)
        If Select("ZA1") == 0
            MsgAlert("Tabela ZA1 nao encontrada!", "Erro")
            Return
        EndIf
    EndIf

	l_oBrowse := FWMBrowse():New()
	If l_oBrowse <> Nil

		l_oBrowse:SetAlias("ZA1")
		If ZA1->(IndexOrd()) > 0
        	ZA1->(DbSetOrder(1))
    	EndIf

		l_oBrowse:SetDescription(cCadastro)
		l_oBrowse:SetMenuDef("CADZA1") // Use o nome do arquivo PRW atual
      //If AllTrim(l_sFiltro) <> ""
      //   l_oBrowse:SetFilterDefault(l_sFiltro)
      //EndIf

		l_oBrowse:Activate()
	EndIf
	RpcClearEnv()

Return
///////////////////////////////////////////////////////////////////////////////////
// Menu
Static Function MenuDef()
Local aRotina  := {}

	ADD OPTION aRotina TITLE "Pesquisar"    ACTION "AxPesqui"       OPERATION 1 ACCESS 0
	ADD OPTION aRotina TITLE "Visualizar"   ACTION ID_VIEW_DEF_MENU OPERATION 2 ACCESS 0
    ADD OPTION aRotina TITLE "Incluir"      ACTION ID_VIEW_DEF_MENU OPERATION 3 ACCESS 0
	ADD OPTION aRotina TITLE "Alterar"      ACTION ID_VIEW_DEF_MENU OPERATION 4 ACCESS 0
	ADD OPTION aRotina TITLE "Excluir"      ACTION ID_VIEW_DEF_MENU OPERATION 5 ACCESS 0

Return aRotina
//////////////////////////////////////////////////////////////////////////////////////////////
Static Function ViewDef()
	Local l_oView    := Nil
	Local l_oModel   := FWLoadModel("CADZA1")
	Local l_oStruZA1 := FWFormStruct(2 /*Modelo View*/,'ZA1')

	If l_oModel == Nil
        MsgStop("Erro: O Modelo (ModelDef) nao foi carregado. Verifique o nome do arquivo ou erros na ModelDef.")
        Return Nil
    EndIf

	//Criao do formulrio da viso
	l_oView := FWFormView():New()
	l_oView:SetModel(l_oModel)

	//Defini��o dos dados do cabe�alho
	l_oView:AddField(ID_VIEW_ZA1,l_oStruZA1,ID_MASTER)

	l_oView:EnableTitleView(ID_VIEW_ZA1)//, "Cabecalho - ZA1")

	// Fechar a tela se foi tudo ok
	l_oView:SetCloseOnOk({||.T.})

Return l_oView
///////////////////////////////////////////////////////////////////////////////////////////////////
Static Function ModelDef()
	Local l_oModel    := Nil
	Local l_oStrZA1   := FWFormStruct(1/*Modelo de dados*/,"ZA1")
	Private  cCadastro := "Manutencao de Segmentos"
	//Cabecalho do modelo
	l_oModel := MPFormModel():New(FORM_MODEL,/**/,;
		{|l_oModel| FZA1TOK(l_oModel)},;
      /*{|l_oModel| FZA1GRV(l_oModel)}*/,;
		{|l_oModel| FZA1CAN(l_oModel)})

	l_oModel:SetDescription(cCadastro)
	l_oModel:addFields(ID_MASTER  ,NIL ,l_oStrZA1,{|_oFieldZA1,_sAcao,_sCampo,_vValor| ZA1PosValid(_oFieldZA1,_sAcao,_sCampo,_vValor)},)
	l_oModel:SetPrimaryKey({"ZA1_FILIAL","ZA1_IDCH", "ZA1_CLIENT"})
	l_oModel:SetVldActivate({|l_oModel| FZA1PRE(l_oModel)})

Return l_oModel
//////////////////////////////////////////////////////////////////////////////////////////
// Valida os campos do cabe�alho (tabela ZA1)
Static Function ZA1PosValid(p_oField, p_sAcao, p_sCampo, p_vValor)
    Local l_bOk := .T.

    If AllTrim(p_sAcao) == "SETVALUE"

        If AllTrim(p_sCampo) == "ZA1_ASSUNTO"
            If Empty(p_vValor)
                MsgAlert("O campo Assunto nao pode ser vazio!", "Atencao")
                l_bOk := .F.
            EndIf
        EndIf

        If AllTrim(p_sCampo) == "ZA1_DATA"
            If Empty(p_vValor)
                MsgAlert("O campo Data nao pode ser vazio!", "Atencao")
                l_bOk := .F.
            EndIf
        EndIf

    EndIf

Return l_bOk
/////////////////////////////////////////////////////////////////////////////////////////
// Permitir ou n�o a altera��o do registro
Static Function FZA1PRE(p_oModel)
Local l_bRet := .T.

Return l_bRet
//Fun��o de valida��o dos dados TudoOK
Static Function FZA1TOK(p_oModel)
//Local l_oMdMaster := p_oModel:GetModel( ID_MASTER )
Local l_bOk       := .T.
	
Return l_bOk
//Fun��o executada ao clicar em cancelar
Static Function FZA1CAN(p_oModel)

Return .T.
