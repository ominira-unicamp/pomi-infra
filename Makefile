.DEFAULT_GOAL := help

BACKUP ?=
TAIL ?=100
TARGET_ENV ?=
POMI_IMAGE_TAG ?=
POMI_COMPONENT_IMAGE_TAG ?=
SSH_KEY_PATH ?=.local/pomi-lightsail
SSH_KNOWN_HOSTS ?=.local/known_hosts
POMI_KEYCLOAK_URL ?=http://localhost:8080
POMI_KEYCLOAK_REALM ?=pomi
POMI_TOKEN_CLIENT_ID ?=pomi-token-cli
POMI_TOKEN_USERNAME ?=

LIGHTSAIL_SSH = ssh -i "$(SSH_KEY_PATH)" -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile="$(SSH_KNOWN_HOSTS)" "ubuntu@$$(tofu -chdir=terraform output -raw lightsail_static_ip)"

BACKEND_CONFIG = backend.$(TARGET_ENV).hcl

define require_target
	@test -n "$(TARGET_ENV)" || { echo 'Informe TARGET_ENV=homolog ou TARGET_ENV=develop.' >&2; exit 1; }
	@test "$(TARGET_ENV)" = homolog || { echo 'O ambiente develop ainda não foi provisionado.' >&2; exit 1; }
endef

.PHONY: help target-check tf-bootstrap-state tf-init-legacy tf-init tf-migrate-state tf-format tf-validate tf-plan tf-apply ansible-init reconcile-check reconcile deploy-pomi deploy-migrate deploy-data deploy-app deploy-injection deploy-notifier rollback-pomi rollback-data rollback-app rollback-injection rollback-notifier stop-pomi force-stop-pomi status assess-infrastructure import-vercel-pomi-environments remote-bash postgres-tunnel logs-pomi logs-injection logs-notifier logs-platform secrets-pomi validate-backup token token-local token-production

help:
	@printf '%s\n' \
	  'OpenTofu:' \
	  '  make tf-bootstrap-state  Cria bucket e lock remoto usando o state local atual' \
	  '  make tf-init-legacy      Inicializa temporariamente a chave de state anterior' \
	  '  make tf-init TARGET_ENV=homolog Inicializa providers e backend do ambiente' \
	  '  make tf-migrate-state    Migra o state local para o backend remoto' \
	  '  make tf-format           Verifica a formatação dos arquivos OpenTofu' \
	  '  make tf-validate         Valida a configuração OpenTofu' \
	  '  make tf-plan TARGET_ENV=homolog Exibe o plano sem alterar recursos' \
	  '  make tf-apply TARGET_ENV=homolog Aplica o plano OpenTofu' \
	  'Ansible:' \
	  '  make ansible-init        Instala as collections requeridas' \
	  '  make reconcile-check     Simula a reconciliação do host' \
	  '  make reconcile           Reconcilia host, Docker e plataforma' \
	  '  make deploy-pomi         Publica e aplica a API do POMI' \
	  '  make deploy-migrate      Publica e aplica migrations do POMI' \
	  '  make deploy-data         Publica e aplica somente a API Data' \
	  '  make deploy-app          Publica e aplica somente a API App' \
	  '  make deploy-injection    Publica e aplica somente a injection' \
	  '  make deploy-notifier     Publica e aplica somente o notifier' \
	  '  make deploy-keycloak     Publica tema e configuração do Keycloak sem as APIs' \
	  '  make rollback-pomi POMI_IMAGE_TAG=<tag>' \
	  '  make rollback-data POMI_COMPONENT_IMAGE_TAG=<tag>' \
	  '  make rollback-app POMI_COMPONENT_IMAGE_TAG=<tag>' \
	  '  make rollback-injection POMI_COMPONENT_IMAGE_TAG=<tag>' \
	  '  make rollback-notifier POMI_COMPONENT_IMAGE_TAG=<tag>' \
	  '  make stop-pomi           Faz backup validado e para o POMI' \
	  '  make force-stop-pomi     Para o POMI mesmo sem backup válido' \
	  'Operação:' \
	  '  make status              Exibe endpoints, imagens, backup e recursos' \
	  '  make assess-infrastructure Avalia métricas, host e containers da Lightsail' \
	  '  make import-vercel-pomi-environments Mostra imports das variáveis Vercel existentes do POMI' \
	  '  make remote-bash         Abre Bash interativo na Lightsail' \
	  '  make postgres-tunnel     Abre 127.0.0.1:5433 para o PostgreSQL' \
	  '  make logs-pomi           Acompanha logs do Compose do POMI' \
	  '  make logs-injection      Acompanha logs da injection do POMI' \
	  '  make logs-notifier       Acompanha logs do notifier do POMI' \
	  '  make logs-platform       Acompanha logs do Compose da plataforma' \
	  '  make secrets-pomi        Cria ou substitui segredos do POMI' \
	  '  eval "$$(make token-local POMI_TOKEN_USERNAME=<usuario>)"' \
	  '                             Define POMI_ACCESS_TOKEN para o Keycloak local' \
	  '  eval "$$(make token-production POMI_TOKEN_USERNAME=<usuario>)"' \
	  '                             Define POMI_ACCESS_TOKEN para o Keycloak de produção' \
	  '  make validate-backup BACKUP=s3://bucket/key.dump'

