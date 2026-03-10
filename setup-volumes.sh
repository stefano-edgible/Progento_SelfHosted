#!/usr/bin/env bash
# Create volume directories. Run once (or when PROGENTO_DATA_ROOT changes).
# Uses PROGENTO_DATA_ROOT from .env or current dir.
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
echo "Done."
