#include "Protheus.ch"
#include "totvs.ch"

User function DiasAniv()

    Local cData := FWInputBox("Digite seu aniversario")
    Local dNasc := CTOD(cData) //char to date
    Local nDias := 0

    nDias := Date() - dNasc
    MsgInfo("Voce ja viveu aproximadamente " + AllTrim(Str(nDias)) + " dias!", "Caramba!")  
return                                        //removedor de espaços
