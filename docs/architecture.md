# Arquitetura da infraestrutura POMI

## Estado e composição

`terraform/` é a raiz do único state. Ela instancia três módulos localizados
nas slices e publica a interface operacional usada pelos scripts locais.

| Slice | Possui | Não possui |
| --- | --- | --- |
| `platform` | Lightsail, IP, firewall, snapshots, Caddy, redes e Collector | Aplicações e bancos dos produtos |
| `pomi-exchange` | API Exchange, imagem ECR, SQLite, Vercel, Route53, SMTP e seus segredos | Host e recursos do planejador |
| `pomi` | API de teste, frontend Vercel, Keycloak, imagem ECR, PostgreSQL, backup S3 e seus segredos | Lightsail e produção do Exchange |

Recursos compartilhados nunca são declarados novamente dentro das slices de
produto.

O `user_data` da Lightsail é usado somente na criação. O lifecycle ignora
mudanças posteriores nesse campo para impedir substituição da instância, e a
configuração evolutiva do host é reconciliada por `prepare-shared-host.sh`.

## Rede e roteamento

O firewall publica somente SSH, HTTP e HTTPS. Caddy e as duas APIs usam a rede
`pomi-edge`. PostgreSQL e a API do planejador também usam a rede interna
`pomi-test-internal`, sem publicação da porta 5432.

O Caddy importa arquivos em `/opt/pomi/caddy/sites`. Cada produto substitui
somente seu próprio arquivo. A configuração é validada antes de cada reload.

Os serviços são declarados em três projetos Docker Compose independentes:

| Projeto | Arquivo no host | Serviços |
| --- | --- | --- |
| `pomi-platform` | `/opt/pomi/compose/platform.yaml` | Caddy |
| `pomi-exchange` | `/opt/pomi/compose/exchange.yaml` | API Exchange e Collector |
| `pomi-test` | `/opt/pomi/compose/pomi.yaml` | API POMI e PostgreSQL |

As redes `pomi-edge` e `pomi-test-internal` são externas aos projetos para
permitir comunicação entre slices sem transferir a propriedade dos serviços.
O Compose preserva os nomes históricos dos containers para manter os comandos
operacionais e a coleta de métricas compatíveis.

## Persistência

O SQLite do Exchange permanece no caminho legado `/opt/pomi/data`. PostgreSQL 18 usa
`/opt/pomi/postgres-data` montado em `/var/lib/postgresql`, conforme o contrato
da imagem oficial para a versão 18.

Antes de parar o ambiente POMI, o pipeline executa `pg_dump`, valida o arquivo e
o envia ao bucket S3 versionado. Backups expiram após 30 dias.

## Imagens

Cada slice de produto possui um repositório ECR privado. As imagens usam tags
imutáveis e uma política remove versões mais antigas que o limite configurado.
O nome completo retornado pelo OpenTofu é o contrato entre build, pull e o campo
`image` interpolado no Compose.

O operador autentica localmente no ECR, constrói e publica a imagem. Depois dos
arquivos de configuração chegarem ao host, um token temporário é enviado pelo
stdin do SSH para o Docker remoto. O host baixa a referência completa, encerra
a sessão do registry e inicia o Compose com pull desabilitado, garantindo que o
artefato validado seja exatamente o artefato executado.

## Operação

O Exchange é publicado de forma independente e permanece ativo. O POMI é
iniciado e parado manualmente. O operador deve serializar mudanças na
Lightsail.

Os scripts locais continuam responsáveis por obter outputs do OpenTofu,
resolver segredos no Parameter Store, construir e publicar imagens. As roles
Ansible em `ansible/` reconciliam host, Caddy e os estados de produto; os
playbooks de deploy de produto ainda serão a próxima migração. No host, os
serviços usam Docker Compose para criação, recriação, dependências e espera por
health checks.

Na primeira execução, cada fluxo identifica containers sem a label do projeto
Compose esperado e os substitui. Essa adoção elimina configurações legadas sem
alterar os bind mounts persistentes.

O rollback do POMI afeta `pomi-data-api-test`, `pomi-app-api-test`,
`pomi-migrate-test`, `pomi-postgres-test`, sua rede
interna e seu fragmento Caddy.
