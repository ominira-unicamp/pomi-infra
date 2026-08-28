#!/usr/bin/env bash

set -euo pipefail

compose_file=/opt/pomi/compose/platform.yaml

sudo docker compose --file "$compose_file" run --rm --no-deps caddy \
  caddy validate --config /etc/caddy/Caddyfile

if sudo docker inspect pomi-caddy >/dev/null 2>&1; then
  compose_project="$(sudo docker inspect --format '{{with index .Config.Labels "com.docker.compose.project"}}{{.}}{{end}}' pomi-caddy)"
  if [[ "$compose_project" != "pomi-platform" ]]; then
    sudo docker rm --force pomi-caddy >/dev/null
  fi
fi

sudo docker compose --file "$compose_file" up --detach --wait --wait-timeout 60 caddy
sudo docker compose --file "$compose_file" exec --no-TTY caddy \
  caddy reload --config /etc/caddy/Caddyfile
