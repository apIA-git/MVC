#include "RESTFUL.CH"
#include "PROTHEUS.CH"
#include "RWMAKE.CH"
#include "TOPCONN.CH"
#include "TOTVS.CH"
#include "FWMBROWSE.CH"
#include "FWMVCDEF.CH"
#include "COLORS.CH"

#define CNSA_FWMODEL_HOST  "http://10.0.0.3:3624"
#define CNSA_FWMODEL_PATH  "/rest/FwModel/agenda/"
#define CNSA_FWMODEL_MODEL "ModelSZ6_Main"


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

    ADD OPTION aRotina TITLE "Pesquisar"        ACTION "AxPesqui"               OPERATION 1 ACCESS 0
    ADD OPTION aRotina TITLE "Visualizar"       ACTION "VIEWDEF.CNSA001"        OPERATION 2 ACCESS 0
    ADD OPTION aRotina TITLE "Incluir"          ACTION "VIEWDEF.CNSA001"        OPERATION 3 ACCESS 0
    ADD OPTION aRotina TITLE "Alterar"          ACTION "U_CNSA_ALT"             OPERATION 4 ACCESS 0 //funcao action alterada por causa de permissoes
    ADD OPTION aRotina TITLE "Excluir"          ACTION "U_CNSA_EXCLUIR"         OPERATION 0 ACCESS 0
    ADD OPTION aRotina TITLE "Agendar"          ACTION "U_CNSA_CRIAAGENDA"      OPERATION 0 ACCESS 0
    ADD OPTION aRotina TITLE "Assumir"          ACTION "U_CNSA_ASSUMIR"         OPERATION 0 ACCESS 0
    ADD OPTION aRotina TITLE "Anotacoes"        ACTION "U_CNSA_INTERAGIR"       OPERATION 0 ACCESS 0
    ADD OPTION aRotina TITLE "Ver Agendas"      ACTION "U_ABREAGENDA"           OPERATION 0 ACCESS 0
    ADD OPTION aRotina TITLE "Legenda"          ACTION "U_CNSA_LEG"             OPERATION 0 ACCESS 0

Return aRotina

//////////////////////////////////////////////////////////////////////////////////////////////
Static Function ViewDef()

    Local l_oView    := Nil
    Local l_oModel   := FWLoadModel("CNSA001")
    Local l_oStruZA1 := FWFormStruct(2, "ZA1")
    Local l_oStruZA2 := FWFormStruct(2, "ZA2")
    Local l_oStruSZ6 := FWFormStruct(2, "SZ6")

    If l_oModel == Nil
        MsgStop("Erro: O Modelo (ModelDef) nao foi carregado.", "Erro")
        Return Nil
    EndIf

    l_oView := FWFormView():New()
    l_oView:SetModel(l_oModel)

    l_oView:AddField("VIEW_ZA1", l_oStruZA1, "ZA1MASTER")
    l_oView:AddGrid("VIEW_ZA2",  l_oStruZA2, "ZA2DETAIL")
    l_oView:AddGrid("VIEW_SZ6",  l_oStruSZ6, "SZ6DETAIL")

    // Duas linhas horizontais empilhadas
    l_oView:CreateHorizontalBox("CABEC",  70)
    l_oView:CreateHorizontalBox("ABAIXO", 30)

    // A linha de baixo se divide em duas colunas
    l_oView:CreateVerticalBox("GRID",    50, "ABAIXO")
    l_oView:CreateVerticalBox("GRIDAGE", 50, "ABAIXO")

    l_oView:SetOwnerView("VIEW_ZA1", "CABEC")
    l_oView:SetOwnerView("VIEW_ZA2", "GRID")
    l_oView:SetOwnerView("VIEW_SZ6", "GRIDAGE")

    l_oView:EnableTitleView("VIEW_ZA1", "Dados do Chamado")
    l_oView:EnableTitleView("VIEW_ZA2", "Anotações")
    l_oView:EnableTitleView("VIEW_SZ6", "Agendamento")

    l_oView:SetCloseOnOk({||.T.})

Return l_oView
//////////////////////////////////////////////////////////////////
//MODELACAO
//////////////////////////////////////////////////////////////////
Static Function ModelDef()

    Local l_oModel  := Nil
    Local l_oStrZA1 := FWFormStruct(1, "ZA1")
    Local l_oStrZA2 := FWFormStruct(1, "ZA2")
    Local l_oStrSZ6 := FWFormStruct(1, "SZ6")
    Local aRelZA2   := {}
    Local aRelSZ6   := {}
    Local oGridSZ6  := Nil

    l_oModel := MPFormModel():New(;
        "FCNSA001",;
        {|oModel| CNSA_TOK(oModel)},;          // Pre-Validacao
        {|oModel| CNSA_APOSCOMMIT(oModel)},;  // Pos-Validacao (pós-commit)
        NIL,;                                // Commit (NIL = comportamento padrão)
        {|oModel| CNSA_CAN(oModel)})        // Cancel

    l_oModel:AddFields(;
        "ZA1MASTER",;
        NIL,;
        l_oStrZA1,;
        {|_f,_a,_c,_v| CNSA_POSVAL(_f,_a,_c,_v)},;
        NIL)

    // Grid de interacoes (ZA2)
    l_oModel:AddGrid("ZA2DETAIL", "ZA1MASTER", l_oStrZA2)
    aAdd(aRelZA2, {"ZA2_IDCH", "ZA1_IDCH"})
    l_oModel:SetRelation("ZA2DETAIL", aRelZA2, ZA2->(IndexKey(1)))

    // Grid de agendamentos (SZ6) - somente leitura, usa a Ordem 2 (por chamado)
    l_oModel:AddGrid("SZ6DETAIL", "ZA1MASTER", l_oStrSZ6)
    aAdd(aRelSZ6, {"Z6_CHAMADO", "ZA1_IDCH"})
    l_oModel:SetRelation("SZ6DETAIL", aRelSZ6, SZ6->(IndexKey(2)))

    oGridSZ6 := l_oModel:GetModel("SZ6DETAIL")
    If oGridSZ6 <> Nil
        oGridSZ6:SetNoInsertLine(.T.)
        oGridSZ6:SetNoDeleteLine(.T.)
        oGridSZ6:SetNoUpdateLine(.T.)
    EndIf

    l_oModel:SetPrimaryKey({"ZA1_FILIAL","ZA1_IDCH"})

Return l_oModel

//////////////////////////////////////////////////////////////////////////////////////////
Static Function CNSA_POSVAL(p_oModel, p_sAcao, p_sCampo, p_vValor)
    Local l_bOk := .T.
Return l_bOk


