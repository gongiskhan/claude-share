#!/usr/bin/env bash
# install-memory-compiler.sh — one-time global install of coleam00/claude-memory-compiler
# into ~/.claude/memory-compiler/ so the hooks already declared in ~/.claude/settings.json
# can fire instead of silently no-op'ing.
#
# Idempotent: if the target directory already contains pyproject.toml, exits 0
# without cloning or syncing. Re-run to upgrade (triggers git pull + uv sync).
#
# Prerequisites: git, uv.

set -eu

REPO_URL="https://github.com/coleam00/claude-memory-compiler.git"
DEST="$HOME/.claude/memory-compiler"

log() { printf '[install-memory-compiler] %s\n' "$*"; }
fail() { printf '[install-memory-compiler] ERROR: %s\n' "$*" >&2; exit 1; }

# --- prerequisites ---
command -v git >/dev/null 2>&1 || fail "git not found. Install git and retry."
command -v uv  >/dev/null 2>&1 || fail "uv not found. Install uv (https://docs.astral.sh/uv/) and retry."

mkdir -p "$(dirname "$DEST")"

# --- clone or pull ---
if [ -d "$DEST/.git" ]; then
  log "memory-compiler already cloned at $DEST — pulling latest"
  (cd "$DEST" && git pull --ff-only)
elif [ -d "$DEST" ] && [ "$(ls -A "$DEST" 2>/dev/null)" ]; then
  fail "$DEST exists and is non-empty but is not a git checkout. Remove or move it, then retry."
else
  log "cloning $REPO_URL → $DEST"
  git clone --depth 1 "$REPO_URL" "$DEST"
fi

# --- sync python deps ---
if [ ! -f "$DEST/pyproject.toml" ]; then
  fail "$DEST/pyproject.toml not found after clone — unexpected repo layout. Inspect $DEST and retry."
fi

log "running uv sync in $DEST"
(cd "$DEST" && uv sync)

# --- verify hook scripts exist ---
MISSING=""
for hook in session-start.py session-end.py pre-compact.py; do
  if [ ! -f "$DEST/hooks/$hook" ]; then
    MISSING="$MISSING $hook"
  fi
done
if [ -n "$MISSING" ]; then
  log "WARNING: expected hook scripts missing:$MISSING"
  log "The upstream repo layout may have changed. The global settings.json hooks will still no-op safely."
else
  log "hook scripts present: session-start.py session-end.py pre-compact.py"
fi

log "done. The SessionStart/SessionEnd/PreCompact hooks in ~/.claude/settings.json will now fire."