tf-bootstrap-state:
	@aws s3api head-bucket --bucket pomi-exchange-terraform-state --region sa-east-1 2>/dev/null || aws s3api create-bucket --bucket pomi-exchange-terraform-state --create-bucket-configuration LocationConstraint=sa-east-1 --region sa-east-1
	@aws s3api wait bucket-exists --bucket pomi-exchange-terraform-state --region sa-east-1
	@aws s3api put-public-access-block --bucket pomi-exchange-terraform-state --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
	@aws s3api put-bucket-encryption --bucket pomi-exchange-terraform-state --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
	@aws s3api put-bucket-versioning --bucket pomi-exchange-terraform-state --versioning-configuration Status=Enabled
	@aws dynamodb describe-table --table-name pomi-exchange-terraform-locks --region sa-east-1 >/dev/null 2>&1 || aws dynamodb create-table --table-name pomi-exchange-terraform-locks --attribute-definitions AttributeName=LockID,AttributeType=S --key-schema AttributeName=LockID,KeyType=HASH --billing-mode PAY_PER_REQUEST --region sa-east-1 >/dev/null
	@aws dynamodb wait table-exists --table-name pomi-exchange-terraform-locks --region sa-east-1

tf-init-legacy:
	@tofu -chdir=terraform init -reconfigure -backend-config="backend.hcl"

target-check:
	$(require_target)

tf-init:
	@test -n "$(TARGET_ENV)" || { echo 'Informe TARGET_ENV=homolog ou TARGET_ENV=develop.' >&2; exit 1; }
	@test "$(TARGET_ENV)" = homolog || { echo 'O backend develop será inicializado somente no provisionamento do ambiente.' >&2; exit 1; }
	@test -f "terraform/$(BACKEND_CONFIG)" || { echo "Arquivo terraform/$(BACKEND_CONFIG) não encontrado." >&2; exit 1; }
	@tofu -chdir=terraform init -reconfigure -backend-config="$(BACKEND_CONFIG)"

tf-migrate-state:
	@test "$(TARGET_ENV)" = homolog || { echo 'A migração de state só é permitida para TARGET_ENV=homolog.' >&2; exit 1; }
	@tofu -chdir=terraform init -migrate-state -backend-config="backend.homolog.hcl"

tf-format:
	@tofu -chdir=terraform fmt -check -recursive

tf-validate: target-check
	@tofu -chdir=terraform validate

tf-plan: target-check
	@tofu -chdir=terraform plan -var="target_environment=$(TARGET_ENV)"

tf-apply: target-check
	@tofu -chdir=terraform apply -var="target_environment=$(TARGET_ENV)"

ansible-init:
	@if locale -a 2>/dev/null | grep -Fxq C.utf8; then export LANG=C.utf8 LC_ALL=C.utf8; fi; \
	  ANSIBLE_LOCAL_TEMP="$${ANSIBLE_LOCAL_TEMP:-/tmp}" \
	  ansible-galaxy collection install -r ansible/requirements.yml

