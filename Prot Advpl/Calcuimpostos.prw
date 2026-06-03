#include "Protheus.ch"
#include "totvs.ch"

User function calcImpostos()

Local cValor := 0
cValor := Val(FWinputbox("Digite o valor: "))
Local nICMS := cValor * 0.08
Local nIPI := cValor * 0.05
Local nTotal := cValor + nICMS + nIPI

MsgInfo("Total com os impostos: " + Cvaltochar(nTotal))



return
