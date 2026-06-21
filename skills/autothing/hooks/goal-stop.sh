#!/usr/bin/env bash
# autothing goal-loop Stop hook  (reproduces /goal, deterministically)
#
# type:"command" Stop hook. NO model call, NO `claude -p`, NO Agent SDK.
# It blocks the stop (forcing another turn) while an autothing run is armed and
# has NOT yet printed its terminal `GLOBAL GATE:` verdict in this session's
# transcript. The verdict line, the sentinel's absence, or the turn cap release it.
#
# Termination (any -> allow the stop, exit 0):
#   * sentinel absent / different session         -> not our run
#   * transcript has the terminal GLOBAL GATE line -> done (delete sentinel)
#   * iteration >= turnCap                          -> turn-budget backstop (surface)
# Otherwise -> increment + emit {"decision":"block", ...} to take another turn.
#
# FAIL SAFE: on any error/ambiguity (missing jq, unparseable JSON, unreadable
# sentinel) it exits 0 (ALLOWS the stop). A hook that wrongly blocks is a runaway;
# allowing the stop is always the safe failure. `CLAUDE_CODE_STOP_HOOK_BLOCK_CAP`
# (raised in settings.json) is the platform backstop behind this hook.
set -u

SENTINEL="${HOME}/.autothing/goal-sentinel.json"

INPUT="$(cat 2>/dev/null || true)"

# Not in an autothing run -> allow stop.
[ -f "$SENTINEL" ] || exit 0
# jq is required to parse safely; if absent, fail safe.
command -v jq >/dev/null 2>&1 || exit 0

SESSION_ID="$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)"
TRANSCRIPT="$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)"
STOP_ACTIVE="$(printf '%s' "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null)"

SENT_SESSION="$(jq -r '.sessionId // empty' "$SENTINEL" 2>/dev/null)"
RUN_ID="$(jq -r '.runId // "unknown"' "$SENTINEL" 2>/dev/null)"
TURN_CAP="$(jq -r '.turnCap // 250' "$SENTINEL" 2>/dev/null)"
ITER="$(jq -r '.iteration // 0' "$SENTINEL" 2>/dev/null)"

# A sentinel bound to a DIFFERENT session must never block this session.
if [ -n "$SENT_SESSION" ] && [ -n "$SESSION_ID" ] && [ "$SENT_SESSION" != "$SESSION_ID" ]; then
  exit 0
fi

# Bind on first fire if Phase 0 could not set sessionId at arm time.
if [ -z "$SENT_SESSION" ] && [ -n "$SESSION_ID" ]; then
  tmp="$(mktemp)" && jq --arg s "$SESSION_ID" '.sessionId=$s' "$SENTINEL" >"$tmp" 2>/dev/null && mv "$tmp" "$SENTINEL" || rm -f "$tmp" 2>/dev/null
fi

# DONE: the terminal GLOBAL GATE verdict is in this session's transcript.
# Match the real verdict by its metric signature `videos:<n>/<n>` so the QUOTED
# `"GLOBAL GATE: passed"` target inside autothing's /goal invocation handoff (which
# has no videos:N/N) can NEVER be mistaken for the verdict. See build-loop.md
# "Gate lines must print in the lead context (ultracode-safe)".
if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ] \
   && grep -Eq 'GLOBAL GATE:.*videos:[0-9]+/[0-9]+' "$TRANSCRIPT" 2>/dev/null; then
  rm -f "$SENTINEL" 2>/dev/null
  exit 0
fi

# Turn-budget backstop (mirrors /goal's "Stop after N turns"): release the session.
if [ "${ITER:-0}" -ge "${TURN_CAP:-250}" ] 2>/dev/null; then
  echo "autothing goal-loop: run ${RUN_ID} reached its turn cap (${TURN_CAP}) without a terminal GLOBAL GATE line — releasing the session. Surface this as a loop failure, not a clean completion." 1>&2
  exit 0
fi

# Not done, budget remains -> block the stop and force another turn.
NEXT=$(( ${ITER:-0} + 1 ))
tmp="$(mktemp)" && jq --argjson n "$NEXT" '.iteration=$n' "$SENTINEL" >"$tmp" 2>/dev/null && mv "$tmp" "$SENTINEL" || rm -f "$tmp" 2>/dev/null

# stop_hook_active is logged for visibility only — it is deliberately NOT a
# terminator. A /goal-style loop legitimately stays in forced-continuation for
# many turns; the terminators above (GLOBAL GATE / sentinel / turn cap) end it.
reason="autothing run ${RUN_ID} has not printed its terminal GLOBAL GATE line (iteration ${NEXT}/${TURN_CAP}, stop_hook_active=${STOP_ACTIVE}); buildable work may remain — resume the per-slice loop from the durable FLOW_PLAN + gate-status + evidence-index files and continue to the next buildable slice."
jq -cn --arg r "$reason" '{decision:"block", reason:$r}'
exit 0
