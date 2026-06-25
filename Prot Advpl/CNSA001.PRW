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

    ADD OPTION aRotina TITLE "Pesquisar"        ACTION "AxPesqui"          OPERATION 1 ACCESS 0
    ADD OPTION aRotina TITLE "Visualizar"       ACTION "VIEWDEF.CNSA001"   OPERATION 2 ACCESS 0
    ADD OPTION aRotina TITLE "Incluir"          ACTION "VIEWDEF.CNSA001"   OPERATION 3 ACCESS 0
    ADD OPTION aRotina TITLE "Alterar"          ACTION "VIEWDEF.CNSA001"   OPERATION 4 ACCESS 0
    ADD OPTION aRotina TITLE "Excluir"          ACTION "U_CNSA_EXCLUIR"    OPERATION 0 ACCESS 0
    ADD OPTION aRotina TITLE "Assumir/Designar" ACTION "U_CNSA_ASSUMIR"    OPERATION 0 ACCESS 0
    ADD OPTION aRotina TITLE "Legenda"          ACTION "U_CNSA_LEG"        OPERATION 0 ACCESS 0

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

//////////////////////////////////////////////////////////////////
//MODELACAO
//////////////////////////////////////////////////////////////////
Static Function ModelDef()

    Local l_oModel  := Nil
    Local l_oStrZA1 := FWFormStruct(1, "ZA1")
    Local l_oStrZA2 := FWFormStruct(1, "ZA2")
    Local aRelZA2   := {}

    l_oModel := MPFormModel():New(;
    "FCNSA001",;
    {|oModel| CNSA_TOK(oModel)},;       // Pre-Validacao
    {|oModel| CNSA_APOSCOMMIT(oModel)},; // Pos-Validacao (pós-commit)
    NIL,;                                // Commit (NIL = comportamento padrão)
    {|oModel| CNSA_CAN(oModel)})        // Cancel

    l_oModel:AddFields(;
        "ZA1MASTER",;
        NIL,;
        l_oStrZA1,;
        {|_f,_a,_c,_v| CNSA_POSVAL(_f,_a,_c,_v)},;
        NIL)

    l_oModel:AddGrid("ZA2DETAIL", "ZA1MASTER", l_oStrZA2)

    aAdd(aRelZA2, {"ZA2_IDCH",   "ZA1_IDCH"})
    l_oModel:SetRelation("ZA2DETAIL", aRelZA2, ZA2->(IndexKey(3)))
    l_oModel:GetModel("ZA2DETAIL"):SetOptional(.T.)
    l_oModel:SetPrimaryKey({"ZA1_FILIAL","ZA1_IDCH"})

Return l_oModel

//////////////////////////////////////////////////////////////////////////////////////////
Static Function CNSA_POSVAL(p_oModel, p_sAcao, p_sCampo, p_vValor)
    Local l_bOk := .T.
Return l_bOk

////////////////////////////////////////////////////////////////////////////////////////////
//PEDE MOTIVO DA EXCLUSAO ETC...
////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////
// Intercepta a exclusao, pede motivo e chama o MVC para deletar
//////////////////////////////////////////////////////////////////////
User Function CNSA_EXCLUIR()
    Local oDialog        := Nil
    Local oBtnOk         := Nil
    Local oBtnCan        := Nil
    Local oGetMotivo     := Nil

    If ZA1->(Eof()) .Or. ZA1->(Bof())
        MsgAlert("Nenhum chamado selecionado.", "Excluir")
        Return
    EndIf

    // Captura dados antes de qualquer acao
    Public cConsulAnterior  := AllTrim(ZA1->ZA1_CONSUL)
    Public cIdChAnterior    := AllTrim(ZA1->ZA1_IDCH)
    Public cClienteAnterior := AllTrim(ZA1->ZA1_CLIENT)
    Public cLojaAnterior    := AllTrim(ZA1->ZA1_LOJA)
    Public cMotivoExclusao  := ""
    Public lExclusaoConfirm := .F.

    // Se nao tem tecnico, nao precisa de modal, vai direto
    If Empty(cConsulAnterior)
        RecLock("ZA1", .F.)
            ZA1->(DbDelete())
        ZA1->(MsUnlock())
        Return
    EndIf

    Private nMotivo      := 1
    Private cOutroMotivo := Space(100)
    Private lMotConfirm  := .F.
    

    //CRIAÇÃO DA JANELA POPUP
    DEFINE MSDIALOG oDialog TITLE "Motivo da Exclusao" FROM 0,0 TO 300,600 PIXEL

        @ 10,10  SAY "Motivo do cancelamento:"    SIZE 200,12 PIXEL OF oDialog
        @ 25,10  SAY "1-Apia  2-Cliente  3-Outro" SIZE 200,12 PIXEL OF oDialog
        @ 40,10  MSGET oGetMot VAR nMotivo        PICTURE "9" SIZE 20,12 PIXEL OF oDialog

        @ 60,10  SAY "Descricao (para Outro motivo):" SIZE 150,12 PIXEL OF oDialog
        @ 75,10  MSGET oGetMotivo VAR cOutroMotivo PICTURE "@!" SIZE 240,12 PIXEL OF oDialog

        oBtnOk  := TButton():New(100, 90,  "OK",       oDialog, {|| lMotConfirm:=.T., oDialog:End()}, 50,14,,,.F.,.T.,.F.,,.F.,,,.F.)
        oBtnCan := TButton():New(100, 145, "Cancelar", oDialog, {|| oDialog:End()},                   50,14,,,.F.,.T.,.F.,,.F.,,,.F.)

    ACTIVATE MSDIALOG oDialog CENTERED

    If !lMotConfirm
        Return
    EndIf

    Do Case
        Case nMotivo == 1
            If Empty(AllTrim(cOutroMotivo))
                cMotivoExclusao := "Cancelamento pela Apia"
            Else
                cMotivoExclusao := "Cancelamento pela Apia - " + AllTrim(cOutroMotivo)
            EndIf
        Case nMotivo == 2
            If Empty(AllTrim(cOutroMotivo))
                cMotivoExclusao := "Cancelamento pelo Cliente"
            Else
                cMotivoExclusao := "Cancelamento pelo Cliente - " + AllTrim(cOutroMotivo)
            EndIf
        Case nMotivo == 3
            If Empty(AllTrim(cOutroMotivo))
                MsgAlert("Informe o motivo para a opcao 'Outro'.", "Motivo")
                Return
            EndIf
            cMotivoExclusao := AllTrim(cOutroMotivo)
    EndCase

    lExclusaoConfirm := .T.

    // Executa o delete diretamente
    RecLock("ZA1", .F.)
        ZA1->(DbDelete())
    ZA1->(MsUnlock())

    // Chama o poscommit manualmente
    CNSA_POSCOMMIT_EXCLUIR()

