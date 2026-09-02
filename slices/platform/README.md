# Platform

Slice proprietária da instância Lightsail compartilhada, IP estático, firewall,
Caddy, redes Docker, swap, snapshots e métricas do host.

Os produtos publicam somente seus próprios fragmentos em
`/opt/pomi/caddy/sites`. A configuração principal e o container do Caddy são
controlados por esta slice.

O projeto `pomi-platform`, definido em `compose/compose.yaml`, preserva o nome
`pomi-caddy`, as portas 80/443, a rede `pomi-edge` e os diretórios persistentes
de certificados e configuração. `reconcile-caddy.sh` valida o Caddyfile, adota
eventuais containers legados, aplica o Compose e então executa o reload.

OpenObserve e Vector também são executados nesta composição. O Vector coleta
os logs diretamente da API Docker e envia os eventos para o OpenObserve local;
a interface fica disponível apenas em `127.0.0.1:5080` para acesso por túnel
SSH. O OpenTelemetry Collector não faz parte da plataforma.
