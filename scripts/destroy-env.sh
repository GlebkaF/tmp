#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <env-id>"
  exit 1
fi

ENV_ID="$1"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="$ROOT_DIR/sandbox/docker-compose.yml"

printf 'Destroying sandbox %s\n' "$ENV_ID"
docker compose -p "$ENV_ID" -f "$COMPOSE_FILE" down -v
printf 'Done.\n'
