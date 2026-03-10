#!/usr/bin/env bash
# Stop all Progento containers (same project name for all compose variants)
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
docker compose -p progento down
echo "Progento stopped."
