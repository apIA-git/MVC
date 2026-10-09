# Aprovador-OS

Página pública em que o cliente aprova ou recusa uma OS pelo link do e-mail.
É uma **camada fina**: não lê nem grava no banco. Mostra a tela e repassa ao
Protheus (`/CNSAAPROVA`), onde fica toda a regra (`U_CNSAPR`, CNSA004).

```
Cliente ──► www.apia.com.br/aprovador-os/?t=<token> ──► REST /CNSAAPROVA (rede interna) ──► U_CNSAPR
```

- URL: `https://www.apia.com.br/aprovador-os/?t=<token>` (o IIS não diferencia maiúsculas;
  o link é montado com o parâmetro `MV_CNSAURL`).
- Servidor: `\\10.0.0.3\SistemasWeb\Mais_Aplicacoes\Aprovador-OS` (ao lado de `clienteaprovar`).
- IIS: a pasta precisa estar cadastrada no site (mesmo tipo da `clienteaprovar`).

## Arquivos

| Arquivo | O quê |
|---|---|
| `index.php` | a página: abre o link (GET `/CNSAAPROVA`), mostra o formulário e envia a resposta (POST `/CNSAAPROVA`) |
| `estilo.css` | visual do portal (logo, azul, celular) |
| `web.config` | abre o `index.php` como página inicial da pasta |
| `config.exemplo.php` | modelo do `config.php` (URL do REST e usuário de serviço) |

O `config.php` **não vai para o git**: é criado só no servidor, a partir do exemplo,
com o usuário de serviço do Protheus (login só para esta página).

## Requisitos

- PHP 7 ou superior com `allow_url_fopen` ligado e a extensão `openssl` (chamada https ao REST).
- Usuário de serviço do Protheus com acesso ao REST.

## Comportamento

| Resposta do Protheus | Tela |
|---|---|
| 200 no GET | formulário (resumo da OS, Aprovo / Não aprovo, observação até 240) |
| 200 no POST | "Obrigado! Sua resposta foi registrada" |
| 409 | "Esta OS já foi respondida" |
| 404 | "Link inválido ou expirado" (inválido, vencido ou já substituído - resposta genérica) |
| sem resposta, 401, 5xx | "Sistema indisponível, tente mais tarde" (o link continua valendo) |
| outro (ex.: 400) | formulário de novo com a mensagem do Protheus |

O IP do cliente vai no cabeçalho `X-Forwarded-For` (gravado em `Z1_APVIP`/`ZA_IP`).

## Publicar

Copiar `index.php`, `estilo.css` e `web.config` para a pasta do servidor e criar lá o
`config.php` a partir do `config.exemplo.php`.
