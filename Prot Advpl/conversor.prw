#include "Protheus.ch"
#Include "totvs.ch"

User function conversor()
    //StrTran ele subsititui quando voce coloca uma virgula por um ponto
    Local nReal := Val(StrTran(FWInputbox("Digite o valor em real a ser convertido: "), ",", "."))
    Local nResultado := 0
    Local cOperador := UPPER(FWInputBox("Digite uma opcao (D = dolar, E = euro, L = libra)"))
    Local cMoeda := ""

    if( cOperador == "D")
        nResultado := nReal / 4.9
        cMoeda := "Dolares"
    elseif(cOperador == "L")
        nResultado := nReal / 6.62
        cMoeda := "Libras"
    elseif(cOperador == "E")
        nResultado := nReal / 5.75
        cMoeda := "Euros"
    else   
        MsgAlert("Digite uma opcao existente", "ATENCAO")
    endif

    MsgInfo("O Valor convertido ficou em: " + AllTrim(Str(nResultado, 10, 2)) + " " + cMoeda, "conversao" )
    //o str ele limita a usar 2 casas decimais e 10 casas antes do ponto
    //AllTrim é o removedor de espaços em branco

return
