#!/usr/bin/env bash
# Start Progento – full stack (Ollama + embedding + Weaviate + Postgres + API + UI) in Docker
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
# shellcheck source=scripts/progento-compose.sh
source "$SCRIPT_DIR/scripts/progento-compose.sh"
[ -f .env ] && set -a && source .env && set +a
progento_compose docker-compose.yml pull
progento_compose docker-compose.yml up -d
echo "Progento starting. UI: http://localhost:3001"