reconcile-check: target-check
	@cd ansible && \
	  if locale -a 2>/dev/null | grep -Fxq C.utf8; then export LANG=C.utf8 LC_ALL=C.utf8; fi; \
	  LIGHTSAIL_HOST="$$(tofu -chdir=../terraform output -raw lightsail_static_ip)" \
	  ANSIBLE_PRIVATE_KEY_FILE="$${SSH_KEY_PATH:-../.local/pomi-lightsail}" \
	  ansible-playbook playbooks/reconcile-host.yml --check --diff

reconcile: target-check
	@cd ansible && \
	  if locale -a 2>/dev/null | grep -Fxq C.utf8; then export LANG=C.utf8 LC_ALL=C.utf8; fi; \
	  LIGHTSAIL_HOST="$$(tofu -chdir=../terraform output -raw lightsail_static_ip)" \
	  ANSIBLE_PRIVATE_KEY_FILE="$${SSH_KEY_PATH:-../.local/pomi-lightsail}" \
	  ansible-playbook playbooks/reconcile-host.yml

deploy-pomi: target-check
	@cd ansible && \
	  if locale -a 2>/dev/null | grep -Fxq C.utf8; then export LANG=C.utf8 LC_ALL=C.utf8; fi; \
	  LIGHTSAIL_HOST="$$(tofu -chdir=../terraform output -raw lightsail_static_ip)" \
	  ANSIBLE_PRIVATE_KEY_FILE="$${SSH_KEY_PATH:-../.local/pomi-lightsail}" \
	  ansible-playbook playbooks/deploy-pomi.yml

deploy-migrate: target-check
	@cd ansible && \
	  if locale -a 2>/dev/null | grep -Fxq C.utf8; then export LANG=C.utf8 LC_ALL=C.utf8; fi; \
	  LIGHTSAIL_HOST="$$(tofu -chdir=../terraform output -raw lightsail_static_ip)" \
	  ANSIBLE_PRIVATE_KEY_FILE="$${SSH_KEY_PATH:-../.local/pomi-lightsail}" \
	  ansible-playbook playbooks/deploy-migrate.yml

deploy-data: target-check
	@cd ansible && \
	  if locale -a 2>/dev/null | grep -Fxq C.utf8; then export LANG=C.utf8 LC_ALL=C.utf8; fi; \
	  LIGHTSAIL_HOST="$$(tofu -chdir=../terraform output -raw lightsail_static_ip)" \
	  ANSIBLE_PRIVATE_KEY_FILE="$${SSH_KEY_PATH:-../.local/pomi-lightsail}" \
	  ansible-playbook playbooks/deploy-data.yml

deploy-app: target-check
	@cd ansible && \
	  if locale -a 2>/dev/null | grep -Fxq C.utf8; then export LANG=C.utf8 LC_ALL=C.utf8; fi; \
	  LIGHTSAIL_HOST="$$(tofu -chdir=../terraform output -raw lightsail_static_ip)" \
	  ANSIBLE_PRIVATE_KEY_FILE="$${SSH_KEY_PATH:-../.local/pomi-lightsail}" \
	  ansible-playbook playbooks/deploy-app.yml

deploy-injection: target-check
	@cd ansible && \
	  if locale -a 2>/dev/null | grep -Fxq C.utf8; then export LANG=C.utf8 LC_ALL=C.utf8; fi; \
	  LIGHTSAIL_HOST="$$(tofu -chdir=../terraform output -raw lightsail_static_ip)" \
	  ANSIBLE_PRIVATE_KEY_FILE="$${SSH_KEY_PATH:-../.local/pomi-lightsail}" \
	  ansible-playbook playbooks/deploy-injection.yml

deploy-notifier: target-check
	@cd ansible && \
	  if locale -a 2>/dev/null | grep -Fxq C.utf8; then export LANG=C.utf8 LC_ALL=C.utf8; fi; \
	  LIGHTSAIL_HOST="$$(tofu -chdir=../terraform output -raw lightsail_static_ip)" \
	  ANSIBLE_PRIVATE_KEY_FILE="$${SSH_KEY_PATH:-../.local/pomi-lightsail}" \
	  ansible-playbook playbooks/deploy-notifier.yml

deploy-keycloak: target-check
	@cd ansible && \
	  if locale -a 2>/dev/null | grep -Fxq C.utf8; then export LANG=C.utf8 LC_ALL=C.utf8; fi; \
	  LIGHTSAIL_HOST="$$(tofu -chdir=../terraform output -raw lightsail_static_ip)" \
	  ANSIBLE_PRIVATE_KEY_FILE="$${SSH_KEY_PATH:-../.local/pomi-lightsail}" \
	  ansible-playbook playbooks/deploy-keycloak.yml

