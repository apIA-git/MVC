#include "Protheus.ch"
#include "totvs.ch"


User function Lacowhile()

Local nNum1 := 0

WHILE nNum1 <= 10
    nNum1       := nNum1 + 1 //nNum++
    Alert(CValTochar(nNum1)) //ele emite um alerta a cada interação do laço, ou seja, 10 alertas
ENDDO
//Msginfo("O Laço while terminou "+ Transform(nNum1))

return
