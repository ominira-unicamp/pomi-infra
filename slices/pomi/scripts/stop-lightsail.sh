#!/usr/bin/env bash

set -euo pipefail

if [[ -z "${DATA_API_HOST:-}" || -z "${APP_API_HOST:-}" || -z "${KEYCLOAK_HOST:-}" ]]; then
  echo "DATA_API_HOST, APP_API_HOST e KEYCLOAK_HOST são obrigatórios." >&2
  exit 1
fi

bash /tmp/prepare-shared-host.sh
sudo install -m 0644 -o root -g root /tmp/pomi-compose.yaml /opt/pomi/compose/pomi.yaml

compose_file=/opt/pomi/compose/pomi.yaml
for service_definition in 'data-api:pomi-data-api-test:30' 'app-api:pomi-app-api-test:30' 'injection:pomi-injection-test:60' 'keycloak:pomi-keycloak-test:60' 'postgres:pomi-postgres-test:60'; do
  IFS=: read -r service_name container_name timeout <<<"$service_definition"
  if ! sudo docker inspect "$container_name" >/dev/null 2>&1; then
    continue
  fi
  compose_project="$(sudo docker inspect --format '{{with index .Config.Labels "com.docker.compose.project"}}{{.}}{{end}}' "$container_name")"
  if [[ "$compose_project" == "pomi-test" ]]; then
    sudo docker compose --file "$compose_file" stop --timeout "$timeout" "$service_name"
  else
    sudo docker stop --time "$timeout" "$container_name" >/dev/null
  fi
done

sudo install -m 0644 -o root -g root /tmp/pomi-offline.caddy /opt/pomi/caddy/sites/pomi.caddy
bash /tmp/reconcile-caddy.sh
rm -f \
  /tmp/pomi-offline.caddy \
  /tmp/pomi-compose.yaml \
  /tmp/platform-compose.yaml
