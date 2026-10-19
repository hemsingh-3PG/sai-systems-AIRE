#!/usr/bin/env bash
# install-aire-cli.sh — installs/updates the `aire` CLI on a teammate's machine.
# Does NOT run `aire init`: sai-systems-AIRE already contains SPEC/, docs/ and .claude/.
# Running `aire init` or `aire update` here would rewrite those and the .gitignore — don't,
# unless the team lead asks (TEAM-WORKFLOW.md §14).
# Needs GitHub access to 3PillarGlobal/AIRE-SDLC-Agentic-Framework (gh auth login).
# Idempotent: re-running pulls the latest framework and re-links the CLI.
set -euo pipefail

FRAMEWORK_DIR="${AIRE_DIR:-$HOME/Projects/AIRE-SDLC-Agentic-Framework}"
REPO_SSH="git@github.com:3PillarGlobal/AIRE-SDLC-Agentic-Framework.git"
REPO_HTTPS="https://github.com/3PillarGlobal/AIRE-SDLC-Agentic-Framework.git"

# 1. Clone or update the framework
if [[ -d "$FRAMEWORK_DIR/.git" ]]; then
  echo "==> updating $FRAMEWORK_DIR"
  git -C "$FRAMEWORK_DIR" pull --ff-only
else
  echo "==> cloning framework to $FRAMEWORK_DIR"
  git clone "$REPO_SSH" "$FRAMEWORK_DIR" || git clone "$REPO_HTTPS" "$FRAMEWORK_DIR"
fi

# 2. Install deps and link the CLI
CLI_DIR="$FRAMEWORK_DIR/SPEC_cli_node_package"
[[ -d "$CLI_DIR" ]] || { echo "ERROR: $CLI_DIR not found — check the repo layout"; exit 1; }
echo "==> npm install in $CLI_DIR"
cd "$CLI_DIR" && npm install
# npm's global prefix here is /usr/local (root-owned), so `npm link` would prompt for
# sudo. A symlink into ~/.local/bin — already on PATH — is what `npm link` does for the
# bin anyway, and needs no password. Node resolves deps from the symlink's real path.
BIN="$CLI_DIR/bin/spec.js"
chmod +x "$BIN"
if [[ -w "$(npm prefix -g)/lib/node_modules" ]]; then
  echo "==> npm link"
  npm link
else
  echo "==> global prefix not writable; symlinking to ~/.local/bin/aire instead"
  mkdir -p "$HOME/.local/bin"
  ln -sfn "$BIN" "$HOME/.local/bin/aire"
  case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) echo "    WARNING: $HOME/.local/bin is not on PATH — add it to your shell profile" ;;
  esac
fi

# 3. Verify
command -v aire >/dev/null || { echo "ERROR: aire not on PATH"; exit 1; }
aire --help | head -5
echo
echo "==> done. Next: tools/check-workspace.sh"
