#!/usr/bin/env bash
# Best-effort: ensure host Ollama (and optionally embedding) is reachable before
# docker compose starts when using external-* compose files.
#
# Reads OLLAMA_URL / EMBEDDING_SERVICE_URL from the environment (load .env before calling).
#
# PROGENTO_AUTO_START_EXTERNAL=0 — skip all probes and start attempts (default is 1).
# PROGENTO_EMBEDDING_START_CMD — if set and embedding is down, runs from this repo root via bash -c (see script body)
# PROGENTO_EMBEDDING_START_WAIT_SEC — max seconds to poll /health after auto-start (default 120; first model load is often slow).
# PROGENTO_EMBEDDING_START_WAIT_INTERVAL — seconds between /health checks (default 3).
# PROGENTO_OLLAMA_START_WAIT_SEC — max seconds to poll Ollama /api/tags after auto-start (default 90).
# PROGENTO_OLLAMA_START_WAIT_INTERVAL — seconds between Ollama checks (default 3).
#
# Usage (from repo root): scripts/ensure-external-host-services.sh ollama|embedding|both
set -euo pipefail

# Repo root (Progento_SelfHosted). Embedding start cmd resolves relative paths from here (e.g. ../Progento/embedding_service).
_SELFHOSTED_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

_have_curl() { command -v curl >/dev/null 2>&1; }
_have_wget() { command -v wget >/dev/null 2>&1; }

_http_get() {
  local url="$1" code
  if _have_curl; then
    code="$(curl -sS --connect-timeout 2 --max-time 5 -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || true)"
    [[ -z "$code" ]] && code="000"
    echo "$code"
  elif _have_wget; then
    wget -q --timeout=5 --spider "$url" 2>/dev/null && echo 200 || echo 000
  else
    echo "000"
  fi
}

# Print host and port to use for local probes / start (maps host.docker.internal → 127.0.0.1).
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

