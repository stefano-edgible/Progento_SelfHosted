#!/usr/bin/env bash
# Source from Progento_SelfHosted repo root (after cd there), e.g. from start*.sh:
#   source "$SCRIPT_DIR/scripts/progento-compose.sh"
#
# On every source, refreshes docker-compose.kbase.generated.yml from kbase.volumes
# (no-op if kbase.volumes is missing — same as ./scripts/gen-kbase-compose.sh).
#
# Then: progento_compose docker-compose.yml pull
#   or: progento_compose docker-compose.external-ollama.yml up -d
_pcs_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_pcs_root="$(cd "$_pcs_dir/.." && pwd)"
if [ -f "$_pcs_dir/gen-kbase-compose.sh" ]; then
  (cd "$_pcs_root" && bash "$_pcs_dir/gen-kbase-compose.sh")
fi

progento_compose() {
  local main_file="$1"
  shift
  if [ -f docker-compose.kbase.generated.yml ]; then
    docker compose -f "$main_file" -f docker-compose.kbase.generated.yml "$@"
  else
    docker compose -f "$main_file" "$@"
  fi
}
