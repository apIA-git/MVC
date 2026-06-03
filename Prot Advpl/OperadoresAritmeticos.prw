#include "Protheus.ch"
#include "totvs.ch"


//Operadores Aritméticos : + - * /
User function operadoresAritmeticos()

Local nNum1 := 10
Local nnum2 := 20    //variaveis locais Local nNome da variavel


Local nSub := nNum1 - nNum2
Local nAdd := nNum1 + nNum2
Local nDiv := nNum1 / nNum2
Local nMul := nNum1 * nNum2

Msginfo("Subtração: " + CValtochar(nSub) + ", Adição: " + CValtochar(nAdd) + ", Divisão: " + CValtochar(nDiv) + ", Multiplicação: " + CValtochar(nMul))
//converter o resultado para string usando a função Transform()
//usar um dos dois métodos para converter o resultado para string: Transform() ou CValtochar()
/*
Msginfo(CValtochar(nSub), "SUBTRAÇÃO = 10-20") //converter o resultado para string usando a função CValtochar()
Msginfo(CValtochar(nAdd), "ADIÇÃO = 10+20") //converter o resultado para string usando a função CValtochar()
Msginfo(CValtochar(nDiv), "DIVISÃO = 10/20") //converter o resultado para string usando a função CValtochar()
Msginfo(CValtochar(nMul), "MULTIPLICAÇÃO = 10*20") //converter o resultado para string usando a função CValtochar()
*/

return

