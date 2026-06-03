#include "Protheus.ch"
#include "totvs.ch"


User function Pense()

    Local nMeuNum := Val(FWInputBox("Digite o numero pro pc acertar"))
    Local nNumPc := 0
    Local nTentivasPC := 0
    Local nMin := 1
    Local nMax := 100
    Local lAcerto := .F.

    do while(nTentivasPC < 10)

        nTentivasPC ++
        If nMin <= nMax
            nNumPc := Random(nMin, nMax)
        Else
            // Se o min superou o max, houve erro na lógica ou nos limites
            nNumPc := nMin 
        Endif

        
        if (nNumPc == nMeuNum)
            MsgAlert("O PC acertou o numero " + cValToChar(nNumPc) + " na tentativa " + cValToChar(nTentivasPC), "ACERTOU")
            lAcerto := .T.
            exit
        elseif(nNumPc < nMeuNum)
            MsgInfo("PC chutou " + cValToChar(nNumPc) + ". O real e MAIOR.")
            nMin := nNumPc + 1
        elseif (nNumPc > nMeuNum)
            MsgInfo("PC chutou " + cValToChar(nNumPc) + ". O real e MENOR.")
            nMax := nNumPc - 1
        endif
    enddo

    if(!lAcerto)
        MsgAlert("O COMPUTADOR NAO DESCOBRIU SEU NUMERO", "SUCESSO")
    endif




return
