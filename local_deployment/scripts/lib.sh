#!/usr/bin/env bash
# Shared helpers. Sourced by every other script — never run this file directly.

set -euo pipefail

DEPLOY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

[ -f "$DEPLOY_ROOT/config.env" ] || { echo "config.env not found in $DEPLOY_ROOT" >&2; exit 1; }
# shellcheck disable=SC1091
. "$DEPLOY_ROOT/config.env"
# Optional per-person overrides (git-ignored): see config.local.env.example.
# shellcheck disable=SC1091
[ -f "$DEPLOY_ROOT/config.local.env" ] && . "$DEPLOY_ROOT/config.local.env"

# Relative repo paths in config.env are resolved against local_deployment/.
_resolve() { case "$1" in /*) printf '%s' "$1" ;; *) printf '%s' "$DEPLOY_ROOT/$1" ;; esac; }
API_REPO_ABS="$(cd "$(_resolve "$API_REPO")" 2>/dev/null && pwd)" || API_REPO_ABS=""
WEB_REPO_ABS="$(cd "$(_resolve "$WEB_REPO")" 2>/dev/null && pwd)" || WEB_REPO_ABS=""
AI_REPO_ABS="$(cd "$(_resolve "$AI_REPO")" 2>/dev/null && pwd)" || AI_REPO_ABS=""
# A file, not a folder: resolved even when it does not exist yet, so preflight can name it.
_ai_env="$(_resolve "$AI_ENV_FILE")"
if _ai_env_dir="$(cd "$(dirname "$_ai_env")" 2>/dev/null && pwd)"; then AI_ENV_FILE_ABS="$_ai_env_dir/$(basename "$_ai_env")"
else AI_ENV_FILE_ABS="$_ai_env"; fi

# Which services a target means: api | web | ai | all.
services_for() {
  case "$1" in
    api|web|ai) printf '%s' "$1" ;;
    all)        printf '%s' "api web ai" ;;
    *)          die "unknown target: $1  (api | web | ai | all)" ;;
  esac
}

# ── output helpers ──────────────────────────────────────────────────────────
if [ -t 1 ]; then
  C_OK=$'\033[32m'; C_ERR=$'\033[31m'; C_WARN=$'\033[33m'; C_DIM=$'\033[2m'; C_B=$'\033[1m'; C_0=$'\033[0m'
else
  C_OK=''; C_ERR=''; C_WARN=''; C_DIM=''; C_B=''; C_0=''
fi
step() { printf '\n%s==> %s%s\n' "$C_B" "$*" "$C_0"; }
ok()   { printf '  %s✓%s %s\n' "$C_OK" "$C_0" "$*"; }
info() { printf '  %s·%s %s\n' "$C_DIM" "$C_0" "$*"; }
warn() { printf '  %s!%s %s\n' "$C_WARN" "$C_0" "$*"; }
die()  { printf '  %s✗ %s%s\n' "$C_ERR" "$*" "$C_0" >&2; exit 1; }

# ── podman helpers ──────────────────────────────────────────────────────────
podman_ready() { command -v podman >/dev/null 2>&1 && podman info >/dev/null 2>&1; }
container_exists()  { podman container exists "$1" 2>/dev/null; }
container_running() { [ "$(podman inspect -f '{{.State.Running}}' "$1" 2>/dev/null || echo false)" = "true" ]; }
image_exists()      { podman image exists "$1" 2>/dev/null; }

# Remove a container whether it is running or stopped. Safe if absent.
remove_container() {
  if container_exists "$1"; then
    podman rm -f "$1" >/dev/null 2>&1 || true
    info "removed existing container: $1"
  fi
}

# HTTP status of a URL, or 000 if unreachable. curl prints 000 *and* exits
# non-zero on a refused connection, so the exit status is swallowed rather than
# adding a second 000.
http_code() {
  local code
  code="$(curl -s -o /dev/null -m "${2:-5}" -w '%{http_code}' "$1" 2>/dev/null)" || true
  [ -n "$code" ] || code="000"
  printf '%s' "$code"
}

# Poll a URL until it answers with any HTTP status, up to N seconds.
wait_for_http() {
  local url="$1" timeout="${2:-60}" waited=0
  while [ "$waited" -lt "$timeout" ]; do
    [ "$(http_code "$url" 3)" != "000" ] && return 0
    sleep 2; waited=$((waited + 2))
  done
  return 1
}
