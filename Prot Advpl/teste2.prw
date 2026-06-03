#include "Protheus.ch"
#include "totvs.ch"

User function teste2()

Local nNum1 := 10
Local nNum2 := 20

IF .NOT. (nNum1 > 5 .AND. nNum2 >12)
    Msginfo("Pelo menos um dos numeros não respeita suas condições")
    
ELSE
    Msginfo("Ambos os numeros respeitam suas condições")
ENDIF
return
/*Isso resultaria em verdade 10 > 5 e 20> 12 porem com o not n frente resultaria em falso
printadno na tela "Ambos os numeros respeitam suas condições" */
