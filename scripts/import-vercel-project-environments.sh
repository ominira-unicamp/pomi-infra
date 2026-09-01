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
    keys=(VITE_DATA_API_URL VITE_APP_API_URL VITE_KEYCLOAK_URL VITE_KEYCLOAK_REALM VITE_KEYCLOAK_CLIENT_ID)
    declare -A targets=(
      [VITE_DATA_API_URL]='["production","preview"]'
      [VITE_APP_API_URL]='["production","preview"]'
      [VITE_KEYCLOAK_URL]='["production","preview","development"]'
      [VITE_KEYCLOAK_REALM]='["production","preview","development"]'
      [VITE_KEYCLOAK_CLIENT_ID]='["production","preview","development"]'
    )
    ;;
  exchange)
    project_id="$(tofu -chdir="$terraform_dir" output -raw vercel_project_id)"
    resource_prefix="module.pomi_exchange.vercel_project_environment_variable.frontend"
    keys=(VITE_API_URL)
    declare -A targets=(
      [VITE_API_URL]='["production","preview","development"]'
    )
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

has_incompatible_environment=0

for key in "${keys[@]}"; do
  target="${targets[$key]}"

  mapfile -t ids < <(jq -r --arg key "$key" --argjson target "$target" '
    [.envs[] | select(.key == $key and ((.target | sort) == ($target | sort))) | .id][]
  ' <<<"$payload")

  if (( ${#ids[@]} == 1 )); then
    printf "tofu -chdir=terraform import '%s[\"%s\"]' '%s/%s'\n" \
      "$resource_prefix" "$key" "$project_id" "${ids[0]}"
    continue
  fi

  mapfile -t ids < <(jq -r --arg key "$key" '
    [.envs[] | select(.key == $key) | .id][]
  ' <<<"$payload")

  if (( ${#ids[@]} == 0 )); then
    echo "Ausente na Vercel: $key; o tf-apply irá criá-la."
    continue
  fi

  if (( ${#ids[@]} == 1 )); then
    echo "Aviso: $key será importada com targets diferentes; o tf-apply irá reconciliá-los."
    printf "tofu -chdir=terraform import '%s[\"%s\"]' '%s/%s'\n" \
      "$resource_prefix" "$key" "$project_id" "${ids[0]}"
    continue
  fi

  echo "Erro: $key existe ${#ids[@]} vezes com targets diferentes; consolide as variáveis antes de importar." >&2
  has_incompatible_environment=1
done

if (( has_incompatible_environment )); then
  exit 1
fi
