#Include 'Protheus.ch'
#Include 'FWMVCDef.ch'
 
//Variáveis Estáticas
Static cTitulo := "Grp.Produtos (Mod.1)"
 
/*/{Protheus.doc} protNet
Função para cadastro de Grupo de Produtos (ZA1), exemplo de Modelo 1 em MVC
@author Atilio
@since 17/08/2015
@version 1.0
    @return Nil, Função não tem retorno
    @example
    u_protNet()
    @obs Não se pode executar função MVC dentro do fórmulas
/*/
 
User Function protNet()
    Local aArea   := GetArea()
    Local oBrowse
    
    //Instânciando FWMBrowse - Somente com dicionário de dados
    oBrowse := FWMBrowse():New()
     
    //Setando a tabela de cadastro de Autor/Interprete
    oBrowse:SetAlias("ZA1")
 
    //Setando a descrição da rotina
    oBrowse:SetDescription(cTitulo)
     
    //Legendas
    oBrowse:AddLegend( "ZA1->BM_PROORI == '1'", "GREEN",    "Original" )
    oBrowse:AddLegend( "ZA1->BM_PROORI == '0'", "RED",    "Não Original" )
     
    //Ativa a Browse
    oBrowse:Activate()
     
    RestArea(aArea)
Return Nil
 
/*---------------------------------------------------------------------*
 | Func:  MenuDef                                                      |
 | Autor: Daniel Atilio                                                |
 | Data:  17/08/2015                                                   |
 | Desc:  Criação do menu MVC                                          |
 | Obs.:  /                                                            |
 *---------------------------------------------------------------------*/
 
Static Function MenuDef()
    Local aRot := {}
     
    //Adicionando opções
    ADD OPTION aRot TITLE 'Visualizar' ACTION 'VIEWDEF.protNet' OPERATION MODEL_OPERATION_VIEW   ACCESS 0 //OPERATION 1
    ADD OPTION aRot TITLE 'Legenda'    ACTION 'u_zMVC01Leg'     OPERATION 6                      ACCESS 0 //OPERATION X
    //ADD OPTION aRot TITLE 'Incluir'    ACTION 'VIEWDEF.protNet' OPERATION MODEL_OPERATION_INSERT ACCESS 0 //OPERATION 3
    //ADD OPTION aRot TITLE 'Alterar'    ACTION 'VIEWDEF.protNet' OPERATION MODEL_OPERATION_UPDATE ACCESS 0 //OPERATION 4
    //ADD OPTION aRot TITLE 'Excluir'    ACTION 'VIEWDEF.protNet' OPERATION MODEL_OPERATION_DELETE ACCESS 0 //OPERATION 5
 
Return aRot
 
/*---------------------------------------------------------------------*
 | Func:  ModelDef                                                     |
 | Autor: Daniel Atilio                                                |
 | Data:  17/08/2015                                                   |
 | Desc:  Criação do modelo de dados MVC                               |
 | Obs.:  /                                                            |
 *---------------------------------------------------------------------*/
 
Static Function ModelDef()
    //Criação do objeto do modelo de dados
    Local oModel := Nil
     
    //Criação da estrutura de dados utilizada na interface
    Local oStZA1 := FWFormStruct(1, "ZA1")
     
    //Instanciando o modelo, não é recomendado colocar nome da user function (por causa do u_), respeitando 10 caracteres
    oModel := MPFormModel():New("protNetM",/*bPre*/, /*bPos*/,/*bCommit*/,/*bCancel*/) 
     
    //Atribuindo formulários para o modelo
    oModel:AddFields("FORMZA1",/*cOwner*/,oStZA1)
     
    //Setando a chave primária da rotina
    oModel:SetPrimaryKey({'BM_FILIAL','BM_GRUPO'})
     
    //Adicionando descrição ao modelo
    oModel:SetDescription("Modelo de Dados do Cadastro "+cTitulo)
     
    //Setando a descrição do formulário
    oModel:GetModel("FORMZA1"):SetDescription("Formulário do Cadastro "+cTitulo)
Return oModel
 
/*---------------------------------------------------------------------*
 | Func:  ViewDef                                                      |
 | Autor: Daniel Atilio                                                |
 | Data:  17/08/2015                                                   |
 | Desc:  Criação da visão MVC                                         |
 | Obs.:  /                                                            |
 *---------------------------------------------------------------------*/
 
Static Function ViewDef()
    //Criação do objeto do modelo de dados da Interface do Cadastro de Autor/Interprete
    Local oModel := FWLoadModel("protNet")
     
    //Criação da estrutura de dados utilizada na interface do cadastro de Autor
    Local oStZA1 := FWFormStruct(2, "ZA1")  //pode se usar um terceiro parâmetro para filtrar os campos exibidos { |cCampo| cCampo $ 'ZA1_NOME|ZA1_DTAFAL|'}
     
    //Criando oView como nulo
    Local oView := Nil
 
    //Criando a view que será o retorno da função e setando o modelo da rotina
    oView := FWFormView():New()
    oView:SetModel(oModel)
     
    //Atribuindo formulários para interface
    oView:AddField("VIEW_ZA1", oStZA1, "FORMZA1")
     
    //Criando um container com nome tela com 100%
    oView:CreateHorizontalBox("TELA",100)
     
    //Colocando título do formulário
    oView:EnableTitleView('VIEW_ZA1', 'Dados do Grupo de Produtos' )  
     
    //Força o fechamento da janela na confirmação
    oView:SetCloseOnOk({||.T.})
     
    //O formulário da interface será colocado dentro do container
    oView:SetOwnerView("VIEW_ZA1","TELA")
Return oView
 
/*/{Protheus.doc} zMVC01Leg
Função para mostrar a legenda das rotinas MVC com grupo de produtos
@author Atilio
@since 17/08/2015
@version 1.0
    @example
    u_zMVC01Leg()
/*/
 
User Function TST002()
    Local aLegenda := {}
     
    //Monta as cores
    AADD(aLegenda,{"BR_VERDE",        "Original"  })
    AADD(aLegenda,{"BR_VERMELHO",    "Não Original"})
     
    BrwLegenda("Grupo de Produtos", "Procedencia", aLegenda)
Return
