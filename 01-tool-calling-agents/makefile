DOCKER_COMPOSE=docker/docker-compose.yml
COMPOSE=docker compose -f $(DOCKER_COMPOSE) --env-file .env

model ?= anthropic

.PHONY: help init build rebuild start stop restart logs clean test ask

help:
	@echo "Available targets: init build rebuild start stop restart logs clean test ask"
	@echo "  make init                         install uv + Python deps, create .env"
	@echo "  make build                        build images and start"
	@echo "  make ask q=\"Koľko je 17*23?\"      ask the agent from the CLI (optional model=...)"

# -----------------------------------------------------------------
# Setup
# -----------------------------------------------------------------

# Installs everything needed on the host. Creates .env from .env.example if it does not exist
# and generates LITELLM_MASTER_KEY if it is missing or empty. Other values are never touched.
init:
	@command -v docker >/dev/null || { echo "Docker is missing: install Docker Desktop"; exit 1; }
	@command -v uv >/dev/null || brew install uv
	uv sync
	@[ -f .env ] || { cp .env.example .env; echo "Created .env - fill in your API keys"; }
	@grep -q '^LITELLM_MASTER_KEY=.' .env || { \
	  awk -v line="LITELLM_MASTER_KEY=sk-$$(openssl rand -hex 16)" \
	    '/^LITELLM_MASTER_KEY=/ { print line; done = 1; next } { print } END { if (!done) print line }' \
	    .env > .env.tmp && mv .env.tmp .env; \
	  echo "Generated LITELLM_MASTER_KEY in .env"; \
	}

# -----------------------------------------------------------------
# Docker targets
# -----------------------------------------------------------------

build:
	$(COMPOSE) build
	@make start

rebuild:
	@make stop
	@make build

start:
	$(COMPOSE) up -d
	@echo "App: http://localhost:8080"

stop:
	$(COMPOSE) down

restart: stop start

logs:
	$(COMPOSE) logs -f

clean:
	$(COMPOSE) down --rmi local --volumes --remove-orphans

# -----------------------------------------------------------------
# App
# -----------------------------------------------------------------

test:
	uv run src/tools.py

# Usage: make ask q="Recept na palacinky pre 2, prepočítaj na 6" model=gemini
ask:
	MODEL=$(model) uv run src/agent.py "$(q)"
