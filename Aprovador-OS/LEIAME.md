# Aprovador-OS (aposentado)

Desde 20/10/2026 a página em que o cliente aprova ou recusa a OS é a **rota pública
do portal Angular**: `https://www.apia.com.br/apia_cs/aprovacao/<token>`
(projeto `apia-po-cnshub`, pasta `src/app/aprovacao`), conforme a nota do Luis
("Como fazer a tela de aprovação dentro do app Angular", 15/10/2026).

Esta pasta ficou só com um **redirecionamento** em HTML estático (sem ASP.NET nem PHP),
para os links antigos dos e-mails continuarem funcionando:

```
https://www.apia.com.br/Aprovador-OS/?t=<token>  ->  https://www.apia.com.br/apia_cs/aprovacao/<token>
```

| Arquivo | O quê |
|---|---|
| `index.html` | lê o `?t=` e redireciona para a rota Angular |
| `web.config` | página inicial = `index.html` |

## Onde ficou cada coisa

- Link do e-mail: `MV_CNSAURL = https://www.apia.com.br/apia_cs/aprovacao` (o `AP_ENVIAR` do CNSA004
  monta `MV_CNSAURL + "/" + token`).
- Tela: `apia-po-cnshub/src/app/aprovacao` (rota `aprovacao/:token`, sem login).
- Credencial do usuário de serviço (`Aprovador de OS`): `config.json` na pasta `apia_cs` do servidor
  (fora do git; o `deploy.ps1` não apaga).
- Regra: `U_CNSAPR` (CNSA004) via `GET/POST /CNSAAPROVA`.

## Para funcionar fora da rede da Ápia

- Porta 8624 do REST aberta para a internet (NAT).
- Cadeia completa do certificado no REST (`[SSLConfigure] CertificateServer` com o intermediário),
  senão celular/Firefox recusam.
