#include "Protheus.ch"
#include "totvs.ch"

User function ListMulti()

    Local aLista := {}
    Local cProdutos := ""
    Local cPreco := ""
    Local cMensagem := "Tem os produtos: " + CRLF
    Local nI := 0

    While .T.
        cProdutos := FWInputBox("Digite o produto (ou 'FIM' para encerrar):")
        
        if upper(cProdutos) == "FIM"
            Exit
        endif
        cPreco := FWInputBox("Digite o preco de " + cProdutos + ":")
        AADD(aLista, {cProdutos, cPreco}) //lista multidimensional

    enddo

    for nI := 1 to len(aLista)
        cMensagem += "-" + aLista[nI][1] + " | R$" + aLista[nI][2] + CRLF
    next nI

    MsgInfo(cMensagem, "Minha lista")
return
