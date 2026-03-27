#!/usr/bin/env bash
# Best-effort: ensure host Ollama (and optionally embedding) is reachable before
# docker compose starts when using external-* compose files.
#
# Reads OLLAMA_URL / EMBEDDING_SERVICE_URL from the environment (load .env before calling).
#
# PROGENTO_AUTO_START_EXTERNAL=0 — skip all probes and start attempts (default is 1).
# PROGENTO_EMBEDDING_START_CMD — if set and embedding is down, runs via: bash -lc "$PROGENTO_EMBEDDING_START_CMD"
#
# Usage (from repo root): scripts/ensure-external-host-services.sh ollama|embedding|both
set -euo pipefail

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
    sleep 4
    _ollama_reachable && return 0
  fi

  if command -v ollama >/dev/null 2>&1; then
    if pgrep -f "[o]llama serve" >/dev/null 2>&1 || pgrep -x ollama >/dev/null 2>&1; then
      sleep 2
      _ollama_reachable && return 0
    fi
    (OLLAMA_HOST="${OLLAMA_HOST:-0.0.0.0:11434}" ollama serve >>"${TMPDIR:-/tmp}/progento-ollama-serve.log" 2>&1 &)
    sleep 3
    _ollama_reachable && return 0
  fi

  if command -v systemctl >/dev/null 2>&1; then
    systemctl start ollama 2>/dev/null || systemctl --user start ollama 2>/dev/null || true
    sleep 2
    _ollama_reachable && return 0
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

  if _embedding_reachable; then
    return 0
  fi

  if [[ -n "${PROGENTO_EMBEDDING_START_CMD:-}" ]]; then
    echo "ensure-external-host-services: Embedding not reachable — running PROGENTO_EMBEDDING_START_CMD…" >&2
    bash -lc "$PROGENTO_EMBEDDING_START_CMD" &
    sleep 3
    _embedding_reachable && return 0
  fi

  echo "ensure-external-host-services: Embedding not reachable at http://${host}:${port}/health." >&2
  echo "  Run the progento-embedding service on the host (e.g. Docker image ghcr.io/.../progento-embedding, or uvicorn in Progento/embedding_service)." >&2
  echo "  Optional: set PROGENTO_EMBEDDING_START_CMD in .env to a shell command that starts it." >&2
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
