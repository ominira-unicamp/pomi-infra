#!/usr/bin/env bash

set -euo pipefail

if [[ -z "${DATA_IMAGE_REF:-}" || -z "${APP_IMAGE_REF:-}" || -z "${MIGRATE_IMAGE_REF:-}" || -z "${REGISTRY_HOST:-}" || -z "${DATA_API_HOST:-}" || -z "${APP_API_HOST:-}" || -z "${KEYCLOAK_HOST:-}" ]]; then
  echo "DATA_IMAGE_REF, APP_IMAGE_REF, MIGRATE_IMAGE_REF, REGISTRY_HOST, DATA_API_HOST, APP_API_HOST e KEYCLOAK_HOST são obrigatórios." >&2
  exit 1
fi

cleanup() {
  sudo docker logout "$REGISTRY_HOST" >/dev/null 2>&1 || true
  rm -f \
    /tmp/pomi-data.env \
    /tmp/pomi-app.env \
    /tmp/pomi-postgres.env \
    /tmp/pomi-keycloak.env \
    /tmp/pomi-keycloak-config.tar \
    /tmp/pomi-online.caddy \
    /tmp/pomi-compose.yaml \
    /tmp/platform-compose.yaml
}
trap cleanup EXIT

bash /tmp/prepare-shared-host.sh

sudo install -m 0600 -o root -g root /tmp/pomi-data.env /opt/pomi/planner-test/data.env
sudo install -m 0600 -o root -g root /tmp/pomi-app.env /opt/pomi/planner-test/app.env
sudo install -m 0600 -o root -g root /tmp/pomi-postgres.env /opt/pomi/planner-test/postgres.env
sudo install -m 0600 -o root -g root /tmp/pomi-keycloak.env /opt/pomi/planner-test/keycloak.env
sudo install -d -m 0750 -o root -g root /opt/pomi/keycloak-config
sudo tar -xf /tmp/pomi-keycloak-config.tar -C /opt/pomi/keycloak-config
sudo install -m 0644 -o root -g root /tmp/pomi-online.caddy /opt/pomi/caddy/sites/pomi.caddy
sudo install -m 0644 -o root -g root /tmp/pomi-compose.yaml /opt/pomi/compose/pomi.yaml

sudo docker pull postgres:18-alpine
sudo docker pull quay.io/keycloak/keycloak:26.7.0@sha256:0f198be292568439d700cdbfb893e69a6009bb43a94a06a945b1d3d506c76b13
sudo docker pull "$DATA_IMAGE_REF"
sudo docker pull "$APP_IMAGE_REF"
sudo docker pull "$MIGRATE_IMAGE_REF"
sudo docker logout "$REGISTRY_HOST" >/dev/null

for container_name in pomi-postgres-test pomi-data-api-test pomi-app-api-test pomi-migrate-test pomi-keycloak-test; do
  if sudo docker inspect "$container_name" >/dev/null 2>&1; then
    compose_project="$(sudo docker inspect --format '{{with index .Config.Labels "com.docker.compose.project"}}{{.}}{{end}}' "$container_name")"
    if [[ "$compose_project" != "pomi-test" ]]; then
      sudo docker rm --force "$container_name" >/dev/null
    fi
  fi
done

compose_file=/opt/pomi/compose/pomi.yaml
if ! sudo env COMPOSE_PROFILES=api POMI_DATA_IMAGE="$DATA_IMAGE_REF" POMI_APP_IMAGE="$APP_IMAGE_REF" POMI_MIGRATE_IMAGE="$MIGRATE_IMAGE_REF" \
  docker compose --file "$compose_file" up --detach --pull never \
  --force-recreate --remove-orphans --wait --wait-timeout 180; then
  sudo env COMPOSE_PROFILES=api POMI_DATA_IMAGE="$DATA_IMAGE_REF" POMI_APP_IMAGE="$APP_IMAGE_REF" POMI_MIGRATE_IMAGE="$MIGRATE_IMAGE_REF" \
    docker compose --file "$compose_file" logs --tail 100 >&2
  exit 1
fi

bash /tmp/reconcile-caddy.sh
