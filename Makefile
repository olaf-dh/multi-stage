SHELL := /bin/bash
PROJECT ?= my-symfony-app
IMAGE   ?= $(PROJECT):prod
APP_DIR ?= app
CMD ?=

.PHONY: help setup build up down logs sh init-frontend up-prod composer node-build node-watch first-init install-doctrine wait-db db-create migrate console ensure-env-local phpstan phpcs start-project install-twig init-demo health k8s-apply k8s-clean k8s-status

help:
	@echo "Targets:"
	@echo "  first-init      	- initialize complete project (setup, build, up, init-frontend, node-build)"
	@echo "  setup           	- create symfony skeleton in $(APP_DIR) (just once)"
	@echo "  install-doctrine   - install symfony/orm-pack and necessary packages"
	@echo "  ensure-env-local   - set the DATABASE_URL"
	@echo "  wait-db            - stalls the install process until data base is created"
	@echo "  db-create          - create data base"
	@echo "  migrate            - executes the migrations"
	@echo "  build           	- docker compose build"
	@echo "  up              	- docker compose up -d"
	@echo "  up-prod         	- like-prod (without override) build & start"
	@echo "  down            	- docker compose down"
	@echo "  init-frontend   	- initialize encore in symfony directory (app/)"
	@echo "  node-build      	- build assets once (in node-container)"
	@echo "  node-watch      	- encore watch in node-container"
	@echo "  composer CMD=…  	- execute composer in container (like make composer CMD=\"require foo/bar\")"
	@echo "  sh              	- shell in PHP-container"
	@echo "  console            - execute bin/console commands in container (like: make console CMD=\"make:controller HomeController\")"
	@echo "  phpstan            - execute static analysis PHPStan"
	@echo "  phpcs              - execute static analysis PHP CodeSniffer"
	@echo "  start-project      - use this command after clone to start the project"
	@echo "  install-twig       - use this command to install Twig-Templating"
	@echo "  init-demo          - install a first controller and a twig-template"
	@echo "  health             - check status for services nginx, php and db"
	@echo "  k8s-apply          - apply all kubernetes resources"
	@echo "  k8s-clean          - clean up"
	@echo "  k8s-status         - check status for pods, svc"

# This is only necessary when app-directory not exists
first-init: setup build up wait-db ensure-env-local install-doctrine db-create migrate install-twig init-demo init-frontend node-build
	@echo "🚀 Project was initialized fully!"

install-doctrine:
	# deactivate flex recipes(just once in project)
	@$(MAKE) composer CMD='config extra.symfony.docker false'
	# (optional, one timer: allow community recipes – if not set
	@$(MAKE) composer CMD='config extra.symfony.allow-contrib true'
	# install packages - not interactive
	@$(MAKE) composer CMD='require --no-interaction symfony/orm-pack'
	@$(MAKE) composer CMD='require --no-interaction --dev symfony/maker-bundle doctrine/doctrine-migrations-bundle'

ensure-env-local:
	@test -f app/.env.local || echo 'DATABASE_URL="mysql://app:app@db:3306/app?serverVersion=mariadb-10.6&charset=utf8"' > app/.env.local
	@echo "✅ app/.env.local set (DATABASE_URL → db:3306)"

# wait, until Postgres is ready
wait-db:
	@echo "⏳ Wait for MariaDB…"
	@until docker compose exec -T db mysqladmin ping -h 127.0.0.1 -uapp -papp --silent; do \
		sleep 1; \
	done
	@echo "✅ MariaDB is ready."

# create DB (idempotent)
db-create:
	@docker compose exec php bin/console doctrine:database:create --if-not-exists || true

# execute migrations, only when exist
migrate:
	@docker compose exec php bash -lc 'if compgen -G "migrations/*.php" > /dev/null; then \
		bin/console doctrine:migrations:migrate -n; \
	else \
		echo "ℹ️  No migrations found (migrations/ empty)."; \
	fi'

setup:
	@test -d $(APP_DIR) || docker run --rm -u $(shell id -u):$(shell id -g) \
    	-v $(PWD):/work -w /work \
    	composer:2 create-project symfony/skeleton $(APP_DIR)

install-twig:
	docker compose run --rm composer require symfony/twig-bundle

init-demo:
	@APP_DIR=$(APP_DIR) bash scripts/init-demo.sh

build:
	docker compose build

up:
	docker compose up -d

# forced "only prod-like" (without override), for CI
up-prod:
	docker compose -f docker-compose.yml up -d --build

down:
	docker compose down

init-frontend:
	@APP_DIR=$(APP_DIR) bash scripts/init-frontend.sh

# Composer in separate service (dev-like - make composer CMD='require outdated')
composer:
	docker compose run --rm composer $(CMD)

# build assets in node-container once
node-build:
	docker compose run --rm node sh -lc "cd /app && npm ci && npm run build"

# start watch manuel (when node-service not used from compose)
node-watch:
	docker compose run --rm node sh -lc "cd /app && npm install && npm run watch"

logs:
	docker compose logs -f --tail=100

sh:
	docker compose exec php sh || true

console:
	docker compose exec php bin/console $(CMD)

phpstan:
	docker compose exec php vendor/bin/phpstan

phpcs:
	docker compose exec php vendor/bin/phpcs

start-project:
	@$(MAKE) up
	@$(MAKE) console CMD='install'

health:
	@echo "nginx:" && docker compose exec -T nginx sh -lc 'wget -q --spider http://127.0.0.1/health && echo "  OK" || (echo "  DOWN"; exit 1)'
	@echo "php-fpm:" && docker compose exec -T php sh -lc 'php -r '\''exit(@fsockopen("127.0.0.1",9000) ? 0 : 1);'\'' && echo "  OK" || (echo "  DOWN"; exit 1)'
	@echo "db:" && docker compose exec -T db sh -lc 'mysqladmin ping -h localhost -u$$MARIADB_USER -p$$MARIADB_PASSWORD --silent && echo "  OK" || (echo "  DOWN"; exit 1)'

k8s-apply:
	kubectl apply -f k8s/

k8s-clean:
	kubectl delete -f k8s/ --ignore-not-found=true

k8s-status:
	kubectl -n symfony get pods,svc
