#Include "Totvs.ch"
#Include "FWMVCDef.ch"
//#include "tlpp-core.th"
//#include "tlpp-rest.th"
#include "protheus.ch"
#include "fwmvcdef.ch"

PUBLISH MODEL REST NAME agenda RESOURCE OBJECT oRestAgenda

User Function CNSA003()
// O Browse com o MenuDef são parte do Control ("C" do MVC)

Local   oBrowse := Nil
Private aRotina := MenuDef()

oBrowse := FWMBrowse():New()
If oBrowse <> Nil
	oBrowse:SetDescription("Agendas dos Técnicos") 
    oBrowse:SetAlias('SZ6') 
	oBrowse:Activate()
EndIf

Return

Static Function MenuDef()
// Usando MenuDef padrão por enquanto
Return FWMVCMenu('CNSA003')


Static Function ModelDef()
// Model do MVC
Local oModel
Local ostruSZ6

ostruSZ6:=FWFormStruc(1,'SZ6')
oModel:=MPFormModel():New('ModelSZ6')
//oModel := MPFormModel():New('ModelSZ6', , , {|| U_CNS003VldH()}, )
oModel:AddFields('ModelSZ6_Main',,oStruSZ6)
oModel:SetPrimaryKey({'Z6_FILIAL','Z6_DTAGE','Z6_TECNICO','Z6_SEQ'})
oModel:SetDescription('Model Agendas')
oModel:GetModel('ModelSZ6_Main'):SetDescription('Model Agendas Main')

Return oModel

Static Function ViewDef()
// VieW do MVC
Local oView
Local oModel
Local oStruSZ6

oModel:=ModelDef() //Se não estivesse nesse fonte oModel:=FWLoadModel('CNSA003')

oView:=FWFormView():New()
oView:SetModel(oModel)

oStruSZ6:=FWFormStruc(2,'SZ6')

oView:AddField('ViewSZ6',oStruSZ6,'ModelSZ6_Main')

oView:CreateHorizontalBox('Tela',100)
oView:SetOwnerView('ViewSZ6','Tela')
oView:SetViewProperty('ViewSZ6','SETCOLUMNSEPARTOR',{10})
oView:SetCloseOnOk({||,.T.})

Return oView

// Funções parametrizadas no Model são executadas quando chamadas pelo rest/fwmodel


// Validação de sobreposição de horários
User Function CNS003VldH()
//Local oModel := FWModelActive()
Local lRet   := .T.

MsgStop("Validação de sobreposição de horário não implementada.", "Atenção")

Return lRet

// Funções Complementares
// Essas funções no dicionário e gatilhos não são executadas no rest/fwmodel

User Function CNS003Seq()
// Próxima sequencia de agenda - cadastrada no sx7 e sx3 (inicializador)
// Situação específica desse Crud 
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

// Gatilho nome técnico — cadastrado no sx7 
User Function CNS003NTec()
Local oModel:= FWModelActive()
Local cCod  := oModel:GetValue('ModelSZ6_Main','Z6_TECNICO')
Local cNome := Posicione("AA1", 1, xFilial("AA1") + cCod, "AA1_NOMTEC")
oModel:SetValue('ModelSZ6_Main','Z6_NOMTEC',cNome)
Return cNome

// Gatilho nome cliente — cadastrado no sx7
User Function CNS003NCli()
Local oModel:= FWModelActive()
Local cCod  := oModel:GetValue('ModelSZ6_Main','Z6_CLIENTE')
Local cLoja := oModel:GetValue('ModelSZ6_Main','Z6_LOJA')
Local cNome := Posicione("SA1", 1, xFilial("SA1") + cCod + cLoja, "A1_NREDUZ")
oModel:SetValue('ModelSZ6_Main','Z6_NOMCLI',cNome)
Return cNome

// Gatilho p/ preencher data legado - cadastrado no sx7
User Function CNS003DtLg()
Local oModel := FWModelActive()
Local dDtAge := oModel:GetValue('ModelSZ6_Main','Z6_DTAGE')
Local cData := DToS(dDtAge)
oModel:SetValue('ModelSZ6_Main','Z6_DATA',cData)
Return cData

// Classe declara no Publish que extende fwmodel quando necessário
Class oRestAgenda From FwRestModel

Method GetData(lFieldDetail, lFieldVirtual, lFieldEmpty, lFirstLevel, lInternalID)
Method SaveData(cPK, cData, cError)

EndClass

// Extender GerData foi necessário para preencher os nomes já que no MVC é por gatilho o rest não executa
Method GetData(lFieldDetail, lFieldVirtual, lFieldEmpty, lFirstLevel, lInternalID) Class oRestAgenda
Local cRet
Local oErroExcpt := Nil
Local cTecnico   := ""
Local cCliente   := ""
Local cLoja      := ""
Local cNomTec    := ""
Local cNomCli    := ""
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
  
    cRet := self:oModel:GetJsonData(lFieldDetail,,lFieldVirtual,,lFieldEmpty,.T./*lPK*/,.T./*lPKEncoded*/,self:aFields,lFirstLevel,lInternalID)
    self:oModel:DeActivate()

    Begin Sequence
        cNomTec := Posicione("AA1", 1, xFilial("AA1") + cTecnico, "AA1_NOMTEC")
        cNomCli := Posicione("SA1", 1, xFilial("SA1") + cCliente + cLoja, "A1_NREDUZ")
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

// Extender SaveData foi necessário porque a sequencia é preenchida por gatilho que o rest não executa
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
        Return _Super:SaveData(cPK, cData, cError)
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
            oModelSZ6:SetValue("Z6_CONFIRM", AllTrim(jBody:GetJsonText("confirmado")))
            oModelSZ6:SetValue("Z6_TURNO",   Val(jBody:GetJsonText("turno")))
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

