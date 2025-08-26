# ---------- 1) Composer Build ----------
FROM php:8.3-fpm-bullseye AS composer-build

RUN apt-get update && apt-get install -y \
    git unzip libicu-dev libzip-dev libpq-dev \
 && docker-php-ext-install intl zip opcache pdo pdo_mysql pdo_pgsql

# Composer from official image
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# We build in /app (only stage workspace)
WORKDIR /app
ARG APP_DIR=app

# Only composer files copy from sub directory (cache friendly)
COPY ${APP_DIR}/composer.json ./composer.json
# composer.lock usually exists in skeleton – when not, remove the line below
COPY ${APP_DIR}/composer.lock ./composer.lock

# Install prod dependencies (without source code)
ENV COMPOSER_ALLOW_SUPERUSER=1
RUN composer install --no-dev --no-scripts --prefer-dist --no-progress --no-interaction --optimize-autoloader

# ---------- 2) Assets Build (Encore optional) ----------
FROM node:20-alpine AS assets-build

WORKDIR /app
ARG APP_DIR=app

# Tools for native module
RUN apk add --no-cache python3 make g++

# Copy complete app directory
COPY ${APP_DIR}/ ./

# Only install/build, when frontend exist
RUN if [ -f package-lock.json ]; then npm ci; \
    elif [ -f yarn.lock ]; then yarn install --frozen-lockfile; \
    elif [ -f package.json ]; then npm install; \
    else echo "No package.json found – skipping JS deps"; fi \
 && if [ -f webpack.config.js ]; then (npm run build || npx encore production); \
    else echo "No webpack.config.js – skipping asset build"; fi \
    && mkdir -p /app/public/build

# ---------- 3) Runtime ----------
FROM php:8.3-fpm-alpine AS runtime

# Runtime-Libs
RUN apk add --no-cache bash icu-libs libzip postgresql-libs

# Build-deps temporary for PHP extensions
RUN apk add --no-cache --virtual .build-deps \
      $PHPIZE_DEPS icu-dev libzip-dev postgresql-dev \
 && docker-php-ext-install -j"$(nproc)" opcache pdo pdo_mysql pdo_pgsql intl \
 && apk del .build-deps

ENV APP_ENV=prod APP_DEBUG=0
WORKDIR /var/www/html
ARG APP_DIR=app

# Copy complete app code from sub directory (inkludes public/ & bin/)
COPY ${APP_DIR}/ ./

# Inherit vendor & build assets from previous stages
COPY --from=composer-build /app/vendor ./vendor
COPY --from=assets-build  /app/public/build ./public/build

# Add some convenience
RUN echo "alias ll='ls -al --color'" > /etc/profile.d/app.sh && \
    echo "alias bc='php bin/console'" | tee -a /etc/profile.d/app.sh && \
    echo "alias phpunit='php vendor/bin/phpunit'" | tee -a /etc/profile.d/app.sh

# (optional) secure directories & access rights
RUN mkdir -p var/cache var/log public/build \
 && addgroup -g 1000 www && adduser -G www -D -u 1000 www \
 && chown -R www:www var public
USER www

EXPOSE 9000
CMD ["php-fpm"]
