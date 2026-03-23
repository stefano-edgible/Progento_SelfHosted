#!/usr/bin/env bash
# Start Progento with Ollama and embedding on the host (e.g. both on GPU machine).
# Set OLLAMA_URL and EMBEDDING_SERVICE_URL in .env
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
# shellcheck source=scripts/progento-compose.sh
source "$SCRIPT_DIR/scripts/progento-compose.sh"
[ -f .env ] && set -a && source .env && set +a
progento_compose docker-compose.external-both.yml pull
progento_compose docker-compose.external-both.yml up -d
echo "Progento starting (Ollama + embedding on host). UI: http://localhost:3001"
