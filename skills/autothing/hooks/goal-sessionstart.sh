#!/usr/bin/env bash
# autothing SessionStart guard (stale-sentinel cleanup + session id record)
#
# Runs at every session start. Two jobs:
#   1. Record this session's id to ~/.autothing/current-session so autothing's
#      Phase 0 can bind the goal sentinel to the right session at ARM time
#      (eliminates the Stop-hook "bind on first fire" race).
#   2. Delete any goal sentinel that is bound to a DIFFERENT session — i.e. a
#      crashed/abandoned autothing run whose sentinel would otherwise linger.
#
# FAIL SAFE: never errors out the session start (always exit 0).
set -u
DIR="${HOME}/.autothing"
SENTINEL="${DIR}/goal-sentinel.json"
mkdir -p "$DIR" 2>/dev/null || true

INPUT="$(cat 2>/dev/null || true)"
command -v jq >/dev/null 2>&1 || exit 0

SID="$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)"
if [ -n "$SID" ]; then
  printf '%s' "$SID" > "${DIR}/current-session" 2>/dev/null || true
fi

# Remove a sentinel owned by an already-bound, different session.
if [ -f "$SENTINEL" ]; then
  SENT_SESSION="$(jq -r '.sessionId // empty' "$SENTINEL" 2>/dev/null)"
  if [ -n "$SENT_SESSION" ] && [ -n "$SID" ] && [ "$SENT_SESSION" != "$SID" ]; then
    rm -f "$SENTINEL" 2>/dev/null
  fi
fi
exit 0
