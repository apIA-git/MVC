#include "Protheus.ch"
#include "totvs.ch"

User function Carro()
    Local oCarro
    Local cModelo := "Porsche"
    Local nAno := 2020
    oCarro := automoveis():new(cModelo, nAno)
    oCarro:MostraInfo()
return
