#include "protheus.ch"
#include "rwmake.ch"
#include "TOPCONN.CH"
#include "TOTVS.CH"
#include "FWMBROWSE.CH"
#include "FWMVCDEF.CH"

#define CRLF (chr(13)+chr(10))
#define FORM_MODEL       "FZA1_MVC"
#define LOAD_MODEL       "ZA1_MVC"
#define ID_VIEW_DEF_MENU "VIEWDEF.ZA1_MVC"
#define ID_MASTER        "ZA1MASTER"
#define ID_VIEW_ZA1      "VIEW_ZA1"
#define ID_TELA_ZA1      "TELA_ZA1"

///////////////////////////////////////////////////////////////////////////////////////
// MODELO DE DADOS
///////////////////////////////////////////////////////////////////////////////////////
Static Function ModelDef()
    Local l_oModel    := Nil
    Local l_oStrZA1   := FWFormStruct(1,"ZA1")
    Private cCadastro := "Manutencao de Segmentos"
    
    // Desbloqueia os campos restritos direto na estrutura para permitir o SetValue
    l_oStrZA1:SetProperty("ZA1_FILIAL", MODEL_FIELD_WHEN, {|| .T. })
    l_oStrZA1:SetProperty("ZA1_IDCH"  , MODEL_FIELD_WHEN, {|| .T. })
    l_oStrZA1:SetProperty("ZA1_DATA"  , MODEL_FIELD_WHEN, {|| .T. })
    l_oStrZA1:SetProperty("ZA1_ASSUNT"  , MODEL_FIELD_WHEN, {|| .T. })
    l_oStrZA1:SetProperty("ZA1_CLIENT", MODEL_FIELD_WHEN, {|| .T. })
    l_oStrZA1:SetProperty("ZA1_LOJA"  , MODEL_FIELD_WHEN, {|| .T. })
    // Cabecalho do modelo
    l_oModel := MPFormModel():New(FORM_MODEL, ;
        {|l_oModel| FZA1TOK(l_oModel)}, ;
        {|l_oModel| FZA1CAN(l_oModel)})

    l_oModel:SetDescription(cCadastro)
    l_oModel:addFields(ID_MASTER, NIL, l_oStrZA1, {|_oFieldZA1,_sAcao,_sCampo,_vValor| ZA1PosValid(_oFieldZA1,_sAcao,_sCampo,_vValor)})
    l_oModel:SetPrimaryKey({"ZA1_FILIAL", "ZA1_IDCH"})
    l_oModel:SetVldActivate({|l_oModel| FZA1PRE(l_oModel)})

Return l_oModel

//////////////////////////////////////////////////////////////////////////////////////////
// Valida os campos do cabeÃ§alho (tabela ZA1)
Static Function ZA1PosValid(p_oField, p_sAcao, p_sCampo, p_vValor)
    Local l_bOk := .T.

    If AllTrim(p_sAcao) == "SETVALUE"

        // Corrigido para ZA1_ASSUNT (10 caracteres)
        If AllTrim(p_sCampo) == "ZA1_ASSUNT"
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
// Permitir ou nÃ£o a alteraÃ§Ã£o do registro
Static Function FZA1PRE(p_oModel)
    Local l_bRet := .T.
Return l_bRet

// FunÃ§Ã£o de validaÃ§Ã£o dos dados TudoOK
Static Function FZA1TOK(p_oModel)
    Local l_bOk := .T.
Return l_bOk

// FunÃ§Ã£o executada ao clicar em cancelar
Static Function FZA1CAN(p_oModel)
Return .T.


