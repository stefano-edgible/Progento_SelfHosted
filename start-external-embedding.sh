#!/usr/bin/env bash
# Start Progento with embedding service on the host (e.g. GPU).
# Set EMBEDDING_SERVICE_URL in .env (e.g. http://host.docker.internal:8002)
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
[ -f .env ] && set -a && source .env && set +a
docker compose -f docker-compose.external-embedding.yml pull
docker compose -f docker-compose.external-embedding.yml up -d
echo "Progento starting (embedding on host). UI: http://localhost:3001"
