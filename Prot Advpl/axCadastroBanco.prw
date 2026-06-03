#include "protheus.ch"
#include "totvs.ch"

User Function axcadastroBanco()
    Local cAlias  := "ZA1"
    Local cTitulo := "Manutencao de Segmentos"
    
    // Variaveis OBRIGATORIAS que o AxCadastro le por tras dos panos
    Private cCadastro := cTitulo
    Private aRotina   := { ;
        {"Pesquisar" , "AxPesqui", 0, 1}, ;
        {"Visualizar", "AxVisual", 0, 2}, ;
        {"Incluir"   , "AxInclui", 0, 3}, ;
        {"Alterar"   , "AxAltera", 0, 4}, ;
        {"Excluir"   , "AxDeleta", 0, 5}  ;
    }

    // Inicializa o ambiente apenas se estiver testando por fora do menu
    If Select("SX2") == 0
        RpcSetEnv("01", "01")
    EndIf

    // Deixamos o AxCadastro fazer TODO o trabalho (abrir tabela, posicionar e desenhar a tela)
    AxCadastro(cAlias, cTitulo, ".T.", ".T.")

Return
