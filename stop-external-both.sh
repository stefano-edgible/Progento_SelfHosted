#!/usr/bin/env bash
# Stop the same stack as start-external-both.sh: Docker (external-both compose + kbase fragment), then host Ollama + embedding.
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
# shellcheck source=scripts/progento-compose.sh
source "$SCRIPT_DIR/scripts/progento-compose.sh"
[ -f .env ] && set -a && source .env && set +a

progento_compose docker-compose.external-both.yml down

# Host services (local URLs only; see scripts/stop-external-host-services.sh)
"$SCRIPT_DIR/scripts/stop-external-host-services.sh" both || true

echo "External-both stopped (Docker stack + best-effort host Ollama/embedding)."
