#!/bin/bash
# obsidian-vault-sync.sh — automatic git sync for the Obsidian Vault.
#
# Why this exists: agents (Basic Memory via Claude / Codex / Gemini) write notes
# into the vault even when Obsidian is closed, so obsidian-git (which only runs
# while the app is open) is insufficient. This runs under launchd regardless of
# whether Obsidian or any editor is open.
#
# Strategy (non-destructive, never hard-resets):
#   1. Stage + commit local changes first (captures agent/editor writes).
#   2. git pull --rebase --autostash to ingest other machines below our commit.
#   3. On rebase conflict: abort (restores pre-rebase state) and log; never reset.
#   4. git push.
# Status is written to ~/.garrison/obsidian-vault-sync-status.json; full log to
# ~/Library/Logs/obsidian-vault-sync.log.
# NOTE: the status/lock filenames are obsidian-* prefixed to avoid colliding with
# Garrison's separate rsync `vault-sync` fitting (which owns vault-sync-status.json).

set -uo pipefail

VAULT="${OBSIDIAN_VAULT:-$HOME/ObsidianVault}"
LOG="$HOME/Library/Logs/obsidian-vault-sync.log"
STATUS_DIR="$HOME/.garrison"
STATUS="$STATUS_DIR/obsidian-vault-sync-status.json"
LOCK="$STATUS_DIR/obsidian-vault-sync.lock"

mkdir -p "$STATUS_DIR" "$(dirname "$LOG")"

ts() { date -u +%Y-%m-%dT%H:%M:%SZ; }
log() { echo "[$(ts)] $*" >>"$LOG"; }

write_status() {
  # $1 = state (ok|conflict|error|nochange|push-failed), $2 = message.
  # Pure-bash JSON escaping (no python dependency — launchd context may lack it).
  local msg="$2"
  msg="${msg//\\/\\\\}"   # backslash
  msg="${msg//\"/\\\"}"   # double-quote
  msg="${msg//$'\n'/ }"   # newlines -> space
  printf '{"state":"%s","message":"%s","ts":"%s"}\n' "$1" "$msg" "$(ts)" >"$STATUS"
}

# Single-instance lock (mkdir is atomic). Stale locks older than 30 min are cleared.
if ! mkdir "$LOCK" 2>/dev/null; then
  if [ -d "$LOCK" ] && [ "$(find "$LOCK" -maxdepth 0 -mmin +30 2>/dev/null)" ]; then
    rmdir "$LOCK" 2>/dev/null && mkdir "$LOCK" 2>/dev/null || { log "lock held, exiting"; exit 0; }
  else
    log "another sync is running, exiting"; exit 0
  fi
fi
trap 'rmdir "$LOCK" 2>/dev/null' EXIT

cd "$VAULT" 2>/dev/null || { log "vault not found at $VAULT"; write_status error "vault dir missing"; exit 1; }

if [ ! -d .git ]; then
  log "no git repo in vault"; write_status error "no .git in vault"; exit 1
fi

# 1. Commit local changes (if any).
git add -A
if ! git diff --cached --quiet; then
  git commit -q -m "vault sync: $(ts)" 2>>"$LOG"
  log "committed local changes"
  LOCAL_CHANGES=1
else
  LOCAL_CHANGES=0
fi

# 2. Ingest remote (rebase our work on top). --autostash guards any stray worktree state.
if ! git pull --rebase --autostash origin main >>"$LOG" 2>&1; then
  log "rebase conflict — aborting (no data lost; manual resolution needed)"
  git rebase --abort >>"$LOG" 2>&1 || true
  write_status conflict "git pull --rebase hit a conflict; aborted. Resolve manually in $VAULT."
  exit 1
fi

# 3. Push if we are ahead.
if [ -n "$(git rev-list origin/main..HEAD 2>/dev/null)" ]; then
  if git push origin main >>"$LOG" 2>&1; then
    log "pushed"
    write_status ok "synced"
  else
    log "push failed (network/auth?)"
    write_status push-failed "git push failed; will retry next interval"
    exit 1
  fi
else
  [ "$LOCAL_CHANGES" -eq 0 ] && write_status nochange "nothing to sync" || write_status ok "synced (already current)"
fi

log "done"
exit 0
