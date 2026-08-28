#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 1 || "$1" != s3://* ]]; then
  echo "Uso: $0 s3://bucket/chave.dump" >&2
  exit 1
fi

for command_name in aws docker mktemp; do
  command -v "$command_name" >/dev/null 2>&1 || {
    echo "Erro: '$command_name' não está instalado." >&2
    exit 1
  }
done

backup_uri="$1"
temporary_dir="$(mktemp -d)"
container_name="pomi-backup-validation-$$"

cleanup() {
  docker rm --force "$container_name" >/dev/null 2>&1 || true
  rm -rf "$temporary_dir"
}
trap cleanup EXIT

aws s3 cp "$backup_uri" "$temporary_dir/backup.dump"
docker run --rm \
  --volume "$temporary_dir:/backup:ro" \
  postgres:18-alpine \
  pg_restore --list /backup/backup.dump >/dev/null

docker run \
  --detach \
  --name "$container_name" \
  --env POSTGRES_PASSWORD=validation \
  postgres:18-alpine >/dev/null

for attempt in {1..24}; do
  if docker exec "$container_name" pg_isready -U postgres >/dev/null 2>&1; then
    break
  fi
  [[ "$attempt" == 24 ]] && {
    docker logs "$container_name" >&2
    exit 1
  }
  sleep 2
done

docker cp "$temporary_dir/backup.dump" "$container_name:/tmp/backup.dump"
docker exec "$container_name" \
  pg_restore --exit-on-error --no-owner --no-privileges -U postgres -d postgres /tmp/backup.dump

echo "Backup restaurado com sucesso em PostgreSQL temporário."
