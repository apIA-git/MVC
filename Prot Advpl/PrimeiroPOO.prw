#include "protheus.ch"
#include "totvs.ch"

class Pessoa
    data cNome
    data nIdade
    data dDataNascimento
    //contrutor
    method new(cNome, dDataNascimento) Constructor
    //metodo
    method MostraIdade()
endclass


method MostraIdade() Class Pessoa
    Local cMsg := ""
    cMsg := "A Pessoa " + ::cNome + " tem " + cValToChar(::nIdade) + " anos."
    MsgInfo(cMsg, "Idade da Pessoa")

return

// Programa Construtor
method new(cNome, dDataNascimento) Class Pessoa
    ::cNome := cNome
    ::nIdade := CalcIdade(dDataNascimento)
    ::dDataNascimento := dDataNascimento

return Self

static function CalcIdade(dDataNascimento)
    Local nIdade := 0
    Local dDataAtual := Date()
    nIdade := DateDiffYear(dDataAtual, dDataNascimento)
           
    // Implementação da função CalcIdade

return nIdade
