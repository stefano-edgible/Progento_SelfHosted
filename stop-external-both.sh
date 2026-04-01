#!/usr/bin/env bash
# Stop host Ollama and embedding (for external-both / external-ollama / external-embedding stacks).
# Loads .env from this repo. See scripts/stop-external-host-services.sh.
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
[ -f .env ] && set -a && source .env && set +a
exec "$SCRIPT_DIR/scripts/stop-external-host-services.sh" both
