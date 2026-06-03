#include "Protheus.ch"
#Include "totvs.ch"


User function ValidSenhas()

    Local cSen := FWInputBox("Digite sua senha")
    Local nTam := len(cSen)
    Local lTemNum := .F.
    Local nI := 0
    Local lMaiuscula := .F.

    if(nTam < 8)
        MsgAlert("Senha muito curta", "ATENCAO")
    endif
    
    for nI := 1 to nTam
        if (isDigit(SubStr(cSen, nI, 1)))
            lTemNum := .T.
        endif
        if IsUpper(SubStr(cSen, nI, 1))
            lMaiuscula := .T.
        endif
        If lTemNum .AND. lMaiuscula
            Exit
        Endif
    next 

    If (lTemNum .AND. lMaiuscula)
        MsgInfo("Senha cadastrada com sucesso!", "OK")
    Else
        MsgAlert("A senha precisa ter pelo menos um numero e uma letra maiuscula !", "SENHA FRACA")
    Endif

return