Return

///////////////////////////////////////////////////////////////
//POS COMMIT DO EXCLUIR
///////////////////////////////////////////////////////////////
Static Function CNSA_POSCOMMIT_EXCLUIR()
    Local cExclPor  := ""
    Local cCliente  := ""
    Local cIdCh     := ""
    Local cEmailAnt := ""
    Local cDataAge  := DToC(Date())
    Local cHmini    := ""
    Local cHmfim    := ""
    Local cCorpo    := ""
    Local cAlias    := GetNextAlias()
    Local nCham     := 0

    If Empty(cConsulAnterior) .Or. !lExclusaoConfirm
        Return
    EndIf

    cExclPor  := AllTrim(Posicione("AA1", 4, xFilial("AA1") + __cUserId, "AA1_NOMTEC"))
    cIdCh     := cIdChAnterior
    cCliente  := AllTrim(Posicione("SA1",1,xFilial("SA1")+cClienteAnterior+cLojaAnterior,"A1_NOME"))
    cEmailAnt := AllTrim(Posicione("AA1", 1, xFilial("AA1") + cConsulAnterior, "AA1_EMAIL"))
    nCham     := Val(cIdCh)

    BeginSql Alias cAlias
        SELECT Z6_DTAGE, Z6_HMINI, Z6_HMFIM
        FROM %Table:SZ6% SZ6
        WHERE Z6_FILIAL  = %xFilial:SZ6%
          AND Z6_CHAMADO = %Exp:nCham%
          AND %NotDel%
    EndSql
    If !(cAlias)->(Eof())
        // Z6_DTAGE pode vir como string da query BeginSql
        If ValType((cAlias)->Z6_DTAGE) == "D"
            cDataAge := DToC((cAlias)->Z6_DTAGE)
        Else
            cDataAge := AllTrim((cAlias)->Z6_DTAGE)
            // converte de YYYYMMDD para DD/MM/AAAA se vier como string
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

    cCorpo := CNSA_HTML_CANCEL(cCliente, cDataAge, cHmini, cHmfim, ;
                cIdCh, cMotivoExclusao, cExclPor)

    CNSA_ENVIAEMAIL(cEmailAnt, ;
        "Cancelamento do Chamado " + cIdCh, ;
        cCorpo, ;
        "apia@apia.com.br")

    CNSA_REMOVEAGENDA(cIdCh)

Return

///////////////////////////////////////////////////////////////////////////
//PARTE DA EXCLUSAO/ALTERAÇÃO DE CHAMADOS
//////////////////////////////////////////////////////////////////////////
Static Function CNSA_TOK(p_oModel)
    Local l_bOk  := .T.
    Local nOper  := p_oModel:GetOperation()

    
    // Só inicializa as Publics se ainda nao existirem
    // Para nao sobrescrever o que CNSA_EXCLUIR ja preencheu
    If Type("cConsulAnterior") <> "C"
        Public cConsulAnterior  := ""
    EndIf
    If Type("cMotivoExclusao") <> "C"
        Public cMotivoExclusao  := ""
    EndIf
    If Type("lExclusaoConfirm") <> "L"
        Public lExclusaoConfirm := .F.
    EndIf
    If Type("cIdChAnterior") <> "C"
        Public cIdChAnterior    := ""
    EndIf
    If Type("cClienteAnterior") <> "C"
        Public cClienteAnterior := ""
    EndIf
    If Type("cLojaAnterior") <> "C"
        Public cLojaAnterior    := ""
    EndIf

    If (nOper == 4)
        cConsulAnterior  := AllTrim(ZA1->ZA1_CONSUL)
        cIdChAnterior    := AllTrim(ZA1->ZA1_IDCH)
        cClienteAnterior := AllTrim(ZA1->ZA1_CLIENT)
        cLojaAnterior    := AllTrim(ZA1->ZA1_LOJA)
    EndIf

Return l_bOk


/////////////////////////////////////////////////////////////////////////////////////////////
Static Function CNSA_CAN(p_oModel)
Return .T.

