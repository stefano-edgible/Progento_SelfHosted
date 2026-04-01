#!/usr/bin/env bash
# Best-effort: stop host Ollama / embedding started for external-* compose (not Docker services).
#
# Reads OLLAMA_URL / EMBEDDING_SERVICE_URL from the environment (load .env before calling).
# Only acts when the URL host resolves to this machine (127.0.0.1 after mapping host.docker.internal).
#
# Ollama: pkill "ollama serve", macOS app quit — does NOT kill docker-proxy on 11434.
# Embedding: stops Python listeners on the configured port when command looks like host embedding
#   (python + main.py or uvicorn under embedding path), or if PROGENTO_STOP_EMBEDDING_BY_PORT=1.
#
# Usage (from repo root): scripts/stop-external-host-services.sh ollama|embedding|both
set -euo pipefail

_parse_http_host_port() {
  local raw="$1" default_port="$2"
  local url="$raw"
  url="${url#http://}"
  url="${url#https://}"
  url="${url%%/*}"
  local host port
  if [[ "$url" == *:* ]]; then
    host="${url%%:*}"
    port="${url##*:}"
  else
    host="$url"
    port="$default_port"
  fi
  case "$host" in
    host.docker.internal | localhost | "") host="127.0.0.1" ;;
  esac
  printf '%s %s' "$host" "${port:-$default_port}"
}

_is_local_target() {
  local raw="$1" default_port="$2" host
  read -r host _ <<<"$(_parse_http_host_port "$raw" "$default_port")"
  [[ "$host" == "127.0.0.1" ]]
}

_stop_ollama_host() {
  local raw="${OLLAMA_URL:-http://127.0.0.1:11434}"
  _is_local_target "$raw" 11434 || {
    echo "stop-external-host-services: Ollama URL is not local — not stopping host Ollama." >&2
    return 0
  }

  echo "stop-external-host-services: stopping host Ollama (if running)…" >&2

  if [[ "$(uname -s)" == "Darwin" ]]; then
    osascript -e 'tell application "Ollama" to quit' 2>/dev/null || true
    sleep 1
  fi

  if pgrep -f '[o]llama serve' >/dev/null 2>&1; then
    pkill -f '[o]llama serve' 2>/dev/null || true
    sleep 1
  fi

  if [[ "$(uname -s)" == "Darwin" ]] && pgrep -x Ollama >/dev/null 2>&1; then
    killall Ollama 2>/dev/null || true
  fi

  echo "stop-external-host-services: Ollama stop attempted." >&2
}

_embedding_port() {
  read -r _ port <<<"$(_parse_http_host_port "${EMBEDDING_SERVICE_URL:-http://127.0.0.1:8002}" 8002)"
  echo "$port"
}

_stop_embedding_host() {
  local raw="${EMBEDDING_SERVICE_URL:-http://127.0.0.1:8002}"
  _is_local_target "$raw" 8002 || {
    echo "stop-external-host-services: Embedding URL is not local — not stopping host embedding." >&2
    return 0
  }

  local port
  port="$(_embedding_port)"
  echo "stop-external-host-services: stopping host embedding on port ${port} (if matched)…" >&2

  if [[ "${PROGENTO_STOP_EMBEDDING_BY_PORT:-0}" == "1" ]]; then
    _kill_listener_on_port "$port"
    echo "stop-external-host-services: port ${port} kill attempted (PROGENTO_STOP_EMBEDDING_BY_PORT=1)." >&2
    return 0
  fi

  if pkill -f '[e]mbedding_service/main.py' 2>/dev/null; then
    echo "stop-external-host-services: matched embedding_service/main.py" >&2
    sleep 1
    return 0
  fi

  _stop_embedding_by_port_python "$port"
}

_kill_listener_on_port() {
  local port="$1" pids
  if command -v lsof >/dev/null 2>&1; then
    pids=$(lsof -ti TCP:"$port" -sTCP:LISTEN 2>/dev/null || true)
    if [[ -n "$pids" ]]; then
      # shellcheck disable=SC2086
      kill $pids 2>/dev/null || true
      sleep 1
      pids=$(lsof -ti TCP:"$port" -sTCP:LISTEN 2>/dev/null || true)
      if [[ -n "$pids" ]]; then
        # shellcheck disable=SC2086
        kill -9 $pids 2>/dev/null || true
      fi
    fi
  elif command -v fuser >/dev/null 2>&1; then
    fuser -k "${port}/tcp" 2>/dev/null || true
  fi
}

_stop_embedding_by_port_python() {
  local port="$1"
  if ! command -v lsof >/dev/null 2>&1; then
    echo "stop-external-host-services: no lsof — set PROGENTO_STOP_EMBEDDING_BY_PORT=1 to force port kill, or install lsof." >&2
    return 0
  fi
  local pids
  pids=$(lsof -ti TCP:"$port" -sTCP:LISTEN 2>/dev/null || true)
  if [[ -z "$pids" ]]; then
    echo "stop-external-host-services: nothing listening on port ${port}." >&2
    return 0
  fi
  local pid cmd ok=0
  for pid in $pids; do
    cmd=$(ps -p "$pid" -o command= 2>/dev/null || true)
    case "$cmd" in
      *docker-proxy* | *com.docker* ) continue ;;
      *python*main.py* | *Python*main.py* | *uvicorn* | *embedding_service* )
        kill "$pid" 2>/dev/null || true
        ok=1
        ;;
    esac
  done
  if [[ "$ok" == "1" ]]; then
    sleep 1
    echo "stop-external-host-services: stopped embedding listener on port ${port}." >&2
  else
    echo "stop-external-host-services: port ${port} listener did not look like host embedding (use PROGENTO_STOP_EMBEDDING_BY_PORT=1 to force)." >&2
  fi
}

main() {
  local mode="${1:-}"
  case "$mode" in
    ollama) _stop_ollama_host ;;
    embedding) _stop_embedding_host ;;
    both)
      _stop_ollama_host
      _stop_embedding_host
      ;;
    *)
      echo "usage: $0 ollama|embedding|both" >&2
      return 2
      ;;
  esac
}

main "$@"
