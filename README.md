# MVC — Ápia Consultoria

Customizações AdvPL/TLPP do Protheus e os portais Angular (PO-UI) da Ápia. Cobre as telas de **Ordem de Serviço**, **Chamados** e **Agenda** usadas na intraweb/portal da empresa.

## Estrutura do repositório

| Pasta | Conteúdo |
|---|---|
| `Codigos apia intraweb henrique/` | **Backend ativo** — APIs REST em TLPP que o portal PO-UI consome hoje. [Detalhes →](./Codigos%20apia%20intraweb%20henrique/README.md) |
| `apia-po-cnshub/` | **Frontend ativo** — app Angular + PO-UI (módulos de Chamados, OS e Agenda). Repositório git próprio (`apIA-git/apia-po-cnshub`), incluído aqui só como cópia de trabalho |
| `Fontes cnshub/` | Telas MVC clássicas do Protheus (`CNSA001`/`CNSA002`) que os REST acima espelham/substituem |
| `Protheus fonts/` | Fontes de referência/legado (versões antigas dos apps de chamados, OS e agenda) |
| `apia_consultoria/` | App Angular anterior (referência histórica, não é o portal ativo) |
| `docs/` | Specs e planos de implementação |

## Onde mexer

- **Mudou regra de negócio/endpoint REST?** → `Codigos apia intraweb henrique/`
- **Mudou tela/comportamento do portal?** → `apia-po-cnshub/`
- **Precisa entender uma tela clássica do Protheus (MVC)?** → `Fontes cnshub/`

## Branches

Desenvolvimento corrente na branch `henrique`.
