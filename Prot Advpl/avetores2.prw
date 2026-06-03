#include "Protheus.ch"
#include "totvs.ch"

User function AVE()

    Local aValores2 := {10,20,30,40}
    Local nCount := 0
/**
    AADD: Insercao de valores no vetor ja existente
    AINS: insercao de valores em qualquer posicao do vetor
    ACLONE: copia do vetor
    ADEL: permite a exclusao de um elemento do vetor, tornando o ultimo valor nulo
    ASIZE: redefine a estrutura do veor pre existente, add ou del elementos
    LEN: retorna quantidade de elementos do vetor
**/
    //aAdd(aValores2,50) ;;adiciona o valor 50 no vetor
    Alert(LEN(aValores2)) //informa a qntd de elementos do vetor apos att

    AINS(aValores2,2) //insere um valor nulo da posicao 2,independente do valor que estiver la
    aValores2[2] := 200 //subscreve esse nulo pelo valor 200
    Alert(aValores2[2])

    aVetor2 := ACLONE(aValores2)  //clona o vetor aValores2 no aVetor2
        for nCount := 1 to len(aVetor2)
            Alert(aVetor2[nCount])
        next nCount


    ADEL(aValores2, 2) //nao muda o tamanho do vetor, ele apenas apaga e coloca  um valor nulo
    Alert(aValores2, 3)

    ASIZE(aValores2, 2)
    Alert(len(aValores2))
    MsgInfo("Vetor aValores2: " + aValores2, "Vetor aValores2")

return


