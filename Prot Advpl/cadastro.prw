#include "protheus.ch"
#include "totvs.ch"

User function Cadastro()
    Local oPessoa
    Local cNome := "Joao"
    Local dDataNascimento := CTOD("01/01/1990")
    oPessoa := Pessoa():new(cNome, dDataNascimento)
    oPessoa:MostraIdade()
    
return
