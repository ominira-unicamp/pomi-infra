#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd -- "$script_dir/../../.." && pwd)"
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

local_port="${POMI_POSTGRES_LOCAL_PORT:-5433}"
[[ "$local_port" =~ ^[1-9][0-9]*$ && "$local_port" -le 65535 ]] || {
  echo "Erro: POMI_POSTGRES_LOCAL_PORT deve estar entre 1 e 65535." >&2
  exit 1
}

lightsail_ip="$(tofu -chdir="$terraform_dir" output -raw lightsail_static_ip)"
ssh_options=(
  -i "$ssh_key"
  -o StrictHostKeyChecking=accept-new
  -o UserKnownHostsFile="$known_hosts_file"
  -o ConnectTimeout=10
  -o ExitOnForwardFailure=yes
  -o ServerAliveInterval=30
  -o ServerAliveCountMax=3
)
postgres_ip="$(
  ssh "${ssh_options[@]}" "ubuntu@$lightsail_ip" \
    "sudo docker inspect --format '{{if .State.Running}}{{with index .NetworkSettings.Networks \"pomi-test-internal\"}}{{.IPAddress}}{{end}}{{end}}' pomi-postgres-test"
)"

[[ -n "$postgres_ip" ]] || {
  echo "Erro: o contêiner pomi-postgres-test não está em execução." >&2
  exit 1
}

printf 'Túnel aberto: postgresql://pomi@127.0.0.1:%s/pomi\n' "$local_port"
printf 'Mantenha este terminal aberto; pressione Ctrl+C para encerrar.\n'

exec ssh "${ssh_options[@]}" \
  -N \
  -L "127.0.0.1:${local_port}:${postgres_ip}:5432" \
  "ubuntu@$lightsail_ip"
