#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd -- "$script_dir/../../.." && pwd)"
workspace_dir="$(cd -- "$repo_dir/.." && pwd)"
terraform_dir="$repo_dir/terraform"
tfvars_file="$terraform_dir/terraform.tfvars"
backend_dir="${EXCHANGE_BACKEND_DIR:-$workspace_dir/pomi-exchange/pomi-exchange-backend}"
frontend_dir="${EXCHANGE_FRONTEND_DIR:-$workspace_dir/pomi-exchange/pomi-exchange-frontend}"
ssh_key="${SSH_KEY_PATH:-$repo_dir/.local/pomi-lightsail}"
known_hosts_file="$repo_dir/.local/known_hosts"
ssh_options=(-i "$ssh_key" -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile="$known_hosts_file")

for command_name in aws tofu docker ssh scp curl sed; do
  command -v "$command_name" >/dev/null 2>&1 || {
    echo "Erro: '$command_name' não está instalado." >&2
    exit 1
  }
done

[[ -f "$tfvars_file" && -f "$ssh_key" ]] || {
  echo "terraform.tfvars ou chave SSH ausente." >&2
  exit 1
}
[[ -d "$backend_dir" ]] || {
  echo "Backend do Exchange não encontrado em $backend_dir." >&2
  exit 1
}

