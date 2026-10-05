#Include "Totvs.ch"
#Include "FWMVCDef.ch"
//#include "tlpp-core.th"
//#include "tlpp-rest.th"
#include "protheus.ch"
#include "fwmvcdef.ch"

PUBLISH MODEL REST NAME agenda RESOURCE OBJECT oRestAgenda

//-------------------------------------------------------------------
/*/{Protheus.doc} CNSA003
Ponto de entrada do browse de Agenda dos Tecnicos (SZ6).
@author Luiz Muller
@since 01/09/2026
@version P12
/*/
//-------------------------------------------------------------------
User Function CNSA003()
// O Browse com o MenuDef s�oo parte do Control ("C" do MVC)

Local   oBrowse := Nil
Private aRotina := MenuDef()

oBrowse := FWMBrowse():New()
If oBrowse <> Nil
	oBrowse:SetDescription("Agendas dos T�cnicos") 
    oBrowse:SetAlias('SZ6') 
	oBrowse:Activate()
EndIf

Return

//-------------------------------------------------------------------
/*/{Protheus.doc} MenuDef
Menu padrao do browse (Pesquisar/Visualizar/Incluir/Alterar/Excluir).
@return aRotina Array de opcoes do menu (FWMVCMenu)
@author Luiz Muller
@since 01/09/2026
@version P12
/*/
//-------------------------------------------------------------------
Static Function MenuDef()
// Usando MenuDef padr�o por enquanto
Return FWMVCMenu('CNSA003')

//-------------------------------------------------------------------
/*/{Protheus.doc} ModelDef
Model do MVC do SZ6 (Agenda dos Tecnicos).
@return oModel Model montado (MPFormModel)
@author Luiz Muller
@since 01/09/2026
@version P12
/*/
//-------------------------------------------------------------------
Static Function ModelDef()
// Model do MVC

Local oModel
Local ostruSZ6

ostruSZ6:=FWFormStruc(1,'SZ6')
oModel:=MPFormModel():New('ModelSZ6', , {|oModel| CNS003VldH(oModel)}, , ) //VOLTAR PARA MPFORMMODEL !!!!! R U_
// Calendario do Outlook do tecnico: cria/atualiza/apaga o evento depois de
// gravar (CNS003OUTL) - vale pra toda tela que grava SZ6 por este modelo.
oModel:InstallEvent("CNS003OUTL", /*cOwner*/, CNS003OUTL():New())
oModel:AddFields('ModelSZ6_Main',,oStruSZ6)
oModel:SetPrimaryKey({'Z6_FILIAL','Z6_DTAGE','Z6_TECNICO','Z6_SEQ'})
oModel:SetDescription('Model Agendas')
oModel:GetModel('ModelSZ6_Main'):SetDescription('Model Agendas Main')

Return oModel

