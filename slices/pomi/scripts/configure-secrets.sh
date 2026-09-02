#!/usr/bin/env bash

set -euo pipefail

for command_name in aws openssl; do
  command -v "$command_name" >/dev/null 2>&1 || {
    echo "Erro: '$command_name' não está instalado." >&2
    exit 1
  }
done

aws_region="${AWS_REGION:-$(aws configure get region 2>/dev/null || true)}"
aws_region="${aws_region:-sa-east-1}"
keycloak_parameter_name="${POMI_KEYCLOAK_ADMIN_PASSWORD_PARAMETER_NAME:-/pomi/planner/test/keycloak-admin-password}"
data_admin_token_parameter_name="${POMI_DATA_ADMIN_TOKEN_PARAMETER_NAME:-/pomi/planner/test/data-admin-token}"
notifier_unsubscribe_secret_parameter_name="${POMI_NOTIFIER_UNSUBSCRIBE_SECRET_PARAMETER_NAME:-/pomi/planner/test/notifier-unsubscribe-secret}"

ensure_secret() {
  local parameter_name="$1" description="$2" value
  if aws ssm get-parameter --region "$aws_region" --name "$parameter_name" >/dev/null 2>&1; then
    echo "O segredo $parameter_name já existe; nenhuma alteração foi realizada."
    return
  fi

  value="$(openssl rand -base64 36 | tr -d '\n')"
  aws ssm put-parameter \
    --region "$aws_region" \
    --name "$parameter_name" \
    --description "$description" \
    --type SecureString \
    --tier Standard \
    --value "$value" >/dev/null
  unset value
  echo "Segredo $parameter_name configurado no Parameter Store."
}

ensure_secret "$keycloak_parameter_name" "Administrador Keycloak do ambiente de teste do planejador POMI"
ensure_secret "$data_admin_token_parameter_name" "Token administrativo da API Data do ambiente de teste do POMI"
ensure_secret "$notifier_unsubscribe_secret_parameter_name" "Segredo de descadastro do notifier do ambiente de teste do POMI"
