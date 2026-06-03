#include "PROTHEUS.CH"
#include "RWMAKE.CH"
#include "TOPCONN.CH"
#include "TOTVS.CH"
#include "FWMBROWSE.CH"
#include "FWMVCDEF.CH"
#include "COLORS.CH"


////////////////////////////////////////////////////////////////////////////////////////////
//FUNCAO PRINCIPAL
User Function CNSA002()

    Local l_oBrowse := Nil
    Private aRotina := MenuDef()

    //Private cNMTEC := ""
    //cNMTEC := Posicione("AA1",4,xFilial("AA1")+__cUserId,"AA1_CODTEC")

    l_oBrowse := FWMBrowse():New()
    If l_oBrowse <> Nil

        l_oBrowse:SetDescription("OS - APIA")
        l_oBrowse:SetAlias("SZ1")

        l_oBrowse:AddLegend("(SZ1->Z1_APROVAD=='S'.OR.SZ1->Z1_APROVAD=='A').AND.SZ1->Z1_FATURAR=='S'",                    "BLUE",     "Aprovada e Faturada")
        l_oBrowse:AddLegend("SZ1->Z1_FATURAR=='S'.AND.SZ1->Z1_APROVAD!='S'.AND.SZ1->Z1_APROVAD!='A'",                    "PINK",     "Faturada sem Aprovacao")
        l_oBrowse:AddLegend("(SZ1->Z1_APROVAD=='S'.OR.SZ1->Z1_APROVAD=='A').AND.SZ1->Z1_FATURAR!='S'",                   "GREEN",    "Aprovada")
        l_oBrowse:AddLegend("SZ1->Z1_APROVAD!='S'.AND.SZ1->Z1_APROVAD!='A'.AND.!Empty(SZ1->Z1_TEC)",                     "YELLOW",   "Aguardando Aprovacao")
        l_oBrowse:AddLegend("SZ1->Z1_APROVAD!='S'.AND.SZ1->Z1_APROVAD!='A'.AND.Empty(SZ1->Z1_TEC)",                      "BR_CANCEL","Negada")

        l_oBrowse:Activate()

    EndIf

Return

///////////////////////////////////////////////////////////////////////////////////
//ROTINA MENU
Static Function MenuDef()

Local aRotina  := {}

	ADD OPTION aRotina TITLE "Pesquisar"    ACTION "AxPesqui"           OPERATION 1 ACCESS 0
	ADD OPTION aRotina TITLE "Visualizar"   ACTION "VIEWDEF.CNSA002"    OPERATION 2 ACCESS 0
    ADD OPTION aRotina TITLE "Incluir"      ACTION "VIEWDEF.CNSA002"    OPERATION 3 ACCESS 0
	ADD OPTION aRotina TITLE "Alterar"      ACTION "VIEWDEF.CNSA002"    OPERATION 4 ACCESS 0
	ADD OPTION aRotina TITLE "Excluir"      ACTION "VIEWDEF.CNSA002"    OPERATION 5 ACCESS 0
    ADD OPTION aRotina TITLE "Copiar"       ACTION "U_COPIAR_OS"        OPERATION 0 ACCESS 0
    ADD OPTION aRotina TITLE "Legenda"      ACTION "U_LEGENDA"          OPERATION 0 ACCESS 0


Return aRotina
//////////////////////////////////////////////////////////////////////////////////////////////
Static Function ViewDef()

    Local l_oView    := Nil
    Local l_oModel   := FWLoadModel("CNSA002")
    Local l_oStruSZ1 := FWFormStruct(2, "SZ1")
    Local l_oStruSZ2 := FWFormStruct(2, "SZ2")
    //Local l_oStruSZ3 := FWFormStruct(2, "SZ3")

    If l_oModel == Nil
        MsgStop("Erro: O Modelo (ModelDef) nao foi carregado.", "Erro")
        Return Nil
    EndIf

    l_oView := FWFormView():New()
    l_oView:SetModel(l_oModel)

    l_oView:AddField("VIEW_SZ1", l_oStruSZ1, "SZ1MASTER")
    l_oView:AddGrid("VIEW_SZ2",  l_oStruSZ2, "SZ2DETAIL")
    //l_oView:AddGrid("VIEW_SZ3",  l_oStruSZ3, "SZ3DETAIL")


    l_oView:CreateHorizontalBox("CABEC", 60)
    l_oView:CreateHorizontalBox("GRID",  40)
    //l_oView:CreateHorizontalBox("GRID3", 25)

    l_oView:SetOwnerView("VIEW_SZ1", "CABEC")
    l_oView:SetOwnerView("VIEW_SZ2", "GRID")
    //l_oView:SetOwnerView("VIEW_SZ3", "GRID3")

    l_oView:EnableTitleView("VIEW_SZ1", "Dados da OS")
    l_oView:EnableTitleView("VIEW_SZ2", "Horas Contratadas")
    //l_oView:EnableTitleView("VIEW_SZ3", "Proposta")

    l_oView:SetCloseOnOk({||.T.})