//-------------------------------------------------------------------
/*/{Protheus.doc} CNS003OUTL
Evento do modelo da Agenda: mantem o agendamento no calendario do Outlook
do tecnico (spec docs/superpowers/specs/2026-10-05-agenda-outlook-design.md).
BeforeTTS guarda tecnico/id do evento ANTES de gravar (alterar/excluir);
AfterTTS (depois do commit) cria, atualiza, troca de calendario ou apaga
via U_CNSOUTGR / U_CNSOUTEX (cnslib.tlpp). Falha do Outlook
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
        // Rastro no console (REST/tela) - confirma que o evento rodou.
        ConOut("CNSOUTLOOK: CNS003OUTL oper " + cValToChar(nOper) + " tecnico " + AllTrim(oSZ6:GetValue('Z6_TECNICO')) + ;
            " email [" + CNS003EmTec(AllTrim(oSZ6:GetValue('Z6_TECNICO'))) + "] id anterior [" + ::cIdAnt + "]")
        // aTexto = {cTitulo (nome do cliente), cCorpoEvento, aLinhas, cIdCh}
        aTexto := CNS003OutTx(oSZ6)

        If nOper == MODEL_OPERATION_DELETE
            U_CNSOUTEX(CNS003EmTec(::cTecAnt), ::cIdAnt)
            CNS003Mail(::cTecAnt, aTexto, "Agendamento cancelado", ;
                "O agendamento abaixo foi cancelado e removido do seu calend&aacute;rio.")
            Break
        EndIf
        If nOper != MODEL_OPERATION_INSERT .And. nOper != MODEL_OPERATION_UPDATE
            Break
        EndIf

        cTec := AllTrim(oSZ6:GetValue('Z6_TECNICO'))
        cId  := ::cIdAnt

        // Trocou o tecnico: sai do calendario do antigo, entra no do novo.
        If nOper == MODEL_OPERATION_UPDATE .And. ::cTecAnt != cTec
            U_CNSOUTEX(CNS003EmTec(::cTecAnt), cId)
            CNS003Mail(::cTecAnt, aTexto, "Agendamento cancelado", ;
                "Este agendamento foi transferido para outro t&eacute;cnico e removido do seu calend&aacute;rio.")
            cId := ""
        EndIf

        cId := U_CNSOUTGR(CNS003EmTec(cTec), cId, oSZ6:GetValue('Z6_DTAGE'), ;
                    oSZ6:GetValue('Z6_HMINI'), oSZ6:GetValue('Z6_HMFIM'), aTexto[1], aTexto[2])

        If nOper == MODEL_OPERATION_UPDATE .And. ::cTecAnt == cTec
            CNS003Mail(cTec, aTexto, "Agendamento alterado", ;
                "Um agendamento seu foi alterado. Confira os dados atualizados abaixo - o seu calend&aacute;rio j&aacute; foi atualizado.")
        Else
            CNS003Mail(cTec, aTexto, "Novo agendamento", ;
                "Um atendimento foi agendado para voc&ecirc; e j&aacute; est&aacute; no seu calend&aacute;rio do Outlook.")
        EndIf

        ConOut("CNSOUTLOOK: evento " + If(Empty(cId), "NAO gravado", "gravado - id " + Left(cId, 30) + "..."))
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

// Dados do agendamento pro Outlook e pro e-mail:
// {cTitulo (nome do cliente), cCorpoEvento, aLinhas {rotulo, valor}, cIdCh, cQuando (texto puro pro assunto)}
Static Function CNS003OutTx(oSZ6)
    Local cCli     := AllTrim(oSZ6:GetValue('Z6_CLIENTE'))
    Local cLoja    := AllTrim(oSZ6:GetValue('Z6_LOJA'))
    Local cTec     := AllTrim(oSZ6:GetValue('Z6_TECNICO'))
    Local cProj    := AllTrim(oSZ6:GetValue('Z6_PROJET'))
    Local cTaf     := AllTrim(oSZ6:GetValue('Z6_TAREFA'))
    Local nCham    := oSZ6:GetValue('Z6_CHAMADO')
    Local cIdCh    := AllTrim(oSZ6:GetValue('Z6_IDCH'))
    Local cNomCli  := ""
    Local cAssunto := ""
    Local cTitulo  := ""
    Local cCorpo   := ""
    Local aLinhas  := {}
    Local nI       := 0

    If Empty(cIdCh) .And. ValType(nCham) == "N" .And. nCham > 0
        cIdCh := StrZero(nCham, 6)
    EndIf
    If !Empty(cCli)
        cNomCli := AllTrim(Posicione("SA1", 1, xFilial("SA1") + cCli + cLoja, "A1_NREDUZ"))
    EndIf
    // Assunto: o do chamado; sem chamado, o servico/descricao da agenda.
    If !Empty(cIdCh)
        cAssunto := AllTrim(Posicione("ZA1", 1, xFilial("ZA1") + cIdCh, "ZA1_ASSUNT"))
    EndIf
    If Empty(cAssunto)
        cAssunto := AllTrim(oSZ6:GetValue('Z6_SERVICO'))
    EndIf

    // Titulo do evento = nome do cliente (pedido do usuario).
    cTitulo := If(Empty(cNomCli), "Agendamento", cNomCli)

    AAdd(aLinhas, {"Data", DToC(oSZ6:GetValue('Z6_DTAGE'))})
    AAdd(aLinhas, {"Hor&aacute;rio", AllTrim(oSZ6:GetValue('Z6_HMINI')) + " &agrave;s " + AllTrim(oSZ6:GetValue('Z6_HMFIM'))})
    AAdd(aLinhas, {"T&eacute;cnico", AllTrim(Posicione("AA1", 1, xFilial("AA1") + cTec, "AA1_NOMTEC"))})
    AAdd(aLinhas, {"Cliente", cNomCli})
    If !Empty(cProj)
        AAdd(aLinhas, {"Projeto", cProj + " - " + AllTrim(Posicione("AF8", 1, xFilial("AF8") + cProj, "AF8_DESCRI"))})
    EndIf
    If !Empty(cTaf)
        AAdd(aLinhas, {"Tarefa", cTaf + " - " + AllTrim(Posicione("AF9", 1, xFilial("AF9") + cProj + cTaf, "AF9_DESCRI"))})
    EndIf
    AAdd(aLinhas, {"Assunto", cAssunto})
    If !Empty(cIdCh)
        AAdd(aLinhas, {"Chamado", "#" + cIdCh})
    EndIf
    // Campos de lista da agenda: titulo e opcao do proprio dicionario.
    CNS003Opc(aLinhas, oSZ6, "Z6_TIPOAG")
    CNS003Opc(aLinhas, oSZ6, "Z6_LOCAL")
    CNS003Opc(aLinhas, oSZ6, "Z6_CONFIRM")
    CNS003Opc(aLinhas, oSZ6, "Z6_INTERNO")
    CNS003Opc(aLinhas, oSZ6, "Z6_COBRAR")
    If !Empty(oSZ6:GetValue('Z6_QGRAVOU'))
        AAdd(aLinhas, {"Agendado por", AllTrim(oSZ6:GetValue('Z6_QGRAVOU'))})
    EndIf

    cCorpo := ""
    For nI := 1 To Len(aLinhas)
        cCorpo += "<p><b>" + aLinhas[nI][1] + ":</b> " + aLinhas[nI][2] + "</p>"
    Next nI

Return {cTitulo, cCorpo, aLinhas, cIdCh, ;
    DToC(oSZ6:GetValue('Z6_DTAGE')) + " " + AllTrim(oSZ6:GetValue('Z6_HMINI')) + "-" + AllTrim(oSZ6:GetValue('Z6_HMFIM'))}

// Campo de lista (X3_CBOX): titulo do dicionario + descricao da opcao.
Static Function CNS003Opc(aLinhas, oSZ6, cCampo)
    Local cValor := AllTrim(cValToChar(oSZ6:GetValue(cCampo)))
    Local cDesc  := ""

    If Empty(cValor)
        Return
    EndIf
    cDesc := AllTrim(X3Combo(cCampo, cValor))
    AAdd(aLinhas, {AllTrim(RetTitle(cCampo)), If(Empty(cDesc), cValor, cDesc)})
Return

// E-mail de aviso ao tecnico (layout padrao Apia, via U_CNSOUTMA no cnslib).
Static Function CNS003Mail(cTec, aTexto, cAlerta, cIntro)
    Local cNomTec := ""

    If Empty(cTec)
        Return
    EndIf
    cNomTec := AllTrim(Posicione("AA1", 1, xFilial("AA1") + cTec, "AA1_NOMTEC"))
    U_CNSOUTMA(CNS003EmTec(cTec), cAlerta + " - " + aTexto[1] + " - " + aTexto[5], ;
        aTexto[4], cAlerta, cNomTec, cIntro, aTexto[3])
Return

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

//-------------------------------------------------------------------
/*/{Protheus.doc} ViewDef
View do MVC do SZ6 (Agenda dos Tecnicos).
@return oView View montada (FWFormView)
@author Luiz Muller
@since 01/09/2026
@version P12
/*/
//-------------------------------------------------------------------
Static Function ViewDef()
// VieW do MVC
Local oView
Local oModel
Local oStruSZ6

oModel:=ModelDef() //Se n�o estivesse nesse fonte oModel:=FWLoadModel('CNSA003')

oView:=FWFormView():New()
oView:SetModel(oModel)

oStruSZ6:=FWFormStruc(2,'SZ6')
// Z6_IDOUTL (id do evento no Outlook) e so do sistema - fora da tela.
oStruSZ6:RemoveField('Z6_IDOUTL')

oView:AddField('ViewSZ6',oStruSZ6,'ModelSZ6_Main')

oView:CreateHorizontalBox('Tela',100)
oView:SetOwnerView('ViewSZ6','Tela')
oView:SetViewProperty('ViewSZ6','SETCOLUMNSEPARTOR',{10})
oView:SetCloseOnOk({||,.T.})

Return oView

// Fun��es parametrizadas no Model s�o executadas quando chamadas pelo rest/fwmodel

//-------------------------------------------------------------------
/*/{Protheus.doc} CNS003VldH
Validacao pos-commit do model: bloqueia inclusao/alteracao de
agendamento com horario sobreposto a outro ja existente do mesmo
tecnico no mesmo dia.
@param  oModel  Model ativo (MPFormModel)
@return lRet    Indica se a validacao passou
@author Luiz Muller
@since 01/09/2026
@version P12
/*/
//-------------------------------------------------------------------
Static Function CNS003VldH(oModel)

Local dDtAge   := oModel:GetValue('ModelSZ6_Main', 'Z6_DTAGE')
Local cTec     := oModel:GetValue('ModelSZ6_Main', 'Z6_TECNICO')
Local cHoraIni := oModel:GetValue('ModelSZ6_Main', 'Z6_HMINI')
Local cHoraFim := oModel:GetValue('ModelSZ6_Main', 'Z6_HMFIM')
Local cSeqAtu  := oModel:GetValue('ModelSZ6_Main', 'Z6_SEQ')

Local nOper := oModel:GetOperation()
Local oErroSeq := Nil
Local lRet     := .T.
Local cMensagem := ""
Local cDtAge := DToS(dDtAge)

    If nOper == 3 .Or. nOper == 4

        Begin Sequence

            If !Empty(dDtAge) .And. !Empty(cTec) .And. !Empty(cHoraIni) .And. !Empty(cHoraFim)
                DbSelectArea("SZ6")
                SZ6->(DbSetOrder(1))  
                If SZ6->(DbSeek(xFilial("SZ6") + cDtAge + cTec))
                    While !SZ6->(Eof()) .And. ;
                        SZ6->Z6_FILIAL  == xFilial("SZ6") .And. ;
                        DToS(SZ6->Z6_DTAGE) == cDtAge .And. ;
                        SZ6->Z6_TECNICO == cTec
                        If SZ6->Z6_SEQ != cSeqAtu
                            If cHoraIni < SZ6->Z6_HMFIM .And. SZ6->Z6_HMINI < cHoraFim
                                lRet := .F.
                                cMensagem := "Horario " + cHoraIni + "-" + cHoraFim + " sobrepoe agendamento existente (" + ;
                                    SZ6->Z6_HMINI + "-" + SZ6->Z6_HMFIM + ") do mesmo tecnico em " + DToC(dDtAge) + "."
                                oModel:SetErrorMessage("ModelSZ6_Main","Z6_HMINI","ModelSZ6_Main","Z6_HMFIM","CNSA003E01",cMensagem,'Corrija os Dados')
                            EndIf
                        EndIf
                        SZ6->(DbSkip())
                    EndDo
                EndIf
            Else
                // Campos n�o preenchidos N�o faz nada
                Return .T.
            EndIf
        Recover Using oErroSeq
            lRet   := .F.
            ConOut("[oRestAgenda:CNS003VldH] Opera��o: " + Str(nOper) + oErroSeq:Description)
        End Sequence
    Else
        // Outras opera��es n�o faz nada
        Return .T.
    EndIf

Return lRet

// Fun��es Complementares
// Essas fun��es no dicion�rio e gatilhos n�o s�o executadas no rest/fwmodel

//-------------------------------------------------------------------
/*/{Protheus.doc} CNS003Seq
Gatilho (SX7) que calcula a proxima sequencia (Z6_SEQ) de agendamento
pra um tecnico numa data - usado tanto pelo browse quanto pelo
SaveData() do REST.
@return cSeq Proxima sequencia disponivel
@author Luiz Muller
@since 01/09/2026
@version P12
/*/
//-------------------------------------------------------------------
User Function CNS003Seq()
// Pr�xima sequencia de agenda - cadastrada no sx7 e sx3 (inicializador)
// Situa��o espec�fica desse Crud
Local oModel  := FWModelActive()
Local dDtAge  := CToD("")
Local cTec    := ""
Local cDtAge  := ""
Local cSeqAnt := ""
Local cSeq    := ""

dDtAge := oModel:GetValue('ModelSZ6_Main', 'Z6_DTAGE')
cTec   := oModel:GetValue('ModelSZ6_Main', 'Z6_TECNICO')

If Empty(dDtAge) .Or. Empty(cTec)
    oModel:SetValue('ModelSZ6_Main', 'Z6_SEQ', '001')
    Return '001'
EndIf

cDtAge := DToS(dDtAge)
DbSelectArea("SZ6")
SZ6->(DbSetOrder(1))
If SZ6->(DbSeek(xFilial("SZ6") + cDtAge + cTec))
    While !SZ6->(Eof()) .And. ;
          SZ6->Z6_FILIAL  == xFilial("SZ6") .And. ;
          DToS(SZ6->Z6_DTAGE) == cDtAge .And. ;
          SZ6->Z6_TECNICO == cTec
        cSeqAnt := SZ6->Z6_SEQ
        SZ6->(DbSkip())
    EndDo
    cSeq := StrZero(Val(cSeqAnt) + 1, Len(SZ6->Z6_SEQ))
Else
    cSeq := StrZero(1, Len(SZ6->Z6_SEQ))
EndIf

oModel:SetValue('ModelSZ6_Main', 'Z6_SEQ', cSeq)

Return cSeq

//-------------------------------------------------------------------
/*/{Protheus.doc} CNS003NTec
Gatilho (SX7) que resolve o nome do tecnico (Z6_NOMTEC) a partir do
codigo ja preenchido no model (Z6_TECNICO).
@return cNome Nome do tecnico
@author Luiz Muller
@since 01/09/2026
@version P12
/*/
//-------------------------------------------------------------------
User Function CNS003NTec()
Local oModel:= FWModelActive()
Local cCod  := oModel:GetValue('ModelSZ6_Main','Z6_TECNICO')
Local cNome := Posicione("AA1", 1, xFilial("AA1") + cCod, "AA1_NOMTEC")
oModel:SetValue('ModelSZ6_Main','Z6_NOMTEC',cNome)
Return cNome

//-------------------------------------------------------------------
/*/{Protheus.doc} CNS003NCli
Gatilho (SX7) que resolve o nome do cliente (Z6_NOMCLI) a partir do
codigo+loja ja preenchidos no model (Z6_CLIENTE/Z6_LOJA).
@return cNome Nome reduzido do cliente
@author Luiz Muller
@since 01/09/2026
@version P12
/*/
//-------------------------------------------------------------------
User Function CNS003NCli()
Local oModel:= FWModelActive()
Local cCod  := oModel:GetValue('ModelSZ6_Main','Z6_CLIENTE')
Local cLoja := oModel:GetValue('ModelSZ6_Main','Z6_LOJA')
Local cNome := Posicione("SA1", 1, xFilial("SA1") + cCod + cLoja, "A1_NREDUZ")
oModel:SetValue('ModelSZ6_Main','Z6_NOMCLI',cNome)
Return cNome

//-------------------------------------------------------------------
/*/{Protheus.doc} CNS003TemOS
Calcula o campo Temos (Z6_TEMOS): verifica se ja existe uma OS (SZ1)
do mesmo tecnico/dia com horario compativel (dentro da tolerancia) com
o horario do agendamento - "1" se encontrou, "2" caso contrario.
Parametros explicitos (nao le do alias posicionado) pra poder ser
chamada tanto pelo gatilho do browse (SX7, passando os campos SZ6->)
quanto pelo GetData() do REST.
@param  cTecnico    Codigo do tecnico (Z6_TECNICO)
@param  dData       Data do agendamento (Z6_DTAGE)
@param  cHoraIni    Hora inicial do agendamento (Z6_HMINI)
@param  cHoraFim    Hora final do agendamento (Z6_HMFIM)
@return cRet        "1" se ja tem OS compativel, "2" caso contrario
@author Luiz Muller
@since 01/09/2026
@version P12
/*/
//-------------------------------------------------------------------
User Function CNS003TemOS(cTecnico, dData, cHoraIni, cHoraFim)

Local nIniAge   := U_HrMin(cHoraIni)
Local nFimAge   := U_HrMin(cHoraFim)
Local nIniOS    := 0
Local nFimOS    := 0
Local cRet      := "2"
Local nToler    := 15 // Parametrizar futuramente
Local cChave    := ""
Local aAreaZ1   := SZ1->(FWGetArea())

DbSelectArea("SZ1")
SZ1->(DbSetOrder(3))
cChave := xFilial("SZ1") + cTecnico + DToS(dData)
If SZ1->(DbSeek(cChave))
    While !SZ1->(Eof()) .And. SZ1->Z1_FILIAL == xFilial("SZ1") .And. SZ1->Z1_TEC == cTecnico .And. SZ1->Z1_DTOS   == dData
        nIniOS := U_HrMin(SZ1->Z1_HRINI)
        nFimOS := U_HrMin(SZ1->Z1_HRFIM)
        If Abs(nIniOS - nIniAge) <= nToler .And. Abs(nFimOS - nFimAge) <= nToler
            cRet := "1"
            Exit
        EndIf
        SZ1->(DbSkip())
    EndDo
EndIf
FWRestArea(aAreaZ1)

Return cRet

//-------------------------------------------------------------------
/*/{Protheus.doc} CNS003DtLg
Gatilho (SX7) que preenche o campo de data legado (Z6_DATA, formato
AAAAMMDD) a partir da data do agendamento (Z6_DTAGE) - campo nao
exibido no browse.
@return cData Data no formato AAAAMMDD
@author Luiz Muller
@since 01/09/2026
@version P12
/*/
//-------------------------------------------------------------------
User Function CNS003DtLg()

Local oModel := FWModelActive()
Local dDtAge := oModel:GetValue('ModelSZ6_Main','Z6_DTAGE')
Local cData := DToS(dDtAge)
oModel:SetValue('ModelSZ6_Main','Z6_DATA',cData)

Return cData

//-------------------------------------------------------------------
/*/{Protheus.doc} oRestAgenda
Extensao do FwRestModel do SZ6 (Agenda dos Tecnicos) - sobrescreve
GetData()/SaveData() porque o MVC resolve nomes/sequencia por gatilho
(SX7), e o REST generico nao executa gatilho nenhum.
@author Luiz Muller
@since 01/09/2026
@version P12
/*/
//-------------------------------------------------------------------
Class oRestAgenda From FwRestModel

Method GetData(lFieldDetail, lFieldVirtual, lFieldEmpty, lFirstLevel, lInternalID)
Method SaveData(cPK, cData, cError)

EndClass

//-------------------------------------------------------------------
/*/{Protheus.doc} GetData
Sobrescreve o GetData() padrao pra injetar no JSON os campos que no
MVC sao resolvidos por gatilho (Z6_NOMTEC/Z6_NOMCLI/Z6_TEMOS) - o REST
generico nao executa gatilho de SX7.
@param  lFieldDetail    Indica se retorna o registro com informacoes detalhadas
@param  lFieldVirtual   Indica se retorna o registro com campos virtuais
@param  lFieldEmpty     Indica se retorna o registro com campos nao obrigatorios vazios
@param  lFirstLevel     Indica se deve retornar todos os models filhos ou nao
@param  lInternalID     Indica se deve retornar o ID como informacao complementar das linhas do GRID
@return cRet            JSON do registro, com os campos calculados ja substituidos
@author Luiz Muller
@since 01/09/2026
@version P12
/*/
//-------------------------------------------------------------------
Method GetData(lFieldDetail, lFieldVirtual, lFieldEmpty, lFirstLevel, lInternalID) Class oRestAgenda
Local cRet
Local oErroExcpt := Nil
Local cTecnico   := ""
Local cCliente   := ""
Local cLoja      := ""
Local dDtAge     := CToD("")
Local cHoraIni   := ""
Local cHoraFim   := ""
Local cNomTec    := ""
Local cNomCli    := ""
Local cTemOS     := ""
Local jRegistro  := Nil
Local aModels    := Nil
Local aFields    := Nil
Local nX
Local nY

    self:oModel:SetOperation(MODEL_OPERATION_VIEW)
    self:oModel:Activate()
    cTecnico := self:oModel:GetValue('ModelSZ6_Main', 'Z6_TECNICO')
    cCliente := self:oModel:GetValue('ModelSZ6_Main', 'Z6_CLIENTE')
    cLoja    := self:oModel:GetValue('ModelSZ6_Main', 'Z6_LOJA')
    dDtAge   := self:oModel:GetValue('ModelSZ6_Main', 'Z6_DTAGE')
    cHoraIni := self:oModel:GetValue('ModelSZ6_Main', 'Z6_HMINI')
    cHoraFim := self:oModel:GetValue('ModelSZ6_Main', 'Z6_HMFIM')

    cRet := self:oModel:GetJsonData(lFieldDetail,,lFieldVirtual,,lFieldEmpty,.T./*lPK*/,.T./*lPKEncoded*/,self:aFields,lFirstLevel,lInternalID)
    self:oModel:DeActivate()

    Begin Sequence
        cNomTec := Posicione("AA1", 1, xFilial("AA1") + cTecnico, "AA1_NOMTEC")
        cNomCli := Posicione("SA1", 1, xFilial("SA1") + cCliente + cLoja, "A1_NREDUZ")
        cTemOS  := U_CNS003TemOS(cTecnico, dDtAge, cHoraIni, cHoraFim)

        jRegistro := JsonObject():New()
        jRegistro:fromJson(cRet)
        If jRegistro != Nil
            aModels := jRegistro:GetJsonObject("models")

            For nX := 1 To Len(aModels)
            If aModels[nX]:GetJsonText("id") == "ModelSZ6_Main"
                aFields := aModels[nX]:GetJsonObject("fields")
                For nY := 1 To Len(aFields)
                    If aFields[nY]:GetJsonText("id") == "Z6_NOMTEC"
                        aFields[nY]['value'] := cNomTec
                    ElseIf aFields[nY]:GetJsonText("id") == "Z6_NOMCLI"
                        aFields[nY]['value'] := cNomCli
                    ElseIf aFields[nY]:GetJsonText("id") == "Z6_TEMOS"
                        aFields[nY]['value'] := cTemOS
                    EndIf
                Next nY
                Exit
            EndIf
        Next nX
            
            cRet := jRegistro:toJson()
        EndIf
    Recover Using oErroExcpt
        // Se der qualquer problema montando o JSON, devolve como veio
        ConOut("[oRestAgenda:GetData] Falha ao injetar nome tecnico/cliente: " + oErroExcpt:Description)
    End Sequence
    
