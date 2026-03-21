#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <env-id>"
  exit 1
fi

ENV_ID="$1"
BASE_DOMAIN="${BASE_DOMAIN:-dev.localtest.me}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-postgres}"

export ENV_ID
export BASE_DOMAIN
export POSTGRES_PASSWORD

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="$ROOT_DIR/sandbox/docker-compose.yml"

export NEXT_PUBLIC_API_BASE_URL="http://api.${ENV_ID}.${BASE_DOMAIN}"

printf '\n[1/2] Starting sandbox %s\n' "$ENV_ID"
docker compose -p "$ENV_ID" -f "$COMPOSE_FILE" up -d --build

printf '\n[2/2] Sandbox URLs\n'
printf 'web: http://%s.%s\n' "$ENV_ID" "$BASE_DOMAIN"
printf 'api: http://api.%s.%s/health\n' "$ENV_ID" "$BASE_DOMAIN"
