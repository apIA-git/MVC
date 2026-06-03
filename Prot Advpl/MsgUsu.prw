#include "Protheus.ch"
#include "totvs.ch"

User function MsgUsu()
    Local nNotas := Val(FWInputbox("Digite sua nota"))
    Local lRec := .F.

    if(nNotas > 7)
        MsgAlert("PARABENS APROVACAO DIRETA", "PARABENS")
    elseif(lRec := MsgYesNo("Voce quer ver se ficou de PF ou nao?"))
        if(lRec)
            if(nNotas < 3)
                MsgAlert("Reprovacao direta")
            elseif(nNotas < 7)
                MsgAlert("Passilvel de PF", "Dia 15")
                
            endif
        else 
            MsgAlert("PARABENS", "APROVADO")
        endif
    endif
return
