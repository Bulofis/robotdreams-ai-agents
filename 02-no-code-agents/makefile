ENV_FILE ?= .env
DOCKER_COMPOSE=docker/docker-compose.yml
COMPOSE=docker compose -f $(DOCKER_COMPOSE) --env-file $(ENV_FILE)

N8N_URL=http://localhost:5679
LANGFLOW_URL=http://localhost:7860

# Runs one SQL statement as the agent's database role, over TCP so the password is checked.
AGENT_SQL=$(COMPOSE) exec -T postgres sh -c \
  'PGPASSWORD="$$AGENT_DB_PASSWORD" psql -h 127.0.0.1 -U shop_agent -d shop -v ON_ERROR_STOP=1 -qAt -c "$$1"' sh

q ?= Ktorých 5 produktov je najdrahších?

.PHONY: help init start stop restart logs clean test ask-n8n ask-langflow

help:
	@echo "Available targets: init start stop restart logs clean test ask-n8n ask-langflow"
	@echo "  make init                       create .env, start everything, seed the database, import the n8n workflow"
	@echo "  make ask-n8n q=\"...\"            ask the n8n agent from the CLI"
	@echo "  make ask-langflow q=\"...\"       ask the LangFlow agent from the CLI"

# -----------------------------------------------------------------
# Setup
# -----------------------------------------------------------------

# One command from a fresh clone to two running agents. Creates .env from .env.example if it
# does not exist and generates the secrets that are missing or empty (other values are never
# touched). Then starts the stack: Postgres seeds the shop database on its first start,
# LangFlow loads its flow from langflow/ and import.sh sets up n8n. Safe to run again.
init:
	@command -v docker >/dev/null || { echo "Docker is missing: install Docker Desktop"; exit 1; }
	@command -v jq >/dev/null || brew install jq
	@[ -f $(ENV_FILE) ] || { cp .env.example $(ENV_FILE); echo "Created $(ENV_FILE) - fill in your API keys"; }
	@for item in LITELLM_MASTER_KEY=sk- POSTGRES_PASSWORD= AGENT_DB_PASSWORD= N8N_OWNER_PASSWORD=Aa1; do \
	  key=$${item%%=*}; prefix=$${item#*=}; \
	  grep -q "^$$key=." $(ENV_FILE) && continue; \
	  awk -v key="$$key" -v line="$$key=$$prefix$$(openssl rand -hex 16)" \
	    'index($$0, key "=") == 1 { print line; done = 1; next } { print } END { if (!done) print line }' \
	    $(ENV_FILE) > $(ENV_FILE).tmp && mv $(ENV_FILE).tmp $(ENV_FILE); \
	  echo "Generated $$key in $(ENV_FILE)"; \
	done
	$(COMPOSE) up -d --wait
	$(COMPOSE) exec -T n8n sh /import/import.sh
	$(COMPOSE) restart n8n
	@make start

# -----------------------------------------------------------------
# Docker targets
# -----------------------------------------------------------------

start:
	$(COMPOSE) up -d --wait
	@echo "n8n chat:    $(N8N_URL)/webhook/shop-agent/chat"
	@echo "n8n editor:  $(N8N_URL)  (login: N8N_OWNER_EMAIL and N8N_OWNER_PASSWORD from .env)"
	@echo "LangFlow:    $(LANGFLOW_URL)/flow/6b0d3c9e-5a41-4f7b-9c2d-1e8f7a6b5c40  (Playground)"

stop:
	$(COMPOSE) down

restart: stop start

logs:
	$(COMPOSE) logs -f

# Also deletes the volumes: the database, the n8n account and the LangFlow data.
clean:
	$(COMPOSE) down --volumes --remove-orphans

# -----------------------------------------------------------------
# Agents
# -----------------------------------------------------------------

# Checks the two deliverables and the database role. Needs the stack running.
test:
	@jq -e '.nodes | length > 0' n8n/shop-agent.json >/dev/null && echo "ok  n8n/shop-agent.json is a workflow"
	@jq -e '.data.nodes | length > 0' langflow/shop-agent.json >/dev/null && echo "ok  langflow/shop-agent.json is a flow"
	@! grep -nE 'sk-[A-Za-z0-9]{16,}|://[^/"@ ]+:[^/"@ ]+@' n8n/shop-agent.json langflow/shop-agent.json \
	  && echo "ok  no secrets in the workflow files"
	@$(AGENT_SQL) "SELECT count(*) FROM orders" >/dev/null && echo "ok  shop_agent can read"
	@$(AGENT_SQL) "BEGIN; INSERT INTO order_notes (order_id, note) VALUES (1, 'make test'); ROLLBACK" >/dev/null \
	  && echo "ok  shop_agent can add an order note"
	@! $(AGENT_SQL) "DELETE FROM order_notes" >/dev/null 2>&1 && echo "ok  shop_agent cannot delete"
	@! $(AGENT_SQL) "UPDATE products SET price = 0" >/dev/null 2>&1 && echo "ok  shop_agent cannot change products"

# Each call is a new conversation (own session id), the chat UIs keep the history.
# Usage: make ask-n8n q="Ktorý zákazník minul najviac a na koľkých objednávkach?"
ask-n8n:
	@jq -n --arg q "$(q)" --arg s "cli-$$(date +%s)" '{action: "sendMessage", sessionId: $$s, chatInput: $$q}' \
	  | curl -sS -X POST "$(N8N_URL)/webhook/shop-agent/chat" -H 'Content-Type: application/json' -d @- \
	  | jq -r '.output // .'

# Usage: make ask-langflow q="Ktoré produkty sú vypredané?"
ask-langflow:
	@jq -n --arg q "$(q)" --arg s "cli-$$(date +%s)" \
	    '{input_value: $$q, input_type: "chat", output_type: "chat", session_id: $$s}' \
	  | curl -sS -X POST "$(LANGFLOW_URL)/api/v1/run/shop-agent?stream=false" -H 'Content-Type: application/json' -d @- \
	  | jq -r '.outputs[0].outputs[0].results.message.text // .'
