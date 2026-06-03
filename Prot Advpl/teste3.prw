#include "Protheus.ch"
#include "totvs.ch"

User function teste3()

Local nNum1 := 10
Local nNum2 := 20

IF (nNum1 > 5 .OR. nNum2 > 12)
    Msginfo("Pelo menos um dos numeros respeita suas condições")
    
ELSE 
    Msginfo("Nenhum dos numeros respeitam suas condições")
ENDIF
return