Return cRet

//-------------------------------------------------------------------
/*/{Protheus.doc} SaveData
Sobrescreve o SaveData() padrao: alteracao (cPK preenchido) segue o
caminho generico do FwRestModel; inclusao (cPK vazio) monta o model na
mao, na ordem que evita conflito do gatilho de Z6_SEQ (precisa
DTAGE/TECNICO setados antes de rodar o gatilho da sequencia).
@param  cPK         PK do registro (vazio = inclusao)
@param  cData       Corpo da requisicao (JSON)
@param  @cError     Retorna mensagem de erro, se houver
@return lRet        Indica se salvou com sucesso
@author Luiz Muller
@since 01/09/2026
@version P12
/*/
//-------------------------------------------------------------------
Method SaveData(cPK, cData, cError) Class oRestAgenda
// Extendi SaveData pela necessidade de executar o gatilho da sequencia
Local lRet        := .T.
Local jBody        := Nil
Local oModelSZ6    := Nil
Local oErroModel   := Nil
Local oErroExcpt   := Nil
Local dDtAge       := CToD("")
Local cTecnico     := ""
Local cSeq         := ""
    // Alteracao: caminho generico ja validado contra o servidor real -
    // nao precisa (e nao deve) ser reimplementado aqui.
    If !Empty(cPK)
        Return _Super:SaveData(cPK, cData, @cError)
    EndIf
    // Inclusao: monta o model na mao, na ordem que evita o conflito do
    // gatilho de Z6_SEQ.
    Begin Sequence
        jBody := JsonObject():New()
        jBody:fromJson(cData)
        If jBody == Nil
            cError := "Corpo da requisicao invalido (JSON malformado)."
            lRet   := .F.
        Else
            self:oModel:SetOperation(MODEL_OPERATION_INSERT)
            self:oModel:Activate()
            oModelSZ6 := self:oModel:GetModel("ModelSZ6_Main")
            dDtAge   := StoD(jBody:GetJsonText("dataAge"))
            cTecnico := AllTrim(jBody:GetJsonText("tecnico"))
            // Ordem importa: DTAGE/TECNICO antes de rodar o gatilho da
            // sequencia (U_CNS003Seq() le os dois do model ativo).
            oModelSZ6:SetValue("Z6_FILIAL",  xFilial("SZ6"))
            oModelSZ6:SetValue("Z6_DTAGE",   dDtAge)
            oModelSZ6:SetValue("Z6_TECNICO", cTecnico)
            cSeq := U_CNS003Seq()
            oModelSZ6:SetValue("Z6_SEQ", cSeq)
            oModelSZ6:SetValue("Z6_HMINI",   jBody:GetJsonText("horaInicial"))
            oModelSZ6:SetValue("Z6_HMFIM",   jBody:GetJsonText("horaFinal"))
            oModelSZ6:SetValue("Z6_CLIENTE", AllTrim(jBody:GetJsonText("cliente")))
            oModelSZ6:SetValue("Z6_LOJA",    AllTrim(jBody:GetJsonText("loja")))
            oModelSZ6:SetValue("Z6_PROJET",  AllTrim(jBody:GetJsonText("projeto")))
            oModelSZ6:SetValue("Z6_REVISA",  AllTrim(jBody:GetJsonText("revisao")))
            oModelSZ6:SetValue("Z6_TAREFA",  AllTrim(jBody:GetJsonText("tarefa")))
            oModelSZ6:SetValue("Z6_IDCH",    AllTrim(jBody:GetJsonText("chamado")))
            oModelSZ6:SetValue("Z6_CONFIRM", AllTrim(jBody:GetJsonText("confirmado")))
            oModelSZ6:SetValue("Z6_INTERNO", AllTrim(jBody:GetJsonText("semcliente")))
            oModelSZ6:SetValue("Z6_TIPOAG",  AllTrim(jBody:GetJsonText("tipoagenda")))
            oModelSZ6:SetValue("Z6_LOCAL",   AllTrim(jBody:GetJsonText("local")))
            If self:oModel:VldData()
                lRet := self:oModel:CommitData()
            Else
                lRet := .F.
            EndIf
            If !lRet
                oErroModel := self:oModel:GetErrorMessage()
                cError := FwJsonSerialize(oErroModel)
            EndIf
            self:oModel:DeActivate()
        EndIf
    Recover Using oErroExcpt
        lRet   := .F.
        cError := "Erro interno: " + oErroExcpt:Description
        ConOut("[oRestAgenda:SaveData] " + cError)
        If self:oModel <> Nil
            self:oModel:DeActivate()
        EndIf
    End Sequence
Return lRet

// Fun�oes Gen�ricas
//-------------------------------------------------------------------
/*/{Protheus.doc} HrMin
Converte uma hora no formato "HH:MM" (ou "HHMM") pra minutos totais
desde a meia-noite - usado pra comparar horarios com tolerancia.
@param  cHora   Hora no formato "HH:MM"
@return nMin    Total de minutos (hora*60 + minuto)
@author Luiz Muller
@since 01/09/2026
@version P12
/*/
//-------------------------------------------------------------------
User Function HrMin(cHora)

    Local cHr  := StrTran(AllTrim(cHora), ":", "")
    Local nHr  := 0
    Local nMin := 0

    If Len(cHr) >= 4
        nHr  := Val(SubStr(cHr, 1, 2))
        nMin := Val(SubStr(cHr, 3, 2))
    EndIf

Return (nHr * 60) + nMin

