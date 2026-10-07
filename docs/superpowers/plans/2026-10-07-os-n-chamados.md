# OS ligada a vários chamados — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Uma OS passa a ter N chamados do mesmo cliente (ZA3), com o que foi feito **separado por chamado** e uma tela "Chamados" por OS.

**Architecture:** Protheus (CNSA002) grava/valida/lê a ZA3 nos núcleos REST e ganha `GET /CNSAOSCHAMADOS`; `Z1_IDCH` = chamado principal. Portal troca o campo "Chamado" por múltipla escolha e mostra **um bloco por chamado**, cada um com o componente de interação que já existe (`app-interacao-historico` com o `idCh` daquele chamado + `os`), mais um atalho "Aplicar a todos".

**Tech Stack:** TLPP (Protheus 12.1.2510, Oracle), Angular + PO-UI.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-10-07-os-n-chamados-design.md` (revisão de 07/10: interação separada por chamado, bloqueio de remoção, horas só no total).
- ZA3: `ZA3_FILIAL`, `ZA3_OS`, `ZA3_IDCH`; índice 1 `ZA3_FILIAL+ZA3_OS+ZA3_IDCH`.
- Só chamados do mesmo cliente/loja da OS. `Z1_IDCH` = primeiro da lista. Chamados da OS = ZA3 ∪ `Z1_IDCH`.
- Remover chamado com interação desta OS (`ZA2_IDCH` + `ZA2_OS`) = bloqueado.
- Horas: só o total da OS. Vários chamados só no portal.
- ADVPL em CP1252 + CRLF, sem acento em código; compilação pelo usuário; testes manuais.

---

### Task 1: Protheus — ZA3 no CNSA002

**Files:** Modify `Fontes MVC e Site/CNSA002.TLPP`: `OS_NUCLEOINCLUIR` (~984), `OS_NUCLEOALTERAR` (~1175), `OS_APIEXCLUIR` (~2085), `OS_NUCLEOCOPIAR` (~557), `OS_APILISTAR` (~1893), `OS_APILISTAINTERACOES` (~2451); bloco novo no final.

**Interfaces (produz):**
- `POST /CNSAOSINCLUIR` e `/CNSAOSALTERAR` aceitam `chamados` (CSV). `chamado` (um só) continua aceito.
- `GET /CNSAOS` → item com `chamados: string[]`, `qtdChamados: number`.
- `GET /CNSAOSCHAMADOS?os=` → `{os, items:[{idCh, assunto, status}]}`.
- `GET /CNSAOSINTERACOES` → item com `assunto`.

- [ ] **Step 1: Bloco "OS x CHAMADOS (ZA3)" no final do CNSA002**

```
// Chamados da OS: ZA3 + Z1_IDCH (OS antigas, antes da ZA3), sem repetir.
Static Function OS_CHAMADOS(cOs, cIdCh)
    Local aCh    := {}
    Local cAlias := GetNextAlias()

    BeginSql Alias cAlias
        SELECT ZA3_IDCH FROM %Table:ZA3% ZA3
        WHERE ZA3_FILIAL = %xFilial:ZA3% AND ZA3_OS = %Exp:cOs% AND %NotDel%
        ORDER BY ZA3_IDCH
    EndSql
    While !(cAlias)->(Eof())
        AAdd(aCh, AllTrim((cAlias)->ZA3_IDCH))
        (cAlias)->(DbSkip())
    EndDo
    (cAlias)->(DbCloseArea())

    cIdCh := AllTrim(cIdCh)
    If !Empty(cIdCh) .And. AScan(aCh, cIdCh) == 0
        AAdd(aCh, Nil)
        AIns(aCh, 1)
        aCh[1] := cIdCh
    EndIf
Return aCh

