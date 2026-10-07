# Agendamento direto no calendário do Outlook do técnico

Data: 05/10/2026 — Autor: Henrique (com Claude)

## Objetivo

Todo agendamento (SZ6) passa a existir também como evento no calendário do
Outlook do técnico, já salvo — sem convite, sem o técnico abrir a mensagem,
aceitar e salvar. O calendário acompanha o agendamento em inclusão,
alteração (inclusive troca de técnico) e exclusão.

## Decisões

| Tema | Decisão |
|---|---|
| Mecanismo | Microsoft Graph, `POST/PATCH/DELETE /users/{email-do-técnico}/events` (credencial de aplicativo já usada no envio de e-mail). |
| Telas cobertas | Todas que gravam SZ6: Agendar do chamado (tela clássica e portal), Agenda clássica (CNSA003) e Agenda do portal (cns009 via `FwModel/agenda`). |
| Ponto de gancho | Evento de modelo (`FWModelEvent`) no modelo `ModelSZ6` do CNSA003 — todos os caminhos acima já usam esse modelo. |
| Ciclo | Incluir cria; Alterar atualiza (troca de técnico: apaga no antigo, cria no novo); Excluir apaga. |
| Vínculo | Campo novo `Z6_IDOUTL` (C, 200, não usado na tela) guarda o id do evento no Graph. |
| Quando cria | Sempre. A caixa "Enviar e-mail para o técnico" continua controlando só o e-mail de aviso. |
| Falha | Outlook nunca impede gravar o agendamento. Erro só vai pro console (ConOut) e `Z6_IDOUTL` fica vazio. |

Aprovado pelo usuário em 05/10/2026 (inclui autorização para alterar o
CNSA003, código do Luiz).

## Arquitetura

### Funções de Outlook no final do `cnslib.tlpp` (sem fonte novo)

Funções globais (o `cnslib.tlpp` não tem namespace), sem regra de negócio —
decisão do usuário em 05/10/2026: nada de fonte novo.

- `U_CNSOUTGR(cEmailTec, cIdEvento, dData, cHrIni, cHrFim, cAssunto, cCorpoHtml) -> cIdEvento`
  - `cIdEvento` vazio: `POST /users/{cEmailTec}/events`; preenchido: `PATCH /users/{cEmailTec}/events/{cIdEvento}`.
  - PATCH com 404 (evento apagado à mão no Outlook): cria de novo (POST).
  - Devolve o id do evento (`id` da resposta) ou `""` em falha.
- `U_CNSOUTEX(cEmailTec, cIdEvento) -> lOk`
  - `DELETE /users/{cEmailTec}/events/{cIdEvento}`; 404 conta como sucesso.
- Token próprio no cnslib (client credentials) com `MV_CNSATEN` / `MV_CNSACLI` / `MV_CNSASEC` — não depende do CNSA001 (que está em namespace e tem o token como Static).
- Toda falha (token, e-mail vazio, HTTP != 2xx) faz `ConOut("CNSOUTLOOK: ...")` (prefixo do log) e devolve vazio/.F. — nunca lança erro.

### CNSA003 (`cnsa003.prw`)

- Classe de evento do modelo (`FWModelEvent`), instalada no `ModelDef` com `oModel:InstallEvent(...)`.
- Método pós-gravação (fora da transação do banco, depois do commit — `AfterTTS`), por operação:
  - **Incluir**: monta assunto/corpo, `U_CNSOUTGR` com `cIdEvento` vazio, grava o id retornado em `SZ6->Z6_IDOUTL` (RecLock no registro recém-gravado).
  - **Alterar**: se o técnico mudou, `U_CNSOUTEX` no e-mail do técnico antigo e cria no novo; senão `U_CNSOUTGR` com o id atual (atualiza). Grava o id retornado.
  - **Excluir**: `U_CNSOUTEX` com o id gravado.
- Técnico antigo/id antigo: lidos antes do commit (valores originais do registro SZ6) e guardados no objeto do evento.

### CNSA001 (exclusão do chamado)

A exclusão do chamado apaga os SZ6 com `RecLock`/`DbDelete` direto (não passa
pelo modelo). Antes de cada `DbDelete`, chama `U_CNSOUTEX` com o
`AA1_EMAIL` do `Z6_TECNICO` e o `Z6_IDOUTL` do registro.

