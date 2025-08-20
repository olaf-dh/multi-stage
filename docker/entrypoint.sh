#!/usr/bin/env sh
set -e
php bin/console cache:clear --no-warmup || true
php bin/console cache:warmup || true
exec "$@"
