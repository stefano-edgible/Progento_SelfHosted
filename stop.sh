#!/usr/bin/env bash
# Stop all Progento containers (same project name for all compose variants)
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

docker compose -p progento down

# Host Ollama / embedding (external-* stacks): stop when .env points at local services.
# Opt out: PROGENTO_STOP_EXTERNAL_HOST=0
# Opt in always: PROGENTO_STOP_EXTERNAL_HOST=1 (even if URLs unset — uses defaults; avoid if unsure)
if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

_ext_stop="${PROGENTO_STOP_EXTERNAL_HOST:-}"
if [[ -z "$_ext_stop" ]]; then
  if [[ -n "${OLLAMA_URL:-}" ]] || [[ -n "${EMBEDDING_SERVICE_URL:-}" ]]; then
    _ext_stop=1
  else
    _ext_stop=0
  fi
fi

if [[ "$_ext_stop" == "1" ]]; then
  "$SCRIPT_DIR/scripts/stop-external-host-services.sh" both || true
fi

echo "Progento stopped."
