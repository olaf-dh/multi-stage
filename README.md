# Symfony Docker Setup (Makefile + Docker Compose)

This repository contains a Symfony application located in `app/`, plus a Docker‑based development setup driven by a `Makefile`. PHP and Node/Encore tooling run in containers — nothing to install locally except Docker.

The stack uses **two Compose files**:

- `docker-compose.yml` — base services (php, nginx, db)
- `docker-compose.override.yml` — local dev overrides (bind-mounts, Composer and Node services, watcher, etc.)

Docker Compose automatically merges both when you run `docker compose …`.

> If you just cloned this repo and `app/` already exists in the repository (recommended), you **do not** need to scaffold Symfony again. Follow the **Quick Start** below.

---

## Prerequisites

- **Docker** and **Docker Compose v2**
- **GNU Make** and Bash

> The containers assume the Symfony project root is mounted at `/app` (composer/node) and `/var/www/html` (php/nginx), mapped to `./app` on your host.

---

## Quick Start (fresh clone)

### Easiest way (one command)

```bash
make start
```

This will: build images, start containers, run Composer install, install Node dev dependencies, and build assets once. Then the **Node watcher** from `docker-compose.override.yml` keeps rebuilding assets on changes.

App URL (default): `http://localhost:8080/`

### Alternatively (step by step)

```bash
make build
make up
make composer-install   # PHP deps
# Dev mode already has a node watcher running from docker-compose.override.yml
# If you need a one-off build:
make assets-build
```

---

## Make targets (cheat sheet)

- `make start` — Build, up, composer install, npm ci, and one-off asset build (all-in-one). After that, the dev watcher from the override keeps running.
- `make build` — Build images defined in `docker-compose.yml`.
- `make up` — Start containers in the background (merges override automatically).
- `make down` — Stop and remove containers.
- `make logs` — Tail logs of all services.
- `make sh` — Shell into the PHP container (named `php`).
- `make install` — Composer install + npm ci + asset build.
- `make composer-install` — Only Composer install.
- `make composer-update` — Only Composer update.
- `make assets-install` — `npm ci` inside a short‑lived Node container.
- `make assets-build` — `npm run build` once inside a short‑lived Node container.
- `make assets-dev` — `npm run dev` once inside a short‑lived Node container (the long‑running watcher already comes from the override).
- `make init-encore` — Optional one-time Encore init script.
- `make up-prod` — Bring up services **without** local overrides (uses only `docker-compose.yml`).
- `make first-init` — **One-time bootstrap** to scaffold `app/` if it is missing.

> Note: Running `make up` by default uses both compose files. Use `make up-prod` to simulate a minimal/CI run without the override.

## Service overview

| Service  | Defined in      | Role                        | Image / Build                                                              | Ports (host→container) | Volumes (host → container)                                                                        | Env / Command                                                   | Depends on |
| -------- | --------------- | --------------------------- | -------------------------------------------------------------------------- | ---------------------- | ------------------------------------------------------------------------------------------------- | --------------------------------------------------------------- | ---------- |
| php      | base + override | PHP-FPM runtime for Symfony | Build: `Dockerfile` → `my-symfony-app:prod`                                | –                      | `./app` → `/var/www/html:delegated` (override)                                                    | `APP_ENV=dev`, `APP_DEBUG=1`                                    | db         |
| nginx    | base + override | HTTP server & static files  | Build: `docker/nginx/Dockerfile` (arg `RUNTIME_IMAGE=my-symfony-app:prod`) | `8080` → `80`          | `./app` → `/var/www/html:ro`, `./docker/nginx/default.conf` → `/etc/nginx/conf.d/default.conf:ro` | –                                                               | php        |
| db       | base            | PostgreSQL 16               | Image: `postgres:16-alpine`                                                | – (internal only)      | `dbdata` (named volume) → `/var/lib/postgresql/data`                                              | `POSTGRES_DB=app`, `POSTGRES_USER=app`, `POSTGRES_PASSWORD=app` | –          |
| composer | override        | Composer CLI (ephemeral)    | Build: `docker/composer/Dockerfile`                                        | –                      | `./app` → `/app`, `${HOME}/.cache/composer` → `/tmp/composer/cache`                               | `COMPOSER_HOME=/tmp/composer`, entrypoint `composer`            | –          |
| node     | override        | Assets build + dev watcher  | Image: `node:20-alpine`                                                    | –                      | `./app` → `/app`                                                                                  | `command: npm install && npm run dev -- --watch`                | –          |

