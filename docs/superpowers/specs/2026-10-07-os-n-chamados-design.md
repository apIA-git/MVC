# OS ligada a vários chamados

Data: 07/10/2026 — Autor: Henrique (com Claude)

## Objetivo

Uma OS pode atender **vários chamados do mesmo cliente** (ex.: 15 chamados da Safran com a mesma causa → uma OS só), mantendo **separado o que foi feito em cada chamado** (interações por chamado) e com um lugar para ver **quais e quantos chamados** a OS tem.

## Decisões

| Tema | Decisão |
|---|---|
| Armazenamento | Tabela de ligação **ZA3** (OS × Chamado), um registro por chamado. |
| Campo antigo | `Z1_IDCH` continua: **chamado principal** = primeiro da lista (compatibilidade: Agenda, tela clássica, relatórios). |
| Restrição | Só chamados do **mesmo cliente e loja** da OS (lupa filtra + Protheus valida ao gravar). |
| Onde liga | **Só no portal**, no formulário da OS (campo "Chamados" múltipla escolha). Tela clássica segue só com o principal. |
| Interação | **Separada por chamado**: cada chamado da OS tem a sua caixa "O que foi feito neste chamado" (grava só naquele chamado, com `ZA2_OS`). Atalho "Aplicar a todos os chamados" (desmarcado) grava o mesmo texto em todos, só quando for igual. |
| Remover chamado | **Bloqueado** se o chamado já tem interação desta OS (ZA2 com `ZA2_IDCH` = chamado e `ZA2_OS` = OS). |
| Horas | Continuam **só no total da OS** (separar horas por chamado = fora do escopo). |
| Visualização | Lista de OS: coluna "Chamados" (quantidade) e ação "Chamados" nos 3 pontinhos → janela com um bloco por chamado (número, assunto, status, interações daquela OS naquele chamado). |
| OS sem chamado | = zero chamados ligados (regra da descrição única continua). |
| Copiar OS | Cópia nasce **sem** chamados. |

Aprovado pelo usuário em 07/10/2026. Revisado em 07/10/2026: interação separada por chamado, bloqueio de remoção, horas só no total.

## Dados

Tabela **ZA3** (criada pelo usuário; modo igual à SZ1; campos "usado", sem browse/obrigatório):

| Campo | Tipo | Tamanho |
|---|---|---|
| `ZA3_FILIAL` | C | igual a `Z1_FILIAL` |
| `ZA3_OS` | C | igual a `Z1_OS` (8) |
| `ZA3_IDCH` | C | igual a `ZA1_IDCH` (6) |

Índices: (1) `ZA3_FILIAL+ZA3_OS+ZA3_IDCH`; (2) `ZA3_FILIAL+ZA3_IDCH+ZA3_OS`.

**OS antigas:** chamados da OS = registros da ZA3 **∪** `Z1_IDCH` (se preenchido e não estiver na ZA3). Sem migração em massa; ao alterar a OS no portal a ZA3 passa a ter todos.

## Protheus

### CNSA002.TLPP

- **Incluir/Alterar (REST):** novo parâmetro `chamados` (códigos separados por vírgula). O antigo `chamado` continua aceito (vira lista de 1).
  - Valida cada chamado: existe na ZA1 e `ZA1_CLIENT`/`ZA1_LOJA` = cliente/loja da OS. Senão 400: "Chamado #n não é do cliente da OS."
  - Grava `Z1_IDCH` = primeiro da lista (ou vazio).
  - Bloqueia remover chamado que já tem interação desta OS: 400 "Chamado #n já tem interação desta OS - não pode ser removido."
  - Sincroniza a ZA3 depois do commit: apaga os que saíram, inclui os novos.
- **Excluir OS:** apaga a ZA3 da OS.
- **Copiar OS:** não copia ZA3 e grava `Z1_IDCH` vazio.
- **Listagem (`GET /CNSAOS`):** cada OS devolve `chamados` (lista de códigos, ZA3 ∪ Z1_IDCH) e `qtdChamados`.
- **Novo `GET /CNSAOSCHAMADOS?os=`:** para cada chamado da OS → `{idCh, assunto, status, interacoes:[{seq, consultor, data, hora, texto}]}`, onde as interações são as da ZA2 com `ZA2_IDCH` = chamado **e** `ZA2_OS` = OS, mais recente primeiro.
- **Interações da OS (`GET /CNSAOSINTERACOES`):** já lista ZA2 por `ZA2_OS`; passa a devolver também o **assunto** do chamado de cada item (pra o destaque no histórico).
- Regra "OS sem chamado" (descrição única) passa a olhar "zero chamados ligados" (ZA3 ∪ Z1_IDCH).

### cnslib.tlpp

- Lupa de chamado (`CNS001_CHAMLUPA`): cliente **obrigatório** quando chamado pela OS (sem cliente → lista vazia).

## Portal (apia-po-cnshub)

- **Formulário da OS:** campo "Chamado" vira **"Chamados"** (`po-lookup` com `p-multiple`), lupa dos chamados do cliente/loja; desabilitado sem cliente; trocar o cliente limpa. Envia `chamados` no incluir/alterar.
- **Interações (OS com chamados):** um bloco por chamado ("Chamado #n - assunto"), cada um com o componente de interação já existente (`app-interacao-historico` com `idCh` daquele chamado e `os` da OS) - caixa própria "O que foi feito neste chamado" + histórico do chamado. Acima dos blocos, atalho "Aplicar a todos os chamados" (texto único gravado em todos, desmarcado por padrão).
- **OS sem chamado:** inalterado (descrição única).
- **Lista de OS:** coluna "Chamados" (quantidade); ação "Chamados" nos 3 pontinhos → modal com um bloco por chamado (número, assunto, status, interações dessa OS nesse chamado).
- **Detalhe da OS:** lista os chamados ligados.

## Fora do escopo

- Vários chamados na tela clássica (CNSA002) — segue o principal (`Z1_IDCH`).
- Vincular OS a partir do chamado.

## Testes (manuais)

1. Criar OS com 3 chamados do mesmo cliente → ZA3 com 3 registros, `Z1_IDCH` = primeiro.
2. Tentar chamado de outro cliente (via REST) → 400.
3. Interação no bloco do chamado #2 → grava só nele; "Aplicar a todos" → grava nos 3. Remover um chamado que já tem interação desta OS → recusado.
4. "Chamados" nos 3 pontinhos → 3 blocos, interações certas em cada um.
5. Alterar OS antiga (só `Z1_IDCH`) → aparece 1 chamado; ao salvar com mais, ZA3 preenchida.
6. Excluir OS → ZA3 da OS apagada. Copiar OS → cópia sem chamados.

## Fora do escopo (revisão)

- Horas separadas por chamado (OS continua com um horário/total).
