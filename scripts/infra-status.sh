#!/usr/bin/env bash

set -euo pipefail

export AWS_PAGER=""

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd -- "$script_dir/.." && pwd)"
terraform_dir="$repo_dir/terraform"
ssh_key="${SSH_KEY_PATH:-$repo_dir/.local/pomi-lightsail}"
known_hosts_file="$repo_dir/.local/known_hosts"

for command_name in aws curl ssh tofu; do
  command -v "$command_name" >/dev/null 2>&1 || {
    echo "Erro: '$command_name' não está instalado." >&2
    exit 1
  }
done

[[ -f "$ssh_key" ]] || {
  echo "Erro: chave SSH não encontrada em $ssh_key." >&2
  exit 1
}

tf_output() {
  tofu -chdir="$terraform_dir" output -raw "$1"
}

section() {
  printf '\n== %s ==\n' "$1"
}

curl_status() {
  local url="$1" code
  code="$(curl --connect-timeout 5 --max-time 15 --output /dev/null --silent --show-error --write-out '%{http_code}' "$url" 2>&1)" || {
    printf '%s: indisponível (%s)\n' "$url" "$code"
    return
  }
  printf '%s: HTTP %s\n' "$url" "$code"
}

aws_region="$(tf_output aws_region)"
lightsail_ip="$(tf_output lightsail_static_ip)"
pomi_data_api_url="$(tf_output pomi_data_api_url)"
pomi_app_api_url="$(tf_output pomi_app_api_url)"
pomi_repository="$(tf_output pomi_backend_repository_url)"
backup_bucket="$(tf_output pomi_backup_bucket)"

section "Endpoints públicos"
curl_status "$pomi_data_api_url/public-openapi.json"
curl_status "$pomi_app_api_url/health"

section "Imagens ECR mais recentes"
for repository in "$pomi_repository" "$(tf_output pomi_injection_repository_url)" "$(tf_output pomi_notifier_repository_url)"; do
  repository_name="${repository#*/}"
  printf '\n%s\n' "$repository"
  aws ecr describe-images \
    --region "$aws_region" \
    --repository-name "$repository_name" \
    --query 'reverse(sort_by(imageDetails,&imagePushedAt))[0:5].[imageTags[0],imagePushedAt,imageDigest]' \
    --output table || true
done

section "Último backup PostgreSQL"
aws s3api list-objects-v2 \
  --region "$aws_region" \
  --bucket "$backup_bucket" \
  --prefix postgres/ \
  --query 'reverse(sort_by(Contents,&LastModified))[0].[Key,LastModified,Size]' \
  --output table || true

section "Host Lightsail ($lightsail_ip)"
ssh \
  -i "$ssh_key" \
  -o StrictHostKeyChecking=accept-new \
  -o UserKnownHostsFile="$known_hosts_file" \
  -o ConnectTimeout=10 \
  "ubuntu@$lightsail_ip" \
  'set -u
   echo "-- Compose --"
   for definition in platform pomi; do
     compose_file="/opt/pomi/compose/$definition.yaml"
     if sudo test -f "$compose_file"; then
       sudo docker compose --file "$compose_file" ps
     else
       echo "$definition: composição ainda não instalada"
     fi
   done
   echo "-- Recursos --"
   free -h
   swapon --show
   df -h / /opt/pomi
   echo "-- Containers --"
   sudo docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" || true'