Risco: o CNSA001 está no namespace `apia.cnsa001`. A chamada à função global
`U_CNSOUTEX` deve resolver no escopo global; se não resolver, criar
chamar por macro (`&("U_CNSOUTEX")(...)`), que resolve no escopo global.

## Conteúdo do evento

- Calendário: do técnico, pelo `AA1_EMAIL` do `Z6_TECNICO`.
- Assunto: `Agendamento - <A1_NREDUZ> - Chamado #<Z6_CHAMADO>` (sem o trecho do chamado quando `Z6_CHAMADO` = 0/vazio).
- Início/fim: `Z6_DTAGE` + `Z6_HMINI` / `Z6_HMFIM`, `timeZone` = `E. South America Standard Time`.
- Corpo (HTML simples): cliente, projeto/tarefa, serviço/descrição (`Z6_SERVICO`), quem agendou (`Z6_QGRAVOU`).
- `showAs` = `busy`, lembrete 15 min, sem `attendees` (não dispara e-mail de convite).

## Falhas e casos de borda

- Técnico sem `AA1_EMAIL`: não chama o Graph, ConOut, `Z6_IDOUTL` vazio.
- Sem permissão `Calendars.ReadWrite` (403) ou Graph fora: ConOut, agendamento gravado normalmente.
- Agendamento sem `Z6_IDOUTL` (antigo ou falha anterior) sendo alterado: cria o evento nesse momento.
- Exclusão sem `Z6_IDOUTL`: nada a fazer no Outlook.
- Agendamentos já existentes antes da implantação: não são enviados retroativamente.

## Pré-requisitos (usuário)

1. Liberar `Calendars.ReadWrite` (Application) com consentimento de administrador no app do Azure já usado (`MV_CNSACLI`).
2. Criar `Z6_IDOUTL` (Caractere, 200, contexto real, não usado/não visível na tela).
3. Compilar `cnslib.tlpp`, `cnsa003.prw` e `CNSA001.TLPP`.

## Testes (manuais)

1. Agendar pelo chamado (tela clássica e portal) → evento aparece no Outlook do técnico, já salvo, sem e-mail de convite.
2. Portal "Criar Agenda" com período de vários dias → um evento por dia.
3. Agenda: alterar horário → evento atualizado; trocar técnico → sai do antigo, entra no novo.
4. Agenda: excluir → evento some.
5. Excluir chamado com agendamentos → eventos somem.
6. Técnico sem e-mail / app sem permissão → agendamento grava, console mostra o motivo.

## Fora do escopo

- Envio retroativo dos agendamentos já existentes.
- Sincronização no sentido Outlook → Protheus (mudança feita direto no Outlook não volta pra SZ6).

## Adendo 05/10/2026 — e-mail ao técnico e convite ao cliente

- E-mail de aviso ao técnico em incluir / alterar / excluir / troca de técnico (layout padrão, `U_CNSOUTMA`); avisos antigos do Agendar removidos.
- Título do evento = nome reduzido do cliente; corpo com todos os dados da agenda.
- Cliente Participa? = Sim (`Z6_INTERNO` = "NAO"): e-mails do chamado (`ZA1_EMAIL`) + cadastro (`A1_EMAIL`), separados por `;`/`,` e sem repetir, entram como convidados do evento — o Outlook manda o convite (Aceitar/Recusar) em nome do técnico, atualizações no PATCH e cancelamento (`/cancel`) na exclusão. Com convidados, o corpo do evento leva só dados que o cliente pode ver (sem Cobrar/tipo/confirmado).

## Adendo 05/10/2026 — código enxuto

Tudo do Outlook virou **uma função só** no `cnslib.tlpp`: `U_CNSOUTL(cAcao, ...)` com `Do Case` (AGENDA, EXCLUIR, SALVAR, DADOS, JSON, AVISO, GRAVAID, EMAIL, HTTP, TOKEN) — as opções internas chamam a própria função. O CNSA003 ficou só com a classe `CNS003OUTL` (BeforeTTS guarda técnico/id; AfterTTS chama `U_CNSOUTL("AGENDA", ...)`). O CNSA001 chama `U_CNSOUTL("EXCLUIR", email, id)`. Substitui `U_CNSOUTGR`/`U_CNSOUTEX`/`U_CNSOUTMA`.
