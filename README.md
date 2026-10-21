# MVC — Ápia Consultoria

Customizações TLPP do Protheus (CNSHUB) e o portal Angular (PO-UI) da Ápia: **Chamados**, **Ordem de Serviço**, **Aprovação de OS pelo cliente** e **Agenda**.

## Estrutura do repositório

| Pasta | Conteúdo |
|---|---|
| `Fontes MVC e Site/` | **Backend ativo** — fontes TLPP: telas MVC clássicas e as APIs REST que o portal consome |
| `apia-po-cnshub/` | **Frontend ativo** — app Angular + PO-UI. Repositório git próprio (`apIA-git/apia-po-cnshub`), aqui só como cópia de trabalho |
| `Aprovador-OS/` | Redirecionamento dos links antigos de aprovação para a rota pública do portal (ver `LEIAME.md`) |
| `docs/` | Specs e planos (`superpowers/`) e a cópia do código retirado na auditoria de 21/10/2026 (`backup-codigo-morto-21-10/`) |
| `graphify-out/` | Grafo de conhecimento do projeto (fontes + portal + docs), gerado localmente; fora do git |

## Fontes do Protheus

| Fonte | O quê |
|---|---|
| `CNSA001.TLPP` | Chamados (ZA1/ZA2): tela, REST `/CNSACHAMADOS*`, e-mails e importação da caixa apia@ |
| `CNSA002.TLPP` | Ordem de Serviço (SZ1): tela, REST `/CNSAOS*`, interações e o evento `CNS002APR` da aprovação |
| `CNSA004.TLPP` | Aprovação de OS: `U_CNSAPR` (todas as regras), `U_CNSAPJOB` (prazo), REST `/CNSAPR` e `/CNSAAPROVA` (público, por token) |
| `cnslib.tlpp` | Biblioteca comum: lupas (`/CNSLIBCOMPONENTES`), `U_CNSOUTL` (Outlook, e-mail, token, UTF-8, texto), `U_CNSSERVICO` |
| `CNSLOGIN.tlpp` | Login do portal (`/CNSLOGIN`) |
| `CNSA003.prw` | Agenda — mantida pelo Luiz |

**Ordem de compilação:** `cnslib` → `CNSA004` → `CNSA002` → `CNSA001` → `CNSLOGIN`, depois reiniciar o REST. Os fontes ficam em CP1252 com CRLF.

## Onde mexer

- **Regra de negócio ou endpoint REST?** → `Fontes MVC e Site/`
- **Tela ou comportamento do portal?** → `apia-po-cnshub/` (deploy com `deploy.ps1`, ver `apia-po-cnshub/docs/manual-github-e-deploy.md`)
- **Regra da aprovação de OS?** → `U_CNSAPR` no `CNSA004.TLPP` e `apia-po-cnshub/docs/spec-cnsapr-backend.md`

## Branches e entregas

Uma branch por dia (`feature/henrique-DD-MM`), PR para `main` e merge. Os fontes do CNSHUB também vão por PR para `apIA-git/apia-protheus` (pasta `Ápia/CNSHUB`).
