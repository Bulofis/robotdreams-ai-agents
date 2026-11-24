#!/bin/sh
# Sets up n8n without clicking in the UI: owner account, credentials, workflow.
# Runs inside the n8n container (make init). Safe to run again: everything is an upsert.
set -eu

# 1) Owner account. n8n answers 400 when the owner already exists.
node -e '
const e = process.env;
fetch("http://127.0.0.1:5678/rest/owner/setup", {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({
    email: e.N8N_OWNER_EMAIL,
    firstName: "Shop",
    lastName: "Admin",
    password: e.N8N_OWNER_PASSWORD,
  }),
}).then(async (r) => {
  if (r.ok) return console.log("n8n owner created");
  const text = await r.text();
  if (r.status === 400 && /already/i.test(text)) return console.log("n8n owner already set up");
  console.error("n8n owner setup failed:", r.status, text);
  process.exit(1);
});'

# 2) Credentials. The secrets come from the environment, the plain-text file
#    lives only in this container and only for the import (n8n encrypts it).
umask 077
credentials=$(mktemp)
trap 'rm -f "$credentials"' EXIT
node -e '
const e = process.env;
process.stdout.write(JSON.stringify([
  {
    id: "litellmCred00001",
    name: "LiteLLM",
    type: "openAiApi",
    data: { apiKey: e.LITELLM_MASTER_KEY, url: "http://litellm:4000/v1" },
  },
  {
    id: "shopPgCred000001",
    name: "Shop Postgres",
    type: "postgres",
    data: {
      host: "postgres",
      port: 5432,
      database: "shop",
      user: "shop_agent",
      password: e.AGENT_DB_PASSWORD,
      ssl: "disable",
      sshTunnel: false,
    },
  },
]));' > "$credentials"
n8n import:credentials --input="$credentials"

# 3) Workflow. The import always leaves it inactive, publishing activates it
#    after the next n8n restart (make init restarts n8n).
n8n import:workflow --input=/import/workflows/shop-agent.json
n8n publish:workflow --id=shopAgentWf00001
