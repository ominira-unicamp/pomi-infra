#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd -- "$script_dir/.." && pwd)"
terraform_dir="$repo_dir/terraform"
ssh_key="${SSH_KEY_PATH:-$repo_dir/.local/pomi-lightsail}"
known_hosts_file="$repo_dir/.local/known_hosts"

for command_name in ssh tofu; do
  command -v "$command_name" >/dev/null 2>&1 || {
    echo "Erro: '$command_name' não está instalado." >&2
    exit 1
  }
done

[[ -f "$ssh_key" ]] || {
  echo "Erro: chave SSH não encontrada em $ssh_key." >&2
  exit 1
}

lightsail_ip="$(tofu -chdir="$terraform_dir" output -raw lightsail_static_ip)"

exec ssh \
  -tt \
  -i "$ssh_key" \
  -o StrictHostKeyChecking=accept-new \
  -o UserKnownHostsFile="$known_hosts_file" \
  -o ConnectTimeout=10 \
  "ubuntu@$lightsail_ip" \
  'exec bash --login'
