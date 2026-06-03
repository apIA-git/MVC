#include "Protheus.ch"
#include "totvs.ch"


User function LacoFor()

Local nCont as numeric


For nCont := 1 to 5
    Msginfo("Contador: " + CValtochar(nCont)) //ele emite uma mensagem a cada interação do laço, ou seja, 10 mensagens

    //Alert(CValTochar(nCont))
    
    /*emite um alerta quando cheagr no fim do laço
    voce aperta no OK e ele continua o processo, ou seja,
    ele emite um alerta a cada interação do laço, ou seja, 10 alertas*/

    //identador
    Next nCont

return
