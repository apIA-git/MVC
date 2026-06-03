#include "Protheus.ch"
#include "totvs.ch"


User function ADV2()

    Local nNum := 0
    Local nSecreto := random(1,100)
    //Local nSecreto := 50
    Local nTentativa := 0
    Local lAcertou := .F.
    WHILE(nNum != nSecreto)
        nTentativa++
        nNum := Val(FWInputBox("Digite sua tentativa[1 - 100]: "))
        IF (nNum == nSecreto)
            MsgInfo("VOCE ACERTOU!! <b>")  //<b> coloca em negrito
            lAcertou := .T.
        ELSEIF (nNum < nSecreto)
            MsgInfo("OLHA.. ACHO QUE O NUMERO EH MAIOR QUE ESSE HEIN: "+ cValtochar(nNum))
        ELSEIF (nNum > nSecreto)
            MsgInfo("CARAMBA.. O NUMERO EH MENOR QUE ESSE DIGITADO: " + cValtochar(nNum))
        ELSE
            exit
        ENDIF
    ENDDO
return
