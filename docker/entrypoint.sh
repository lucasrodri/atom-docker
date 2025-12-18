#!/usr/bin/env bash
set -euo pipefail

APP_DIR=/var/www/atom

# Checa se o código está montado
if [ ! -f "$APP_DIR/symfony" ]; then
  echo "ERRO: não encontrei o AtoM em $APP_DIR (bind mount ./src)."
  exit 1
fi

# Espera serviços (bem simples)
echo "Aguardando MySQL em ${ATOM_DB_HOST:-mysql}:3306..."
until nc -z "${ATOM_DB_HOST:-mysql}" 3306; do sleep 2; done

echo "Aguardando Elasticsearch em ${ATOM_ES_HOST:-elasticsearch}:9200..."
until curl -fsS "http://${ATOM_ES_HOST:-elasticsearch}:9200" >/dev/null; do sleep 2; done

echo "Aguardando Gearman em ${ATOM_GEARMAN_HOST:-gearman}:4730..."
until nc -z "${ATOM_GEARMAN_HOST:-gearman}" 4730; do sleep 2; done

# Auto-install (idempotente)
if [ "${AUTO_INSTALL:-0}" = "1" ]; then
  echo "Verificando se já existe schema no DB..."
  # Um teste simples: existe alguma tabela? (funciona bem pra “primeira vez”)
  TABLES=$(mysql -h"${ATOM_DB_HOST:-mysql}" -u"${ATOM_DB_USER:-root}" -p"${ATOM_DB_PASS:-rootpass}" \
    -Nse "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${ATOM_DB_NAME:-atom}';" || echo 0)

  if [ "${TABLES}" = "0" ]; then
    echo "Primeira execução detectada. Rodando instalação do AtoM..."

    APP=/var/www/atom
    echo "Aplicando patch no plugin arElasticSearchMapping..."
    MAP="$APP/plugins/arElasticSearchPlugin/lib/arElasticSearchMapping.class.php"
    sed -i "/include_in_root/d; /include_in_parent/d" "$MAP"
    
    cd "$APP_DIR"
    #Deixando a identação a seguir assim mesmo, é necessário para o PHP interpretar corretamente.    

INSTALL_ANSWERS=$(
cat <<EOF
${ATOM_DB_HOST:-mysql}
${ATOM_DB_PORT:-3306}
${ATOM_DB_NAME:-atom}
${ATOM_DB_USER:-atom}
${ATOM_DB_PASS:-atom}
${ATOM_ES_HOST:-elasticsearch}
${ATOM_ES_PORT:-9200}
${ATOM_ES_INDEX:-atom}
${ATOM_SITE_TITLE:-AtoM}
${ATOM_SITE_DESC:-Access to Memory}
${ATOM_BASE_URL:-http://127.0.0.1}
${ATOM_ADMIN_EMAIL:-lucasrodrigues@ibict.br}
${ATOM_ADMIN_USER:-lucasrodrigues}
${ATOM_ADMIN_PASS:-lucas}
y
y
EOF
)
    # Roda instalação
    echo "Rodando a instalação com stdin vindo do heredoc"
    printf "%s\n" "$INSTALL_ANSWERS" | php -d memory_limit=-1 symfony tools:install

    # valida rapidamente que o banco nasceu
    TABLES_AFTER=$(mysql -h"${ATOM_DB_HOST:-mysql}" -u"${ATOM_DB_USER:-root}" -p"${ATOM_DB_PASS:-rootpass}" \
    -Nse "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${ATOM_DB_NAME:-atom}';" || echo 0)

    if [ "${TABLES_AFTER}" = "0" ]; then
    echo "ERRO: tools:install terminou mas DB ainda está vazio. Abortando."
    exit 1
    fi

    # agora sim: índice
    php symfony cc
    php -d memory_limit=-1 symfony search:populate

    echo "Instalação concluída."
    echo "Criando arquivo marcador de instalação..."
    INSTALL_MARKER=/var/www/atom/.installed
    touch "$INSTALL_MARKER"
  else
    echo "DB já inicializado. Pulando tools:install."
    cd "$APP_DIR"
    echo "Atualizando índice de busca..."
    php symfony cc
    php -d memory_limit=-1 symfony search:populate
  fi
fi

chown -R www-data:www-data "$APP_DIR" || true

exec "$@"
