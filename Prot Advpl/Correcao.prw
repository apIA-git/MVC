#include "Protheus.ch"
#include "totvs.ch"

User function Correcao()

    Local cPalavra := FWInputbox("Digite sua palavra: ")
    //cPalavra := UPPER(cPalavra) tudo maiusculo
    //cPalavra := AllTrim(cPalavra) retira os espaços

    Local cLetra := ""
    Local cNova := ""
    Local nTam := len(cPalavra)
    Local nI := 0

    if (nTam < 100)
        for nI := 1 to nTam
            cLetra = SubStr(cPalavra, nI, 1)
            if(nI % 2 == 0)
                cNova += lower(cLetra)
            else
                cNova += cLetra
            endif
        next nI
        
        cPalavra := cNova
    endif

    MsgAlert(cPalavra)

return 