////////////////////////////////////////////////////////////////////////////////////////////
//USADA PARA POS SALVAR CONTEXTO ELE ENVIAR OS EMAIL PARA OS CANCELADOS E REDESIGNADOS
///////////////////////////////////////////////////////////////////////////////////////////
Static Function CNSA_APOSCOMMIT(p_oModel)
    Local nOper       := p_oModel:GetOperation()
    Local cConsulNovo := ""
    Local cNomeAnt    := ""
    Local cNomeNovo   := ""
    Local cEmailAnt   := ""
    Local cEmailNovo  := ""
    Local cCliente    := ""
    Local cIdCh       := ""
    Local cAssunto    := ""
    Local cExclPor    := ""
    Local cDataAge    := DToC(Date())
    Local cHmini      := ""
    Local cHmfim      := ""
    Local cCorpo      := ""
    Local cAlias      := GetNextAlias()
    Local nCham       := 0

    // Acessa direto as Privates declaradas na CNSA_TOK
    cExclPor := AllTrim(Posicione("AA1", 4, xFilial("AA1") + __cUserId, "AA1_NOMTEC"))

    // --- ALTERACAO ---
    If nOper == 4

        cConsulNovo := AllTrim(p_oModel:GetValue("ZA1MASTER", "ZA1_CONSUL"))
        cIdCh       := AllTrim(p_oModel:GetValue("ZA1MASTER", "ZA1_IDCH"))
        cCliente    := AllTrim(Posicione("SA1",1,xFilial("SA1")+;
                            AllTrim(p_oModel:GetValue("ZA1MASTER","ZA1_CLIENT"))+;
                            AllTrim(p_oModel:GetValue("ZA1MASTER","ZA1_LOJA")),"A1_NOME"))
        cAssunto    := AllTrim(p_oModel:GetValue("ZA1MASTER", "ZA1_ASSUNT"))
        nCham       := Val(cIdCh)

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
                    cDataAge := SubStr(cDataAge,7,2)+"/"+SubStr(cDataAge,5,2)+"/"+SubStr(cDataAge,1,4)
                EndIf
            EndIf
            cHmini := AllTrim((cAlias)->Z6_HMINI)
            cHmfim := AllTrim((cAlias)->Z6_HMFIM)
        EndIf
        (cAlias)->(DbCloseArea())

        If Empty(cHmini) ; cHmini := "00:00" ; EndIf
        If Empty(cHmfim) ; cHmfim := "00:00" ; EndIf

        // Tecnico removido ou trocado
        If !Empty(cConsulAnterior) .And. cConsulAnterior <> cConsulNovo

            cNomeAnt  := AllTrim(Posicione("AA1", 1, xFilial("AA1") + cConsulAnterior, "AA1_NOMTEC"))
            cEmailAnt := AllTrim(Posicione("AA1", 1, xFilial("AA1") + cConsulAnterior, "AA1_EMAIL"))

            cCorpo := CNSA_HTML_CANCEL(cCliente, cDataAge, cHmini, cHmfim, ;
                        cIdCh, "Tecnico substituido no chamado", cExclPor)

            CNSA_ENVIAEMAIL(cEmailAnt, ;
                "Remocao do Chamado " + cIdCh, ;
                cCorpo, ;
                "apia@apia.com.br")

        EndIf

        // Novo tecnico designado
        If !Empty(cConsulNovo) .And. cConsulNovo <> cConsulAnterior

            cNomeNovo  := AllTrim(Posicione("AA1", 1, xFilial("AA1") + cConsulNovo, "AA1_NOMTEC"))
            cEmailNovo := AllTrim(Posicione("AA1", 1, xFilial("AA1") + cConsulNovo, "AA1_EMAIL"))

            cCorpo := CNSA_MONTAHTML(cNomeNovo, cIdCh, cCliente, cAssunto, ;
                        cDataAge, cHmini, cHmfim, cExclPor, "DESIGNACAO")

            CNSA_ENVIAEMAIL(cEmailNovo, ;
                "Designacao de Chamado " + cIdCh, ;
                cCorpo, ;
                "apia@apia.com.br")

        EndIf

        Return .T.
    EndIf

Return .T.

////////////////////////////////////////////////////////////////////////////////////////////
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

/////////////////////////////////////////////////////////////////////////
//legenda dos STATUS de chamado
////////////////////////////////////////////////////////////////////////
User Function CNSA_LEG()
    BrwLegenda("Legenda de Status", "Status do Chamado", ;
        { ;
            { "BR_VERDE",     "Aberto"        }, ;
            { "BR_AMARELO",   "Pendente Apia" }, ;
            { "BR_LARANJA",   "Pendente Cli." }, ;
            { "BR_VERMELHO",  "Fechado"       }  ;
        })
Return

