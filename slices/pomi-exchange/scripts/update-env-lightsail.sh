#!/usr/bin/env bash

set -euo pipefail

sudo install -m 0600 -o root -g root /tmp/exchange.env /opt/pomi/exchange/backend.env

compose_file=/opt/pomi/compose/exchange.yaml
[[ -f "$compose_file" ]] || {
  echo "Projeto Compose do Exchange não encontrado; execute um deploy completo primeiro." >&2
  exit 1
}

backend_image="$(sudo docker inspect --format '{{.Config.Image}}' pomi-exchange-backend 2>/dev/null || true)"
[[ -n "$backend_image" ]] || {
  echo "Container do Exchange não encontrado; execute um deploy completo primeiro." >&2
  exit 1
}

compose_project="$(sudo docker inspect --format '{{with index .Config.Labels "com.docker.compose.project"}}{{.}}{{end}}' pomi-exchange-backend)"
if [[ "$compose_project" != "pomi-exchange" ]]; then
  sudo docker rm --force pomi-exchange-backend >/dev/null
fi

if ! sudo env EXCHANGE_IMAGE="$backend_image" \
  docker compose --file "$compose_file" up --detach --force-recreate \
  --wait --wait-timeout 120 api; then
  sudo env EXCHANGE_IMAGE="$backend_image" \
    docker compose --file "$compose_file" logs --tail 100 api >&2
  exit 1
fi
