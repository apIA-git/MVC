#include "Protheus.ch"
#include "totvs.ch"


User function Edecisao()
/*Outra forma de criar variaves
    nNum1 as numeric
    nNum2 as numeric
    nNum2 := 10
    nNum2 := 20  
    Tanto faz os dois, ambos dao a mesma coisa*/


Local nNum1 := 10
Local nNum2 := 20

IF (nNum2 > nNum1)
    Msginfo("O numero 2: " + CValtochar(nNum2) + " é maior que o numero 1: " + CValtochar(nNum1))
ELSEIF (nNum1 > nNum2)
    Msginfo("O numero 1: " + CValtochar(nNum1) + " é maior que o numero 2: " + CValtochar(nNum2))
ELSE
    Msginfo("O numero 1: " + CValtochar(nNum1) + " é igual ao numero 2: " + CValtochar(nNum2))
ENDIF

return
