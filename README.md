# POMI Infra

Infraestrutura compartilhada do POMI Exchange e do planejador POMI. Uma única
instância Amazon Lightsail em São Paulo executa a API de produção do Exchange e,
quando solicitado, a API e o PostgreSQL do ambiente de teste do planejador.

## Organização

```text
.
├── terraform/               # composição, providers, backend e interface pública
└── slices/
    ├── platform/            # Lightsail, Caddy, redes, swap e observabilidade
    │   └── compose/         # estado declarativo dos serviços compartilhados
    ├── pomi-exchange/       # API, Vercel, e-mail e deploy do Exchange
    │   └── compose/         # API e OpenTelemetry Collector
    └── pomi/                # API, frontend Vercel, PostgreSQL, backup e ciclo start/stop do POMI
        └── compose/         # API e PostgreSQL do ambiente de teste
```

As três slices são módulos verticais dentro de um único state. A slice
`platform` é a única proprietária da Lightsail, IP estático e firewall. Os
produtos recebem esses dados por inputs e controlam somente seus próprios
recursos e fragmentos do Caddy.

Detalhes de fronteiras e fluxo estão em [docs/architecture.md](docs/architecture.md).

## State remoto

O state do OpenTofu é mantido no S3. A configuração do backend fica fora do
Git em `terraform/backend.hcl`; use o modelo versionado:

```bash
cp terraform/backend.hcl.example terraform/backend.hcl
```

Para migrar o state local existente uma única vez, com as credenciais AWS que
podem ler e gravar no bucket e na tabela de lock:

```bash
make tf-migrate-state
```

O comando transfere o state para o backend remoto. Preserve o arquivo local
até confirmar `make tf-plan`; ele continua ignorado pelo Git. Os blocos
`moved` em `terraform/moved.tf` migram endereços antigos para os módulos sem
recriar recursos.

Antes do primeiro deploy com registry, aplique a criação dos dois repositórios
ECR e de suas políticas de retenção:

```bash
tofu -chdir=terraform init
tofu -chdir=terraform plan
tofu -chdir=terraform apply
```

O plano esperado adiciona os repositórios `pomi-exchange-production/backend` e
`pomi-test/backend`, suas políticas e novos outputs. Não aplique se o plano
substituir ou destruir a Lightsail, o IP estático, DNS ou projeto Vercel.

## Configuração local

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
cp terraform/backend.hcl.example terraform/backend.hcl
mkdir -p .local
ssh-keygen -t ed25519 -f .local/pomi-lightsail -C pomi-deploy
make tf-init
tofu -chdir=terraform fmt -check -recursive
tofu -chdir=terraform validate
tofu -chdir=terraform plan
```

State, tfvars, cache, chaves e arquivos `.env` são locais e ignorados. O
`terraform/.terraform.lock.hcl` permanece versionado.

Configure separadamente os segredos dos produtos:

```bash
./slices/pomi-exchange/scripts/configure-secrets.sh
./slices/pomi/scripts/configure-secrets.sh
```

Os valores ficam em parâmetros `SecureString`; somente seus nomes são usados
pela configuração. O script do planner cria apenas a senha bootstrap do
Keycloak quando ela ainda não existe; ele não cria, altera ou rotaciona a senha
do PostgreSQL.

O tema das telas e dos e-mails do Keycloak pertence ao checkout irmão
`pomi-keycloak-theme`. Os deploys do POMI exigem esse projeto ao lado de
`pomi-infra` e copiam `theme/pomi` para o host sem duplicar seus arquivos nesta
infraestrutura.

Para publicar somente alterações no tema ou na configuração do Keycloak, sem
reconstruir ou atualizar as APIs, valide o tema e execute:

```bash
cd ../pomi-keycloak-theme && npm test
cd ../pomi-infra && make deploy-keycloak
```

O alvo atualiza os arquivos no host, recria apenas o Keycloak e reaplica a
configuração declarativa do realm e dos clientes.

O host usa Docker Compose v2. O bootstrap instala o plugin em instâncias novas
e os fluxos operacionais o reconciliam em instâncias existentes antes de
aplicar os projetos `pomi-platform`, `pomi-exchange` e `pomi-test`.
Alterações posteriores no bootstrap são ignoradas pelo lifecycle da Lightsail
porque `user_data` força substituição; evolução de hosts existentes deve passar
pelos scripts idempotentes de preparação.

Cada backend possui um repositório ECR privado com tags imutáveis, criptografia
AES256, scan no push e retenção das 20 imagens mais recentes por padrão. Altere
`registry_image_retention` para outro limite, mantendo pelo menos duas versões
para rollback.

## POMI Exchange

O projeto Vercel permanece conectado ao repositório GitHub informado por
`frontend_git_repository`, permitindo que o frontend continue integrado à
Vercel. Essa é a única configuração GitHub mantida na infraestrutura.

Deploy local:

```bash
export VERCEL_API_TOKEN="..."
./slices/pomi-exchange/scripts/deploy-local.sh
```

O script cria uma tag UTC, publica a imagem no ECR e entrega ao Lightsail apenas
arquivos de configuração. A imagem é baixada diretamente pelo Docker remoto.

## Ambiente de teste do POMI

O projeto Vercel do `pomi-frontend` é gerenciado pela slice `pomi`. O OpenTofu
define `VITE_DATA_API_URL`, `VITE_APP_API_URL`, `VITE_KEYCLOAK_URL`, `VITE_KEYCLOAK_REALM` e
`VITE_KEYCLOAK_CLIENT_ID` para os ambientes Production e Preview. As variáveis
`VITE_*` são públicas por definição e não devem conter segredos.

Depois de alterar variáveis no Vercel, é necessário criar um novo deployment
para que elas cheguem ao bundle do frontend. O deploy do backend também usa a
URL do frontend para configurar CORS e os redirects do cliente Keycloak.

### Migração das variáveis do Vercel

As variáveis de ambiente dos projetos Vercel são gerenciadas como recursos
individuais do OpenTofu. Antes do primeiro `make tf-apply` após essa mudança,
importe as variáveis que já existem para evitar que sejam recriadas:

```bash
export VERCEL_API_TOKEN="..."
make import-vercel-pomi-environments
```

Execute cada comando `tofu import` exibido pelo alvo acima. Repita para o
Exchange, se ele também estiver no mesmo estado:

```bash
make import-vercel-exchange-environments
```

Em seguida, confirme o plano com `make tf-plan`. Caso a conta Vercel pertença
a um time e a API não encontre o projeto, defina também `VERCEL_TEAM_ID`.

O script de deploy inicia PostgreSQL 18, aplica migrations do `pomi-backend`,
inicia o Keycloak, aplica migrations uma vez, publica as APIs Data e App e ativa:

```text
https://data.pomi.<IP-ESTATICO>.sslip.io
https://app.pomi.<IP-ESTATICO>.sslip.io
https://auth.pomi.<IP-ESTATICO>.sslip.io
```

O deploy falha antes do build se houver diretórios vazios em
`packages/db/prisma/migrations`, pois `prisma migrate deploy` não consegue inicializar o
banco nessa condição.

Os nomes dos containers e os caminhos persistentes permanecem estáveis. Na
primeira execução após a migração, containers criados pelos scripts antigos são
removidos e recriados sob controle do Compose. Dados do PostgreSQL, SQLite e
certificados do Caddy permanecem nos mesmos bind mounts.

Deploy local:

```bash
POMI_CORS_ORIGIN="http://localhost:5174" \
  ./slices/pomi/scripts/deploy-local.sh
