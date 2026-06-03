#include "Protheus.ch"
#include "totvs.ch"

Class automoveis
    data cModelo
    data nAno
    method new(cModelo, nAno) Constructor
    method MostraInfo()
endclass

//construtor
method new(cModelo, nAno) Class automoveis
    ::cModelo := cModelo
    ::nAno := nAno
return Self


Method MostraInfo()Class automoveis
    Local CMsg := ""
    cMsg := "O carro " + ::cModelo + " do ano " + cValToChar(::nAno) + "."
    MsgInfo(cMsg, "Informações do Carro")
    
Return 