_ollama_reachable() {
  local host port
  read -r host port <<<"$(_parse_http_host_port "${OLLAMA_URL:-http://127.0.0.1:11434}" 11434)"
  local code
  code="$(_http_get "http://${host}:${port}/api/tags")"
  [[ "$code" == "200" ]]
}

_embedding_reachable() {
  local host port
  read -r host port <<<"$(_parse_http_host_port "${EMBEDDING_SERVICE_URL:-http://127.0.0.1:8002}" 8002)"
  local code
  code="$(_http_get "http://${host}:${port}/health")"
  [[ "$code" == "200" ]]
}

# True if something accepts TCP on loopback:port (no HTTP — avoids uvicorn access lines on user TTY during probes).
_embedding_loopback_port_open() {
  local host port
  read -r host port <<<"$(_parse_http_host_port "${EMBEDDING_SERVICE_URL:-http://127.0.0.1:8002}" 8002)"
  [[ "$host" == "127.0.0.1" ]] || return 1
  if command -v python3 >/dev/null 2>&1; then
    python3 -c "import socket; s=socket.socket(); s.settimeout(1); s.connect(('127.0.0.1', int('$port'))); s.close()" 2>/dev/null
    return $?
  fi
  _embedding_reachable
}

# Poll until Ollama responds (first arg = max seconds).
_wait_ollama_reachable() {
  local max_sec="${1:-90}"
  local interval="${PROGENTO_OLLAMA_START_WAIT_INTERVAL:-3}"
  local elapsed=0
  while [[ "$elapsed" -lt "$max_sec" ]]; do
    if _ollama_reachable; then
      [[ "$elapsed" -gt 0 ]] && echo "ensure-external-host-services: Ollama OK after ${elapsed}s." >&2
      return 0
    fi
    sleep "$interval"
    elapsed=$((elapsed + interval))
  done
  return 1
}

# Poll embedding /health until OK (PROGENTO_EMBEDDING_START_WAIT_SEC, default 120).
_wait_embedding_reachable() {
  local max_sec="${PROGENTO_EMBEDDING_START_WAIT_SEC:-120}"
  local interval="${PROGENTO_EMBEDDING_START_WAIT_INTERVAL:-3}"
  local elapsed=0
  while [[ "$elapsed" -lt "$max_sec" ]]; do
    if _embedding_reachable; then
      [[ "$elapsed" -gt 0 ]] && echo "ensure-external-host-services: embedding /health OK after ${elapsed}s." >&2
      return 0
    fi
    sleep "$interval"
    elapsed=$((elapsed + interval))
  done
  return 1
}


_try_start_ollama() {
  local host port
  read -r host port <<<"$(_parse_http_host_port "${OLLAMA_URL:-http://127.0.0.1:11434}" 11434)"
  if [[ "$host" != "127.0.0.1" ]]; then
    echo "ensure-external-host-services: Ollama URL host is ${host} (not local). Not auto-starting; start Ollama on that machine." >&2
    return 1
  fi

  if _ollama_reachable; then
    return 0
  fi

  echo "ensure-external-host-services: Ollama not reachable at http://${host}:${port} — attempting to start…" >&2

  if [[ "$(uname -s)" == "Darwin" ]] && command -v open >/dev/null 2>&1; then
    open -a Ollama 2>/dev/null || true
    echo "ensure-external-host-services: waiting for Ollama (up to ${PROGENTO_OLLAMA_START_WAIT_SEC:-90}s)…" >&2
    _wait_ollama_reachable "${PROGENTO_OLLAMA_START_WAIT_SEC:-90}" && return 0
  fi

  if command -v ollama >/dev/null 2>&1; then
    if pgrep -f "[o]llama serve" >/dev/null 2>&1 || pgrep -x ollama >/dev/null 2>&1; then
      echo "ensure-external-host-services: ollama process present — waiting for API…" >&2
      _wait_ollama_reachable "${PROGENTO_OLLAMA_START_WAIT_SEC:-90}" && return 0
    fi
    (OLLAMA_HOST="${OLLAMA_HOST:-0.0.0.0:11434}" ollama serve >>"${TMPDIR:-/tmp}/progento-ollama-serve.log" 2>&1 &)
    echo "ensure-external-host-services: started ollama serve — waiting for API (up to ${PROGENTO_OLLAMA_START_WAIT_SEC:-90}s)…" >&2
    _wait_ollama_reachable "${PROGENTO_OLLAMA_START_WAIT_SEC:-90}" && return 0
  fi

  if command -v systemctl >/dev/null 2>&1; then
    systemctl start ollama 2>/dev/null || systemctl --user start ollama 2>/dev/null || true
    _wait_ollama_reachable "${PROGENTO_OLLAMA_START_WAIT_SEC:-60}" && return 0
  fi

  echo "ensure-external-host-services: Could not start Ollama automatically. Install/start Ollama on the host, then:" >&2
  echo "  curl -sS http://127.0.0.1:${port}/api/tags" >&2
  echo "Or use ./start.sh to run Ollama inside Docker instead." >&2
  return 1
}

_try_start_embedding() {
  local host port
  read -r host port <<<"$(_parse_http_host_port "${EMBEDDING_SERVICE_URL:-http://127.0.0.1:8002}" 8002)"
  if [[ "$host" != "127.0.0.1" ]]; then
    echo "ensure-external-host-services: Embedding URL host is ${host} (not local). Not auto-starting." >&2
    return 1
  fi

  _emb_log="$_SELFHOSTED_ROOT/progento-embedding-host.log"

  if _embedding_loopback_port_open; then
    if [[ -n "${PROGENTO_EMBEDDING_START_CMD:-}" ]]; then
      echo "ensure-external-host-services: embedding already up on http://${host}:${port} — did not run PROGENTO_EMBEDDING_START_CMD (no log file from this script)." >&2
      echo "ensure-external-host-services: stop the existing process to use auto-start, or tail logs wherever you launched it." >&2
    fi
    return 0
  fi

  if [[ -n "${PROGENTO_EMBEDDING_START_CMD:-}" ]]; then
    echo "ensure-external-host-services: Embedding not reachable — running PROGENTO_EMBEDDING_START_CMD…" >&2
    : >>"$_emb_log"
    (
      cd "$_SELFHOSTED_ROOT" || exit 1
      exec >>"$_emb_log" 2>&1
      bash -c "$PROGENTO_EMBEDDING_START_CMD"
    ) &
    echo "ensure-external-host-services: embedding stdout/stderr → $_emb_log" >&2
    echo "ensure-external-host-services: waiting for /health (up to ${PROGENTO_EMBEDDING_START_WAIT_SEC:-120}s — first model load is often slow)…" >&2
    sleep 2
    if _wait_embedding_reachable; then
      return 0
    fi
    echo "ensure-external-host-services: embedding still not healthy after ${PROGENTO_EMBEDDING_START_WAIT_SEC:-120}s." >&2
    echo "  Check: tail -f $_emb_log" >&2
    echo "  Increase wait: PROGENTO_EMBEDDING_START_WAIT_SEC=300 ./start-external-both.sh" >&2
  fi

  echo "ensure-external-host-services: Embedding not reachable at http://${host}:${port}/health." >&2
  echo "  Run embedding natively on the host (GPU): pip install -r embedding_service/requirements.txt then PROGENTO_EMBEDDING_START_CMD=./scripts/start-embedding-host.sh — or any command listening on port 8002." >&2
  echo "  Optional: set PROGENTO_EMBEDDING_START_CMD in .env to a shell command that starts it." >&2
  echo "  Docker compose will still start; fix embedding before scanning." >&2
  return 1
}

main() {
  local mode="${1:-}"

  if [[ "${PROGENTO_AUTO_START_EXTERNAL:-1}" == "0" ]]; then
    echo "ensure-external-host-services: PROGENTO_AUTO_START_EXTERNAL=0 — skipping." >&2
    return 0
  fi

  case "$mode" in
    ollama)
      _try_start_ollama || true
      ;;
    embedding)
      _try_start_embedding || true
      ;;
    both)
      _try_start_ollama || true
      _try_start_embedding || true
      ;;
    *)
      echo "usage: $0 ollama|embedding|both" >&2
      return 2
      ;;
  esac
}

main "$@"
