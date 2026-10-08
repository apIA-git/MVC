# Informar cliente / técnico em Chamado e OS - Design

Data: 08/10/2026 · Autor: Henrique (com Claude)

## Objetivo

Em **Chamado** e **OS**, quem grava decide se o **cliente** e/ou o **técnico** recebem
e-mail - no **portal** (cns001/cns003) e na **tela clássica do Protheus**
(CNSA001/CNSA002), com o mesmo comportamento. Agenda (cns009/CNSA003) fora do escopo.

## Regra única

- Duas opções: **Informar o cliente** e **Informar o técnico**.
- Padrão: **as duas opções marcadas (Sim)**; quem grava desmarca se não quiser.
  Vale também para as ações que já existem (Alterar/Assumir/Excluir chamado,
  interação) - hoje o código abre cliente desmarcado (`lChkCli := .F.` em
  CH_PERGUNTAEMAIL e `notificarCliente* = false` no cns001/interacao): passa a Sim.
- Portal: `po-switch` no formulário/janela da ação. Protheus clássico: a janela
  `CH_PERGUNTAEMAIL` (checkboxes) que já existe.
- Só aparece a opção que faz sentido (sem técnico definido não oferece técnico; sem
  e-mail de cliente não oferece cliente).
- Layout de e-mail: o atual (`CH_HTMLEMAIL` via `apia.cnsa001.U_CH_HTMLPUB` / `U_CH_MAILPUB`),
  remetente apia@apia.com.br.

## Situação atual x o que muda

### Chamado

| Ação | Cliente hoje | Técnico hoje | Muda |
|---|---|---|---|
| Incluir | não existe | existe | **+ Informar o cliente** (e-mail "Chamado Aberto", o mesmo do chamado por e-mail - `CH_NOTIFICARCHAMADOCRIADO`) |
| Alterar / Assumir / Excluir | existe | existe | nada |
| Nova interação | existe | não existe | **+ Informar o técnico** (texto da interação ao técnico do chamado) |
| Excluir interação | existe | não existe | **+ Informar o técnico** |
| Automáticos (aberto por e-mail, fechado 30 dias) | sempre | - | nada |

Interação: o técnico **não** recebe quando ele mesmo é quem interagiu
(ZA1_CONSUL = consultor da sessão) - o Protheus simplesmente não envia nesse caso
(no portal a opção aparece sempre; o componente não sabe quem é o técnico).

### OS (hoje não manda nenhum e-mail)

- Incluir e Alterar ganham as duas opções.
- **Técnico**: e-mail ao analista da OS (Z1_TEC -> AA1_EMAIL) com o resumo da OS.
- **Cliente**: mesmo resumo para os e-mails dos chamados da OS (ZA1_EMAIL de todos,
  sem repetir); OS sem chamado -> A1_EMAIL. Grava `Z1_OSENVCL = "S"`, `Z1_ENVDT`, `Z1_ENVHR`.
- OS Interna (Z1_INTERNO = S) não oferece cliente.
- Resumo da OS: número, cliente-loja, data, hora inicial/final, total de horas,
  analista, projeto/tarefa, chamados (#id - assunto) e descrição.
- Base do futuro "aprovar OS" (memória `pendente-aprovar-os-cliente`): o e-mail ao
  cliente passa a levar o link de aprovação quando aquele projeto for criado.

## Componentes

### Portal (apia-po-cnshub)
- `cns001`: switch "Informar o cliente" na janela de Incluir; envia `notificarCliente`
  na inclusão (`chamado-serv.ts` incluir).
- `shared/interacao`: switch "Informar o técnico" ao incluir e ao excluir interação
  (escondido quando o logado é o técnico do chamado); `interacao-serv.ts` manda
  `notificarTecnico=1`.
- `cns003`: dois switches no formulário da OS (Incluir/Editar); `os-serv.ts` manda
  `notificarCliente`/`notificarTecnico` no incluir/alterar.

### Protheus
- `CNSA001.TLPP`
  - Incluir (REST e clássico): aceita `notificarCliente`; clássico oferece cliente
    na janela (linha ~800 hoje só oferece técnico).
  - Interação incluir/excluir (REST e clássico): aceita `notificarTecnico`; e-mail ao
    técnico reaproveitando `CH_NOTIFICARINTERACAO` (destino AA1_EMAIL do ZA1_CONSUL).
  - Novo `User Function CH_PERGUNTAPUB` (no bloco do fim, junto de CH_HTMLPUB/CH_MAILPUB)
    expondo `CH_PERGUNTAEMAIL` para o CNSA002.
- `CNSA002.TLPP`
  - Uma função Do Case `OS_EMAIL(cAcao, ...)`: `TECNICO`, `CLIENTE`, `RESUMO` (linhas do e-mail).
  - REST: `OS_NUCLEOINCLUIR`/`OS_NUCLEOALTERAR` leem `notificarCliente`/`notificarTecnico`
    e chamam `OS_EMAIL` depois do commit.
  - Clássico: evento pós-gravação do modelo (FWModelEvent `AfterTTS`, como o
    CNS003OUTL) pergunta com `U_CH_PERGUNTAPUB` e chama `OS_EMAIL`; via REST não pergunta.

## Erros

- Falha no envio nunca desfaz a gravação: só `ConOut` (mesma regra dos e-mails atuais).
- Sem e-mail de destino: não envia e não marca `Z1_OSENVCL`.

## Teste (manual, após compilar)

1. Portal: incluir chamado com cliente marcado -> cliente recebe "Chamado Aberto".
2. Portal: interação por outro usuário com técnico marcado -> técnico recebe; logado
   como o técnico -> opção não aparece.
3. Portal: incluir OS com os dois marcados -> técnico e cliente recebem resumo;
   OS fica "Enviada" com data/hora.
4. Mesmo 1-3 na tela clássica (janela de checkboxes).
5. Desmarcados -> ninguém recebe.