Return l_oView
///////////////////////////////////////////////////////////////////////////////////////////////////
//MODELAÇÃO
Static Function ModelDef()

    Local l_oModel  := Nil
    Local l_oStrSZ1  := FWFormStruct(1, "SZ1")
    Local l_oStrSZ2  := FWFormStruct(1, "SZ2")
    Local aRelSZ2   := {}
    //Local l_oStrSZ3  := FWFormStruct(1, "SZ3")
    //Local aRelSZ3   := {}

    l_oModel := MPFormModel():New(;
        "FCNSA002",;
        {|oModel| FSZ1TOK(oModel)},;
        {|oModel| FSZ1CAN(oModel)})

    // Tabela pai: SZ1 (OS)
    l_oModel:AddFields(;
        "SZ1MASTER",;
        NIL,;
        l_oStrSZ1,;
        {|_f,_a,_c,_v| FSZ1PosValid(_f,_a,_c,_v)},;
        NIL)

    // Tabela filha 1: SZ2 (horas contratadas) - relacao por cliente
    l_oModel:AddGrid("SZ2DETAIL", "SZ1MASTER", l_oStrSZ2)
    aAdd(aRelSZ2, {"Z2_CODCLI", "Z1_CLI"})
    aAdd(aRelSZ2, {"Z2_LOJA",   "Z1_LOJA"})
    l_oModel:SetRelation("SZ2DETAIL", aRelSZ2, SZ2->(IndexKey(2)))

    //l_oModel:AddGrid("SZ3DETAIL", "SZ1MASTER", l_oStrSZ3)
    //aAdd(aRelSZ3, {"Z3_NUM",    "Z1_NUMPRO"})
    //aAdd(aRelSZ3, {"Z3_CODCLI", "Z1_CLI"})
    //aAdd(aRelSZ3, {"Z3_LOJA",   "Z1_LOJA"})
    //l_oModel:SetRelation("SZ3DETAIL", aRelSZ3, SZ3->(IndexKey(1)))

    l_oModel:SetPrimaryKey({"Z1_FILIAL","Z1_OS"})

Return l_oModel
//////////////////////////////////////////////////////////////////////////////////////////
// Valida os campos do cabecalho (tabela SZ1)
Static Function FSZ1PosValid(p_oField, p_sAcao, p_sCampo, p_vValor)
    Local l_bOk := .T.

Return l_bOk

Static Function FSZ1TOK(p_oModel)
    Local l_bOk := .T.
Return l_bOk

Static Function FSZ1CAN(p_oModel)

Return .T.


User Function COPIAR_OS()

    Local aFields   := {}
    Local nI        := 0
    Local cNovaOS   := ""

    If SZ1->(Eof())
        MsgStop("Selecione uma OS para copiar.", "Copiar OS")
        Return
    EndIf

    cNovaOS := AllTrim(SZ1->Z1_OS)

    If !MsgYesNo("Deseja copiar a OS " + cNovaOS + "?", "Copiar OS")
        Return
    EndIf

    // Salva todos os campos do registro atual antes de criar o novo
    DbSelectArea("SZ1")
    For nI := 1 To FCount()
        aAdd(aFields, {FieldName(nI), FieldGet(nI)})
    Next nI

    // Cria novo registro e copia os campos
    If SZ1->(RecLock("SZ1", .T.))
        For nI := 1 To Len(aFields)
            FieldPut(FieldPos(aFields[nI][1]), aFields[nI][2])
        Next nI
        // Campos que devem ser diferentes na copia
        SZ1->Z1_OS      := GetSXENum("SZ1", "Z1_OS")
        SZ1->Z1_DTDIGIT := Date()
        SZ1->Z1_APROVAD := "N"
        SZ1->Z1_FATURAR := "N"
        SZ1->Z1_APVDOR  := ""
        SZ1->Z1_APVMAIL := ""
        SZ1->Z1_APVIP   := ""
        SZ1->Z1_APVDATA := CtoD("")
        SZ1->Z1_APVHORA := ""
        MsUnlock()
        MsgInfo("OS copiada com sucesso! Nova OS: " + AllTrim(SZ1->Z1_OS), "Copiar OS")
    Else
        MsgStop("Erro ao copiar a OS.", "Copiar OS")
    EndIf

Return

User Function LEGENDA()

    BrwLegenda("Legenda de Status", "Status da OS", ;
        { ;
            { "BR_AZUL",      "Faturada e Aprovada"    }, ;
            { "BR_PINK",   "Faturada sem Aprovacao"  }, ;
            { "BR_VERDE",     "Aprovada"               }, ;
            { "BR_AMARELO",   "Aguardando Aprovacao"   }, ;
            { "BR_CANCEL",  "Negada"                 }  ;
        })

Return
