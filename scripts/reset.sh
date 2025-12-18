#!/usr/bin/env bash
set -e

echo "♻️  RESET PARCIAL (mantém uploads)"

docker compose down

docker volume rm \
  atom-docker_mysql_data \
  atom-docker_es_data \
  atom-docker_atom_cache \
  2>/dev/null || true

docker compose up -d --build

echo "✅ Reset parcial concluído."
