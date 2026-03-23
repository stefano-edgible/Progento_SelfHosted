#!/usr/bin/env bash
# Create volume directories under PROGENTO_DATA_ROOT/volumes/.
# Run once, or after a full reset (rm -rf volumes). On Linux, run with sudo so postgres can write;
# chmod 777 also helps Docker Desktop (macOS) where bind mounts may not preserve UIDs.
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
[ -f .env ] && set -a && source .env && set +a
ROOT="${PROGENTO_DATA_ROOT:-.}"
echo "Creating volumes under ${ROOT}/volumes/..."
mkdir -p "${ROOT}/volumes/ollama_data"
mkdir -p "${ROOT}/volumes/weaviate_data"
mkdir -p "${ROOT}/volumes/postgres_data"
mkdir -p "${ROOT}/volumes/code_repos"
mkdir -p "${ROOT}/volumes/knowledge_base"

# postgres:15 (Debian image) runs as postgres (999:999). chown so Linux bind mounts work.
# On Docker Desktop (macOS) bind mounts often don't preserve UIDs; chmod 777 ensures containers can write.
if ! chown 999:999 "${ROOT}/volumes/postgres_data" 2>/dev/null; then
  echo "Could not chown volumes/postgres_data. Run: sudo ./setup-volumes.sh"
  exit 1
fi
chmod 777 "${ROOT}/volumes/ollama_data" "${ROOT}/volumes/weaviate_data" "${ROOT}/volumes/postgres_data" \
  "${ROOT}/volumes/code_repos" "${ROOT}/volumes/knowledge_base"
echo "Done."
