#!/usr/bin/env bash
# Start native embedding on the host (Metal/CUDA) — NOT Docker. Code lives in ./embedding_service/.
# Use from .env: PROGENTO_EMBEDDING_START_CMD="./scripts/start-embedding-host.sh"
#
# Prerequisite: pip install -r embedding_service/requirements.txt (venv recommended — see embedding_service/README.md)
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EMB_DIR="$ROOT/embedding_service"

if [[ ! -f "$EMB_DIR/main.py" ]]; then
  echo "start-embedding-host.sh: missing $EMB_DIR/main.py" >&2
  exit 1
fi

cd "$EMB_DIR"
if [[ -x "$EMB_DIR/.venv/bin/python" ]]; then
  exec "$EMB_DIR/.venv/bin/python" main.py
fi
if command -v python3 >/dev/null 2>&1; then
  exec python3 main.py
fi
exec python main.py