```

O backend aceita múltiplas origens separadas por vírgula. Para configurações
manuais, use `CORS_ORIGINS` (ou o nome legado `CORS_ORIGIN`):

```env
CORS_ORIGINS=https://pomi-lime.vercel.app,http://localhost:5174,https://preview.example.com
```

Os espaços ao redor das vírgulas são removidos e entradas vazias são ignoradas.

Para reutilizar uma imagem existente sem executar build ou push:

```bash
USE_EXISTING_IMAGE=true IMAGE_TAG=20260804173651 \
  ./slices/pomi/scripts/deploy-local.sh
```

O mesmo contrato de rollback vale para o script do Exchange. O deploy verifica
se a tag existe no ECR antes de alterar o host.

## Reconciliação com Ansible

`ansible/` contém as roles para host, Caddy, POMI e Exchange. Por enquanto, o
playbook suportado reconcilia somente o host e a plataforma; os scripts locais
continuam publicando imagens e executando os deploys de produto.

```bash
cd ansible
ansible-galaxy collection install -r requirements.yml
LIGHTSAIL_HOST="$(tofu -chdir=../terraform output -raw lightsail_static_ip)" \
  ANSIBLE_PRIVATE_KEY_FILE=../.local/pomi-lightsail \
  ansible-playbook playbooks/reconcile-host.yml --check --diff
```

Consulte [ansible/README.md](ansible/README.md) antes da primeira aplicação.

Depois de reconciliar o host, os deploys de API podem usar Ansible:

```bash
cd ansible
ansible-playbook playbooks/deploy-pomi.yml
ansible-playbook playbooks/deploy-exchange.yml
```

O script de parada cria e valida um `pg_dump`, envia o arquivo ao S3 e somente
então para API e banco. Quando desligado, o hostname responde 503.

O comando continua compatível, mas é agora um encaminhador fino para o
playbook Ansible `stop-pomi.yml`.

Parada local:

```bash
./slices/pomi/scripts/stop-local.sh
```

Se o backup falhar, a parada é cancelada. `FORCE_STOP=true` ignora essa proteção
somente em uma operação local consciente.

Valide uma restauração sem tocar no ambiente remoto:

```bash
./slices/pomi/scripts/validate-backup.sh s3://bucket/postgres/chave.dump
```

## Operação local

Antes de aplicar ou publicar, autentique a AWS pelo perfil local e exporte
`VERCEL_API_TOKEN`. Os scripts usam a chave `.local/pomi-lightsail`, o state
local e os parâmetros SSM configurados para cada produto.

A identidade AWS local precisa criar e consultar repositórios ECR durante o
apply e obter token, consultar, enviar e baixar imagens durante o deploy. O
token temporário é enviado ao `docker login` local e remoto por stdin; ambos
executam logout ao terminar. Nenhuma credencial AWS permanente é instalada na
Lightsail.

Não execute deploy e parada simultaneamente. A serialização das operações é
responsabilidade de quem estiver operando o ambiente localmente.

Para inspecionar o estado declarativo no host:

```bash
sudo docker compose -f /opt/pomi/compose/platform.yaml ps
sudo docker compose -f /opt/pomi/compose/exchange.yaml ps
sudo docker compose -f /opt/pomi/compose/pomi.yaml ps
```

Para uma visão consolidada, sem segredos e sem alterar infraestrutura:

```bash
./scripts/infra-status.sh
```

O comando mostra health checks públicos, últimas imagens ECR, último backup do
PostgreSQL e estado, recursos e consumo dos containers na Lightsail.

## Limites

A instância permanece com 1 GB. O POMI é um ambiente de teste ocasional, não um
ambiente de produção. API e PostgreSQL possuem limites de memória e o host ganha
2 GB de swap, mas a execução deve ser acompanhada por `docker stats`, memória,
swap e reinícios.