//////////////////////////////////////////////////////////////////////////////////////////////////////
// Assume ou designa um chamado.
// - Se o tecnico selecionado for o proprio logado: assume pra si e abre agenda, envia email tambem
// - Se for outro tecnico: designa, abre janela de e-mail, abre agenda e envia e-mail
//////////////////////////////////////////////////////////////////////////////////////////////////////
User Function CNSA_ASSUMIR()

    Local cConsultor     := ""
    Local cNomeConsultor := ""
    Local cFase          := ""
    Local cEmailTec      := ""
    Local cEmailDe       := ""
    Local cNomeDe        := ""
    Local cCorpoMail     := ""
    Local cDataAge       := DToC(Date())
    Local lDesignar      := .F.
    Local oDialog        := Nil
    Local oBtnBuscar     := Nil
    Local oBtnOk         := Nil
    Local oBtnCan        := Nil
    Private oGet2          := Nil
    Private oGet3          := Nil
    Private oGet4          := Nil
    Private cHmini       := "  :  "
    Private cHmfim       := "  :  "
    Private cNomeTec     := ""
    Private cTecnico     := ""
    Private oGet1        := Nil
    Private lConfirm     := .F.

    cConsultor := Posicione("AA1",4,xFilial("AA1")+__cUserId,"AA1_CODTEC")

    If Empty(cConsultor)
        MsgAlert("Seu usuario nao esta vinculado a nenhum consultor (AA1).", "Assumir/Designar")
        Return
    EndIf

    If ZA1->(Eof()) .Or. ZA1->(Bof())
        MsgAlert("Nenhum chamado selecionado.", "Assumir/Designar")
        Return
    EndIf

    If !Empty(AllTrim(ZA1->ZA1_CONSUL))
        cNomeConsultor := Posicione("AA1",1,xFilial("AA1")+AllTrim(ZA1->ZA1_CONSUL),"AA1_NOMTEC")
        If MsgYesNo("Este chamado ja esta com: " + cNomeConsultor + "." + Chr(13)+Chr(10) + "Deseja redesignar?", "Redesignar")
            CNSA_REDESIGNAR(AllTrim(ZA1->ZA1_CONSUL), cNomeConsultor)
        EndIf
        Return
    EndIf

    If ZA1->ZA1_STATUS == "4"
        MsgAlert("Chamado fechado nao pode ser assumido.", "Assumir/Designar")
        Return
    EndIf

    If ZA1->ZA1_STATUS == "2" .Or. ZA1->ZA1_STATUS == "3"
        MsgAlert("Chamado pendente nao pode ser assumido.", "Assumir/Designar")
        Return
    EndIf

    If Empty(AllTrim(ZA1->ZA1_CLIENT))
        MsgAlert("O chamado precisa ter um cliente definido antes de ser assumido.", "Assumir/Designar")
        Return
    EndIf

    If Empty(AllTrim(ZA1->ZA1_PROJ))
        MsgAlert("O chamado precisa ter um projeto definido antes de ser assumido.", "Assumir/Designar")
        Return
    EndIf

    cFase := Posicione("AF8", 1, xFilial("AF8") + AllTrim(ZA1->ZA1_PROJ), "AF8_FASE")
    If AllTrim(cFase) <> "03"
        MsgAlert("O chamado so pode ser assumido com projeto em execucao (fase 03).", "Assumir/Designar")
        Return
    EndIf

    If Empty(AllTrim(ZA1->ZA1_TAREFA))
        MsgAlert("O chamado precisa ter uma tarefa definida antes de ser assumido.", "Assumir/Designar")
        Return
    EndIf

    cTecnico := Space(6)
    cNomeTec := ""
    lConfirm := .F.

    //Criação e abertura da janela de DESIGNAÇÃO de chamado
    DEFINE MSDIALOG oDialog TITLE "Assumir / Designar Chamado" FROM 0,0 TO 550,700 PIXEL

        @ 15,10  SAY "Tecnico:"           SIZE 50,12  PIXEL OF oDialog
        @ 15,65  MSGET oGet1 VAR cNomeTec PICTURE "@!" SIZE 180,12 PIXEL OF oDialog WHEN .F.
        @ 35,10  SAY "Data (DD/MM/AAAA):" SIZE 90,12  PIXEL OF oDialog
        @ 35,100 MSGET oGet2 VAR cDataAge  PICTURE "99/99/9999" SIZE 60,12 PIXEL OF oDialog
        @ 55,10  SAY "Hora Inicio:"        SIZE 70,12  PIXEL OF oDialog
        @ 55,90  MSGET oGet3 VAR cHmini    PICTURE "99:99" SIZE 40,12 PIXEL OF oDialog
        @ 75,10  SAY "Hora Fim:"           SIZE 70,12  PIXEL OF oDialog
        @ 75,90  MSGET oGet4 VAR cHmfim    PICTURE "99:99" SIZE 40,12 PIXEL OF oDialog

        oBtnBuscar := TButton():New(15, 248, "...", oDialog, {|| U_CNSA_BUSCATEC()}, 15, 12,,,.F.,.T.,.F.,,.F.,,,.F.)
        oBtnOk     := TButton():New(110, 100, "OK",             oDialog, {|| lConfirm:=.T.,oDialog:End()}, 50, 14,,,.F.,.T.,.F.,,.F.,,,.F.)
        oBtnCan    := TButton():New(110, 155, "Cancelar",        oDialog, {|| oDialog:End()},              50, 14,,,.F.,.T.,.F.,,.F.,,,.F.)

    ACTIVATE MSDIALOG oDialog CENTERED

    If ValType(oGet3) == "O"
        cHmini := oGet3:GetText()
    EndIf
    If ValType(oGet4) == "O"
        cHmfim := oGet4:GetText()
    EndIf

    cTecnico := AllTrim(cTecnico)

    If !lConfirm .Or. Empty(cTecnico)
        Return
    EndIf

    cNomeTec  := Posicione("AA1", 1, xFilial("AA1") + cTecnico, "AA1_NOMTEC")
    cEmailTec := AllTrim(Posicione("AA1", 1, xFilial("AA1") + cTecnico, "AA1_EMAIL"))

    lDesignar := (AllTrim(cTecnico) <> AllTrim(cConsultor))

    If lDesignar

        cNomeDe  := Posicione("AA1", 1, xFilial("AA1") + cConsultor, "AA1_NOMTEC")
        cEmailDe  := AllTrim(Posicione("AA1", 1, xFilial("AA1") + cConsultor, "AA1_EMAIL"))

        cCorpoMail := CNSA_MONTAHTML(cNomeTec, AllTrim(ZA1->ZA1_IDCH), ;
            AllTrim(Posicione("SA1",1,xFilial("SA1")+AllTrim(ZA1->ZA1_CLIENT)+AllTrim(ZA1->ZA1_LOJA),"A1_NOME")), ;
            AllTrim(ZA1->ZA1_ASSUNT), cDataAge,;
            cHmini, cHmfim, cNomeDe, "INCLUSAO")

        If !MsgYesNo("Deseja designar " + cNomeTec + " para o chamado " + AllTrim(ZA1->ZA1_IDCH) + "?", "Designar")
            Return
        EndIf

        RecLock("ZA1", .F.)
            ZA1->ZA1_CONSUL := cTecnico
            ZA1->ZA1_STATUS := "2"
        ZA1->(MsUnlock())

        CNSA_CRIAAGENDA(cTecnico, CToD(cDataAge), cHmini, cHmfim, ;
            AllTrim(ZA1->ZA1_CLIENT), AllTrim(ZA1->ZA1_LOJA), ;
            AllTrim(ZA1->ZA1_ASSUNT), AllTrim(ZA1->ZA1_PROJ), ;
            AllTrim(ZA1->ZA1_TAREFA), AllTrim(ZA1->ZA1_IDCH))

        CNSA_ENVIAEMAIL(cEmailTec, ;
            "Designacao de Chamado " + AllTrim(ZA1->ZA1_IDCH), ;
            cCorpoMail, ;
            "apia@apia.com.br")

        MsgInfo("Chamado designado e e-mail enviado para " + cNomeTec + "!", "Designar")

    Else
        If !MsgYesNo("Deseja assumir o chamado " + AllTrim(ZA1->ZA1_IDCH) + "?", "Assumir Chamado")
            Return
        EndIf

        RecLock("ZA1", .F.)
            ZA1->ZA1_CONSUL := cTecnico
            ZA1->ZA1_STATUS := "2"
        ZA1->(MsUnlock())

        CNSA_CRIAAGENDA(cTecnico, CToD(cDataAge), cHmini, cHmfim, ;
            AllTrim(ZA1->ZA1_CLIENT), AllTrim(ZA1->ZA1_LOJA), ;
            AllTrim(ZA1->ZA1_ASSUNT), AllTrim(ZA1->ZA1_PROJ), ;
            AllTrim(ZA1->ZA1_TAREFA), AllTrim(ZA1->ZA1_IDCH))

        // envia e-mail de confirmacao para si mesmo
        cEmailTec := AllTrim(Posicione("AA1", 1, xFilial("AA1") + cTecnico, "AA1_EMAIL"))
        cCorpoMail := CNSA_MONTAHTML(cNomeTec, AllTrim(ZA1->ZA1_IDCH), ;
            AllTrim(Posicione("SA1",1,xFilial("SA1")+AllTrim(ZA1->ZA1_CLIENT)+AllTrim(ZA1->ZA1_LOJA),"A1_NOME")), ;
            AllTrim(ZA1->ZA1_ASSUNT), cDataAge,;
            cHmini, cHmfim, cNomeTec, "INCLUSAO")

        CNSA_ENVIAEMAIL(cEmailTec, ;
            "Chamado Assumido " + AllTrim(ZA1->ZA1_IDCH), ;
            cCorpoMail, ;
            "apia@apia.com.br")

        MsgInfo("Chamado assumido com sucesso!", "Assumir Chamado")
    EndIf

