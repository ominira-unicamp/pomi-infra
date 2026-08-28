#!/usr/bin/env bash

set -euo pipefail

if [[ -z "${IMAGE_REF:-}" || -z "${REGISTRY_HOST:-}" || -z "${API_HOST:-}" ]]; then
  echo "IMAGE_REF, REGISTRY_HOST e API_HOST são obrigatórios." >&2
  exit 1
fi

cleanup() {
  sudo docker logout "$REGISTRY_HOST" >/dev/null 2>&1 || true
  rm -f \
    /tmp/exchange.env \
    /tmp/exchange.caddy \
    /tmp/exchange-compose.yaml \
    /tmp/platform-compose.yaml \
    /tmp/otel-collector-config.yaml
}
trap cleanup EXIT

for attempt in {1..120}; do
  [[ -f /var/lib/pomi-bootstrap-complete ]] && break
  sleep 5
done

if [[ ! -f /var/lib/pomi-bootstrap-complete ]]; then
  echo "O bootstrap da Lightsail não terminou dentro de 10 minutos." >&2
  exit 1
fi

bash /tmp/prepare-shared-host.sh

sudo install -m 0600 -o root -g root /tmp/exchange.env /opt/pomi/exchange/backend.env
sudo install -m 0644 -o root -g root /tmp/otel-collector-config.yaml /opt/pomi/otel-collector-config.yaml
sudo install -m 0644 -o root -g root /tmp/exchange.caddy /opt/pomi/caddy/sites/exchange.caddy
sudo install -m 0644 -o root -g root /tmp/exchange-compose.yaml /opt/pomi/compose/exchange.yaml

sudo docker pull "$IMAGE_REF"
sudo docker logout "$REGISTRY_HOST" >/dev/null

for container_name in pomi-exchange-backend pomi-otel-collector; do
  if sudo docker inspect "$container_name" >/dev/null 2>&1; then
    compose_project="$(sudo docker inspect --format '{{with index .Config.Labels "com.docker.compose.project"}}{{.}}{{end}}' "$container_name")"
    if [[ "$compose_project" != "pomi-exchange" ]]; then
      sudo docker rm --force "$container_name" >/dev/null
    fi
  fi
done

compose_file=/opt/pomi/compose/exchange.yaml
if ! sudo env EXCHANGE_IMAGE="$IMAGE_REF" \
  docker compose --file "$compose_file" up --detach --pull never \
  --wait --wait-timeout 120; then
  sudo env EXCHANGE_IMAGE="$IMAGE_REF" \
    docker compose --file "$compose_file" logs --tail 100 >&2
  exit 1
fi

bash /tmp/reconcile-caddy.sh

sudo docker image prune --force >/dev/null
