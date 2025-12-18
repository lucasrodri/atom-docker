FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx \
    php8.3-fpm php8.3-cli \
    php8.3-curl php8.3-ldap php8.3-mysql php8.3-xml php8.3-mbstring php8.3-xsl php8.3-zip \
    php-apcu php-json \
    git unzip curl ca-certificates \
    netcat-traditional \
    supervisor mysql-client \
 && rm -rf /var/lib/apt/lists/*

# Nginx site
COPY docker/nginx-atom.conf /etc/nginx/sites-available/atom
RUN ln -sf /etc/nginx/sites-available/atom /etc/nginx/sites-enabled/atom \
 && rm -f /etc/nginx/sites-enabled/default

# Supervisord: nginx + php-fpm
COPY docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# App dir (o código vem via bind mount ./src)
RUN mkdir -p /var/www/atom

COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 80
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/bin/supervisord","-n"]