///////////////////////////////////////////////////////////////////////////////////////
// FUNCAO DE TESTE: Simula a inclusao, alteracao e exclusao direto na tabela (MVC)
///////////////////////////////////////////////////////////////////////////////////////
User Function TstZA1()
    Local l_oModel  := Nil 

    //Variaveis para Exclusao
    Local cOpcaoDel  := ""
    Local cValorDel  := ""
    Local lDeletar   := .F.
    Local nDeletados := 0 

    //Variaveis para alteracao
    Local cOpcaoAlt  := ""
    Local lAlterar   := .F.
    Local nAlterados := 0
    Local cValorBusca:= ""
    Local cNovoValor := ""
    

    //Escolha se quer INCLUIR, ALTERAR OU EXCLUIR
    Local cOpcaoIAE := ""


    // 1. INICIALIZA AMBIENTE
    If Select("SX2") == 0
        RpcSetEnv("01", "01")
    EndIf

    // 2. CARREGA O MODELO
    l_oModel := ModelDef() // Carrega a definição do modelo (função ModelDef) 
    
    If l_oModel == Nil
        MsgStop("Falha ao carregar o modelo. Verifique se a tabela ZA1 existe no dicionario.", "Erro")
        Return
    EndIf

    cOpcaoIAE := FWInputBox("1-Incluir|" + ;
                            "2-Alterar|" + ;
                            "3-Excluir", "")

    Do Case
        // ---------------------------------------------------------
        // CASO 1: INCLUSAO
        // ---------------------------------------------------------
        Case cOpcaoIAE == "1"
            l_oModel:SetOperation(3)
            l_oModel:Activate()
            
            l_oModel:SetValue(ID_MASTER, "ZA1_FILIAL", xFilial("ZA1"))
            l_oModel:SetValue(ID_MASTER, "ZA1_IDCH",   "0000034") 
            l_oModel:SetValue(ID_MASTER, "ZA1_DATA",   dDataBase)
            l_oModel:SetValue(ID_MASTER, "ZA1_CLIENT", "ge")
            l_oModel:SetValue(ID_MASTER, "ZA1_ASSUNT", "avioes") 
            l_oModel:SetValue(ID_MASTER, "ZA1_LOJA",   "01")

            If l_oModel:VldData()
                l_oModel:CommitData()
                MsgInfo("Inclusao realizada com SUCESSO!", "Teste MVC")
            Else
                MsgStop("Falha na Inclusao: " + l_oModel:GetErrorMessage()[5])
            EndIf
            l_oModel:DeActivate()

        // ---------------------------------------------------------
        // CASO 2: ALTERACAO
        // ---------------------------------------------------------
        Case cOpcaoIAE == "2"
            // 1. Pergunta por onde identificar o registro (Filtro)
            cOpcaoAlt := FWInputBox("Alterar por:"+"1-Assunto|2-Data|3-Loja", "")
            cValorBusca := FWInputBox("Digite o valor para a BUSCA (Filtro):", "")
            
            If !Empty(cValorBusca)
                // 2. Pergunta QUAL campo o usuário quer alterar naquele registro encontrado
                cOpcaoAlt := FWInputBox("Qual campo deseja ALTERAR?"+"1-Assunto|2-Data|3-Loja", "")
                cNovoValor := FWInputBox("Digite o NOVO CONTEÚDO para este campo:", "")
                
                l_oModel:SetOperation(4) // 4 = Alteração
                DbSelectArea("ZA1")
                ZA1->(DbGoTop())
                
                While !ZA1->(EOF())
                    lAlterar := .F.
                    
                    // VALIDAÇÃO DA BUSCA: Localiza o registro correto
                    Do Case
                        Case cOpcaoAlt == "1"; lAlterar := (AllTrim(ZA1->ZA1_ASSUNT)   == AllTrim(cValorBusca))
                        Case cOpcaoAlt == "2"; lAlterar := (ZA1->ZA1_DATA == CToD(AllTrim(cValorBusca)))
                        Case cOpcaoAlt == "3"; lAlterar := (AllTrim(ZA1->ZA1_LOJA) == AllTrim(cValorBusca))
                    EndCase

                    // SE ACHOU O REGISTRO: Altera o campo escolhido autonomamente
                    If lAlterar
                        l_oModel:Activate() 
                        
                        Do Case 
                            Case cOpcaoAlt == "1"; l_oModel:SetValue(ID_MASTER, "ZA1_ASSUNT", cNovoValor)
                            Case cOpcaoAlt == "2"; l_oModel:SetValue(ID_MASTER, "ZA1_DATA",   CToD(cNovoValor))
                            Case cOpcaoAlt == "3"; l_oModel:SetValue(ID_MASTER, "ZA1_LOJA",   cNovoValor)
                        EndCase
                        
                        If l_oModel:VldData()
                            l_oModel:CommitData()
                            nAlterados++
                        Else
                            MsgStop("Erro na alteracao: " + l_oModel:GetErrorMessage()[5])
                        EndIf
                        l_oModel:DeActivate()
                    EndIf
                    
                    ZA1->(DbSkip())
                EndDo
                MsgInfo("Total de registros alterados: " + cValToChar(nAlterados), "Resultado")
            EndIf

        // ---------------------------------------------------------
        // CASO 3: EXCLUSAO
        // ---------------------------------------------------------
        Case cOpcaoIAE == "3"
            cOpcaoDel := FWInputBox("Excluir por:"+"1-Filial|2-ID|3-Data|4-Assunto|5-Cliente", "")
            cValorDel := FWInputBox("Digite o valor para EXCLUSAO:", "")

            If !Empty(cValorDel)
                l_oModel:SetOperation(5)
                DbSelectArea("ZA1")
                ZA1->(DbGoTop())

                While !ZA1->(EOF())
                    lDeletar := .F.
                    Do Case
                        Case cOpcaoDel=="1"; lDeletar := (AllTrim(ZA1->ZA1_FILIAL) == AllTrim(cValorDel))
                        Case cOpcaoDel=="2"; lDeletar := (AllTrim(ZA1->ZA1_IDCH)   == AllTrim(cValorDel))
                        Case cOpcaoDel=="3"; lDeletar := (ZA1->ZA1_DATA == CToD(AllTrim(cValorDel)))
                        Case cOpcaoDel=="4"; lDeletar := (AllTrim(ZA1->ZA1_ASSUNT) == AllTrim(cValorDel))
                        Case cOpcaoDel=="5"; lDeletar := (AllTrim(ZA1->ZA1_CLIENT) == AllTrim(cValorDel))
                    EndCase

                    If lDeletar
                        l_oModel:Activate()
                        If l_oModel:VldData()
                            l_oModel:CommitData()
                            nDeletados++
                        EndIf
                        l_oModel:DeActivate()
                    EndIf
                    ZA1->(DbSkip())
                EndDo
                MsgInfo("Total de registros excluidos: " + cValToChar(nDeletados))
            EndIf
            
        Otherwise
            MsgAlert("Operacao Cancelada.")
    EndCase

    l_oModel:Destroy()
Return
