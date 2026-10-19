#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  PacEHR — one-command local deployment on Podman.
#
#    ./deploy.sh                 preflight → build all three images → start them
#    ./deploy.sh --no-build      just (re)start the containers from existing images
#    ./deploy.sh --api-only      only the .NET API
#    ./deploy.sh --web-only      only the Angular frontend
#    ./deploy.sh --ai-only       only PacEHR_AI (the TypeScript encounter agent)
#    ./deploy.sh --no-cache      force a clean rebuild of the images
#
#  Settings live in config.env. None of the repos is modified by any of this.
# ─────────────────────────────────────────────────────────────────────────────
. "$(dirname "${BASH_SOURCE[0]}")/scripts/lib.sh"

do_build=1
target="all"
build_flags=()

for a in "$@"; do
  case "$a" in
    --no-build) do_build=0 ;;
    --api-only) target="api" ;;
    --web-only) target="web" ;;
    --ai-only)  target="ai" ;;
    --no-cache) build_flags+=(--no-cache) ;;
    -h|--help)  sed -n '3,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)          die "unknown argument: $a  (try --help)" ;;
  esac
done
services="$(services_for "$target")"
wants() { case " $services " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }

printf '%s\n' "${C_B}┌──────────────────────────────────────────────┐${C_0}"
printf '%s\n' "${C_B}│  PacEHR local deployment — Podman            │${C_0}"
printf '%s\n' "${C_B}└──────────────────────────────────────────────┘${C_0}"

"$DEPLOY_ROOT/scripts/preflight.sh" "$target"

if [ "$do_build" -eq 1 ]; then
  "$DEPLOY_ROOT/scripts/build.sh" "$target" ${build_flags[@]+"${build_flags[@]}"}
else
  step "Skipping build (--no-build)"
fi

"$DEPLOY_ROOT/scripts/up.sh" "$target"

step "Waiting for the containers to answer"
if wants api; then
  if wait_for_http "http://localhost:${API_PORT}/swagger/index.html" 90; then ok "API is answering"
  else warn "API did not answer within 90s — check ./scripts/logs.sh api"; fi
fi
if wants web; then
  if wait_for_http "http://localhost:${WEB_PORT}/" 60; then ok "web is answering"
  else warn "web did not answer within 60s — check ./scripts/logs.sh web"; fi
fi
if wants ai; then
  if wait_for_http "http://localhost:${AI_PORT}/health" 30; then ok "AI is answering"
  else warn "AI did not answer within 30s — a settings error exits at startup; check ./scripts/logs.sh ai"; fi
fi

"$DEPLOY_ROOT/scripts/status.sh"
