#!/usr/bin/env bash
# Copy scripts maintained in the main Progento repo into this repo.
# Guests cloning Progento_SelfHosted only do not need this — files are already committed here.
# Run when you change Progento and want to refresh self-hosted copies (maintainers / monorepo workflow).
#
# Usage: ./sync-from-progento.sh
# Optional: PROGENTO_SOURCE=/path/to/Progento  (default: ../Progento)
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
SRC="${PROGENTO_SOURCE:-../Progento}"
if [ ! -d "$SRC" ]; then
  echo "Error: Progento source not found at: $SRC"
  echo "Set PROGENTO_SOURCE to the path of your Progento repo (e.g. PROGENTO_SOURCE=../Progento ./sync-from-progento.sh)"
  exit 1
fi

WRAPPER_SRC="$SRC/scripts/db/postgres-entrypoint-wrapper.sh"
if [ ! -f "$WRAPPER_SRC" ]; then
  echo "Error: Expected file missing: $WRAPPER_SRC"
  exit 1
fi

mkdir -p scripts/db
cp "$WRAPPER_SRC" scripts/db/postgres-entrypoint-wrapper.sh
chmod +x scripts/db/postgres-entrypoint-wrapper.sh

echo "Synced from $SRC:"
echo "  scripts/db/postgres-entrypoint-wrapper.sh"
