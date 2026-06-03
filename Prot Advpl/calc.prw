#include "Protheus.ch"
#include "totvs.ch"


User function calc()

    Local cNum1 := 0
    Local cNum2 := 0
    Local nResultado := 0
    Local cOperator := ""


    cNum1 := Val(FWInputBox("Digite o primeiro numero"))
    cNum2 := Val(FWInputBox("Digite o segundo numero"))


    cOperator := FWInputBox("Digite a operacao desejada: +, -, *, /")



    IF (cOperator == "+")
        nResultado := cNum1 + cNum2
        Msginfo("O resultado da soma eh: " + Cvaltochar(nResultado))
    ELSEIF (cOperator == "-")
        nResultado := cNum1 - cNum2
        Msginfo("O resultado da subtracao eh: " + Cvaltochar(nResultado))
    ELSEIF (cOperator == "*")
        nResultado := cNum1 * cNum2
        Msginfo("O resultado da multiplicacao eh: " + Cvaltochar(nResultado))
    ELSEIF (cOperator == "/")
        IF (cNum2 != 0)
            nResultado := cNum1 / cNum2
            Msginfo("O resultado da divisao eh: " + Cvaltochar(nResultado))
        ELSE
            MsgAlert("Nao eh possivel dividir por zero.")
        ENDIF
    ENDIF

return