rollback-pomi: target-check
	@test -n "$(POMI_IMAGE_TAG)" || { echo 'Informe POMI_IMAGE_TAG=<tag>.' >&2; exit 1; }
	@cd ansible && \
	  if locale -a 2>/dev/null | grep -Fxq C.utf8; then export LANG=C.utf8 LC_ALL=C.utf8; fi; \
	  LIGHTSAIL_HOST="$$(tofu -chdir=../terraform output -raw lightsail_static_ip)" \
	  ANSIBLE_PRIVATE_KEY_FILE="$${SSH_KEY_PATH:-../.local/pomi-lightsail}" \
	  ansible-playbook playbooks/deploy-pomi.yml -e pomi_use_existing_image=true -e "pomi_image_tag=$(POMI_IMAGE_TAG)"

rollback-data: target-check
	@test -n "$(POMI_COMPONENT_IMAGE_TAG)" || { echo 'Informe POMI_COMPONENT_IMAGE_TAG=<tag>.' >&2; exit 1; }
	@cd ansible && \
	  if locale -a 2>/dev/null | grep -Fxq C.utf8; then export LANG=C.utf8 LC_ALL=C.utf8; fi; \
	  LIGHTSAIL_HOST="$$(tofu -chdir=../terraform output -raw lightsail_static_ip)" \
	  ANSIBLE_PRIVATE_KEY_FILE="$${SSH_KEY_PATH:-../.local/pomi-lightsail}" \
	  ansible-playbook playbooks/deploy-data.yml -e pomi_use_existing_image=true -e "pomi_image_tag=$(POMI_COMPONENT_IMAGE_TAG)"

rollback-app: target-check
	@test -n "$(POMI_COMPONENT_IMAGE_TAG)" || { echo 'Informe POMI_COMPONENT_IMAGE_TAG=<tag>.' >&2; exit 1; }
	@cd ansible && \
	  if locale -a 2>/dev/null | grep -Fxq C.utf8; then export LANG=C.utf8 LC_ALL=C.utf8; fi; \
	  LIGHTSAIL_HOST="$$(tofu -chdir=../terraform output -raw lightsail_static_ip)" \
	  ANSIBLE_PRIVATE_KEY_FILE="$${SSH_KEY_PATH:-../.local/pomi-lightsail}" \
	  ansible-playbook playbooks/deploy-app.yml -e pomi_use_existing_image=true -e "pomi_image_tag=$(POMI_COMPONENT_IMAGE_TAG)"

rollback-injection: target-check
	@test -n "$(POMI_COMPONENT_IMAGE_TAG)" || { echo 'Informe POMI_COMPONENT_IMAGE_TAG=<tag>.' >&2; exit 1; }
	@cd ansible && \
	  if locale -a 2>/dev/null | grep -Fxq C.utf8; then export LANG=C.utf8 LC_ALL=C.utf8; fi; \
	  LIGHTSAIL_HOST="$$(tofu -chdir=../terraform output -raw lightsail_static_ip)" \
	  ANSIBLE_PRIVATE_KEY_FILE="$${SSH_KEY_PATH:-../.local/pomi-lightsail}" \
	  ansible-playbook playbooks/deploy-injection.yml -e pomi_use_existing_image=true -e "pomi_image_tag=$(POMI_COMPONENT_IMAGE_TAG)"

rollback-notifier: target-check
	@test -n "$(POMI_COMPONENT_IMAGE_TAG)" || { echo 'Informe POMI_COMPONENT_IMAGE_TAG=<tag>.' >&2; exit 1; }
	@cd ansible && \
	  if locale -a 2>/dev/null | grep -Fxq C.utf8; then export LANG=C.utf8 LC_ALL=C.utf8; fi; \
	  LIGHTSAIL_HOST="$$(tofu -chdir=../terraform output -raw lightsail_static_ip)" \
	  ANSIBLE_PRIVATE_KEY_FILE="$${SSH_KEY_PATH:-../.local/pomi-lightsail}" \
	  ansible-playbook playbooks/deploy-notifier.yml -e pomi_use_existing_image=true -e "pomi_image_tag=$(POMI_COMPONENT_IMAGE_TAG)"

