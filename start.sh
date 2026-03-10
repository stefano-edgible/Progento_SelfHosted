#!/usr/bin/env bash
# Start Progento – full stack (Ollama + embedding + Weaviate + Postgres + API + UI) in Docker
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
[ -f .env ] && set -a && source .env && set +a
docker compose pull
docker compose up -d
echo "Progento starting. UI: http://localhost:3001"
