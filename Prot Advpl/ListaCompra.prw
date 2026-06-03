#include "Protheus.ch"
#include "totvs.ch"

User function ListaCompra()

    Local aLista := {}
    Local cProdutos := ""
    Local cMensagem := "Tem os produtos: " + CRLF
    Local nI := 0

    While .T.
        cProdutos := FWInputBox("Digite o produto (ou 'FIM' para encerrar):")
        if upper(cProdutos) == "FIM"
            Exit
        endif
        AADD(aLista, cProdutos)
    enddo

    for nI := 1 to len(aLista)
        cMensagem += "-" + aLista[nI] + CRLF
    next nI

    MsgInfo(cMensagem, "Minha lista")
return
