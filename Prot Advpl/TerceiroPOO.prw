#include "Protheus.ch"
#include "totvs.ch"

Class Banco
    data cNome
    data cCPF
    data cContaBancaria
    data nSaldo

    method new(cNome, cCPF, cContaBancaria, nSaldo) Constructor
    method MostraInfo()
    method Sacar()
endclass

//construtor
method new(cNome, cCPF, cContaBancaria, nSaldo) Class Banco
    ::cNome := cNome
    ::cCPF := cCPF
    ::cContaBancaria := cContaBancaria
    ::nSaldo := nSaldo
return Self

method MostraInfo() Class Banco
    Local cMsg := ""
    cMsg := "O cliente " + ::cNome + " com CPF " + ::cCPF + " tem a conta bancaria " + ::cContaBancaria + " e saldo de " + CValToChar(::nSaldo) + "."
    MsgInfo(cMsg, "Informacoes do Cliente")
return

method Sacar() Class Banco
    // Implementacao da funcao Sacar
    Local valorSaque
    valorSaque := Val(FWInputBox("Digite o valor do saque:", "Saque"))
    MsgInfo("Valor do saque: " + CValToChar(valorSaque), "Saque")
    if(::nSaldo < valorSaque)
        MsgInfo("Saldo insuficiente para realizar o saque.", "Erro")
    else
        ::nSaldo := ::nSaldo - valorSaque
        MsgInfo("Saque realizado com sucesso. Novo saldo: " + CValToChar(::nSaldo), "Saque")
    endif
return
