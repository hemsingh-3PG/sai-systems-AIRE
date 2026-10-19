#!/usr/bin/env bash
# check-workspace.sh — verifies this machine matches the team workspace layout.
#   tools/check-workspace.sh
# Layout expected (the folder holding sai-systems-AIRE is the "workspace"):
#   <workspace>/PacEHR  pacEHR_API  PacEHR_AI  sai-systems-AIRE
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WS="$(cd "$HERE/.." && pwd)"
ok()   { printf '  ok    %s\n' "$*"; }
bad()  { printf '  FIX   %s\n' "$*"; fails=$((fails+1)); }
note() { printf '  note  %s\n' "$*"; }
fails=0
echo "workspace: $WS"
# bash 3.2 (macOS default) has no associative arrays
base_for() { case "$1" in PacEHR) echo PacEHR-DevelopUI-Main ;; pacEHR_API) echo PacEHR-DevelopAPI-Main ;; PacEHR_AI) echo PacEHR-AI-Develop-Main ;; esac; }
for r in PacEHR pacEHR_API PacEHR_AI; do
  if [ -d "$WS/$r/.git" ]; then
    cur="$(git -C "$WS/$r" branch --show-current)"; [ -n "$cur" ] || cur="(detached)"
    ok "$r  on $cur   (team base branch: $(base_for "$r"))"
    [ -z "$(git -C "$WS/$r" status --porcelain | head -1)" ] || note "$r has uncommitted changes"
  else bad "$r not found at $WS/$r — clone it next to sai-systems-AIRE (exact folder name, case-sensitive)"; fi
done
[ -d "$HERE/SPEC/workflows" ]  && ok "SPEC/workflows present"   || bad "SPEC/ missing — re-clone sai-systems-AIRE"
[ -f "$HERE/.claude/CLAUDE.md" ] && ok ".claude/CLAUDE.md present" || bad ".claude/CLAUDE.md missing"
command -v aire >/dev/null && ok "aire CLI: $(aire --version 2>/dev/null | head -1)" || bad "aire CLI not on PATH — see TEAM-WORKFLOW.md §3"
command -v podman >/dev/null && ok "podman present (local deployment)" || note "podman not installed — only needed for local_deployment"
command -v gh >/dev/null && ok "gh present" || note "gh not installed — needed for pr-generator on GitHub"
git -C "$HERE" check-attr merge docs/status.md | grep -q union && ok "status.md merge=union active" || bad ".gitattributes missing the docs/status.md merge=union rule"
if [ -f "$HERE/.gitignore" ] && grep -q 'config.local.env' "$HERE/.gitignore"; then ok "local overrides are git-ignored"; else bad ".gitignore missing config.local.env"; fi
[ "$(git -C "$HERE" remote get-url origin 2>/dev/null | grep -c 'github.com/hemsingh')" = 0 ] && ok "origin is not a personal remote" || bad "origin is a personal GitHub remote — see TEAM-WORKFLOW.md §14 (move to the team org, private)"
echo; [ "$fails" -eq 0 ] && echo "workspace OK" || { echo "$fails problem(s) above"; exit 1; }
