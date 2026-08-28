# POMI Exchange

Slice proprietária da API do Exchange, frontend Vercel, configuração de e-mail,
segredos de produção e fragmento Caddy do produto.

Seu deploy é independente do ambiente de teste do planejador POMI.

O projeto `pomi-exchange`, definido em `compose/compose.yaml`, controla a API e
o OpenTelemetry Collector. Ele preserva os nomes históricos, o volume SQLite,
a rede `pomi-edge`, o namespace de processos do Collector e o health check
definido na imagem da API.

A imagem da API é publicada no repositório ECR
`pomi-exchange-<ambiente>/backend` com tag imutável. O Lightsail recebe
autenticação temporária somente para baixar essa referência; nenhuma credencial
AWS permanente é armazenada no host.
