#!/usr/bin/env bash
# guard.sh — verifies no AIRE framework artifact has leaked into a client product repo.
# Lives in sai-systems-AIRE/tools/. Run it before any commit/push in PacEHR, pacEHR_API or PacEHR_AI.
#
#   aire/guard.sh          check both repos, report, exit 1 on leak
#   aire/guard.sh --fix    additionally restore a framework-modified .gitignore to HEAD

set -uo pipefail

# This script lives in <workspace>/sai-systems-AIRE/tools/; the repos it guards are
# siblings of sai-systems-AIRE, two levels up. Override: WORKSPACE=/path ./guard.sh
ROOT="${WORKSPACE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
REPOS=("PacEHR" "pacEHR_API" "PacEHR_AI")
FIX=0
[[ "${1:-}" == "--fix" ]] && FIX=1

# Paths AIRE creates. Any of these appearing in a repo's git status is a leak.
FRAMEWORK_PATHS=(
  "SPEC/"
  ".claude/agents/" ".claude/skills/"
  ".github/agents/" ".github/instructions/"
  ".cursor/rules/" ".windsurf/rules/" ".kiro/skills/" ".kiro/steering/"
  ".gemini/antigravity/" ".codex/"
  "docs/status.md" "docs/bugs.md" "docs/requirements.md"
  "docs/architecture/" "docs/architecture-diagrams/"
  "docs/plans/" "docs/stories/" "docs/stories-implemented/"
  "docs/enhancements/" "docs/change-requests/" "docs/deployment/"
  "docs/data/" "docs/helix/" "docs/archive/" "docs/qa/" "docs/reviews/"
  "dev-stories/" "context/" ".mcp.json"
)

leaks=0

for repo in "${REPOS[@]}"; do
  dir="$ROOT/$repo"
  [[ -d "$dir/.git" ]] || { echo "skip   $repo (not a git repo)"; continue; }

  echo "=== $repo ==="

  # 1. Framework artifacts present in the working tree (tracked or untracked)
  status="$(git -C "$dir" status --porcelain --untracked-files=all 2>/dev/null)"
  found=""
  for p in "${FRAMEWORK_PATHS[@]}"; do
    hit="$(printf '%s\n' "$status" | awk '{ $1=""; sub(/^ +/,""); print }' | grep -F -- "$p" || true)"
    [[ -n "$hit" ]] && found+="  LEAK  $p"$'\n'
  done

  # 2. .gitignore touched (aire init/update writes a managed block into it)
  if ! git -C "$dir" diff --quiet -- .gitignore 2>/dev/null; then
    found+="  LEAK  .gitignore modified"$'\n'
    if (( FIX )); then
      git -C "$dir" checkout -- .gitignore && echo "  fixed .gitignore restored to HEAD"
      found="${found//  LEAK  .gitignore modified$'\n'/}"
    fi
  fi

  # 3. pacEHR_API's own tracked AI files must stay as committed
  for f in CLAUDE.md .github/copilot-instructions.md .claude/settings.local.json; do # the repos' own tracked AI files
    if git -C "$dir" ls-files --error-unmatch "$f" >/dev/null 2>&1; then
      if ! git -C "$dir" diff --quiet -- "$f" 2>/dev/null; then
        found+="  WARN  $f modified (yours, not AIRE's — confirm intentional)"$'\n'
      fi
    fi
  done

  if [[ -n "$found" ]]; then
    printf '%s' "$found"
    grep -q "LEAK" <<<"$found" && leaks=1
  else
    echo "  clean — no framework artifacts"
  fi
  echo
done

if (( leaks )); then
  echo "FAILED: framework artifacts found. Move them to sai-systems-AIRE, or re-run with --fix for .gitignore."
  exit 1
fi
echo "OK: all repos free of AIRE framework artifacts."
