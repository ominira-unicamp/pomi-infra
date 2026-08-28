#!/usr/bin/env bash

set -euo pipefail

export AWS_PAGER=""

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd -- "$script_dir/.." && pwd)"
terraform_dir="$repo_dir/terraform"
ssh_key="${SSH_KEY_PATH:-$repo_dir/.local/pomi-lightsail}"
known_hosts_file="${SSH_KNOWN_HOSTS:-$repo_dir/.local/known_hosts}"
window_hours="${INFRA_ASSESSMENT_WINDOW_HOURS:-168}"

for command_name in aws date jq ssh tofu; do
  command -v "$command_name" >/dev/null 2>&1 || {
    echo "Erro: '$command_name' não está instalado." >&2
    exit 1
  }
done

[[ -f "$ssh_key" ]] || {
  echo "Erro: chave SSH não encontrada em $ssh_key." >&2
  exit 1
}

[[ "$window_hours" =~ ^[1-9][0-9]*$ ]] || {
  echo "Erro: INFRA_ASSESSMENT_WINDOW_HOURS deve ser um inteiro positivo." >&2
  exit 1
}

metric_period=""
for candidate_period in 60 300 900 1800 3600 21600 86400; do
  if (( window_hours * 3600 / candidate_period <= 1440 )); then
    metric_period="$candidate_period"
    break
  fi
done

[[ -n "$metric_period" ]] || {
  echo "Erro: INFRA_ASSESSMENT_WINDOW_HOURS é grande demais para as métricas da Lightsail." >&2
  exit 1
}

tf_output() {
  tofu -chdir="$terraform_dir" output -raw "$1"
}

section() {
  printf '\n== %s ==\n' "$1"
}

metric_summary() {
  local metric_name="$1" unit="$2" statistic="$3" payload count average maximum

  payload="$(aws lightsail get-instance-metric-data \
    --region "$aws_region" \
    --instance-name "$instance_name" \
    --metric-name "$metric_name" \
    --unit "$unit" \
    --period "$metric_period" \
    --start-time "$start_time" \
    --end-time "$end_time" \
    --statistics "$statistic" \
    --output json)"
  count="$(jq '.metricData | length' <<<"$payload")"

  if [[ "$count" == "0" ]]; then
    printf '%-28s sem dados\n' "$metric_name"
    return
  fi

  average="$(jq -r --arg statistic "${statistic,,}" '[.metricData[][$statistic] // empty] | if length == 0 then "n/a" else (add / length | tostring) end' <<<"$payload")"
  maximum="$(jq -r --arg statistic "${statistic,,}" '[.metricData[][$statistic] // empty] | if length == 0 then "n/a" else max | tostring end' <<<"$payload")"
  printf '%-28s média: %-12s pico: %-12s %s\n' "$metric_name" "$average" "$maximum" "$unit"
}

aws_region="$(tf_output aws_region)"
instance_name="$(tf_output lightsail_instance_name)"
lightsail_ip="$(tf_output lightsail_static_ip)"
end_time="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
start_time="$(date -u -d "${window_hours} hours ago" +%Y-%m-%dT%H:%M:%SZ)"

section "Escopo"
printf 'Instância: %s\nRegião: %s\nJanela: últimas %s horas\nGranularidade: %s segundos\n' "$instance_name" "$aws_region" "$window_hours" "$metric_period"

section "Métricas Lightsail"
metric_summary "CPUUtilization" "Percent" "Average"
metric_summary "BurstCapacityPercentage" "Percent" "Average"
metric_summary "StatusCheckFailed" "Count" "Maximum"

section "Host e containers"
ssh \
  -i "$ssh_key" \
  -o StrictHostKeyChecking=accept-new \
  -o UserKnownHostsFile="$known_hosts_file" \
  -o ConnectTimeout=10 \
  "ubuntu@$lightsail_ip" \
  'set -euo pipefail

severity() {
  local value="$1" warning="$2" critical="$3"
  if (( value >= critical )); then
    printf "CRÍTICO"
  elif (( value >= warning )); then
    printf "ATENÇÃO"
  else
    printf "OK"
  fi
}

mem_total=$(awk "/MemTotal/ { print \$2 }" /proc/meminfo)
mem_available=$(awk "/MemAvailable/ { print \$2 }" /proc/meminfo)
mem_used=$((mem_total - mem_available))
mem_percent=$((mem_used * 100 / mem_total))
swap_total=$(awk "/SwapTotal/ { print \$2 }" /proc/meminfo)
swap_free=$(awk "/SwapFree/ { print \$2 }" /proc/meminfo)
swap_used=$((swap_total - swap_free))
swap_percent=0
if (( swap_total > 0 )); then
  swap_percent=$((swap_used * 100 / swap_total))
fi
disk_percent=$(df --output=pcent / | tail -n 1 | tr -dc "0-9")

printf "Memória: %s%% (%s)\n" "$mem_percent" "$(severity "$mem_percent" 80 90)"
printf "Swap:    %s%% (%s)\n" "$swap_percent" "$(severity "$swap_percent" 10 30)"
printf "Disco /: %s%% (%s)\n" "$disk_percent" "$(severity "$disk_percent" 75 90)"
printf "Load:    %s\n" "$(cut -d " " -f 1-3 /proc/loadavg)"

printf "\nContainers:\n"
sudo docker ps --format "table {{.Names}}\t{{.Status}}\t{{.RunningFor}}"

printf "\nUso atual dos containers:\n"
sudo docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"

printf "\nReinícios e healthchecks:\n"
container_ids=$(sudo docker ps -aq)
if [[ -n "$container_ids" ]]; then
  sudo docker inspect --format "{{.Name}} status={{.State.Status}} restarts={{.RestartCount}} health={{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}" $container_ids
fi

printf "\nEventos de OOM nos últimos 7 dias:\n"
sudo journalctl -k --since "7 days ago" --no-pager | grep -Ei "out of memory|killed process|oom-kill" | tail -n 20 || true'
