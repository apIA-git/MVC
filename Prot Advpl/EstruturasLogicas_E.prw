#include "Protheus.ch"
#include "totvs.ch"

/*
:= .T true
:= .F false
.AND. siginifica que ambos estao de acordo com suas condições
.OR. significa que um ou outro esta de acordo com suas condições(qualquer um dos dois serve)
ex: nNum1 > 5 AND nNum2 > 12*/

User function funcaologica1()
Local nNum1 := 10
Local nNum2 := 20

IF (nNum1 > 5 .AND. nNum2 > 12)
    Msginfo("Ambos respeitam suas condições")
    
ELSEIF (nNum1 > 5 .AND. nNum2 < 12)
    Msginfo("Apenas o numero 1 respeita sua condição")

ELSEIF (nNum1 < 5 .AND. nNum2 > 12)
    Msginfo("Apenas o numero 2 respeita sua condição")

ELSE 
    Msginfo("Nenhum dos numeros respeitam suas condições")
ENDIF

return

