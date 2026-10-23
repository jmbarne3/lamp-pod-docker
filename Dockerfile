# Official PHP image. The 8.3 tag tracks the latest 8.3 patch release, so
# `docker compose build --pull` picks up future security fixes.
# 8.3.36+ is required for CVE-2026-109618 / CVE-2026-109619 (PHP2Shell).
FROM docker.io/library/php:8.3-apache

# Helper that installs PHP extensions along with their system libraries.
COPY --from=docker.io/mlocati/php-extension-installer:2 /usr/bin/install-php-extensions /usr/local/bin/

# Same extensions as the old thecodingmachine image, plus gd and intl for WordPress.
RUN install-php-extensions \
        apcu calendar exif gettext igbinary mysqli opcache pcntl pdo_mysql redis \
        shmop soap sockets sysvmsg sysvsem sysvshm xsl zip gd intl

# Tools, plus a "docker" user (uid 1000) that owns the files in ./www and ./share.
RUN apt-get update \
    && apt-get install -y --no-install-recommends sudo less mariadb-client unzip \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd -g 1000 docker \
    && useradd -m -u 1000 -g docker -G sudo -s /bin/bash docker \
    && echo 'docker ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/docker \
    && mkdir -p /home/docker/share && chown docker:docker /home/docker/share

# Apache runs as "docker" so WordPress can write uploads, plugins and updates.
ENV APACHE_RUN_USER=docker \
    APACHE_RUN_GROUP=docker
RUN a2enmod rewrite expires deflate headers \
    && sed -i 's/Options -Indexes/Options +Indexes +FollowSymLinks/' /etc/apache2/conf-available/docker-php.conf

# Development PHP settings, matching the old image's defaults.
RUN cp "$PHP_INI_DIR/php.ini-development" "$PHP_INI_DIR/php.ini" \
    && printf '%s\n' \
        'memory_limit = -1' \
        'max_execution_time = 0' \
        'upload_max_filesize = 64M' \
        'post_max_size = 64M' \
        'display_errors = On' \
        'error_reporting = E_ALL' \
        > "$PHP_INI_DIR/conf.d/zz-local.ini"

# WP-CLI. The wrapper runs it as "docker" so files it creates keep the right owner.
RUN curl -sS -o /usr/local/bin/wp-cli.phar https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x /usr/local/bin/wp-cli.phar \
    && printf '%s\n' '#!/bin/sh' \
        'if [ "$(id -u)" = 0 ]; then exec sudo -E -u docker /usr/local/bin/wp-cli.phar "$@"; fi' \
        'exec /usr/local/bin/wp-cli.phar "$@"' > /usr/local/bin/wp \
    && chmod +x /usr/local/bin/wp

WORKDIR /var/www/html