//////////////////////////////////////////////////////////////////////
// Intercepta a exclusao, pede motivo e chama o MVC para deletar
//////////////////////////////////////////////////////////////////////
User Function CNSA_EXCLUIR()
    Local oDialog        := Nil
    Local oBtnOk         := Nil
    Local oBtnCan        := Nil
    Local oGetMotivo     := Nil
    Local aResultado     := {}

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
        aResultado := CNSA_EXCLUINUCLEO(cIdChAnterior, "", .T.)
        If !aResultado[1]
            MsgAlert(aResultado[2], "Excluir")
        EndIf
        Return
    EndIf

    //CRIAÇÃO DA JANELA POPUP
    Private aMotivos := {"Cancelamento pela Apia", "Cancelamento pelo Cliente", "Outro motivo"}
    Private cMotivoSel := aMotivos[1]
    Private cOutroMotivo := Space(100)
    Private lMotConfirm  := .F.

    DEFINE MSDIALOG oDialog TITLE "Motivo da Exclusao" FROM 0,0 TO 300,600 PIXEL

        @ 10,10  SAY "Selecione o motivo do cancelamento:" SIZE 250,12 PIXEL OF oDialog
        @ 25,10  COMBOBOX oCombo VAR cMotivoSel ITEMS aMotivos SIZE 250,12 PIXEL OF oDialog

        @ 60,10  SAY "Descricao: " SIZE 300,12 PIXEL OF oDialog
        @ 75,10  MSGET oGetMotivo VAR cOutroMotivo PICTURE "@!" SIZE 240,12 PIXEL OF oDialog

        oBtnOk  := TButton():New(100, 90,  "OK",       oDialog, {|| lMotConfirm:=.T., oDialog:End()}, 50,14,,,.F.,.T.,.F.,,.F.,,,.F.)
        oBtnCan := TButton():New(100, 145, "Cancelar", oDialog, {|| oDialog:End()},                   50,14,,,.F.,.T.,.F.,,.F.,,,.F.)

    ACTIVATE MSDIALOG oDialog CENTERED

    If !lMotConfirm
        Return
    EndIf

    Do Case
        Case cMotivoSel == "Cancelamento pela Apia"
            If Empty(AllTrim(cOutroMotivo))
                cMotivoExclusao := "Cancelamento pela Apia"
            Else
                cMotivoExclusao := "Cancelamento pela Apia - " + AllTrim(cOutroMotivo)
            EndIf
        Case cMotivoSel == "Cancelamento pelo Cliente"
            If Empty(AllTrim(cOutroMotivo))
                cMotivoExclusao := "Cancelamento pelo Cliente"
            Else
                cMotivoExclusao := "Cancelamento pelo Cliente - " + AllTrim(cOutroMotivo)
            EndIf
        Case cMotivoSel == "Outro motivo"
            If Empty(AllTrim(cOutroMotivo))
                MsgAlert("Informe o motivo para a opcao 'Outro'.", "Motivo")
                Return
            EndIf
            cMotivoExclusao := AllTrim(cOutroMotivo)
    EndCase

    lExclusaoConfirm := .T.

    aResultado := CNSA_EXCLUINUCLEO(cIdChAnterior, cMotivoExclusao, .T.)
    If !aResultado[1]
        MsgAlert(aResultado[2], "Excluir")
    EndIf

Return

///////////////////////////////////////////////////////////////////////////
//PARTE DA EXCLUSAO/ALTERAÇÃO DE CHAMADOS
//////////////////////////////////////////////////////////////////////////
Static Function CNSA_TOK(p_oModel)
    Local l_bOk  := .T.
    Local nOper  := p_oModel:GetOperation()

    // Bloqueia alteração para quem não é do grupo
    If nOper == 4 .And. !CNSA_NOGRUPO()
        MsgAlert("Voce nao tem permissao para alterar chamados. Utilize a opcao Interagir.", "Acesso")
        Return .F.
    EndIf


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
///////////////////////////////////////////////////////////////////////////////////////////


