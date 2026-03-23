#!/usr/bin/env bash
# Source from repo root after: cd "$(dirname "$0")" or SCRIPT_DIR.
# Usage: source scripts/progento-compose.sh
# Then: progento_compose docker-compose.yml pull
#   or: progento_compose docker-compose.external-ollama.yml up -d
progento_compose() {
  local main_file="$1"
  shift
  if [ -f docker-compose.kbase.generated.yml ]; then
    docker compose -f "$main_file" -f docker-compose.kbase.generated.yml "$@"
  else
    docker compose -f "$main_file" "$@"
  fi
}
