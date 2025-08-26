# Symfony Docker Project (Makefile + Docker Compose)

## Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start-fresh-clone)
- [Make targets](#make-targets-cheat-sheet)
- [Service overview](#service-overview)
- [Developer workflow](#typical-developer-workflow)
- [Project structure](#project-structure-excerpt)
- [CI/CD Workflow](#cicd-workflow)
- [Troubleshooting](#troubleshooting)
- [Symfony in K8s](#symfony-in-k8s)
- [FAQ](#faq)


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
- **Kubernetes**

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

- `make first-init` — **One-time bootstrap** to scaffold `app/` if it is missing.
- `make setup` — Create symfony skeleton in `app/` (just once).
- `make build` — Build images defined in `docker-compose.yml`.
- `make up` — Start containers in the background (merges override automatically).
- `make down` — Stop and remove containers.
- `make logs` — Tail logs of all services.
- `make sh` — Shell into the PHP container (named `php`).
- `make composer` — Execute composer in container (like `make composer CMD="require foo/bar"`).
- `make start-project` — Use this command to start the project after clone from repository. 
- `make up-prod` — Bring up services **without** local overrides (uses only `docker-compose.yml`).
- `make health` — Check status for services nginx, php and db.
- `make console` — Execute bin/console commands in container (like: `make console CMD="make:controller HomeController"`)
- `make phpstan` — Starts static analysis PHPStan of defined directories in `app/phpstan.neon.dist`.
- `male phpcs` — Run PHP_CodeSniffer according to `app/phpcs.dist.xml`.

> Note: Running `make up` by default uses both compose files. Use `make up-prod` to simulate a minimal/CI run without the override.

## Service overview

| Service  | Defined in      | Role                        | Image / Build                                                              | Ports (host→container) | Volumes (host → container)                                                                        | Env / Command                                                      | Depends on |
| -------- |-----------------|-----------------------------|----------------------------------------------------------------------------| ---------------------- |---------------------------------------------------------------------------------------------------|--------------------------------------------------------------------| ---------- |
| php      | base + override | PHP-FPM runtime for Symfony | Build: `Dockerfile` → `my-symfony-app:prod`                                | –                      | `./app` → `/var/www/html:delegated` (override)                                                    | `APP_ENV=dev`, `APP_DEBUG=1`                                       | db         |
| nginx    | base + override | HTTP server & static files  | Build: `docker/nginx/Dockerfile` (arg `RUNTIME_IMAGE=my-symfony-app:prod`) | `8080` → `80`          | `./app` → `/var/www/html:ro`, `./docker/nginx/default.conf` → `/etc/nginx/conf.d/default.conf:ro` | –                                                                  | php        |
| db       | base + override | MariaDB 10.6                | Image: `mariadb:10.6.21`                                                   | – (internal only)      | `dbdata` (named volume) → `/var/lib/mysql`                                                        | `MARIADB_DATABASE=app`, `MARIADB_USER=app`, `MARIADB_PASSWORD=app` | –          |
| composer | override        | Composer CLI (ephemeral)    | Build: `docker/composer/Dockerfile`                                        | –                      | `./app` → `/app`, `${HOME}/.cache/composer` → `/tmp/composer/cache`                               | `COMPOSER_HOME=/tmp/composer`, entrypoint `composer`               | –          |
| node     | override        | Assets build + dev watcher  | Image: `node:20-alpine`                                                    | –                      | `./app` → `/app`                                                                                  | `command: npm install && npm run dev -- --watch`                   | –          |

**Notes**

- `docker compose` merges `docker-compose.yml` and `docker-compose.override.yml` automatically for local dev.
- Use `make up-prod` for CI/minimal runs that ignore the override (no dev watcher/Composer service).
- If you need to access MariaDB from the host, you can add a port mapping in the override, e.g.:
  ```yaml
  services:
    db:
      ports:
        - "53306:3306"
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
├── github/
│   ├── workflows/
│   │   └── deploy.yml            # CI/CD piplines            
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

- `app/.env`: template with placeholders (commited to repo) 
- `app/.env.local`: developer-specific (ignored by git) 
- `shared/.env.local`: server-specific (written automatically from GitHub Secrets in deploy)
- `.env.local.php`: compiled env file for production (`composer dump-env prod`)

---

## CI/CD Workflow

### The project uses **GitHub Actions** for:

- Code Quality: PHPStan & PHP_CodeSniffer
- Deployment: rsync over SSH to web hosting

### Deployment process

1. Push your changes to **main** branch:
   
    ```bash
   git add .
   git commit -m "my feature"
   git push -u origin main
   ```

2. GitHub Action runs:
    
   - rsync code to `${REMOTE_PATH}/release/`
   - write `shared/.env.local` from GitHub Secrets
   - symlink into `release/.env.local`
   - create empty `.env` (needed for dump-env)
   - run `composer dump-env prod`
   - install prod dependencies (`--no-dev`)
   - warmup symfony cache
3. Subdomain points to `${REMOTE_PATH}/release/public`
4. **Important:** When the webhost uses Apache, it requires the Symfony `.htaccess` file in `public/` to rewrite requests to `index.php`.

👉 Just open https://your-subdomain.example.com in your browser

### Required GitHub Secrets

- `SSH_HOST`, `SSH_PORT`, `SSH_USER`, `SSH_KEY`
- `REMOTE_PATH`, `PHP_BIN`, `COMPOSER_BIN`
- `APP_SECRET`, `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASS`

---

## Troubleshooting

### 404 errors on routes (/health)

Ensure that `public/.htaccess` exists and was deployed.  
It contains the Apache rewrite rules to forward all requests to `index.php`.  
Without it, Symfony routes will return 404.


### Composer CA certificates (curl error 60)

This project ships a **custom Composer image** defined at `docker/composer/Dockerfile` which installs CA certificates (works on Alpine/Debian bases). If you still encounter `curl error 60`:

Rebuild the Composer image:

```bash
docker compose build composer
```

Re-run your Composer command:

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

## Symfony in K8s

This project also provides an example setup to run the Symfony application in **Kubernetes** with a **MariaDB** database.  
All manifests are located in the `k8s/` directory and include:

- **Namespace** `symfony`
- **Secret** for database credentials
- **ConfigMap** for application environment variables (`APP_ENV`, `APP_SECRET`, `DATABASE_URL`)
- **MariaDB Deployment + PVC + Service** (ClusterIP)
- **Symfony App Deployment + Service** (NodePort for local access with Minikube)

### Prerequisites
- Docker image of the Symfony app (e.g. `my-symfony-app:prod`)
- A Kubernetes cluster (tested with **Minikube**)
- `minikube` (Install local - on Mac with `brew install minikube`)
- `kubectl` CLI

### Deployment
```bash
# Start Minikube
minikube start

# Load the Symfony app image into Minikube
minikube image load my-symfony-app:prod

# Apply all Kubernetes resources
kubectl apply -f k8s/

# Check status
kubectl -n symfony get pods,svc

# Open the app in the browser
minikube service symfony-app -n symfony --url
```

### Notes

- Database connection is configured via `ConfigMap`:
```bash
DATABASE_URL=mysql://app:app@db:3306/app?serverVersion=mariadb-10.6&charset=utf8mb4
```
- Readiness and liveness probes expect a health route (/health) in the Symfony app.
- The application service is exposed as a NodePort (30080 by default) for easy local testing with Minikube.
- Future improvements: add Ingress + TLS, horizontal scaling, and Redis for cache/session handling.

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

