# Codigos apia intraweb henrique

APIs REST em TLPP (Protheus AdvPL) que atendem o portal PO-UI de **Chamados**, **Ordem de Serviço** e **Agenda** usados na intraweb da Ápia. Publicadas via anotação (`@Get(endpoint="...")` / `@Post(endpoint="...")`), sem depender de `WSRESTFUL` clássico.

## Arquivos

| Arquivo | Endpoint base | Descrição |
|---|---|---|
| `Apia-OS.tlpp` | `/rest/CNSAOS*` | CRUD de Ordens de Serviço (SZ1) — listar, incluir, alterar, excluir, copiar |
| `Apia-Chamados.tlpp` | `/rest/CNSACHAMADOS*` | CRUD de Chamados (ZA1/ZA2) — listar, assumir, agendar, anotações, importação automática de e-mail (Microsoft Graph) |
| `Apia-ComponentsRest.tlpp` | `/rest/CNSACOMPONENTES` | "Lupas" de apoio (cliente, técnico, projeto, tarefa, módulo, motivo, serviço, proposta) usadas pelos formulários |
| `Apia-Encerra30dias.tlpp` | — (job agendado) | Fecha automaticamente chamados "Aberto" sem movimentação há 30 dias — registrar no SIGACFG > Agendador de Tarefas apontando pra `CNSA_FECHA30D` |

Consumidas pelo front Angular em `apia-po-cnshub/` (módulos `cns001`=Chamados, `cns003`=OS, `cns009`=Agenda).

## Pontos importantes de manutenção

- **Filial**: as listagens filtram por `cFilAnt`, não por `xFilial()` — dentro do contexto de rota `@Get`/`@Post`, `xFilial()` não reflete a filial real da sessão. Exceção: a `ZA1` (Chamados) é tabela **compartilhada** entre filiais (filial sempre grava em branco) — lá o `xFilial("ZA1")` (que retorna branco) é o valor certo, não o `cFilAnt`.
- **Paginação**: listagens (`CNSAOS`, `CNSACHAMADOS`) usam paginação real no SQL via `ROWNUM`/`COUNT(*) OVER()` (Oracle) — nunca trazem a tabela inteira pra memória. Exceção: filtro de texto livre (campos Memo) e filtro de status (lista OR) só dá pra aplicar em memória, então nesses casos busca tudo que bate nos outros filtros antes de paginar.
- **Parâmetros da querystring**: sempre ler via `CNSA002_JSONSTR`/`CNSA_JSONSTR` (indexação direta no JSON), nunca `jQuery:GetJsonText()` — esse método devolve a string literal `"null"` pra parâmetro ausente em vez de vazio, quebrando qualquer `If !Empty(param)`.
- **Encoding**: texto vindo do formulário do Angular (querystring) precisa de `DecodeUTF8()` antes de gravar. Texto vindo de JSON de API externa já parseado por `JsonObject:FromJson()` (ex: Microsoft Graph) **não** — já vem decodificado, aplicar `DecodeUTF8()` de novo corrompe acento.
- Fonte precisa estar em **CP1252** antes de compilar (não UTF-8).

## Compilando

Via TOTVS Developer Studio (extensão `tds-vscode` no VS Code) conectado ao AppServer, ou SmartClient/TDS clássico.
