#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd -- "$script_dir/../../.." && pwd)"
terraform_dir="$repo_dir/terraform"

if locale -a 2>/dev/null | grep -Fxq 'C.utf8'; then
  export LANG=C.utf8
  export LC_ALL=C.utf8
fi

command -v ansible-playbook >/dev/null 2>&1 || {
  echo "Erro: 'ansible-playbook' não está instalado." >&2
  exit 1
}

playbook_args=(playbooks/stop-pomi.yml)
if [[ "${FORCE_STOP:-false}" == "true" ]]; then
  playbook_args+=(-e pomi_force_stop=true)
fi

cd "$repo_dir/ansible"
LIGHTSAIL_HOST="$(tofu -chdir="$terraform_dir" output -raw lightsail_static_ip)" \
ANSIBLE_PRIVATE_KEY_FILE="${SSH_KEY_PATH:-$repo_dir/.local/pomi-lightsail}" \
  exec ansible-playbook "${playbook_args[@]}"
