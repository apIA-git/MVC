#include "Protheus.ch"
#include "totvs.ch"

User function extrato()
    Local oBanco
    local cNome := FWInputbox("Digite o nome do cliente: ")
    Local cCPF:= FWInputbox("Digite o CPF do cliente: ")
    Local cContaBancaria:= FWInputbox("Digite o numero da conta bancaria: ")

    oBanco := Banco():new(cNome, cCPF, cContaBancaria, 1000.00)
    oBanco:Sacar()
    oBanco:MostraInfo()
    

return