**Notes**

- `docker compose` merges `docker-compose.yml` and `docker-compose.override.yml` automatically for local dev.
- Use `make up-prod` for CI/minimal runs that ignore the override (no dev watcher/Composer service).
- If you need to access Postgres from the host, you can add a port mapping in the override, e.g.:
  ```yaml
  services:
    db:
      ports:
        - "5432:5432"
  ```

## Typical developer workflow

### First time on a machine

```bash
make start
# opens http://localhost:8080/
```

### Day‑to‑day (dev with override)

```bash
make up                   # starts php, nginx, db, composer, and node watcher
make composer-install     # when PHP deps change
# assets are auto‑rebuilt by the watcher; for a one‑off build:
make assets-build
make logs                 # view logs
make sh                   # shell into PHP container
make down                 # stop services
```

### CI / minimal run (without override)

```bash
make up-prod
make composer-install
make assets-build
```

---

## Project structure (excerpt)

```
.
├── Makefile
├── docker-compose.yml
├── docker-compose.override.yml
├── docker/
│   ├── composer/
│   │   └── Dockerfile            # Composer image with CA certificates baked in
│   ├── nginx/
│   │   ├── Dockerfile
│   │   └── default.conf
│   └── php/
│       ├── php.ini
│       └── php-fpm.conf
├── scripts/
│   ├── init-frontend.sh          # optional: sets up Encore in /app
└── app/                          # Symfony app root
    ├── composer.json / composer.lock
    ├── package.json / package-lock.json
    ├── webpack.config.js
    ├── assets/
    ├── public/
    └── .env / .env.local
```

> `vendor/` and `node_modules/` are not committed. They are installed at runtime.

---

## Environment configuration

- Symfony reads environment from `app/.env` and `app/.env.local` (not committed).
- Configure database and other services via `docker-compose.yml` and env variables in `.env` files.
- For local overrides, create `app/.env.local`.

---

## Troubleshooting

### Composer CA certificates (curl error 60)

This project ships a **custom Composer image** defined at `docker/composer/Dockerfile` which installs CA certificates (works on Alpine/Debian bases). If you still encounter `curl error 60`:

1. Rebuild the Composer image:

```bash
docker compose build composer
```

2. Re-run your Composer command:

```bash
make composer-install
```

If your network uses a corporate root CA, add it in `docker/composer/Dockerfile`:

```dockerfile
COPY company-root-ca.crt /usr/local/share/ca-certificates/company-root-ca.crt
RUN update-ca-certificates
```

### Node/Encore (dev watcher)

The `node` service in `docker-compose.override.yml` runs:

```
command: sh -lc "npm install && npm run dev -- --watch"
```

So during development, assets are rebuilt automatically. Use `make assets-build` only for a one-off build (e.g., CI or debugging).

### File permissions

- Symfony needs write access to `app/var/`. In containers this is usually already mapped correctly.
- If needed: `docker compose exec php sh -lc 'chown -R www-data:www-data var'`.

---

## CI / “Prod‑like” notes

- Use `make up-prod` for a run without local overrides.
- Install prod PHP deps: `make composer CMD='install --no-dev --classmap-authoritative'`.
- Build prod assets: `docker compose run --rm node sh -lc 'cd /app && npm run build'`.

---

## FAQ

**Q: After cloning, is **`make build`** enough?**

*A:* Not quite. `make build` only builds images. Use `make start` for a one-command setup, or run `make build`, `make up`, and `make install` step by step. See **Quick Start**.

**Q: What is the fastest one-liner to get running?**

*A:* `make start`.

**Q: Do I ever need **`make first-init`**?**

*A:* Only if `app/` does **not** exist in the repo and you want the script to scaffold a new Symfony skeleton. If `app/` is committed, skip `first-init`.

---

Happy coding! 🎉