////////////////////////////////////////////////////////////////////////////////////////////
// USADA PARA POS SALVAR CONTEXTO
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
    Local lViaRest    := (Type("lCnsaViaRest") == "L" .And. lCnsaViaRest)

    // Variáveis para o bloco de agendamento automático
    Local cClienteAp  := ""
    Local cLojaAp     := ""
    Local cProjAp     := ""
    Local cTarefaAp   := ""
    Local cTecnicoAp  := ""
    Local nQtdAgenda  := 0
    Local cPergAgenda := ""
    Local cHoraAtual  := ""
    Local cHoraFim    := ""

    cExclPor := AllTrim(Posicione("AA1", 4, xFilial("AA1") + __cUserId, "AA1_NOMTEC"))

    // --- ENVIOS DE E-MAIL (APENAS NA ALTERAÇÃO - OPERAÇÃO 4) ---
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

            cCorpo := CNSA_CANCEL_FRONT(cCliente, cDataAge, cHmini, cHmfim, ;
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

            cCorpo := CNSA_EMAIL_FRONT(cNomeNovo, cIdCh, cCliente, cAssunto, ;
                        cDataAge, cHmini, cHmfim, cExclPor, "DESIGNACAO")

            CNSA_ENVIAEMAIL(cEmailNovo, ;
                "Designacao de Chamado " + cIdCh, ;
                cCorpo, ;
                "apia@apia.com.br")

        EndIf
    EndIf

    // --- NOVA INTERAÇÃO: PERGUNTA DE AGENDAMENTO (INCLUSÃO OU ALTERAÇÃO) ---
    // Agora sempre oferece a criacao de um novo agendamento, mesmo que ja existam outros
    If nOper == 3 .Or. nOper == 4
        cIdCh      := AllTrim(p_oModel:GetValue("ZA1MASTER", "ZA1_IDCH"))
        cTecnicoAp := AllTrim(p_oModel:GetValue("ZA1MASTER", "ZA1_CONSUL"))

        // Só executa o resto se o chamado tem técnico
        If !Empty(cTecnicoAp)

            nCham := Val(cIdCh)

            // Conta quantos agendamentos ja existem, apenas para contextualizar a mensagem
            nQtdAgenda := 0
            BeginSql Alias cAlias
                SELECT COUNT(*) AS QTD
                FROM %Table:SZ6% SZ6
                WHERE Z6_FILIAL  = %xFilial:SZ6%
                  AND Z6_CHAMADO = %Exp:nCham%
                  AND %NotDel%
            EndSql
            If !(cAlias)->(Eof())
                nQtdAgenda := (cAlias)->QTD
            EndIf
            (cAlias)->(DbCloseArea())

            cPergAgenda := IIf(nQtdAgenda == 0, ;
                "Este chamado nao possui agendamento. Deseja criar uma agenda para ele agora?", ;
                "Este chamado ja possui " + cValToChar(nQtdAgenda) + " agendamento(s). Deseja criar mais um agora?")

            If lViaRest .Or. MsgYesNo(cPergAgenda, "Agendar Chamado")

                cClienteAp := AllTrim(p_oModel:GetValue("ZA1MASTER", "ZA1_CLIENT"))
                cLojaAp    := AllTrim(p_oModel:GetValue("ZA1MASTER", "ZA1_LOJA"))
                cAssunto   := AllTrim(p_oModel:GetValue("ZA1MASTER", "ZA1_ASSUNT"))
                cProjAp    := AllTrim(p_oModel:GetValue("ZA1MASTER", "ZA1_PROJ"))
                cTarefaAp  := AllTrim(p_oModel:GetValue("ZA1MASTER", "ZA1_TAREFA"))

                // --- CALCULA O HOR? RIO DINÂMICO AQUI ---
                // Captura "HH:MM" do relógio do servidor
                cHoraAtual := Left(Time(), 5)

                // Adiciona 1 hora na hora final
                cHoraFim   := StrZero(Val(Left(cHoraAtual, 2)) + 1, 2) + ":" + Right(cHoraAtual, 2)

                // Trava de segurança para não passar de "23:59"
                If Val(Left(cHoraFim, 2)) >= 24
                    cHoraFim := "23:59"
                EndIf
                // ---------------------------------------

                // Chama a função passando a hora dinâmica
                CNSA_CRIAAGENDA_INT(cTecnicoAp, Date(), cHoraAtual, cHoraFim, ;
                    cClienteAp, cLojaAp, cAssunto, cProjAp, cTarefaAp, cIdCh)
            EndIf
        EndIf
    EndIf

Return .T.
////////////////////////////////////////////////////////////////////////////////////////////
User Function GETIDGRID()
    Local oModel  := FWModelActive()
    Local l_oZA2  := Nil
    Local nLines  := 0
    Local nLinAtu := 0
    Local nI      := 0
    Local nSeq    := 1

    If oModel == Nil
        Return StrZero(1, 3)
    EndIf

    l_oZA2 := oModel:GetModel("ZA2DETAIL")

    If l_oZA2 == Nil
        Return StrZero(1, 3)
    EndIf

    nLines  := l_oZA2:Length()
    nLinAtu := l_oZA2:GetLine()

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
// Assume o chamado para o tecnico logado e envia e-mail de confirmacao
//////////////////////////////////////////////////////////////////////////////////////////////////////
User Function CNSA_ASSUMIR()

    Local cConsultor     := ""
    Local cNomeConsultor := ""
    Local cFase          := ""
    Local cEmailTec      := ""
    Local cCorpoMail     := ""

    cConsultor := Posicione("AA1",4,xFilial("AA1")+__cUserId,"AA1_CODTEC")

    If Empty(cConsultor)
        MsgAlert("Seu usuario nao esta vinculado a nenhum consultor (AA1).", "Assumir")
        Return
    EndIf

    If ZA1->(Eof()) .Or. ZA1->(Bof())
        MsgAlert("Nenhum chamado selecionado.", "Assumir")
        Return
    EndIf

    If !Empty(AllTrim(ZA1->ZA1_CONSUL))
        cNomeConsultor := Posicione("AA1",1,xFilial("AA1")+AllTrim(ZA1->ZA1_CONSUL),"AA1_NOMTEC")
        MsgAlert("Este chamado ja esta com: " + cNomeConsultor + ". Para redesignar use a opcao Alterar.", "Assumir")
        Return
    EndIf

    If ZA1->ZA1_STATUS == "4"
        MsgAlert("Chamado fechado nao pode ser assumido.", "Assumir")
        Return
    EndIf

    If ZA1->ZA1_STATUS == "2" .Or. ZA1->ZA1_STATUS == "3"
        MsgAlert("Chamado pendente nao pode ser assumido.", "Assumir")
        Return
    EndIf

    If Empty(AllTrim(ZA1->ZA1_CLIENT))
        MsgAlert("O chamado precisa ter um cliente definido antes de ser assumido.", "Assumir")
        Return
    EndIf

    If Empty(AllTrim(ZA1->ZA1_PROJ))
        MsgAlert("O chamado precisa ter um projeto definido antes de ser assumido.", "Assumir")
        Return
    EndIf

    cFase := Posicione("AF8", 1, xFilial("AF8") + AllTrim(ZA1->ZA1_PROJ), "AF8_FASE")
    If AllTrim(cFase) <> "03"
        MsgAlert("O chamado so pode ser assumido com projeto em execucao (fase 03).", "Assumir")
        Return
    EndIf

    If Empty(AllTrim(ZA1->ZA1_TAREFA))
        MsgAlert("O chamado precisa ter uma tarefa definida antes de ser assumido.", "Assumir")
        Return
    EndIf

    If !MsgYesNo("Deseja assumir o chamado " + AllTrim(ZA1->ZA1_IDCH) + "?", "Assumir Chamado")
        Return
    EndIf

    RecLock("ZA1", .F.)
        ZA1->ZA1_CONSUL := cConsultor
        ZA1->ZA1_STATUS := "2"
        ZA1->ZA1_MOD    := Date()
    ZA1->(MsUnlock())

    cEmailTec  := AllTrim(Posicione("AA1", 1, xFilial("AA1") + cConsultor, "AA1_EMAIL"))
    cCorpoMail := CNSA_EMAIL_FRONT(AllTrim(Posicione("AA1",1,xFilial("AA1")+cConsultor,"AA1_NOMTEC")), ;
        AllTrim(ZA1->ZA1_IDCH), ;
        AllTrim(Posicione("SA1",1,xFilial("SA1")+AllTrim(ZA1->ZA1_CLIENT)+AllTrim(ZA1->ZA1_LOJA),"A1_NOME")), ;
        AllTrim(ZA1->ZA1_ASSUNT), DToC(Date()), "00:00", "00:00", ;
        AllTrim(Posicione("AA1",1,xFilial("AA1")+cConsultor,"AA1_NOMTEC")), "INCLUSAO")

    CNSA_ENVIAEMAIL(cEmailTec, ;
        "Chamado Assumido " + AllTrim(ZA1->ZA1_IDCH), ;
        cCorpoMail, ;
        "apia@apia.com.br")

    MsgInfo("Chamado assumido com sucesso!", "Assumir Chamado")

Return


////////////////////////////////////////////////////////////////////////////////
// Abre dialog simples para o usuario escolher os dados da agenda,
// depois grava na SZ6 via MVC do CNSA003 (respeitando gatilhos do SX7)
////////////////////////////////////////////////////////////////////////////////
Static Function CNSA_CRIAAGENDA_INT(cTecnico, dData, cHmini, cHmfim, ;
                                 cCliente, cLoja, cDescri, cProjeto, ;
                                 cTarefa, cChamado)
    Local oModel := Nil
    Local cNomeGravou    := AllTrim(Posicione("AA1", 1, xFilial("AA1") + cConsultor, "AA1_NOMTEC"))

    oModel := FWLoadModel("CNSA003")
    If oModel == Nil
        MsgAlert("Nao foi possivel carregar o modelo CNSA003.", "Agenda")
        Return
    EndIf

    oModel:SetOperation(MODEL_OPERATION_INSERT)
    oModel:Activate()

    oModel:SetValue("ModelSZ6_Main", "Z6_FILIAL",  xFilial("SZ6"))
    oModel:SetValue("ModelSZ6_Main", "Z6_DTAGE",   dData)
    oModel:SetValue("ModelSZ6_Main", "Z6_TECNICO", cTecnico)
    oModel:SetValue("ModelSZ6_Main", "Z6_HMINI",   cHmini)
    oModel:SetValue("ModelSZ6_Main", "Z6_HMFIM",   cHmfim)
    oModel:SetValue("ModelSZ6_Main", "Z6_CLIENTE", cCliente)
    oModel:SetValue("ModelSZ6_Main", "Z6_LOJA",    cLoja)
    oModel:SetValue("ModelSZ6_Main", "Z6_SERVICO", cDescri)
    oModel:SetValue("ModelSZ6_Main", "Z6_PROJET",  cProjeto)
    oModel:SetValue("ModelSZ6_Main", "Z6_TAREFA",  cTarefa)
    oModel:SetValue("ModelSZ6_Main", "Z6_CHAMADO", Val(cChamado))
    oModel:SetValue("ModelSZ6_Main", "Z6_QGRAVOU", cNomeGravou)

    // Abre a tela visual do CNSA003 com os campos pre-preenchidos.
    // O usuario completa Confirmacao, Turno, Ag. Interna, Ag. Cobravel,
    // Tipo Agenda e Tipo Hora diretamente na tela antes de confirmar.
    FWExecView("Nova Agenda - Chamado " + cChamado, ;
               "CNSA003", ;
               MODEL_OPERATION_INSERT, ;
               /*oDlg*/ , ;
               {|| .T.}, ;
               NIL, NIL, NIL, NIL, NIL, NIL, ;
               oModel)

    oModel:DeActivate()

Return

//////////////////////////////////////////////////////////////////////////////
//CHAMADA INTERNA QUE CHAMA STATIC PARA SER COLOCADO NO BOTAO AGENDAR
//PARA NAO TER QUE TROCAR PARA U_CRIAAGENDA
//////////////////////////////////////////////////////////////////////////////
User Function CNSA_CRIAAGENDA()
    Local cIdCh    := AllTrim(ZA1->ZA1_IDCH)
    Local cTecnico := AllTrim(ZA1->ZA1_CONSUL)
    Local cCliente := AllTrim(ZA1->ZA1_CLIENT)
    Local cLoja    := AllTrim(ZA1->ZA1_LOJA)

    If ZA1->(Eof()) .Or. ZA1->(Bof())
        MsgAlert("Nenhum chamado selecionado.", "Agendar")
        Return
    EndIf


    If Empty(cTecnico)
        MsgAlert("O chamado precisa ter um tecnico designado antes de agendar.", "Agendar")
        Return
    EndIf

    CNSA_CRIAAGENDA_INT(cTecnico, Date(), "08:00", "09:00", ;
        cCliente, cLoja, ;
        AllTrim(ZA1->ZA1_ASSUNT), AllTrim(ZA1->ZA1_PROJ), ;
        AllTrim(ZA1->ZA1_TAREFA), cIdCh)

Return

////////////////////////////////////////////////////////////////////////////////
// Retorna todos os agendamentos (SZ6) vinculados a um chamado.
// Layout de cada linha: {1 RECNO, 2 Data, 3 HoraIni, 4 HoraFim, 5 CodTecnico, 6 NomeTecnico}
////////////////////////////////////////////////////////////////////////////////
Static Function CNSA_GETAGENDAS(cChamado)
    Local aAgendas := {}
    Local cAlias   := GetNextAlias()
    Local nCham    := Val(cChamado)
    Local cDtFmt   := ""
    Local cNomeTec := ""

    BeginSql Alias cAlias
        SELECT SZ6.R_E_C_N_O_ RECNO, SZ6.Z6_DTAGE, SZ6.Z6_HMINI, SZ6.Z6_HMFIM, SZ6.Z6_TECNICO
        FROM %Table:SZ6% SZ6
        WHERE SZ6.Z6_FILIAL  = %xFilial:SZ6%
          AND SZ6.Z6_CHAMADO = %Exp:nCham%
          AND %NotDel%
        ORDER BY SZ6.Z6_DTAGE, SZ6.Z6_HMINI
    EndSql

    While !(cAlias)->(Eof())
        If ValType((cAlias)->Z6_DTAGE) == "D"
            cDtFmt := DToC((cAlias)->Z6_DTAGE)
        Else
            cDtFmt := AllTrim((cAlias)->Z6_DTAGE)
            If Len(cDtFmt) == 8
                cDtFmt := SubStr(cDtFmt,7,2)+"/"+SubStr(cDtFmt,5,2)+"/"+SubStr(cDtFmt,1,4)
            EndIf
        EndIf

        cNomeTec := AllTrim(Posicione("AA1", 1, xFilial("AA1") + AllTrim((cAlias)->Z6_TECNICO), "AA1_NOMTEC"))

        aAdd(aAgendas, { (cAlias)->RECNO, cDtFmt, AllTrim((cAlias)->Z6_HMINI), ;
                          AllTrim((cAlias)->Z6_HMFIM), AllTrim((cAlias)->Z6_TECNICO), cNomeTec })

        (cAlias)->(DbSkip())
    EndDo
    (cAlias)->(DbCloseArea())

Return aAgendas

////////////////////////////////////////////////////////////////////////////////
// Exibe o Quadro de Agendas (HTML embutido) via TWebEngine
////////////////////////////////////////////////////////////////////////////////
User Function CNSA_VERAGENDAS()
   Local oDialog    := Nil
    Local oWebEngine := Nil
    Local aAgendas   := {}
    Local nAltura    := 0
    Local nLargura   := 700

    If ZA1->(Eof()) .Or. ZA1->(Bof())
        MsgAlert("Nenhum chamado selecionado.", "Ver Agendas")
        Return
    EndIf

    aAgendas := CNSA_GETAGENDAS(AllTrim(ZA1->ZA1_IDCH))

    // Altura base (banner + cabecalho da tabela + rodape) + 32px por linha de agendamento
    nAltura := 220 + (Len(aAgendas) * 32)

    // Limites minimo e maximo, para nao ficar minusculo nem sair da tela
    If nAltura < 300
        nAltura := 300
    ElseIf nAltura > 750
        nAltura := 750
    EndIf

    DEFINE DIALOG oDialog TITLE "Agendamentos - Chamado " + AllTrim(ZA1->ZA1_IDCH) FROM 0,0 TO nAltura, nLargura PIXEL

        oWebEngine := TWebEngine():New(oDialog, 0, 0, 100, 100)
        oWebEngine:SetHtml(CNSA_AGENDA_FRONT(AllTrim(ZA1->ZA1_IDCH), aAgendas))
        oWebEngine:Align := CONTROL_ALIGN_ALLCLIENT

    ACTIVATE DIALOG oDialog CENTERED

Return

////////////////////////////////////////////////////////////////////////////////
// Busca os agendamentos (SZ6) do mes anterior, atual e proximo
// Layout de cada linha: {1 Data(YYYY-MM-DD), 2 HoraIni, 3 HoraFim, 4 NomeTecnico, 5 NomeCliente, 6 Chamado}
////////////////////////////////////////////////////////////////////////////////
Static Function CNSA_PEGA_AGENDAMENTOS()
    Local aAgendas := {}
    Local cAlias   := GetNextAlias()
    Local cDtFmt   := ""
    Local cNomeTec := ""
    Local cNomeCli := ""

    BeginSql Alias cAlias
        SELECT SZ6.Z6_DTAGE, SZ6.Z6_HMINI, SZ6.Z6_HMFIM, SZ6.Z6_TECNICO, SZ6.Z6_CLIENTE, SZ6.Z6_LOJA, SZ6.Z6_CHAMADO
        FROM %Table:SZ6% SZ6
        WHERE SZ6.Z6_FILIAL = %xFilial:SZ6%
          AND SZ6.Z6_DTAGE >= TRUNC(ADD_MONTHS(SYSDATE, -1), 'MM')
          AND SZ6.Z6_DTAGE <  TRUNC(ADD_MONTHS(SYSDATE, 2), 'MM')
          AND %NotDel%
        ORDER BY SZ6.Z6_DTAGE, SZ6.Z6_HMINI
    EndSql

    While !(cAlias)->(Eof())
        If ValType((cAlias)->Z6_DTAGE) == "D"
            cDtFmt := DToS((cAlias)->Z6_DTAGE)
        Else
            cDtFmt := AllTrim((cAlias)->Z6_DTAGE)
        EndIf
        cDtFmt := SubStr(cDtFmt,1,4) + "-" + SubStr(cDtFmt,5,2) + "-" + SubStr(cDtFmt,7,2)

        cNomeTec := AllTrim(Posicione("AA1", 1, xFilial("AA1") + AllTrim((cAlias)->Z6_TECNICO), "AA1_NOMTEC"))
        cNomeCli := AllTrim(Posicione("SA1", 1, xFilial("SA1") + AllTrim((cAlias)->Z6_CLIENTE) + AllTrim((cAlias)->Z6_LOJA), "A1_NOME"))

        aAdd(aAgendas, { cDtFmt, AllTrim((cAlias)->Z6_HMINI), AllTrim((cAlias)->Z6_HMFIM), ;
                          cNomeTec, cNomeCli, AllTrim(Str((cAlias)->Z6_CHAMADO)) })

        (cAlias)->(DbSkip())
    EndDo
    (cAlias)->(DbCloseArea())

Return aAgendas


////////////////////////////////////////////////////////////////////////////////
// Exibe o Quadro de Agendas (HTML embutido) via TWebEngine
////////////////////////////////////////////////////////////////////////////////
User Function CNSA_VE_AGENDAMENTOS()
    Local oDialog    := Nil
    Local oWebEngine := Nil
    Local aAgendas   := {}
    Local cDadosJS   := ""
    Local cHoje      := ""
    Local nI         := 0

    aAgendas := CNSA_PEGA_AGENDAMENTOS()

    cDadosJS := '['
    For nI := 1 To Len(aAgendas)
        If nI > 1
            cDadosJS += ','
        EndIf
        cDadosJS += '{"data":"' + aAgendas[nI][1] + '",'
        cDadosJS += '"hini":"' + CNSA_JSONESC(aAgendas[nI][2]) + '",'
        cDadosJS += '"hfim":"' + CNSA_JSONESC(aAgendas[nI][3]) + '",'
        cDadosJS += '"tecnico":"' + CNSA_JSONESC(aAgendas[nI][4]) + '",'
        cDadosJS += '"empresa":"' + CNSA_JSONESC(aAgendas[nI][5]) + '",'
        cDadosJS += '"chamado":"' + CNSA_JSONESC(aAgendas[nI][6]) + '"}'
    Next nI
    cDadosJS += ']'

    cHoje := StrZero(Year(Date()),4) + "-" + StrZero(Month(Date()),2) + "-" + StrZero(Day(Date()),2)

    DEFINE DIALOG oDialog TITLE "Quadro de Agendamentos" FROM 0,0 TO 700,1000 PIXEL

        oWebEngine := TWebEngine():New(oDialog, 0, 0, 100, 100)
        oWebEngine:SetHtml(CNSA_FRONT_AGENDAMENTO(cDadosJS, cHoje))
        oWebEngine:Align := CONTROL_ALIGN_ALLCLIENT

    ACTIVATE DIALOG oDialog CENTERED

Return

////////////////////////////////////////////////////////////////////////////////
// Remove registro(s) da agenda SZ6 pelo numero do chamado.
// Pergunta individualmente ao usuario quais agendamentos deseja cancelar.
////////////////////////////////////////////////////////////////////////////////
Static Function CNSA_REMOVEAGENDA(cChamado)
    Local aAgendas  := CNSA_GETAGENDAS(cChamado)
    Local nI        := 0
    Local cPergunta := ""

    If Len(aAgendas) == 0
        Return
    EndIf

    dbSelectArea("SZ6")

    For nI := 1 To Len(aAgendas)
        cPergunta := "Cancelar o agendamento de " + aAgendas[nI][2] + " das " + ;
            aAgendas[nI][3] + " as " + aAgendas[nI][4] + " (Tecnico: " + aAgendas[nI][6] + ")?"

        If MsgYesNo(cPergunta, "Cancelamento de Agenda")
            SZ6->(DbGoto(aAgendas[nI][1]))
            If !SZ6->(Eof())
                RecLock("SZ6", .F.)
                    SZ6->(DbDelete())
                SZ6->(MsUnlock())
            EndIf
        EndIf
    Next nI

Return

////////////////////////////////////////////////////////////////////////////////
//APONTAMENTOS DO QUE FOI REALIZADO NO CHAMADO
/////////////////////////////////////////////////////////////////////////////////
User Function CNSA_INTERAGIR()
    Local cConsul  := AllTrim(ZA1->ZA1_CONSUL)
    Local cStatus  := AllTrim(ZA1->ZA1_STATUS)
    Local cCliente := AllTrim(ZA1->ZA1_CLIENT)
    Local cIdCh    := AllTrim(ZA1->ZA1_IDCH)
    Local oModel   := Nil
    Local cAlias   := GetNextAlias()
    Local nChamN   := Val(cIdCh)
    Local nSeq     := 1

    If ZA1->(Eof()) .Or. ZA1->(Bof())
        MsgAlert("Nenhum chamado selecionado.", "Anotar")
        Return
    EndIf

    If cStatus == "4"
        MsgAlert("Chamado fechado nao pode receber anotações.", "Anotar")
        Return
    EndIf

    If Empty(cConsul)
        MsgAlert("O chamado precisa ter um tecnico designado para Anotar.", "Anotar")
        Return
    EndIf

    If Empty(cCliente)
        MsgAlert("O chamado precisa ter um cliente designado para Anotar.", "Anotar")
        Return
    EndIf

    If AllTrim(cConsul) <> AllTrim(cConsultor) .And. !CNSA_NOGRUPO()
        MsgAlert("Voce nao tem permissao para anotar neste chamado.", "Anotar")
        Return
    EndIf

    BeginSql Alias cAlias
        SELECT MAX(ZA2_IDGRID) AS MAXGRID
        FROM %Table:ZA2% ZA2
        WHERE ZA2_FILIAL = %xFilial:ZA2%
          AND ZA2_IDCH   = %Exp:nChamN%
          AND %NotDel%
    EndSql

    If !(cAlias)->(Eof()) .And. !Empty(AllTrim((cAlias)->MAXGRID))
        nSeq := Val(AllTrim((cAlias)->MAXGRID)) + 1
    EndIf
    (cAlias)->(DbCloseArea())

    oModel := FWLoadModel("CNSAZA2VIEW")
    oModel:SetOperation(MODEL_OPERATION_INSERT)
    oModel:Activate()

    oModel:SetValue("ZA2MASTER", "ZA2_IDCH",   cIdCh)
    oModel:SetValue("ZA2MASTER", "ZA2_CONSUL", cConsultor)
    oModel:SetValue("ZA2MASTER", "ZA2_DATA",   CToD(DToC(Date())))
    oModel:SetValue("ZA2MASTER", "ZA2_IDGRID", StrZero(nSeq, 3))

    FWExecView("Nova Anotacao - Chamado " + cIdCh, ;
               "CNSAZA2VIEW", ;
               MODEL_OPERATION_INSERT, ;
               , ;
               {|| .T.}, ;
               NIL, NIL, NIL, NIL, NIL, NIL, ;
               oModel)

    oModel:DeActivate()

Return

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
    Local cTenant := AllTrim(GETMV("MV_CNSATEN"))
    Local cClient := AllTrim(GETMV("MV_CNSACLI"))
    Local cSecret := AllTrim(GETMV("MV_CNSASEC"))
    Local oRest, oJson, cBody, cToken := ""

    If Empty(cTenant) .Or. Empty(cClient) .Or. Empty(cSecret)
        ConOut("CNSA_TOKEN: MV_CNSATEN/MV_CNSACLI/MV_CNSASEC nao configurados no Configurador - e-mail nao sera enviado/verificado.")
        Return ""
    EndIf

    cBody := "grant_type=client_credentials"
    cBody += "&client_id="     + CNSA_URLENC(cClient)
    cBody += "&client_secret=" + CNSA_URLENC(cSecret)
    cBody += "&scope="         + CNSA_URLENC("https://graph.microsoft.com/.default")

    oRest := FWRest():New("https://login.microsoftonline.com")
    oRest:setPath("/" + cTenant + "/oauth2/v2.0/token")
    oRest:SetPostParams(cBody)
    If !oRest:Post({"Content-Type: application/x-www-form-urlencoded"})
        ConOut("CNSA_TOKEN: falha no POST de token (Azure AD): " + oRest:GetLastError())
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
            ZA1->ZA1_CLIENT := IIf(!Empty(cCodCli), cCodCli, "")
            ZA1->ZA1_LOJA   := IIf(!Empty(cCodCli), cLojaCli, "")
            ZA1->ZA1_EMAIL   := cEmail
            ZA1->ZA1_ASSUNT  := cAssunto
            ZA1->ZA1_DATA    := Date()
            ZA1->ZA1_MAILID  := cId
            ZA1->ZA1_MOD     := Date()
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
// FUCNAO QUE VERIFICA QUEM ESTA NO GRUPO DE ADMINISTRADORES
////////////////////////////////////////////////////////////////////////////////
Static Function CNSA_NOGRUPO()
    // FWSFUsrGrps(__cUserId) retorna um array com os IDs dos grupos do usuário logado nativamente
    Local aGrupos   := FWSFUsrGrps(__cUserId)
    Local cGrpPerm  := GetMV("MV_CNSAGRP")
    Local nI        := 0

    // Verifica se a função retornou corretamente um Array
    If ValType(aGrupos) != "A"
        Return .F.
    endif

    If ValType(cGrpPerm) != "C"
        Return .F.
    EndIf

    For nI := 1 To Len(aGrupos)
        If AllTrim(aGrupos[nI]) == AllTrim(cGrpPerm)
            Return .T.
        EndIf
    Next nI

Return .F.

/////////////////////////////////////////////////////////////////////////////////////////////
// Fun??o intermediária para barrar ou filtrar o acesso na Alteração
/////////////////////////////////////////////////////////////////////////////////////////////
User Function CNSA_ALT()

    // Administradores podem alterar o chamado por completo
    If CNSA_NOGRUPO()
        FWExecView("Registro de Chamados", "CNSA001", 4)
        Return
    EndIf

    // Demais usuarios (consultores) sao direcionados para Anotar
    U_CNSA_INTERAGIR()

Return


//-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
//////////////////////////////////////////////////////////////////////////
//CORPO DO EMAIL DE INCLUSAO EM HTML
//////////////////////////////////////////////////////////////////////////
Static Function CNSA_EMAIL_FRONT(cNomeTec, cIdCh, cCliente, cAssunto, cDataAge, cHmini, cHmfim, cNomeDe, cTipo)
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
Static Function CNSA_CANCEL_FRONT(cCliente, cDataAge, cHmini, cHmfim, cChamado, cMotivo, cExcluidoPor)
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


///////////////////////////////////////////////////////////////////////////////
//ABRE A AGENDA
/////////////////////////////////////////////////////////////////////////////
User Function ABREAGENDA()
    FwCallApp("cnsaagenda")
Return

////////////////////////////////////////////////////////////////////////////////
// Converte data BR (DD/MM/AAAA) para ISO (AAAA-MM-DD)
////////////////////////////////////////////////////////////////////////////////
Static Function CNSA_DATAISO(cDataBr)
    Local cRet := ""
    If Len(AllTrim(cDataBr)) == 10
        cRet := SubStr(cDataBr,7,4) + "-" + SubStr(cDataBr,4,2) + "-" + SubStr(cDataBr,1,2)
    EndIf
Return cRet

////////////////////////////////////////////////////////////////////////////////
//API REST DE AGENDAMENTOS (para o app Angular/PO-UI)
//
// Roda no APPServer REST na porta 8624 (appserver.ini: [REST] / PORT=8624).
//
// GET /rest/CNSAAGENDAMENTOS
//   ?pagina=<n>&tamanho=<n>  -> paginacao (padrao: pagina 1, 10 itens)
//
// Usa o FwModel/agenda/ nativo do Protheus via FWRest. O filtro de periodo
// (janela de 3 anos: ano atual -1 e +1) e aplicado direto no FwModel, via
// parametro "filter" da querystring - testado e confirmado via curl:
//   filter=Z6_DTAGE BETWEEN '20250101' AND '20271231'
// O FwModel aplica esse filtro ANTES da paginacao, no servidor: o "total"
// cai de 130700 (todos os registros desde 2004) para ~6300 (so o periodo),
// resolvendo a lentidao com a SZ6 tendo mais de 130 mil linhas.
////////////////////////////////////////////////////////////////////////////////

WSRESTFUL CNSAAGENDAMENTOS DESCRIPTION "API de agendamentos do CNSA001" FORMAT APPLICATION_JSON

    WSDATA pagina         AS INTEGER   OPTIONAL
    WSDATA tamanho        AS INTEGER   OPTIONAL
    WSDATA ano            AS INTEGER   OPTIONAL
    WSDATA mes            AS INTEGER   OPTIONAL
    WSDATA meu            AS INTEGER   OPTIONAL
    WSDATA assumidos      AS INTEGER   OPTIONAL
    WSDATA chamado        AS CHARACTER OPTIONAL
    WSDATA tecnico        AS CHARACTER OPTIONAL
    WSDATA cliente        AS CHARACTER OPTIONAL

    WSMETHOD GET DESCRIPTION "Agendamentos - mes/ano, so-meus, assumidos (com regra de grupo), ou consulta livre"

END WSRESTFUL


WSMETHOD GET WSRECEIVE pagina, tamanho, ano, mes, meu, assumidos, chamado, tecnico, cliente WSSERVICE CNSAAGENDAMENTOS
    Local oJson             := JsonObject():New()
    Local oFwResp           := JsonObject():New()
    Local aRetorno          := {}
    Local aResources        := {}
    Local oResource         := Nil
    Local oLinha            := Nil
    Local oRest             := Nil
    Local aHead             := {}
    Local nPagina           := 1
    Local nTamanho          := 10
    Local nTotal            := 0
    Local nStartIdx         := 1
    Local nI                := 0
    Local cGetParam         := ""
    Local cResp             := ""
    Local cTecCod           := ""
    Local cCliCod           := ""
    Local cLoja             := ""
    Local oErro             := Nil
    Local cFiltro           := ""
    Local nAnoParam         := 0
    Local nMesParam         := 0
    Local nMeuParam         := 0
    Local nAssumidosParam   := 0
    Local cConsultorSessao  := ""
    Local nAnoIni           := Year(Date()) - 1
    Local nAnoFim           := Year(Date()) + 2
    Local dIni              := CToD("")
    Local dFimExclusivo     := CToD("")
    Local cJsonErr          := ""
    Local cAuthValue        := ""
    Local aCacheTec         := {}
    Local aCacheCli         := {}
    Local aCacheChm         := {}
    Local nPosCache         := 0
    Local cNomeTec          := ""
    Local cNomeCli          := ""
    Local cChamado          := ""
    Local cStatusChm        := ""
    Local cAliasChm         := "TCHM"
    Local nMesFimCalc       := 0
    Local nAnoFimCalc       := 0
    Local cChamadoParam     := ""
    Local cTecnicoParam     := ""
    Local cClienteParam     := ""
    Local aCondicoes        := {}

    ::SetContentType("application/json")

    Begin Sequence

        Default ::pagina    := 1
        Default ::tamanho   := 10
        Default ::ano       := 0
        Default ::mes       := 0
        Default ::meu       := 0
        Default ::assumidos := 0
        Default ::chamado   := ""
        Default ::tecnico   := ""
        Default ::cliente   := ""

        nPagina         := If(::pagina  < 1, 1, ::pagina)
        nTamanho        := If(::tamanho < 1 .Or. ::tamanho > 100, 10, ::tamanho)
        nStartIdx       := (nPagina - 1) * nTamanho + 1
        nAnoParam       := ::ano
        nMesParam       := ::mes
        nMeuParam       := ::meu
        nAssumidosParam := ::assumidos
        cChamadoParam   := AllTrim(::chamado)
        cTecnicoParam   := AllTrim(::tecnico)
        cClienteParam   := AllTrim(::cliente)

        // Resolve o codigo do tecnico da sessao uma unica vez, se algum dos
        // dois filtros de permissao (meu / assumidos-nao-privilegiado) precisar.
        If (nMeuParam == 1 .Or. nAssumidosParam == 1) .And. Empty(cConsultorSessao)
            cConsultorSessao := Posicione("AA1", 4, xFilial("AA1") + __cUserId, "AA1_CODTEC")
        EndIf

        If !Empty(cChamadoParam) .Or. !Empty(cTecnicoParam) .Or. !Empty(cClienteParam)
            If !Empty(cChamadoParam)
                AAdd(aCondicoes, "Z6_CHAMADO = '" + cChamadoParam + "'")
            EndIf
            If !Empty(cTecnicoParam)
                AAdd(aCondicoes, "Z6_TECNICO = '" + cTecnicoParam + "'")
            EndIf
            If !Empty(cClienteParam)
                AAdd(aCondicoes, "Z6_CLIENTE = '" + cClienteParam + "'")
            EndIf

            cFiltro := ""
            For nI := 1 To Len(aCondicoes)
                cFiltro += If(nI > 1, " AND ", "") + aCondicoes[nI]
            Next nI

        ElseIf nAnoParam > 0 .And. nMesParam >= 1 .And. nMesParam <= 12
            dIni       := StoD(StrZero(nAnoParam,4) + StrZero(nMesParam,2) + "01")
            nMesFimCalc := nMesParam + 1
            nAnoFimCalc := nAnoParam
            If nMesFimCalc > 12
                nMesFimCalc := 1
                nAnoFimCalc++
            EndIf
            dFimExclusivo := StoD(StrZero(nAnoFimCalc,4) + StrZero(nMesFimCalc,2) + "01")
            cFiltro := "Z6_DTAGE BETWEEN '" + DToS(dIni) + "' AND '" + DToS(dFimExclusivo - 1) + "'"

        ElseIf nAnoParam > 0
            dIni          := StoD(StrZero(nAnoParam,4) + "0101")
            dFimExclusivo := StoD(StrZero(nAnoParam + 1,4) + "0101")
            cFiltro := "Z6_DTAGE BETWEEN '" + DToS(dIni) + "' AND '" + DToS(dFimExclusivo - 1) + "'"

        Else
            dIni          := StoD(StrZero(nAnoIni,4) + "0101")
            dFimExclusivo := StoD(StrZero(nAnoFim,4) + "0101")
            cFiltro := "Z6_DTAGE BETWEEN '" + DToS(dIni) + "' AND '" + DToS(dFimExclusivo - 1) + "'"
        EndIf

        // "Meus" - universal, todo mundo ve so o proprio, sem excecao
        If nMeuParam == 1 .And. !Empty(cConsultorSessao)
            cFiltro += " AND Z6_TECNICO = '" + cConsultorSessao + "'"
        EndIf

        // "Assumidos" - quem e do grupo privilegiado (CNSA_NOGRUPO) ve de TODOS;
        // quem nao e, fica restrito ao proprio tecnico, igual "meus"
        If nAssumidosParam == 1 .And. !CNSA_NOGRUPO() .And. !Empty(cConsultorSessao)
            cFiltro += " AND Z6_TECNICO = '" + cConsultorSessao + "'"
        EndIf

        cAuthValue := GETMV("MV_CNSAAUT")

        AAdd(aHead, "tenantid: " + cEmpAnt + "," + cFilAnt)
        AAdd(aHead, "Authorization: Basic " + cAuthValue)

        cGetParam := "startindex=" + AllTrim(Str(nStartIdx)) + "&count=" + AllTrim(Str(nTamanho))
        cGetParam += "&filter=" + CNSA_URLENC(cFiltro)

        oRest := FWRest():New(CNSA_FWMODEL_HOST)
        oRest:SetPath(CNSA_FWMODEL_PATH)

        If !oRest:Get(aHead, cGetParam)
            ::SetStatus(502)
            ::SetResponse('{"erro":"' + CNSA_JSONESC(oRest:GetLastError()) + '"}')
            FreeObj(oRest)
            Break
        EndIf

        cResp := oRest:GetResult()
        FreeObj(oRest)

        cJsonErr := oFwResp:FromJson(cResp)
        If ValType(cJsonErr) == "C" .And. !Empty(cJsonErr)
            ::SetStatus(500)
            ::SetResponse('{"erro":"Falha no parse do retorno: ' + CNSA_JSONESC(cJsonErr) + '"}')
            Break
        EndIf

        nTotal     := If(ValType(oFwResp['total'])     == 'N', oFwResp['total'],     0)
        aResources := If(ValType(oFwResp['resources']) == 'A', oFwResp['resources'], {})

        For nI := 1 To Len(aResources)
            oResource := aResources[nI]
            cTecCod   := AllTrim(CNSA_CAMPO(oResource, "Z6_TECNICO"))
            cCliCod   := AllTrim(CNSA_CAMPO(oResource, "Z6_CLIENTE"))
            cLoja     := AllTrim(CNSA_CAMPO(oResource, "Z6_LOJA"))

            nPosCache := AScan(aCacheTec, {|x| x[1] == cTecCod})
            If nPosCache > 0
                cNomeTec := aCacheTec[nPosCache][2]
            Else
                cNomeTec := AllTrim(Posicione("AA1", 1, xFilial("AA1") + cTecCod, "AA1_NOMTEC"))
                AAdd(aCacheTec, {cTecCod, cNomeTec})
            EndIf

            nPosCache := AScan(aCacheCli, {|x| x[1] == cCliCod + cLoja})
            If nPosCache > 0
                cNomeCli := aCacheCli[nPosCache][2]
            Else
                cNomeCli := AllTrim(Posicione("SA1", 1, xFilial("SA1") + cCliCod + cLoja, "A1_NOME"))
                AAdd(aCacheCli, {cCliCod + cLoja, cNomeCli})
            EndIf

            cChamado  := AllTrim(CNSA_CAMPO(oResource, "Z6_CHAMADO"))

            // Status do chamado vinculado (mesma legenda do browse ZA1_STATUS,
            // ver AddLegend acima) - via SQL direto (sem Posicione) porque a
            // ordem de indice ZA1_FILIAL+ZA1_IDCH nao esta confirmada no
            // dicionario; SQL so depende de nome de campo, ja confirmado em uso
            // (CNSA001.PRW linhas 41-44/158/407).
            nPosCache := AScan(aCacheChm, {|x| x[1] == cChamado})
            If nPosCache > 0
                cStatusChm := aCacheChm[nPosCache][2]
            ElseIf Empty(cChamado)
                cStatusChm := ""
            Else
                BeginSql Alias cAliasChm
                    SELECT ZA1_STATUS
                    FROM %Table:ZA1% ZA1
                    WHERE ZA1_FILIAL = %xFilial:ZA1%
                    AND ZA1_IDCH = %Exp:cChamado%
                    AND ZA1.%NotDel%
                EndSql
                cStatusChm := If(!(cAliasChm)->(Eof()), AllTrim((cAliasChm)->ZA1_STATUS), "")
                (cAliasChm)->(DbCloseArea())
                AAdd(aCacheChm, {cChamado, cStatusChm})
            EndIf

            oLinha := JsonObject():New()
            oLinha['filial']     := AllTrim(CNSA_CAMPO(oResource, "Z6_FILIAL"))
            oLinha['data']       := CNSA_DTAGE_ISO(AllTrim(CNSA_CAMPO(oResource, "Z6_DTAGE")))
            oLinha['tecnico']    := cNomeTec
            oLinha['seq']        := AllTrim(CNSA_CAMPO(oResource, "Z6_SEQ"))
            oLinha['hini']       := AllTrim(CNSA_CAMPO(oResource, "Z6_HMINI"))
            oLinha['hfim']       := AllTrim(CNSA_CAMPO(oResource, "Z6_HMFIM"))
            oLinha['cliente']    := cNomeCli
            oLinha['loja']       := cLoja
            oLinha['confirmado'] := AllTrim(CNSA_CAMPO(oResource, "Z6_CONFIRM"))
            oLinha['turno']      := AllTrim(CNSA_CAMPO(oResource, "Z6_TURNO"))
            oLinha['chamado']    := cChamado
            oLinha['statusChamado'] := cStatusChm
            AAdd(aRetorno, oLinha)
        Next nI

        oJson['total']        := nTotal
        oJson['totalPaginas'] := If(nTotal == 0, 0, Ceiling(nTotal / nTamanho))
        oJson['startindex']   := nStartIdx
        oJson['pagina']       := nPagina
        oJson['tamanho']      := nTamanho
        oJson['items']        := aRetorno

        ::SetResponse(oJson:ToJson())

    Recover Using oErro
        If oErro != Nil
            ::SetStatus(500)
            ::SetResponse('{"erro":"' + CNSA_JSONESC(oErro:Description) + '"}')
        EndIf
    End Sequence

Return .T.

////////////////////////////////////////////////////////////////////////////////
// percorre models do resource e retorna o valor do campo solicitado.
Static Function CNSA_CAMPO(oResource, cNome)
    Local aModels := Nil
    Local aFields := Nil
    Local oModel  := Nil
    Local oField  := Nil
    Local nM      := 0
    Local nF      := 0

    If ValType(oResource) != 'J'
        Return ''
    EndIf

    aModels := oResource['models']
    If ValType(aModels) != 'A'
        Return ''
    EndIf

    For nM := 1 To Len(aModels)
        oModel := aModels[nM]
        If ValType(oModel) == 'J' .And. AllTrim(oModel['id']) == CNSA_FWMODEL_MODEL
            aFields := oModel['fields']
            If ValType(aFields) == 'A'
                For nF := 1 To Len(aFields)
                    oField := aFields[nF]
                    If ValType(oField) == 'J' .And. AllTrim(oField['id']) == cNome
                        Do Case
                            Case ValType(oField['value']) == 'C'
                                Return oField['value']
                            Case ValType(oField['value']) == 'N'
                                Return cValToChar(oField['value'])
                            OtherWise
                                Return ''
                        EndCase
                    EndIf
                Next nF
            EndIf
        EndIf
    Next nM
Return ''

////////////////////////////////////////////////////////////////////////////////
// Converte Z6_DTAGE (YYYYMMDD) para yyyy-MM-dd que o Angular entende como date
Static Function CNSA_DTAGE_ISO(cDtAge)
    If Len(AllTrim(cDtAge)) == 8
        Return SubStr(cDtAge, 1, 4) + "-" + SubStr(cDtAge, 5, 2) + "-" + SubStr(cDtAge, 7, 2)
    EndIf
Return cDtAge

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
