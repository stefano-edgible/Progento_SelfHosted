#!/usr/bin/env bash
# Start Progento with Ollama on the host (e.g. native for GPU).
# Set OLLAMA_URL in .env (e.g. http://host.docker.internal:11434 or http://YOUR_HOST_IP:11434)
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
# shellcheck source=scripts/progento-compose.sh
source "$SCRIPT_DIR/scripts/progento-compose.sh"
[ -f .env ] && set -a && source .env && set +a
"$SCRIPT_DIR/scripts/ensure-external-host-services.sh" ollama
progento_compose docker-compose.external-ollama.yml pull
progento_compose docker-compose.external-ollama.yml up -d
echo "Progento starting (Ollama on host). UI: http://localhost:3001"