Return

////////////////////////////////////////////////////////////////////////////////
// Cria registro na agenda do tecnico (SZ6) automaticamente.
////////////////////////////////////////////////////////////////////////////////
Static Function CNSA_CRIAAGENDA(cTecnico, dData, cHmini, cHmfim, ;
                                 cCliente, cLoja, cDescri, cProjeto, ;
                                 cTarefa, cChamado)
    Local cNewSeq := CNSA_GERASEQUENCIA(dData, cTecnico)

    RecLock("SZ6", .T.)
        SZ6->Z6_FILIAL  := xFilial("SZ6")
        SZ6->Z6_SEQ     := cNewSeq
        SZ6->Z6_DTAGE   := dData
        SZ6->Z6_TECNICO := cTecnico
        SZ6->Z6_HMINI   := cHmini
        SZ6->Z6_HMFIM   := cHmfim
        SZ6->Z6_CLIENTE := cCliente
        SZ6->Z6_LOJA    := cLoja
        SZ6->Z6_SERVICO := cDescri
        SZ6->Z6_PROJET  := cProjeto
        SZ6->Z6_TAREFA  := cTarefa
        SZ6->Z6_CHAMADO := Val(cChamado)
        SZ6->Z6_QGRAVOU := __cUserId
        SZ6->Z6_DATA    := DToS(Date())
    SZ6->(MsUnlock())

Return

////////////////////////////////////////////////////////////////////////////////
// Remove registro da agenda SZ6 pelo numero do chamado
////////////////////////////////////////////////////////////////////////////////
Static Function CNSA_REMOVEAGENDA(cChamado)
    Local nCham  := Val(cChamado)
    Local cAlias := GetNextAlias()
    Local cDtAge := ""
    Local cTec   := ""

    BeginSql Alias cAlias
        SELECT Z6_DTAGE, Z6_TECNICO
        FROM %Table:SZ6% SZ6
        WHERE Z6_FILIAL  = %xFilial:SZ6%
          AND Z6_CHAMADO = %Exp:nCham%
          AND %NotDel%
    EndSql

    If !(cAlias)->(Eof())
        If ValType((cAlias)->Z6_DTAGE) == "D"
            cDtAge := DToS((cAlias)->Z6_DTAGE)
        Else
            cDtAge := AllTrim((cAlias)->Z6_DTAGE)
        EndIf
        cTec := AllTrim((cAlias)->Z6_TECNICO)
    EndIf

    If !Empty(cDtAge)
        dbSelectArea("SZ6")
        dbSetOrder(1)
        dbSeek(xFilial("SZ6") + cDtAge + cTec)
        While !SZ6->(Eof()) .And. ;
              SZ6->Z6_FILIAL  == xFilial("SZ6") .And. ;
              SZ6->Z6_CHAMADO == nCham
            RecLock("SZ6", .F.)
                SZ6->(DbDelete())
            SZ6->(MsUnlock())
            SZ6->(dbSkip())
        EndDo
    EndIf

Return

/////////////////////////////////////////////////////////////
//Gera Sequencia na criação da agenda
//Usa na sequencia de agendamentos para um mesmo funcionario
/////////////////////////////////////////////////////////////
Static Function CNSA_GERASEQUENCIA(dData, cTecnico)
    Local cDtAge  := ""
    Local cSeqAnt := ""
    Local cSeq    := ""
    Local nTam    := 3

    If Empty(dData) .Or. Empty(cTecnico)
        Return "001"
    EndIf

    cDtAge := DToS(dData)

    dbSelectArea("SZ6")
    SZ6->(dbSetOrder(1))

    If SZ6->(dbSeek(xFilial("SZ6") + cDtAge + cTecnico))
        While !SZ6->(Eof()) .And. ;
              SZ6->Z6_FILIAL  == xFilial("SZ6") .And. ;
              DToS(SZ6->Z6_DTAGE) == cDtAge .And. ;
              SZ6->Z6_TECNICO == cTecnico
            cSeqAnt := SZ6->Z6_SEQ
            nTam    := Len(SZ6->Z6_SEQ)
            SZ6->(dbSkip())
        EndDo
        cSeq := StrZero(Val(cSeqAnt) + 1, nTam)
    Else
        cSeq := StrZero(1, 3)
    EndIf

Return cSeq

////////////////////////////////////////////////////////////////////////////////
// Envia e-mail via Microsoft Graph API.
// cPara    = e-mail do destinatario
// cAssunto = assunto do e-mail
// cCorpo   = corpo do e-mail (texto simples)
// cDe      = caixa de origem (apia@apia.com.br)
////////////////////////////////////////////////////////////////////////////////
Static Function CNSA_ENVIAEMAIL(cPara, cAssunto, cCorpo, cDe)

    Local cToken  := CNSA_TOKEN()
    Local oRest   := Nil
    Local cJson   := ""
    Local aHeader := {}

    If Empty(cToken) .Or. Empty(cPara)
        Return .F.
    EndIf

    cJson := '{'
    cJson +=   '"message": {'
    cJson +=     '"subject": "' + CNSA_JSONESC(cAssunto) + '",'
    cJson +=     '"body": {'
    cJson +=       '"contentType": "HTML",'
    cJson +=       '"content": "' + CNSA_JSONESC(cCorpo) + '"'
    cJson +=     '},'
    cJson +=     '"toRecipients": [{'
    cJson +=       '"emailAddress": {'
    cJson +=         '"address": "' + CNSA_JSONESC(cPara) + '"'
    cJson +=       '}'
    cJson +=     '}]'
    cJson +=   '},'
    cJson +=   '"saveToSentItems": "true"'
    cJson += '}'

    oRest := FWRest():New("https://graph.microsoft.com")
    oRest:setPath("/v1.0/users/" + cDe + "/sendMail")
    oRest:SetPostParams(cJson)

    aHeader := {}
    aAdd(aHeader, "Authorization: Bearer " + cToken)
    aAdd(aHeader, "Content-Type: application/json")

    oRest:Post(aHeader)  // <- chama o Post primeiro

    If oRest:GetLastError() == "202 Accepted" .Or. Empty(oRest:GetLastError())
        Return .T.
    EndIf

    MsgAlert("Falha ao enviar o e-mail: " + oRest:GetLastError(), "E-mail")
    Return .F.
