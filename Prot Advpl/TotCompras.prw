#include "Protheus.ch"
#include "totvs.ch"

User function TotCompras()

    Local aLista := {}
    Local cProdutos := ""
    Local cPreco := ""
    Local cMensagem := "Tem os produtos: " + CRLF
    Local nI := 0
    Local nTotal := 0

    While .T.
        cProdutos := FWInputBox("Digite o produto (ou 'FIM' para encerrar):")
        
        if upper(cProdutos) == "FIM"
            Exit
        endif
        cPreco := val(FWInputBox("Digite o preco de " + cProdutos + ":"))
        AADD(aLista, {cProdutos, cPreco})

    enddo
    
    For nI := 1 to len(aLista)
        nTotal += aLista[nI][2]
    next
    
    for nI := 1 to len(aLista)
        cMensagem += "-" + aLista[nI][1] + " | R$" + cValToChar(aLista[nI][2]) + CRLF
    next nI
    cMensagem += "TOTAL: R$ " + AllTrim(Str(nTotal, 10, 2))
    MsgInfo(cMensagem, "Minha lista")
return
