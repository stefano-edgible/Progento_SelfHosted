#!/usr/bin/env bash
# Start native embedding on the host (Metal/CUDA) — NOT Docker. Code lives in ./embedding_service/.
# Use from .env: PROGENTO_EMBEDDING_START_CMD="./scripts/start-embedding-host.sh"
#
# Creates embedding_service/.venv on first run and pip installs requirements (same idea as Progento's
# start_embedding_service.sh). Avoids falling back to system python3 without deps.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EMB_DIR="$ROOT/embedding_service"
VENV_PY="$EMB_DIR/.venv/bin/python"
VENV_PIP="$EMB_DIR/.venv/bin/pip"

if [[ ! -f "$EMB_DIR/main.py" ]]; then
  echo "start-embedding-host.sh: missing $EMB_DIR/main.py" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "start-embedding-host.sh: python3 not found on PATH" >&2
  exit 1
fi

if [[ ! -x "$VENV_PY" ]]; then
  echo "start-embedding-host.sh: creating $EMB_DIR/.venv …" >&2
  python3 -m venv "$EMB_DIR/.venv"
fi

if ! "$VENV_PY" -c "import fastapi" 2>/dev/null; then
  echo "start-embedding-host.sh: installing dependencies from embedding_service/requirements.txt (first run may take several minutes)…" >&2
  "$VENV_PIP" install -U pip
  "$VENV_PIP" install -r "$EMB_DIR/requirements.txt"
fi

cd "$EMB_DIR"
exec "$VENV_PY" main.py
