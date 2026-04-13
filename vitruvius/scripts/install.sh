#!/usr/bin/env bash
# install.sh — Vitruvius post-install setup
# Run: bash vitruvius/scripts/install.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "Installing vitruvius from: $PLUGIN_ROOT"

# 1. Detect node binary
NODE_BIN=""
if command -v node &>/dev/null; then
  NODE_BIN="$(command -v node)"
elif [[ -f "$HOME/.nvm/nvm.sh" ]]; then
  NODE_BIN="$(. "$HOME/.nvm/nvm.sh" 2>/dev/null && nvm which default 2>/dev/null || echo "")"
elif command -v fnm &>/dev/null; then
  NODE_BIN="$(fnm exec --using default which node 2>/dev/null || echo "")"
fi

if [[ -z "$NODE_BIN" ]]; then
  echo "Error: node not found. Install Node.js >= 18." >&2
  exit 1
fi

NODE_VERSION="$("$NODE_BIN" --version 2>/dev/null || echo "unknown")"
echo "Using node: $NODE_BIN ($NODE_VERSION)"

# 2. Write vitruvius.env
mkdir -p "$HOME/.claude"
cat > "$HOME/.claude/vitruvius.env" <<EOF
export VITRUVIUS_ROOT="$PLUGIN_ROOT"
export VITRUVIUS_NODE_BIN="$NODE_BIN"
EOF
echo "Wrote $HOME/.claude/vitruvius.env"

# 3. Install channel server dependencies
echo "Installing channel server dependencies..."
cd "$PLUGIN_ROOT/channel" && npm install --silent
echo "Channel server dependencies installed."

# 4. Create runtime directories
mkdir -p "$HOME/.claude/bus" "$HOME/.claude/workspaces"

# 5. Add to shell rc (idempotent)
MARKER="# vitruvius ct workspace"
SHELL_RC="$HOME/.zshrc"

# Detect shell if not zsh
if [[ -n "${BASH_VERSION:-}" && ! -f "$HOME/.zshrc" ]]; then
  SHELL_RC="$HOME/.bashrc"
fi

if ! grep -qF "$MARKER" "$SHELL_RC" 2>/dev/null; then
  cat >> "$SHELL_RC" <<'RCEOF'

# vitruvius ct workspace
[ -f "$HOME/.claude/vitruvius.env" ] && source "$HOME/.claude/vitruvius.env"
[ -n "$VITRUVIUS_ROOT" ] && [ -f "$VITRUVIUS_ROOT/scripts/ct.sh" ] && source "$VITRUVIUS_ROOT/scripts/ct.sh"
RCEOF
  echo "Added ct loader to $SHELL_RC"
else
  echo "ct loader already in $SHELL_RC (skipped)"
fi

# 6. Make scripts executable
chmod +x "$PLUGIN_ROOT/scripts/ct.sh" "$PLUGIN_ROOT/scripts/notify.sh"
chmod +x "$PLUGIN_ROOT/hooks/scripts/stop-notify.sh" "$PLUGIN_ROOT/hooks/scripts/notification.sh"

echo ""
echo "Vitruvius installed successfully."
echo "Restart your shell or run: source $SHELL_RC"
echo "Then launch a workspace: ct /path/to/project"
