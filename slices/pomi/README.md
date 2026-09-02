# POMI

Slice do ambiente de teste ocasional do planejador POMI. Ela controla as APIs Data e App,
Keycloak, PostgreSQL privado, frontend Vercel, hostnames temporários, backup S3 e
ciclo manual de início e parada.

O projeto Vercel do frontend recebe pelo OpenTofu as variáveis públicas
`VITE_DATA_API_URL`, `VITE_APP_API_URL`, `VITE_KEYCLOAK_URL`, `VITE_KEYCLOAK_REALM` e
`VITE_KEYCLOAK_CLIENT_ID`. A URL resultante também é usada pelo Ansible para
configurar o CORS da API e os redirects do cliente público do Keycloak.

Os dados permanecem em `/opt/pomi/postgres-data` quando os containers estão
desligados. A porta do banco nunca é publicada no firewall ou no Docker.

O projeto `pomi-test`, definido em `compose/compose.yaml`, controla as APIs
Data e App, o job único de migrations, a injection agendada e o PostgreSQL. Ele
mantém limites de memória, health checks, rede interna, acesso das APIs à
`pomi-edge` e dependência da saúde do banco antes de iniciá-las.

O Keycloak responde no hostname configurado, como `https://auth.ominira.dev`, compartilha o
PostgreSQL do planner no schema `keycloak` e é configurado pelo job transitório
`keycloak-config`. O client público aceita a URL configurada do Vercel e
`http://localhost:5174` para desenvolvimento local. A senha bootstrap do
administrador e o token administrativo da Data ficam no Parameter Store.
O access token do frontend vale uma hora. A opção "Lembrar de mim" preserva a
sessão no navegador por até trinta dias desde o login, inclusive após fechar o
navegador; o token de acesso é renovado durante essa sessão e não é persistido
pelo frontend.
O tema `pomi` é importado do checkout irmão `pomi-keycloak-theme` pelo Ansible
e montado como somente leitura no contêiner.
`scripts/configure-secrets.sh` cria os dois parâmetros quando ausentes e não
altera a credencial do PostgreSQL já existente.

O limite de 640 MiB do Keycloak é deliberadamente inferior à recomendação para
produção. Esta configuração depende do swap do host de 1 GB e deve ser tratada
como experimental; reinícios por OOM exigem mover o serviço ou ampliar o host.

O deploy usa `docker compose up --wait`. A parada interrompe a injection antes
do PostgreSQL, preserva os containers e o bind mount do banco com
`docker compose stop`, depois publica o fragmento offline do Caddy. Backup e
validação de restauração continuam sendo operações explícitas anteriores à
parada.

As imagens Data, App e migrate são publicadas no repositório ECR
`pomi-<ambiente>/backend`; a imagem da injection é publicada em
`pomi-<ambiente>/injection`, sempre com tags imutáveis derivadas da mesma
release. A imagem da injection inclui o `unicamp-scrapper-cli` e o
`unicamp-scrapper-lib`. O Lightsail recebe autenticação temporária somente para
baixá-las; nenhuma credencial AWS permanente é armazenada no host.

A injection executa `pomi-injection watch` no container
`pomi-injection-test`. Seus arquivos de entrada e cache ficam em
`/opt/pomi/injection-data`. Os logs usam o OpenObserve configurado para o POMI, mas
com `OPENOBSERVE_STREAM=pomi-injection-logs`.

## Acesso local ao PostgreSQL

Com o ambiente POMI em execução, abra um túnel SSH sem publicar a porta do
banco:

```bash
./slices/pomi/scripts/open-db-tunnel.sh
```

Ele escuta em `127.0.0.1:5433` e encontra o IP interno atual do container. Para
usar outra porta local, defina `POMI_POSTGRES_LOCAL_PORT`, por exemplo
`POMI_POSTGRES_LOCAL_PORT=5434 ./slices/pomi/scripts/open-db-tunnel.sh`.
