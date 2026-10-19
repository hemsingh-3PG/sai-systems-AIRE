#!/usr/bin/env bash
# Checks everything the deployment needs before a single byte is built.
# Usage: ./scripts/preflight.sh [api|web|ai|all]
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

services="$(services_for "${1:-all}")"
wants() { case " $services " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }

step "Preflight ($services)"

command -v podman >/dev/null 2>&1 || die "podman is not installed. Install Podman Desktop from https://podman-desktop.io"
ok "podman: $(podman --version)"

if ! podman info >/dev/null 2>&1; then
  warn "the Podman machine is not running — starting it"
  podman machine start || die "could not start the Podman machine. Open Podman Desktop and start it there."
fi
ok "podman machine is running"

if wants api; then
  [ -n "$API_REPO_ABS" ] || die "API repo not found at: $(_resolve "$API_REPO")  (clone it next to sai-systems-AIRE, or set API_REPO in config.local.env)"
  [ -f "$API_REPO_ABS/PacEHR.API/PacEHR.API.csproj" ] || die "$API_REPO_ABS does not look like the pacEHR_API repo"
  ok "API repo:  $API_REPO_ABS"
fi

if wants web; then
  [ -n "$WEB_REPO_ABS" ] || die "web repo not found at: $(_resolve "$WEB_REPO")  (clone it next to sai-systems-AIRE, or set WEB_REPO in config.local.env)"
  [ -f "$WEB_REPO_ABS/angular.json" ] || die "$WEB_REPO_ABS does not look like the PacEHR frontend repo"
  ok "web repo:  $WEB_REPO_ABS"
fi

if wants ai; then
  [ -n "$AI_REPO_ABS" ] || die "AI repo not found at: $(_resolve "$AI_REPO")  (clone it next to sai-systems-AIRE, or set AI_REPO in config.local.env)"
  [ -f "$AI_REPO_ABS/package.json" ] || die "$AI_REPO_ABS does not look like the PacEHR_AI repo"
  [ -f "$AI_REPO_ABS/src/server.ts" ] && [ -f "$AI_REPO_ABS/tsconfig.build.json" ] \
    || die "$AI_REPO_ABS has no src/server.ts + tsconfig.build.json — check out PacEHR-AI-Develop-Main (the TypeScript layout)"
  ok "AI repo:   $AI_REPO_ABS  (branch: $(git -C "$AI_REPO_ABS" branch --show-current 2>/dev/null || echo '?'))"
  if [ -f "$AI_ENV_FILE_ABS" ]; then
    ok "AI settings: $AI_ENV_FILE_ABS"
    # Names only — never print a value from this file.
    missing=""
    for name in AZURE_OPENAI_ENDPOINT AZURE_OPENAI_API_VERSION AZURE_OPENAI_GPT_4_1_DEPLOYMENT AZURE_SQL_SERVER AZURE_SQL_DATABASE ENTRA_TENANT_ID ENTRA_AUDIENCE; do
      grep -Eq "^${name}=[^[:space:]]" "$AI_ENV_FILE_ABS" || missing="$missing $name"
    done
    [ -z "$missing" ] || warn "empty in the AI settings file:$missing — the container will exit at startup"
    if grep -Eq '^[A-Z0-9_]+=["'"'"']' "$AI_ENV_FILE_ABS"; then
      warn "the AI settings file has quoted values; podman keeps the quotes as part of the value — remove them"
    fi
  else
    die "AI settings file not found: $AI_ENV_FILE_ABS
       create it:  cp \"$AI_REPO_ABS/.env.example\" \"$AI_ENV_FILE_ABS\"   then fill in the values"
  fi
fi

# Free disk inside the Podman VM. The Angular + .NET builds together need
# roughly 15 GB of headroom; a full VM fails mid-build with a confusing
# "no space left on device" from the layer writer.
avail_kb="$(podman machine ssh -- df -Pk / 2>/dev/null | awk 'NR==2 {print $4}')" || avail_kb=""
if [ -n "$avail_kb" ]; then
  avail_gb=$((avail_kb / 1024 / 1024))
  if [ "$avail_gb" -lt 15 ]; then
    warn "only ${avail_gb} GB free inside the Podman VM — builds may fail"
    warn "free space with:  podman system prune -f"
    warn "or grow the VM:   podman machine stop && podman machine set --disk-size <GB> && podman machine start"
    warn "                  then inside it: sudo growpart /dev/vda 4 && sudo xfs_growfs /"
  else
    ok "Podman VM disk: ${avail_gb} GB free"
  fi
fi

# Ports must be free unless they are held by our own containers (a redeploy).
pairs=()
wants api && pairs+=("API:$API_PORT:$API_CONTAINER")
wants web && pairs+=("WEB:$WEB_PORT:$WEB_CONTAINER")
wants ai  && pairs+=("AI:$AI_PORT:$AI_CONTAINER")
for pair in "${pairs[@]}"; do
  label="${pair%%:*}"; rest="${pair#*:}"; port="${rest%%:*}"; cname="${rest#*:}"
  if lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; then
    if container_running "$cname"; then
      info "$label port $port is held by the existing $cname container (it will be replaced)"
    else
      die "$label port $port is already in use by something else. Change ${label}_PORT in config.env or free the port."
    fi
  else
    ok "$label port $port is free"
  fi
done

step "Preflight passed"