tfvar() {
  local key="$1" line value
  line="$(awk -v key="$key" '$0 !~ /^[[:space:]]*(#|\/\/)/ && $0 ~ "^[[:space:]]*" key "[[:space:]]*=" { print; exit }' "$tfvars_file")"
  value="${line#*=}"
  value="$(printf '%s' "$value" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  [[ "$value" == '"'*'"' ]] && value="${value:1:${#value}-2}"
  [[ "$value" != "null" ]] && printf '%s' "$value"
}

tf_output() {
  tofu -chdir="$terraform_dir" output -raw "$1"
}

read_parameter() {
  aws ssm get-parameter --name "$1" --with-decryption --query 'Parameter.Value' --output text
}

api_url="$(tf_output api_url)"
api_hostname="$(tf_output api_hostname)"
lightsail_ip="$(tf_output lightsail_static_ip)"
frontend_url="$(tf_output frontend_url)"
aws_region="$(tf_output aws_region)"
repository_url="$(tf_output exchange_backend_repository_url)"
jwt_secret="$(read_parameter "$(tfvar jwt_parameter_name)")"
api_key="$(read_parameter "$(tfvar admin_api_key_parameter_name)")"
smtp_password="$(read_parameter "$(tfvar smtp_password_parameter_name)")"
openobserve_auth="$(read_parameter "$(tfvar openobserve_auth_parameter_name)")"
image_tag="${IMAGE_TAG:-$(date -u +%Y%m%d%H%M%S)}"
image_ref="$repository_url:$image_tag"
registry_host="${repository_url%%/*}"
repository_name="${repository_url#*/}"

backend_env="$(mktemp /tmp/exchange.XXXXXX.env)"
caddy_fragment="$(mktemp /tmp/exchange.XXXXXX.caddy)"
local_registry_login=false
cleanup() {
  if [[ "$local_registry_login" == "true" ]]; then
    docker logout "$registry_host" >/dev/null 2>&1 || true
  fi
  rm -f "$backend_env" "$caddy_fragment"
}
trap cleanup EXIT

printf '%s\n' \
  "NODE_ENV=production" \
  "PORT=3000" \
  "DATABASE_URL=file:/data/pomi.db" \
  "FRONTEND_URL=$frontend_url" \
  "CORS_ORIGIN=$frontend_url" \
  "API_URL=$api_url" \
  "SMTP_HOST=$(tfvar smtp_host)" \
  "SMTP_PORT=$(tfvar smtp_port)" \
  "SMTP_USER=$(tfvar smtp_user)" \
  "SMTP_FROM=$(tfvar smtp_from)" \
  "OPENOBSERVE_URL=$(tfvar openobserve_url)" \
  "LOG_LEVEL=info" \
  "DISABLED_AUTH=false" \
  "secretKey=$jwt_secret" \
  "API_KEY=$api_key" \
  "SMTP_PASS=$smtp_password" \
  "OPENOBSERVE_AUTH=$openobserve_auth" >"$backend_env"
chmod 600 "$backend_env"

sed "s/__API_HOST__/$api_hostname/" \
  "$repo_dir/slices/pomi-exchange/templates/exchange.caddy" >"$caddy_fragment"

if [[ "${USE_EXISTING_IMAGE:-false}" == "true" ]]; then
  aws ecr describe-images \
    --region "$aws_region" \
    --repository-name "$repository_name" \
    --image-ids "imageTag=$image_tag" >/dev/null
else
  aws ecr get-login-password --region "$aws_region" |
    docker login --username AWS --password-stdin "$registry_host"
  local_registry_login=true
  if [[ "${SKIP_DOCKER_BUILD:-false}" != "true" ]]; then
    docker build --file "$backend_dir/Dockerfile" --tag "$image_ref" "$backend_dir"
  else
    docker tag "pomi-exchange-backend:$image_tag" "$image_ref"
  fi
  docker push "$image_ref"
fi

for attempt in {1..30}; do
  if ssh "${ssh_options[@]}" -o ConnectTimeout=5 "ubuntu@$lightsail_ip" true 2>/dev/null; then
    break
  fi
  [[ "$attempt" == 30 ]] && {
    echo "SSH não ficou disponível." >&2
    exit 1
  }
  sleep 10
done

scp "${ssh_options[@]}" \
  "$backend_env" "ubuntu@$lightsail_ip:/tmp/exchange.env"
scp "${ssh_options[@]}" \
  "$caddy_fragment" "ubuntu@$lightsail_ip:/tmp/exchange.caddy"
scp "${ssh_options[@]}" \
  "$repo_dir/slices/platform/templates/Caddyfile" \
  "$repo_dir/slices/platform/templates/otel-collector-config.yaml" \
  "$repo_dir/slices/platform/scripts/prepare-shared-host.sh" \
  "$repo_dir/slices/platform/scripts/reconcile-caddy.sh" \
  "$repo_dir/slices/pomi-exchange/scripts/deploy-lightsail.sh" \
  "ubuntu@$lightsail_ip:/tmp/"
scp "${ssh_options[@]}" \
  "$repo_dir/slices/platform/compose/compose.yaml" \
  "ubuntu@$lightsail_ip:/tmp/platform-compose.yaml"
scp "${ssh_options[@]}" \
  "$repo_dir/slices/pomi-exchange/compose/compose.yaml" \
  "ubuntu@$lightsail_ip:/tmp/exchange-compose.yaml"

aws ecr get-login-password --region "$aws_region" |
  ssh "${ssh_options[@]}" "ubuntu@$lightsail_ip" \
    "set -e; trap \"sudo docker logout '$registry_host' >/dev/null 2>&1 || true\" EXIT; sudo docker login --username AWS --password-stdin '$registry_host'; IMAGE_REF='$image_ref' REGISTRY_HOST='$registry_host' API_HOST='$api_hostname' bash /tmp/deploy-lightsail.sh"
curl --fail --silent --show-error "$api_url/ready" >/dev/null

if [[ "${RUN_INITIAL_SYNC:-false}" == "true" ]]; then
  curl --fail --silent --show-error --request POST --header "x-api-key: $api_key" "$api_url/sync"
  curl --fail --silent --show-error --request POST --header "x-api-key: $api_key" "$api_url/notice-notifications"
fi

if [[ -n "${VERCEL_API_TOKEN:-}" && -d "$frontend_dir" ]]; then
  project_name="$(tfvar vercel_project_name)"
  team_id="$(tfvar vercel_team_id)"
  vercel_args=(deploy --prod --yes --token "$VERCEL_API_TOKEN" --name "$project_name")
  [[ -n "$team_id" ]] && vercel_args+=(--scope "$team_id")
  (cd "$frontend_dir" && VITE_API_URL="$api_url" npx --yes vercel@latest "${vercel_args[@]}")
fi

echo "Deploy do POMI Exchange concluído. API: $api_url"
