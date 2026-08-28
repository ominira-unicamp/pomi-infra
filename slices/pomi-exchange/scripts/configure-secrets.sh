#!/usr/bin/env bash

set -euo pipefail

for command_name in aws openssl awk mktemp; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Erro: o comando '$command_name' não está instalado." >&2
    exit 1
  fi
done

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd -- "$script_dir/../../.." && pwd)"
terraform_dir="$repo_dir/terraform"
tfvars_file="$terraform_dir/terraform.tfvars"

default_region="${AWS_REGION:-$(aws configure get region 2>/dev/null || true)}"
default_region="${default_region:-sa-east-1}"

read -r -p "Região AWS [$default_region]: " aws_region
aws_region="${aws_region:-$default_region}"

read -r -p "Perfil AWS (vazio para usar o perfil atual): " aws_profile

aws_args=(--region "$aws_region")
if [[ -n "$aws_profile" ]]; then
  aws_args+=(--profile "$aws_profile")
fi

if ! aws "${aws_args[@]}" sts get-caller-identity >/dev/null; then
  echo "Erro: não foi possível autenticar na AWS." >&2
  exit 1
fi

read -r -p "Prefixo dos parâmetros [/pomi]: " parameter_prefix
parameter_prefix="${parameter_prefix:-/pomi}"
parameter_prefix="/${parameter_prefix#/}"
parameter_prefix="${parameter_prefix%/}"

jwt_parameter_name="$parameter_prefix/jwt"
api_key_parameter_name="$parameter_prefix/api-key"
smtp_parameter_name="$parameter_prefix/smtp-password"
openobserve_parameter_name="$parameter_prefix/openobserve-auth"

read_secret() {
  local prompt="$1"
  local result

  read -r -s -p "$prompt" result
  echo

  if [[ -z "$result" ]]; then
    echo "Erro: o valor não pode ser vazio." >&2
    exit 1
  fi

  REPLY="$result"
}

put_parameter() {
  local parameter_name="$1"
  local parameter_value="$2"
  local value_file

  value_file="$(mktemp)"
  chmod 600 "$value_file"
  printf '%s' "$parameter_value" >"$value_file"

  if ! aws "${aws_args[@]}" ssm put-parameter \
    --name "$parameter_name" \
    --description "Segredo de produção do POMI Exchange" \
    --type SecureString \
    --tier Standard \
    --value "file://$value_file" \
    --overwrite \
    >/dev/null; then
    rm -f "$value_file"
    echo "Erro: não foi possível configurar $parameter_name." >&2
    return 1
  fi

  rm -f "$value_file"

  echo "Configurado: $parameter_name"
}

echo
echo "Gerando JWT secret e API key com fonte criptograficamente segura..."
jwt_secret_value="$(openssl rand -base64 48 | tr -d '\n')"
api_key_value="$(openssl rand -hex 48)"

read_secret "Senha SMTP: "
smtp_password="$REPLY"

read_secret "Credencial OPENOBSERVE_AUTH completa (Basic ...): "
openobserve_auth="$REPLY"
if [[ "$openobserve_auth" != "Basic "* ]]; then
  unset openobserve_auth
  echo "Erro: a credencial deve começar com 'Basic '." >&2
  exit 1
fi

echo
put_parameter "$jwt_parameter_name" "$jwt_secret_value"
put_parameter "$api_key_parameter_name" "$api_key_value"
put_parameter "$smtp_parameter_name" "$smtp_password"
put_parameter "$openobserve_parameter_name" "$openobserve_auth"

unset jwt_secret_value api_key_value smtp_password
unset openobserve_auth

if [[ ! -f "$tfvars_file" ]]; then
  cp "$terraform_dir/terraform.tfvars.example" "$tfvars_file"
fi

tfvars_tmp="$(mktemp "$terraform_dir/.terraform.tfvars.XXXXXX")"
trap 'rm -f "$tfvars_tmp"' EXIT

awk \
  -v region="$aws_region" \
  -v jwt="$jwt_parameter_name" \
  -v api_key="$api_key_parameter_name" \
  -v smtp="$smtp_parameter_name" \
  -v openobserve="$openobserve_parameter_name" '
    BEGIN {
      has_jwt = 0
      has_api_key = 0
      has_smtp = 0
      has_openobserve = 0
    }
    /^(jwt_secret_arn|admin_api_key_secret_arn|smtp_password_secret_arn|openobserve_auth_secret_arn|alarm_email|backend_image_tag|backend_cpu|backend_memory)[[:space:]]*=/ {
      next
    }
    /^aws_region[[:space:]]*=/ {
      print "aws_region = \"" region "\""
      next
    }
    /^jwt_parameter_name[[:space:]]*=/ {
      print "jwt_parameter_name = \"" jwt "\""
      has_jwt = 1
      next
    }
    /^admin_api_key_parameter_name[[:space:]]*=/ {
      print "admin_api_key_parameter_name = \"" api_key "\""
      has_api_key = 1
      next
    }
    /^smtp_password_parameter_name[[:space:]]*=/ {
      print "smtp_password_parameter_name = \"" smtp "\""
      has_smtp = 1
      next
    }
    /^openobserve_auth_parameter_name[[:space:]]*=/ {
      print "openobserve_auth_parameter_name = \"" openobserve "\""
      has_openobserve = 1
      next
    }
    { print }
    END {
      if (!has_jwt) {
        print "jwt_parameter_name = \"" jwt "\""
      }
      if (!has_api_key) {
        print "admin_api_key_parameter_name = \"" api_key "\""
      }
      if (!has_smtp) {
        print "smtp_password_parameter_name = \"" smtp "\""
      }
      if (!has_openobserve) {
        print "openobserve_auth_parameter_name = \"" openobserve "\""
      }
    }
  ' "$tfvars_file" >"$tfvars_tmp"

chmod 600 "$tfvars_tmp"
mv "$tfvars_tmp" "$tfvars_file"
trap - EXIT

if command -v tofu >/dev/null 2>&1; then
  tofu -chdir="$terraform_dir" fmt terraform.tfvars >/dev/null
fi

echo
echo "Configuração concluída."
echo "Os nomes dos parâmetros foram gravados em: $tfvars_file"
echo "Os valores sensíveis estão somente no Parameter Store como SecureString."
