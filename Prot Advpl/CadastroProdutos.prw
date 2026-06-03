#include "protheus.ch"
#include "totvs.ch"

Class Produtos
    data cNome
    data nPreco
    data nLocalizacao

    method new(cNome, nPreco, nLocalizacao) Constructor
    method AdicionarProduto()
    method RemoverProduto()
    method BuscarProduto()
    method MostraInfo()
endclass
