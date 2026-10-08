# Informar cliente / técnico em Chamado e OS - Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Em Chamado e OS (portal + tela clássica), quem grava escolhe avisar cliente e/ou técnico por e-mail; tudo abre marcado.

**Architecture:** Portal manda `notificarCliente`/`notificarTecnico` (1/0) na query; Protheus decide e envia com o layout atual (`CH_HTMLEMAIL`/`CH_ENVIAREMAIL`). Tela clássica usa a janela `CH_PERGUNTAEMAIL`. OS ganha `OS_EMAIL` (Do Case) no CNSA002.

**Tech Stack:** TLPP (CNSA001/CNSA002, CP1252+CRLF, editados por script Python), Angular 19 + PO-UI.

## Global Constraints

- Padrão: as duas opções marcadas (Sim), em todas as telas (inclusive Alterar/Assumir/Excluir/Interação já existentes).
- Falha de e-mail nunca desfaz gravação (só ConOut).
- Técnico não recebe aviso da própria interação.
- OS Interna não manda ao cliente.
- Cliente da OS: ZA1_EMAIL dos chamados da OS (sem repetir); OS sem chamado -> A1_EMAIL. Envio ao cliente grava Z1_OSENVCL="S", Z1_ENVDT, Z1_ENVHR.
- Não mexer em cns009/CNSA003 (Luiz).
- Teste = manual pelo usuário após compilar (não há testes automatizados no projeto); portal valida com `ng build`.

---

### Task 1: CNSA001 - chamado (REST + clássico)

**Files:** Modify `Fontes MVC e Site/CNSA001.TLPP`

**Produces:** `apia.cnsa001.U_CH_PERGUNTAPUB(cTitulo, lOfereceCli, lOfereceTec) -> {lCli, lTec}`; REST aceita `notificarCliente` em CNSACHAMADOSINCLUIR e `notificarTecnico` em CNSACHAMADOSINTERACOESINCLUIR/EXCLUIR.

- [ ] `CH_PERGUNTAEMAIL`: `Private lChkCli := .T.` (doc: padrão os dois marcados).
- [ ] `CH_INCLUIRTELA` (pós FWExecView): janela oferece cliente (ZA1_EMAIL) e técnico (ZA1_CONSUL); cliente -> `CH_NOTIFICARCHAMADOCRIADO(ZA1_EMAIL, idCh)`; técnico -> `CH_NOTIFICARDESIGNA` (como hoje).
- [ ] `CH_APIINCLUIR`: se 200 e `notificarCliente == "1"` -> `CH_NOTIFICARCHAMADOCRIADO(ZA1_EMAIL do chamado, idCh)`.
- [ ] `CH_INCLUIRINTERACAO(..., lNotificarTecnico)`: e-mail ao técnico do chamado (AA1_EMAIL de ZA1_CONSUL) quando ele não é quem interagiu; `CH_APINOVAINTERACAO` lê `notificarTecnico == "1"`.
- [ ] `CH_NUCLEOEXCLUIRINTERACAO(..., lNotificarTecnico)`: idem com "removida"; `CH_APIEXCLUIRINTERACAO` lê o parâmetro; tela clássica de excluir interação oferece os dois.
- [ ] `CNSA_INTERAGIR` (clássico): janela oferece cliente e técnico (técnico só se não for o próprio).
- [ ] `User Function CH_PERGUNTAPUB` no bloco final (junto de CH_HTMLPUB/CH_MAILPUB).
- [ ] Commit.

### Task 2: CNSA002 - OS (REST + clássico)

**Files:** Modify `Fontes MVC e Site/CNSA002.TLPP`

**Consumes:** `apia.cnsa001.U_CH_PERGUNTAPUB`, `apia.cnsa001.U_CH_HTMLPUB`, `apia.cnsa001.U_CH_MAILPUB`, `U_CNSOUTL("TEXTO", c)` (cnslib, entidades HTML).

- [ ] `Static Function OS_EMAIL(cAcao, x1, x2, x3)` no fim do fonte - Cases:
  - `ENVIAR` (x1 OS, x2 lCliente, x3 lTecnico): posiciona SZ1; técnico -> AA1_EMAIL de Z1_TEC; cliente (se Z1_INTERNO != "S") -> cada e-mail de `DESTINO`; se enviou ao cliente grava Z1_OSENVCL/Z1_ENVDT/Z1_ENVHR (RecLock).
  - `TELA` (x1 OS): posiciona SZ1, `U_CH_PERGUNTAPUB` (cliente se não interna, técnico se Z1_TEC) e chama `ENVIAR`.
  - `RESUMO`: linhas {rótulo, valor} do cartão (OS, cliente-loja, data, horário, total horas, analista, projeto, tarefa, chamados).
  - `DESTINO`: e-mails dos chamados da OS (OS_ZA3 "LER") sem repetir, senão A1_EMAIL.
- [ ] `OS_APIINCLUIR` / `OS_APIALTERAR`: após sucesso, `OS_EMAIL("ENVIAR", os, notificarCliente=="1", notificarTecnico=="1")`.
- [ ] `OS_INCLUIRTELA` / `OS_ALTERARTELA`: guarda Z1_OS antes do FWExecView; se retornou 0 -> `OS_EMAIL("TELA", cOs)`.
- [ ] Commit.

### Task 3: Portal cns001 + interação

**Files:** `src/app/cns001/cns001.ts`, `cns001.html`, `chamado-serv.ts`, `chamado.model.ts`, `src/app/shared/interacao/interacao-historico.ts/.html`, `interacao-serv.ts`

- [ ] Todos os `notificarCliente*` passam a abrir `true`.
- [ ] Formulário: switch "Informar o cliente" também no Incluir; `NovoChamado.notificarCliente`; `incluir()` manda `&notificarCliente=1|0`.
- [ ] Interação: switches "Informar o técnico" ao incluir e excluir (padrão Sim); serviço manda `&notificarTecnico=1|0`.
- [ ] `ng build` ok; commit.

### Task 4: Portal cns003 (OS)

**Files:** `src/app/cns003/cns003.ts`, `cns003.html`, `os-serv.ts`, `os.model.ts`

- [ ] `NovaOs.notificarCliente?/notificarTecnico?`; `incluir()`/`alterar()` mandam `&notificarCliente=1|0&notificarTecnico=1|0`.
- [ ] Formulário: dois switches (padrão Sim, resetados ao abrir Incluir/Editar), antes das Interações.
- [ ] `ng build` ok; commit.

### Task 5: Entrega

- [ ] Usuário compila CNSA001 e CNSA002; testes manuais do spec.
- [ ] PR MVC + merge; PR portal + merge + deploy.ps1; atualizar apia-protheus (CNSA001/CNSA002).