// Parametro "chamados" (CSV) ou "chamado" (um so) -> {lVeio, aCodigos}
Static Function OS_CHAMADOSPARAM(jQuery)
    Local lVeio := jQuery["chamados"] != Nil .Or. jQuery["chamado"] != Nil
    Local cCsv  := If(jQuery["chamados"] != Nil, OS_LERJSONTXT(jQuery, "chamados"), OS_LERJSONTXT(jQuery, "chamado"))
    Local aCh   := {}
    Local aLista := StrTokArr2(AllTrim(cCsv), ",", .F.)
    Local nI    := 0

    For nI := 1 To Len(aLista)
        If !Empty(AllTrim(aLista[nI])) .And. AScan(aCh, AllTrim(aLista[nI])) == 0
            AAdd(aCh, AllTrim(aLista[nI]))
        EndIf
    Next nI
Return {lVeio, aCh}

// "" se ok; senao a mensagem. Mesmo cliente/loja + nao remover chamado com interacao desta OS.
Static Function OS_VALIDACHAMADOS(cOs, aCh, cCli, cLoja)
    Local aAntes := If(Empty(cOs), {}, OS_CHAMADOS(cOs, ""))
    Local cAlias := ""
    Local nI     := 0

    For nI := 1 To Len(aCh)
        ZA1->(DbSetOrder(1))
        If !ZA1->(DbSeek(xFilial("ZA1") + aCh[nI]))
            Return "Chamado #" + aCh[nI] + " nao encontrado."
        EndIf
        If AllTrim(ZA1->ZA1_CLIENT) != AllTrim(cCli) .Or. AllTrim(ZA1->ZA1_LOJA) != AllTrim(cLoja)
            Return "Chamado #" + aCh[nI] + " nao e do cliente da OS."
        EndIf
    Next nI

    For nI := 1 To Len(aAntes)
        If AScan(aCh, aAntes[nI]) == 0
            cAlias := GetNextAlias()
            BeginSql Alias cAlias
                SELECT COUNT(*) QTD FROM %Table:ZA2% ZA2
                WHERE ZA2_FILIAL = %xFilial:ZA2% AND ZA2_IDCH = %Exp:aAntes[nI]% AND ZA2_OS = %Exp:cOs% AND %NotDel%
            EndSql
            If (cAlias)->QTD > 0
                (cAlias)->(DbCloseArea())
                Return "Chamado #" + aAntes[nI] + " ja tem interacao desta OS - nao pode ser removido."
            EndIf
            (cAlias)->(DbCloseArea())
        EndIf
    Next nI
Return ""

// Grava a lista da OS na ZA3 (apaga a anterior). Lista vazia = so apaga.
Static Function OS_GRAVACHAMADOS(cOs, aCh)
    Local nI := 0

    ZA3->(DbSetOrder(1))
    While ZA3->(DbSeek(xFilial("ZA3") + PadR(cOs, TamSX3("ZA3_OS")[1])))
        RecLock("ZA3", .F.)
            ZA3->(DbDelete())
        ZA3->(MsUnlock())
    EndDo
    For nI := 1 To Len(aCh)
        RecLock("ZA3", .T.)
            ZA3->ZA3_FILIAL := xFilial("ZA3")
            ZA3->ZA3_OS     := cOs
            ZA3->ZA3_IDCH   := aCh[nI]
        ZA3->(MsUnlock())
    Next nI
Return