Return


////////////////////////////////////////////////////////////////////////////////
// Escapa caracteres especiais para JSON
////////////////////////////////////////////////////////////////////////////////
Static Function CNSA_JSONESC(cTexto)
    Local cRet := cTexto
    cRet := StrTran(cRet, '\',  '\\')
    cRet := StrTran(cRet, '"',  '\"')
    cRet := StrTran(cRet, Chr(13)+Chr(10), '\n')
    cRet := StrTran(cRet, Chr(10), '\n')
    cRet := StrTran(cRet, Chr(13), '\n')
    cRet := StrTran(cRet, Chr(9),  '\t')
Return cRet

////////////////////////////////////////////////////////////////////////////////
//AUTENTICAÇÃO DO EMAIL VIA AZZURE ID, PERMISSÕES ETC
////////////////////////////////////////////////////////////////////////////////
Static Function CNSA_TOKEN()
    Local cTenant := "148b1301-21e9-4477-9897-64d9cf905086"
    Local cClient := "b0b341b5-009f-474a-834a-8839b0c984cd"
    Local cSecret := ""
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
//FAZ A CAPTURA DO EMAIL VIA GRAPH 
//FAZ O FILTRO SE FOR RESF FW, FWD.. PARA NAO REPEETIR EMAIL DE RESPOSTA
//CRIA CHAMADO COM AS INFOS DO EMAIL
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

        //cria o chamado com as informações presentes no corpo do email
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

/////////////////////////////////////////////////////////////////////////////////////////
//FUNÇÃO BUSCATEC PARA A JANELA DE CADASTRO DE AGENDA
//FUNÇÃO USADA NA FUNCAO ASSUMIR CHAMADO
////////////////////////////////////////////////////////////////////////////////////////
User Function CNSA_BUSCATEC()
    Local oDialog  := Nil
    Local oBrowse  := Nil
    Private cCodAux := ""

    ChkFile("AA1")
    dbSelectArea("AA1")
    dbSetOrder(1)
    dbSeek(xFilial("AA1"))

    oDialog := TDialog():New(0, 0, 500, 700, "Selecione o Tecnico",,,,,,,,,.T.)
    oBrowse := FWBrowse():New(oDialog)
    oBrowse:SetDataTable()
    oBrowse:SetAlias("AA1")
    oBrowse:SetDescription("Tecnicos")
    oBrowse:DisableFilter()
    oBrowse:DisableConfig()
    oBrowse:AddColumn({"Codigo",         {|| AA1->AA1_CODTEC}, "C", "@!", 1, 20, 0})
    oBrowse:AddColumn({"Nome do Tecnico", {|| AA1->AA1_NOMTEC}, "C", "@!", 1, 60, 0})
    oBrowse:Activate()

    EnchoiceBar(oDialog, {|| cCodAux := AA1->AA1_CODTEC, oDialog:End()}, {|| oDialog:End()})

    oDialog:Activate(,,,.T.)

    cCodAux := AllTrim(cCodAux)

    If !Empty(cCodAux)
        cTecnico := cCodAux
        cNomeTec := Posicione("AA1", 1, xFilial("AA1") + cCodAux, "AA1_NOMTEC")
        If Type("oGet1") == "O"
            oGet1:Refresh()
        EndIf
    EndIf

    FreeObj(oDialog)
    FreeObj(oBrowse)

Return

//////////////////////////////////////////////////////
//GATILHO PARA ZA1_CLIENTE
///////////////////////////////////////////////////////
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

//////////////////////////////////////////////////////
//GATILHO PARA ZA1_CONSUL
///////////////////////////////////////////////////////

User Function CNSA_TECNICO()
    Local oModel := FWModelActive()
    Local cCod   := ""
    Local cNome  := ""

    cCod  := AllTrim(oModel:GetValue("ZA1MASTER", "ZA1_CONSUL"))
    cNome := Posicione("AA1", 1, xFilial("AA1") + cCod, "AA1_NOMTEC")

    oModel:SetValue("ZA1MASTER", "ZA1_NOMTEC", SubStr(cNome, 1, TamSX3("ZA1_NOMTEC")[1]))

Return cNome

////////////////////////////////////////////////////////////////////////////////
// Redesigna chamado — troca tecnico, atualiza agenda, envia e-mails
////////////////////////////////////////////////////////////////////////////////
Static Function CNSA_REDESIGNAR(cConsulAnt, cNomeAnt)
    Local cEmailAnt  := ""
    Local cEmailNovo := ""
    Local cCorpo     := ""
    Local cCliente   := ""
    Local cIdCh      := ""
    Local cNomeExc   := ""
    Local cAlias     := GetNextAlias()
    Local nCham      := 0
    Local cDtAgeAnt  := ""
    Local cHminiAnt  := ""
    Local cHmfimAnt  := ""
    Local cDataAge    := DToC(Date())
    Local oDialog     := Nil
    Local oBtnBuscar  := Nil
    Local oBtnOk      := Nil
    Local oBtnCan     := Nil
    Private cTecnico  := Space(6)
    Private cNomeTec  := ""
    Private oGet1     := Nil
    Private oGet2     := Nil
    Private oGet3     := Nil
    Private oGet4     := Nil
    Private lConfirm  := .F.
    Private cHmini    := "  :  "
    Private cHmfim    := "  :  "

    cIdCh    := AllTrim(ZA1->ZA1_IDCH)
    cCliente := AllTrim(Posicione("SA1",1,xFilial("SA1")+AllTrim(ZA1->ZA1_CLIENT)+AllTrim(ZA1->ZA1_LOJA),"A1_NOME"))
    cNomeExc := Posicione("AA1", 4, xFilial("AA1") + __cUserId, "AA1_NOMTEC")
    nCham    := Val(cIdCh)

    // busca dados atuais da agenda
    BeginSql Alias cAlias
        SELECT Z6_HMINI, Z6_HMFIM, Z6_DTAGE
        FROM %Table:SZ6% SZ6
        WHERE Z6_FILIAL  = %xFilial:SZ6%
          AND Z6_CHAMADO = %Exp:nCham%
          AND %NotDel%
    EndSql
    If !(cAlias)->(Eof())
        cHminiAnt := AllTrim((cAlias)->Z6_HMINI)
        cHmfimAnt := AllTrim((cAlias)->Z6_HMFIM)
        If ValType((cAlias)->Z6_DTAGE) == "D"
            cDtAgeAnt := DToC((cAlias)->Z6_DTAGE)
        Else
            cDtAgeAnt := AllTrim((cAlias)->Z6_DTAGE)
            If Len(cDtAgeAnt) == 8
                cDtAgeAnt := SubStr(cDtAgeAnt,7,2)+"/"+SubStr(cDtAgeAnt,5,2)+"/"+SubStr(cDtAgeAnt,1,4)
            EndIf
        EndIf
        cDataAge := cDtAgeAnt
        cHmini   := cHminiAnt
        cHmfim   := cHmfimAnt
    EndIf
    (cAlias)->(DbCloseArea())

    // janela pra selecionar novo tecnico e nova data/hora
    DEFINE MSDIALOG oDialog TITLE "Redesignar Chamado" FROM 0,0 TO 150,370 PIXEL
        @ 15,10  SAY "Novo Tecnico:"      SIZE 70,12  PIXEL OF oDialog
        @ 15,90  MSGET oGet1 VAR cNomeTec  PICTURE "@!" SIZE 180,12 PIXEL OF oDialog WHEN .F.
        @ 35,10  SAY "Data (DD/MM/AAAA):" SIZE 90,12  PIXEL OF oDialog
        @ 35,100 MSGET oGet2 VAR cDataAge  PICTURE "99/99/9999" SIZE 60,12 PIXEL OF oDialog
        @ 55,10  SAY "Hora Inicio:"        SIZE 70,12  PIXEL OF oDialog
        @ 55,90  MSGET oGet3 VAR cHmini    PICTURE "99:99" SIZE 40,12 PIXEL OF oDialog
        @ 75,10  SAY "Hora Fim:"           SIZE 70,12  PIXEL OF oDialog
        @ 75,90  MSGET oGet4 VAR cHmfim    PICTURE "99:99" SIZE 40,12 PIXEL OF oDialog
        oBtnBuscar := TButton():New(15, 273, "...", oDialog, {|| U_CNSA_BUSCATEC()}, 15,12,,,.F.,.T.,.F.,,.F.,,,.F.)
        oBtnOk     := TButton():New(110, 100, "OK",       oDialog, {|| lConfirm:=.T.,oDialog:End()}, 50,14,,,.F.,.T.,.F.,,.F.,,,.F.)
        oBtnCan    := TButton():New(110, 155, "Cancelar", oDialog, {|| oDialog:End()},               50,14,,,.F.,.T.,.F.,,.F.,,,.F.)
    ACTIVATE MSDIALOG oDialog CENTERED

    If ValType(oGet3) == "O"
        cHmini := oGet3:GetText()
    EndIf
    If ValType(oGet4) == "O"
        cHmfim := oGet4:GetText()
    EndIf

    cTecnico := AllTrim(cTecnico)

    If !lConfirm .Or. Empty(cTecnico)
        Return
    EndIf

    cEmailAnt  := AllTrim(Posicione("AA1", 1, xFilial("AA1") + cConsulAnt, "AA1_EMAIL"))
    cEmailNovo := AllTrim(Posicione("AA1", 1, xFilial("AA1") + cTecnico, "AA1_EMAIL"))

    // e-mail pro tecnico anterior
    cCorpo := CNSA_HTML_CANCEL(cCliente, cDtAgeAnt, cHminiAnt, cHmfimAnt, ;
                cIdCh, "Redesignacao - novo tecnico alocado", cNomeExc)
    CNSA_ENVIAEMAIL(cEmailAnt, "Substituicao no Chamado " + cIdCh, cCorpo, "apia@apia.com.br")

    // atualiza ZA1
    RecLock("ZA1", .F.)
        ZA1->ZA1_CONSUL := cTecnico
    ZA1->(MsUnlock())

    // atualiza agenda na SZ6
    CNSA_ATUALIZAAGENDA(cIdCh, cTecnico, CToD(cDataAge), cHmini, cHmfim)

    // e-mail pro novo tecnico
    cCorpo := CNSA_MONTAHTML(cNomeTec, cIdCh, cCliente, ;
                AllTrim(ZA1->ZA1_ASSUNT), cDataAge, cHmini, cHmfim, cNomeExc, "REDESIGNACAO")
    CNSA_ENVIAEMAIL(cEmailNovo, "Redesignacao de Chamado " + cIdCh, cCorpo, "apia@apia.com.br")

    MsgInfo("Chamado redesignado para " + cNomeTec + " com sucesso!", "Redesignar")

Return

////////////////////////////////////////////////////////////////////////////////
// Atualiza agenda na SZ6 com novo tecnico e nova data/hora
////////////////////////////////////////////////////////////////////////////////
Static Function CNSA_ATUALIZAAGENDA(cChamado, cTecnico, dData, cHmini, cHmfim)
    Local nCham  := Val(cChamado)
    Local cAlias := GetNextAlias()
    Local cDtAge := ""
    Local cTec   := ""

    BeginSql Alias cAlias
        SELECT Z6_DTAGE, Z6_TECNICO
        FROM %Table:SZ6% SZ6
        WHERE Z6_FILIAL  = %xFilial:SZ6%
          AND Z6_CHAMADO = %Exp:nCham%
          AND %NotDel%
    EndSql

   If !(cAlias)->(Eof())
        If ValType((cAlias)->Z6_DTAGE) == "D"
            cDtAge := DToS((cAlias)->Z6_DTAGE)
        Else
            cDtAge := AllTrim((cAlias)->Z6_DTAGE)
        EndIf
        cTec := AllTrim((cAlias)->Z6_TECNICO)
    EndIf

    If !Empty(cDtAge)
        dbSelectArea("SZ6")
        dbSetOrder(1)
        dbSeek(xFilial("SZ6") + cDtAge + cTec)
        While !SZ6->(Eof()) .And. ;
              SZ6->Z6_FILIAL  == xFilial("SZ6") .And. ;
              SZ6->Z6_CHAMADO == nCham
            RecLock("SZ6", .F.)
                SZ6->Z6_TECNICO := cTecnico
                SZ6->Z6_DTAGE   := dData
                SZ6->Z6_HMINI   := cHmini
                SZ6->Z6_HMFIM   := cHmfim
                SZ6->Z6_QGRAVOU := __cUserId
                SZ6->Z6_DATA    := DToS(Date())
            SZ6->(MsUnlock())
            SZ6->(dbSkip())
        EndDo
    EndIf

Return

//-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
//////////////////////////////////////////////////////////////////////////
//CORPO DO EMAIL DE INCLUSAO EM HTML
//////////////////////////////////////////////////////////////////////////
Static Function CNSA_MONTAHTML(cNomeTec, cIdCh, cCliente, cAssunto, cDataAge, cHmini, cHmfim, cNomeDe, cTipo)
    Local cHtml := ""

    Local cTipoTexto := IIf(Empty(cTipo), "DESIGNACAO", cTipo)

    cHtml := '<div style="font-family:Arial,sans-serif;max-width:600px;border:1px solid #cccccc;border-radius:8px;overflow:hidden">'
    
    cHtml += '<div style="background-color:#1a7fc1;padding:20px;text-align:center">'
    cHtml += '<h2 style="color:#ffffff;margin:0;font-size:18px">Apia Consultoria e Sistemas</h2>'
    cHtml += '<p style="color:#d0e8f8;margin:5px 0 0 0;font-size:13px;font-style:italic">Voce esta recebendo a <b>' + cTipoTexto + '</b> de um chamado.<br>Por favor, verifique os dados abaixo</p>'
    cHtml += '</div>'

    cHtml += '<table style="width:100%;border-collapse:collapse">'
    cHtml += '<tr style="background-color:#1a7fc1;color:#ffffff"><td style="padding:10px 15px;width:35%"><b>Tecnico</b></td><td style="padding:10px 15px">' + cNomeTec + '</td></tr>'
    cHtml += '<tr style="background-color:#1a7fc1;color:#ffffff"><td style="padding:10px 15px"><b>Chamado</b></td><td style="padding:10px 15px">' + cIdCh + '</td></tr>'
    cHtml += '<tr style="background-color:#1a7fc1;color:#ffffff"><td style="padding:10px 15px"><b>Cliente</b></td><td style="padding:10px 15px">' + cCliente + '</td></tr>'
    cHtml += '<tr style="background-color:#1a7fc1;color:#ffffff"><td style="padding:10px 15px"><b>Servico</b></td><td style="padding:10px 15px">' + cAssunto + '</td></tr>'
    cHtml += '<tr style="background-color:#1a7fc1;color:#ffffff"><td style="padding:10px 15px"><b>Data</b></td><td style="padding:10px 15px">' + cDataAge + '</td></tr>'
    cHtml += '<tr style="background-color:#1a7fc1;color:#ffffff"><td style="padding:10px 15px"><b>Hora</b></td><td style="padding:10px 15px">' + cHmini + ' ate ' + cHmfim + '</td></tr>'
    cHtml += '<tr style="background-color:#1a7fc1;color:#ffffff"><td style="padding:10px 15px"><b>Designado por</b></td><td style="padding:10px 15px">' + cNomeDe + '</td></tr>'
    cHtml += '</table>'

    cHtml += '<div style="background-color:#0d5a8a;padding:12px;text-align:center">'
    cHtml += '<p style="color:#ffffff;margin:0;font-size:12px">Apia Consultoria e Sistemas - TOTVS Business Partner</p>'
    cHtml += '</div>'

    cHtml += '</div>'

Return cHtml


//////////////////////////////////////////////////////////////////////////
//CORPO DO EMAIL DE CANCELAMENTO EM HTML
//////////////////////////////////////////////////////////////////////////
Static Function CNSA_HTML_CANCEL(cCliente, cDataAge, cHmini, cHmfim, cChamado, cMotivo, cExcluidoPor)
    Local cHtml := ""

    cHtml := '<div style="font-family:Arial,sans-serif;max-width:600px;border:1px solid #cccccc;border-radius:8px;overflow:hidden">'
    
    cHtml += '<div style="background-color:#0d5a8a;padding:20px;text-align:center">'
    cHtml += '<h2 style="color:#ffffff;margin:0;font-size:18px">Apia Consultoria e Sistemas</h2>'
    cHtml += '<p style="color:#d0e8f8;margin:5px 0 0 0;font-size:13px;font-style:italic">Voce esta recebendo o <b>CANCELAMENTO</b> de um chamado.<br>Por favor, verifique os dados abaixo</p>'
    cHtml += '</div>'

    cHtml += '<table style="width:100%;border-collapse:collapse">'
    cHtml += '<tr style="background-color:#1a7fc1;color:#ffffff"><td style="padding:10px 15px;width:35%"><b>Cliente</b></td><td style="padding:10px 15px">' + cCliente + '</td></tr>'
    cHtml += '<tr style="background-color:#1a7fc1;color:#ffffff"><td style="padding:10px 15px"><b>Data</b></td><td style="padding:10px 15px">' + cDataAge + '</td></tr>'
    cHtml += '<tr style="background-color:#1a7fc1;color:#ffffff"><td style="padding:10px 15px"><b>Horario</b></td><td style="padding:10px 15px">' + cHmini + ' - ' + cHmfim + '</td></tr>'
    cHtml += '<tr style="background-color:#1a7fc1;color:#ffffff"><td style="padding:10px 15px"><b>Chamado</b></td><td style="padding:10px 15px">' + cChamado + '</td></tr>'
    cHtml += '<tr style="background-color:#1a7fc1;color:#ffffff"><td style="padding:10px 15px"><b>Motivo exclusao</b></td><td style="padding:10px 15px">' + cMotivo + '</td></tr>'
    cHtml += '<tr style="background-color:#1a7fc1;color:#ffffff"><td style="padding:10px 15px"><b>Excluido por</b></td><td style="padding:10px 15px">' + cExcluidoPor + '</td></tr>'
    cHtml += '</table>'

    cHtml += '<div style="background-color:#0d5a8a;padding:12px;text-align:center">'
    cHtml += '<p style="color:#ffffff;margin:0;font-size:12px">Apia Consultoria e Sistemas - TOTVS Business Partner</p>'
    cHtml += '</div>'

    cHtml += '</div>'

Return cHtml
