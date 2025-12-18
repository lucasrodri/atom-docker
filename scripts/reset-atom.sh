#!/usr/bin/env bash
set -e

echo "⚠️  RESET TOTAL DO AMBIENTE AtoM"
echo "Isso irá APAGAR:"
echo " - Banco MySQL"
echo " - Índices do Elasticsearch"
echo " - Cache e uploads do AtoM"
echo
read -rp "Tem certeza? (digite 'sim'): " CONFIRM

if [ "$CONFIRM" != "sim" ]; then
  echo "Abortado."
  exit 0
fi

echo
echo "🛑 Parando containers..."
docker compose down

echo
echo "🧹 Removendo volumes..."
docker volume rm \
  atom-docker_mysql_data \
  atom-docker_es_data \
  atom-docker_atom_cache \
  atom-docker_atom_uploads \
  2>/dev/null || true

echo
echo "🚀 Subindo tudo novamente..."
docker compose up -d --build

echo
echo "✅ Reset concluído!"
echo "A instalação automática do AtoM deve rodar sozinha agora."