@Get(endpoint="/CNSAOSCHAMADOS")
User Function OS_APICHAMADOS() As Logical
    Local jQuery := oRest:getQueryRequest() As Json
    Local cOs    := AllTrim(OS_LERJSONTXT(jQuery, "os"))
    Local oJson  := JsonObject():New()
    Local aItens := {}
    Local aCh    := {}
    Local oLinha := Nil
    Local nI     := 0

    oRest:setKeyHeaderResponse("Content-Type", "application/json")
    SZ1->(DbSetOrder(1))
    If Empty(cOs) .Or. !SZ1->(DbSeek(cFilAnt + cOs))
        Return oRest:setStatusResponse(404, '{"erro":"OS nao encontrada."}')
    EndIf
    aCh := OS_CHAMADOS(cOs, SZ1->Z1_IDCH)
    ZA1->(DbSetOrder(1))
    For nI := 1 To Len(aCh)
        oLinha := JsonObject():New()
        oLinha["idCh"] := aCh[nI]
        oLinha["assunto"] := ""
        oLinha["status"]  := ""
        If ZA1->(DbSeek(xFilial("ZA1") + aCh[nI]))
            oLinha["assunto"] := OS_DECODESAFE(AllTrim(ZA1->ZA1_ASSUNT))
            oLinha["status"]  := AllTrim(ZA1->ZA1_STATUS)
        EndIf
        AAdd(aItens, oLinha)
    Next nI
    oJson["os"]    := cOs
    oJson["items"] := aItens
Return oRest:setStatusResponse(200, oJson:ToJson())
```

- [ ] **Step 2: Incluir** (`OS_NUCLEOINCLUIR`): declarar `Local aParCh := OS_CHAMADOSPARAM(jQuery)` e `Local cMsgCh := ""`. Antes de ativar o modelo: `cMsgCh := OS_VALIDACHAMADOS("", aParCh[2], OS_LERJSONTXT(jQuery,"codCliente"), If(Empty(OS_LERJSONTXT(jQuery,"lojaCliente")), "01", OS_LERJSONTXT(jQuery,"lojaCliente")))`; se não vazio, `Return {.F., cMsgCh, ""}`. Trocar o bloco do `Z1_IDCH` por `If Len(aParCh[2]) > 0 ; oModelSZ1:LoadValue("Z1_IDCH", aParCh[2][1]) ; EndIf`. Depois do commit OK (antes do `ConfirmSX8()`): `OS_GRAVACHAMADOS(cOs, aParCh[2])`.

- [ ] **Step 3: Alterar** (`OS_NUCLEOALTERAR`): mesmos Locals. Depois do `DbSeek` da OS: se `aParCh[1]`, validar com `OS_VALIDACHAMADOS(cOs, aParCh[2], cliente da query ou SZ1->Z1_CLI, loja da query ou SZ1->Z1_LOJA)` e retornar erro. Trocar o bloco do `Z1_IDCH` por: se `aParCh[1]`, `oModelSZ1:LoadValue("Z1_IDCH", If(Len(aParCh[2]) > 0, aParCh[2][1], ""))`. Depois do commit OK: se `aParCh[1]`, `OS_GRAVACHAMADOS(cOs, aParCh[2])`.

- [ ] **Step 4: Excluir/Copiar**: em `OS_APIEXCLUIR`, depois do commit OK: `OS_GRAVACHAMADOS(cOs, {})`. Em `OS_NUCLEOCOPIAR`, junto dos "campos diferentes na cópia": `oModelSZ1:LoadValue("Z1_IDCH", "")`.

- [ ] **Step 5: Listar/Interações**: em `OS_APILISTAR`, depois de `oLinha['chamado']`: `aChOs := OS_CHAMADOS(cOsAtual, (cAlias)->Z1_IDCH)`, `oLinha['chamados'] := aChOs`, `oLinha['qtdChamados'] := Len(aChOs)` (Local `aChOs`). Em `OS_APILISTAINTERACOES`, no item da ZA2: `oLinha['assunto'] := OS_DECODESAFE(AllTrim(Posicione("ZA1", 1, xFilial("ZA1") + AllTrim((cAlias)->ZA2_IDCH), "ZA1_ASSUNT")))`.

- [ ] **Step 6: Conferir** encoding/CRLF; usuário compila e testa pelo portal (Tasks 2-3).
- [ ] **Step 7: Commit** `feat: OS com varios chamados (ZA3) no CNSA002`.

### Task 2: Portal — modelo, serviço e formulário

**Files:** `apia-po-cnshub/src/app/cns003/os.model.ts`, `os-serv.ts`, `cns003.ts`, `cns003.html`.

- [ ] **Step 1 — os.model.ts:** em `Os`: `chamados: string[]; qtdChamados: number;`. Em `NovaOs`/`AlterarOs`: `chamados?: string[];`. Novo:
```ts
export interface OsChamado { idCh: string; assunto: string; status: string; }
export interface OsChamadosResposta { os: string; items: OsChamado[]; }
```
- [ ] **Step 2 — os-serv.ts:** tirar `'chamado'` de `CAMPOS_OPCIONAIS`; em incluir: `if (nova.chamados?.length) url += '&chamados=' + encodeURIComponent(nova.chamados.join(','))`; em alterar: **sempre** `url += '&chamados=' + encodeURIComponent((alterada.chamados ?? []).join(','))`. Novo `listarChamados(os: string): Observable<OsChamadosResposta>` → `GET ${environment.protheusBaseUrl}/rest/CNSAOSCHAMADOS?os=`.
- [ ] **Step 3 — cns003.ts (campo):** em `camposClienteDependente()`, `property: 'chamado'` → `property: 'chamados'`, `label: 'Chamados'`, `optionsMulti: true` (po-lookup múltiplo), `disabled: !this.valorFormulario['cliente']`; cache do getter também pelo cliente. Troca de cliente (`aoSelecionarCliente`) zera `chamados: []`. Regra "tem chamado" (`temChamado`, Descrição visível, `[idCh]` do histórico) passa a usar `(this.valorFormulario['chamados'] ?? []).length > 0`. Editar: `chamados: resource.chamados ?? []`. Prefil `?chamado=` → `chamados: [chamado]`. Salvar: `chamados: this.valorFormulario['chamados'] ?? []`.
- [ ] **Step 4:** `npx ng build` ok → commit `feat: OS com varios chamados no formulario`.

### Task 3: Portal — interação separada por chamado e tela "Chamados"

**Files:** `cns003.ts`, `cns003.html`.

- [ ] **Step 1 — formulário:** no lugar do único `<app-interacao-historico #historicoInteracao [idCh]=...>`:
  - OS **sem** chamado: mantém o componente atual (descrição única).
  - OS **com** chamados: atalho `po-switch` "Aplicar a todos os chamados" + editor; e um bloco por chamado:
