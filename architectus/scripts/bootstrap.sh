#!/usr/bin/env bash
# bootstrap.sh — per-project setup for Architectus.
# Runs in the project's cwd. Idempotent — each step presence-checks first.
# First run also installs coleam00/claude-memory-compiler globally.

set -eu

ARCHITECTUS_ROOT="/Users/ggomes/.claude/architectus"

log()  { printf '[architectus-bootstrap] %s\n' "$*"; }
warn() { printf '[architectus-bootstrap] WARN: %s\n' "$*" >&2; }
fail() { printf '[architectus-bootstrap] ERROR: %s\n' "$*" >&2; exit 1; }

# --- 1. cwd must be a project ---
if [ ! -d ".git" ] && [ ! -f "package.json" ] && [ ! -f "pyproject.toml" ] && [ ! -f "Cargo.toml" ] && [ ! -f "go.mod" ]; then
  fail "cwd does not look like a project root (no .git, package.json, pyproject.toml, Cargo.toml, or go.mod). cd into your project and retry."
fi

log "bootstrapping project: $PWD"

# --- 1.5 Plugin registration (user-level, idempotent) ---
MARKETPLACE_DIR="/Users/ggomes/.claude/architectus-marketplace"
if command -v claude >/dev/null 2>&1; then
  if claude plugin marketplace list 2>/dev/null | grep -q '^\s*❯\s*architectus-local$'; then
    log "marketplace architectus-local already registered — skipping"
  else
    log "registering architectus-local marketplace"
    claude plugin marketplace add "$MARKETPLACE_DIR" || warn "marketplace add failed — register manually with: claude plugin marketplace add $MARKETPLACE_DIR"
  fi
  if claude plugin list 2>/dev/null | grep -q 'architectus@architectus-local'; then
    log "plugin architectus already installed — skipping"
  else
    log "installing architectus@architectus-local"
    claude plugin install architectus@architectus-local || warn "plugin install failed — install manually with: claude plugin install architectus@architectus-local"
  fi
else
  warn "'claude' CLI not found on PATH — install the plugin manually from inside Claude Code:"
  warn "  /plugin marketplace add $MARKETPLACE_DIR"
  warn "  /plugin install architectus@architectus-local"
fi

# --- 2. Global once: memory-compiler ---
if [ ! -f "$HOME/.claude/memory-compiler/pyproject.toml" ]; then
  log "memory-compiler not installed globally — running install-memory-compiler.sh"
  bash "$ARCHITECTUS_ROOT/scripts/install-memory-compiler.sh"
else
  log "memory-compiler already installed at ~/.claude/memory-compiler/ — skipping"
fi

# --- 3. Per-project directories ---
for d in .claude/architectus .claude/plans; do
  if [ ! -d "$d" ]; then
    mkdir -p "$d"
    log "created $d"
  fi
done

# --- 4. .claudeignore ---
if [ ! -f ".claudeignore" ]; then
  cp "$ARCHITECTUS_ROOT/templates/claudeignore.template" ".claudeignore"
  log "created .claudeignore"
else
  log ".claudeignore already present — skipping"
fi

# --- 5. .claude/tasks.md ---
if [ ! -f ".claude/tasks.md" ]; then
  cp "$ARCHITECTUS_ROOT/templates/tasks.md" ".claude/tasks.md"
  log "created .claude/tasks.md"
else
  log ".claude/tasks.md already present — skipping"
fi

# --- 6. .claude/project-classifier.md (warn only, do not auto-generate) ---
if [ ! -f ".claude/project-classifier.md" ]; then
  warn ".claude/project-classifier.md is missing."
  warn "Generate it from inside Claude Code by running: /architectus:plan-with-testing"
  warn "Template: $ARCHITECTUS_ROOT/templates/project-classifier.md"
fi

# --- 7. .claude/architectus/strikes.json ---
if [ ! -f ".claude/architectus/strikes.json" ]; then
  printf '%s\n' '{"issues":{}}' > ".claude/architectus/strikes.json"
  log "initialized .claude/architectus/strikes.json"
else
  log "strikes.json already present — skipping"
fi

# --- 8. summary ---
log "bootstrap complete."
log "next: open Claude Code in this project. The SessionStart hook will greet you and prompt for /architectus:plan-with-testing if the classifier is still missing."