stop-pomi: target-check
	@cd ansible && \
	  if locale -a 2>/dev/null | grep -Fxq C.utf8; then export LANG=C.utf8 LC_ALL=C.utf8; fi; \
	  LIGHTSAIL_HOST="$$(tofu -chdir=../terraform output -raw lightsail_static_ip)" \
	  ANSIBLE_PRIVATE_KEY_FILE="$${SSH_KEY_PATH:-../.local/pomi-lightsail}" \
	  ansible-playbook playbooks/stop-pomi.yml

force-stop-pomi: target-check
	@cd ansible && \
	  if locale -a 2>/dev/null | grep -Fxq C.utf8; then export LANG=C.utf8 LC_ALL=C.utf8; fi; \
	  LIGHTSAIL_HOST="$$(tofu -chdir=../terraform output -raw lightsail_static_ip)" \
	  ANSIBLE_PRIVATE_KEY_FILE="$${SSH_KEY_PATH:-../.local/pomi-lightsail}" \
	  ansible-playbook playbooks/stop-pomi.yml -e pomi_force_stop=true

status: target-check
	@./scripts/infra-status.sh

assess-infrastructure: target-check
	@./scripts/assess-infrastructure.sh

import-vercel-pomi-environments: target-check
	@./scripts/import-vercel-project-environments.sh pomi

remote-bash: target-check
	@./scripts/open-lightsail-bash.sh

postgres-tunnel: target-check
	@./slices/pomi/scripts/open-db-tunnel.sh

logs-pomi: target-check
	@$(LIGHTSAIL_SSH) 'sudo docker compose --file /opt/pomi/compose/pomi.yaml logs --follow --tail=$(TAIL)'

logs-injection: target-check
	@$(LIGHTSAIL_SSH) 'sudo docker compose --file /opt/pomi/compose/pomi.yaml logs --follow --tail=$(TAIL) injection'

logs-notifier: target-check
	@$(LIGHTSAIL_SSH) 'sudo docker compose --file /opt/pomi/compose/pomi.yaml logs --follow --tail=$(TAIL) notifier'

logs-platform: target-check
	@$(LIGHTSAIL_SSH) 'sudo docker compose --file /opt/pomi/compose/platform.yaml logs --follow --tail=$(TAIL)'

secrets-pomi: target-check
	@./slices/pomi/scripts/configure-secrets.sh

token:
	@test -n "$(POMI_TOKEN_USERNAME)" || { echo 'Informe POMI_TOKEN_USERNAME=<usuario>.' >&2; exit 1; }
	@command -v jq >/dev/null || { echo 'jq é necessário para extrair o access token.' >&2; exit 1; }
	@printf 'Senha Keycloak: ' >&2; stty -echo; IFS= read -r password; stty echo; printf '\n' >&2; \
	response="$$(curl --fail --silent --show-error \
		--data-urlencode 'grant_type=password' \
		--data-urlencode 'client_id=$(POMI_TOKEN_CLIENT_ID)' \
		--data-urlencode 'username=$(POMI_TOKEN_USERNAME)' \
		--data-urlencode "password=$$password" \
		--data-urlencode 'scope=openid email profile' \
		'$(POMI_KEYCLOAK_URL)/realms/$(POMI_KEYCLOAK_REALM)/protocol/openid-connect/token')" || exit $$?; \
	token="$$(printf '%s' "$$response" | jq -er '.access_token')" || { echo 'A resposta não contém access_token.' >&2; exit 1; }; \
	printf "export POMI_ACCESS_TOKEN='%s'\n" "$$token"

token-local: token

token-production:
	@$(MAKE) --no-print-directory token \
		POMI_KEYCLOAK_URL="$$(tofu -chdir=terraform output -raw pomi_keycloak_url)" \
		POMI_TOKEN_USERNAME="$(POMI_TOKEN_USERNAME)"

validate-backup:
	@test -n "$(BACKUP)" || { echo 'Informe BACKUP=s3://bucket/postgres/key.dump.' >&2; exit 1; }
	@./slices/pomi/scripts/validate-backup.sh "$(BACKUP)"