```html
@for (ch of chamadosForm(); track ch) {
  <po-divider [p-label]="'Chamado #' + ch + ' - ' + (assuntoChamado(ch))"></po-divider>
  <app-interacao-historico [idCh]="ch" [os]="osFormulario"></app-interacao-historico>
}
```
  - "Aplicar a todos": botão grava o texto do editor em cada chamado via `InteracaoServ.incluirInteracao(ch, texto, false, os)` e recarrega os blocos.
- [ ] **Step 2 — lista:** coluna `{ property: 'qtdChamados', label: 'Chamados' }`; ação `{ label: 'Chamados', icon: 'an an-list-bullets', action: (item: Os) => this.abrirChamados(item) }`.
- [ ] **Step 3 — modal "Chamados":** `abrirChamados(os)` chama `listarChamados` e abre modal com o título `OS <n> - <qtd> chamado(s)` e um bloco por chamado (`#idCh`, assunto, badge de status) com `<app-interacao-historico [idCh]="ch.idCh" [os]="os" [somenteLeitura]="false">`.
- [ ] **Step 4:** build ok → commit `feat: interacao separada por chamado e tela Chamados da OS`.

### Task 4: Publicar

- [ ] Usuário compila `CNSA002.TLPP` e testa (spec, Testes 1-6).
- [ ] MVC: branch do dia → PR → merge. apia-protheus: `CNSA002.TLPP` via API (LF) → PR. Portal: branch → PR → merge → `deploy.ps1`.
