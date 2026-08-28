#!/usr/bin/env bash

set -euo pipefail

project_name="${1:-}"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd -- "$script_dir/.." && pwd)"
terraform_dir="$repo_dir/terraform"

for command_name in curl jq tofu; do
  command -v "$command_name" >/dev/null 2>&1 || {
    echo "Erro: '$command_name' não está instalado." >&2
    exit 1
  }
done

[[ -n "${VERCEL_API_TOKEN:-}" ]] || {
  echo "Erro: VERCEL_API_TOKEN é obrigatório." >&2
  exit 1
}

case "$project_name" in
  pomi)
    project_id="$(tofu -chdir="$terraform_dir" output -raw pomi_vercel_project_id)"
    resource_prefix="module.pomi.vercel_project_environment_variable.frontend"
    target='["production","preview"]'
    keys=(VITE_DATA_API_URL VITE_APP_API_URL VITE_KEYCLOAK_URL VITE_KEYCLOAK_REALM VITE_KEYCLOAK_CLIENT_ID)
    ;;
  exchange)
    project_id="$(tofu -chdir="$terraform_dir" output -raw vercel_project_id)"
    resource_prefix="module.pomi_exchange.vercel_project_environment_variable.frontend"
    target='["production","preview","development"]'
    keys=(VITE_API_URL)
    ;;
  *)
    echo "Uso: $0 <pomi|exchange>" >&2
    exit 1
    ;;
esac

request_url="https://api.vercel.com/v9/projects/${project_id}/env"
if [[ -n "${VERCEL_TEAM_ID:-}" ]]; then
  request_url+="?teamId=${VERCEL_TEAM_ID}"
fi

payload="$(curl --fail-with-body --silent --show-error \
  --header "Authorization: Bearer ${VERCEL_API_TOKEN}" \
  "$request_url")"

for key in "${keys[@]}"; do
  mapfile -t ids < <(jq -r --arg key "$key" --argjson target "$target" '
    [.envs[] | select(.key == $key and ((.target | sort) == ($target | sort))) | .id][]
  ' <<<"$payload")

  if (( ${#ids[@]} != 1 )); then
    echo "Erro: esperado exatamente uma variável para $key, encontradas ${#ids[@]}." >&2
    exit 1
  fi

  printf "tofu -chdir=terraform import '%s[\"%s\"]' '%s/%s'\n" \
    "$resource_prefix" "$key" "$project_id" "${ids[0]}"
done
