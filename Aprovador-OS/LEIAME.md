# Aprovador-OS

Página pública em que o cliente aprova ou recusa uma OS pelo link do e-mail.
É uma **camada fina** em ASP.NET (sem PHP): não lê nem grava no banco. Mostra a
tela e repassa ao Protheus (`/CNSAAPROVA`), onde fica toda a regra em TLPP
(`U_CNSAPR`, CNSA004).

```
Cliente ──► www.apia.com.br/aprovador-os/?t=<token> ──► REST /CNSAAPROVA (rede interna, TLS 1.2) ──► U_CNSAPR
```

- URL: `https://www.apia.com.br/aprovador-os/?t=<token>` (montada com o parâmetro `MV_CNSAURL`).
- Servidor: `\\10.0.0.3\SistemasWeb\Mais_Aplicacoes\Aprovador-OS`.
- IIS 10 (Windows Server 2022): aplicativo `aprovador-os` no mesmo nível do `apia_cs`,
  pool com .NET 4.x. Não usa PHP.

## Arquivos

| Arquivo | O quê |
|---|---|
| `default.aspx` | a página (C#): abre o link (GET `/CNSAAPROVA`), mostra o formulário e envia a resposta (POST `/CNSAAPROVA`) |
| `estilo.css` | visual do portal (logo, azul, celular) |
| `web.config` | página inicial, endereço do REST, telefone; esconde detalhes de erro |
| `config.local.exemplo.config` | modelo do `config.local.config` (usuário de serviço) |

O `config.local.config` **não vai para o git**: é criado só no servidor, a partir do exemplo,
com o usuário de serviço do Protheus. O IIS não entrega arquivos `.config` pelo navegador.

## Usuário de serviço (Protheus)

- Login `Aprovador de OS` (padrão do `MV_CNSASRV`): sem grupo e sem menus, senha que não expira,
  sem "trocar senha no próximo acesso".
- Restrições de acesso → Filiais: **01 / 01 (APIA / MATRIZ)** marcada. Sem isso o REST
  responde 403 "Usuário sem acesso a empresa/filial". Acessos simultâneos: 10.
- Nos endpoints próprios ele só consegue usar o `/CNSAAPROVA` (os demais devolvem 403 - `U_CNSSERVICO`, cnslib).
- Alterou o cadastro e o REST continua recusando: reiniciar o serviço do REST (cache do usuário).

## Comportamento

| Resposta do Protheus | Tela |
|---|---|
| 200 no GET | formulário (resumo da OS, Aprovo / Não aprovo, observação até 240) |
| 200 no POST | "Obrigado! Sua resposta foi registrada" |
| 409 | "Esta OS já foi respondida" |
| 404 / 400, ou token fora do formato | "Link inválido ou expirado" (resposta genérica) |
| sem resposta, 401, 403, 5xx | "Sistema indisponível, tente mais tarde" (o link continua valendo) |

O IP do cliente vai no cabeçalho `X-Forwarded-For` (gravado em `Z1_APVIP`/`ZA_IP`).

## Testar

`https://www.apia.com.br/aprovador-os/?t=` + 64 zeros deve mostrar **"Link inválido ou expirado"**
(o Protheus respondeu que o token não existe). "Sistema indisponível" = credencial, filial ou rede.

## Publicar

Copiar `default.aspx`, `estilo.css` e `web.config` para a pasta do servidor e criar lá o
`config.local.config` a partir do `config.local.exemplo.config`.
