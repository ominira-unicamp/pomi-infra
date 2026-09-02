#!/usr/bin/env bash

set -euo pipefail

if ! sudo docker compose version >/dev/null 2>&1; then
  sudo apt-get update
  sudo apt-get install --yes docker-compose-v2
fi

sudo install -d -m 0750 -o root -g root /opt/pomi/compose
sudo install -d -m 0750 -o root -g root /opt/pomi/caddy/sites
sudo install -d -m 0750 -o root -g root /opt/pomi/caddy-data
sudo install -d -m 0750 -o root -g root /opt/pomi/caddy-config
sudo install -d -m 0750 -o 1000 -g 1000 /opt/pomi/data
sudo install -d -m 0750 -o root -g root /opt/pomi/planner-test
sudo install -d -m 0700 -o 70 -g 70 /opt/pomi/postgres-data

if [[ ! -f /swapfile ]]; then
  sudo fallocate -l 2G /swapfile
  sudo chmod 0600 /swapfile
  sudo mkswap /swapfile >/dev/null
fi

if ! sudo swapon --show=NAME --noheadings | grep -qx '/swapfile'; then
  sudo swapon /swapfile
fi

if ! grep -qF '/swapfile none swap sw 0 0' /etc/fstab; then
  printf '/swapfile none swap sw 0 0\n' | sudo tee -a /etc/fstab >/dev/null
fi

sudo docker network inspect pomi-edge >/dev/null 2>&1 ||
  sudo docker network create pomi-edge >/dev/null
sudo docker network inspect pomi-test-internal >/dev/null 2>&1 ||
  sudo docker network create --internal pomi-test-internal >/dev/null

sudo install -m 0644 -o root -g root /tmp/Caddyfile /opt/pomi/caddy/Caddyfile
sudo install -m 0644 -o root -g root /tmp/platform-compose.yaml /opt/pomi/compose/platform.yaml
