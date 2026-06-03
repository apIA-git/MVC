#include "protheus.ch"
#include "totvs.ch"

User function IMC()

    Local nPeso   := Val(FWInputbox("PESO: (Em KG)"))
    Local nAltura := Val(FWInputbox("ALTURA: (Em Metros)"))
    Local nIndice := 0

    if (nPeso > 0 .AND. nAltura > 0)
        nIndice       := nPeso / (nAltura * nAltura)
        MsgInfo("Seu IMC eh: " + CValToChar(nIndice), "Resultado do IMC")
    else
        MsgAlert("Digite Valores Reais", "ATENCAO")
    endif

return
