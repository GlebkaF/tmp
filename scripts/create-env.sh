#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <env-id>"
  exit 1
fi

ENV_ID="$1"
BASE_DOMAIN="${BASE_DOMAIN:-dev.localtest.me}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-postgres}"

export ENV_ID BASE_DOMAIN POSTGRES_PASSWORD

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ── 1. Ensure Caddy is running (idempotent) ──
printf '[1/3] Ensuring Caddy is up\n'
docker compose -p caddy -f "$ROOT_DIR/caddy/docker-compose.yml" up -d

# ── 2. Start sandbox ──
export NEXT_PUBLIC_API_BASE_URL="http://api.${ENV_ID}.${BASE_DOMAIN}"

printf '\n[2/3] Starting sandbox %s\n' "$ENV_ID"
docker compose -p "$ENV_ID" -f "$ROOT_DIR/sandbox/docker-compose.yml" up -d --build

# ── 3. Print URLs ──
printf '\n[3/3] Sandbox URLs\n'
printf 'web: http://%s.%s\n' "$ENV_ID" "$BASE_DOMAIN"
printf 'api: http://api.%s.%s/health\n' "$ENV_ID" "$BASE_DOMAIN"
