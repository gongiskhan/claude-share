#!/usr/bin/env bash
# Architectus SessionStart hook.
# Matcher is $1: startup | resume | clear.
# Emits hookSpecificOutput.additionalContext with briefing + first-turn directives.
# Fails open on any error.

set -u

MATCHER="${1:-startup}"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-/Users/ggomes/.claude/architectus}"
MAIN_BRIEF="$PLUGIN_ROOT/prompts/main-session.md"

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

# Try to read cwd from the hook input (may be JSON on stdin or empty)
HOOK_JSON=""
if [ ! -t 0 ]; then
  HOOK_JSON=$(cat)
fi
CWD=""
if [ -n "$HOOK_JSON" ]; then
  CWD=$(printf '%s' "$HOOK_JSON" | jq -r '.cwd // empty' 2>/dev/null)
fi
[ -z "$CWD" ] && CWD="$PWD"

PROJECT_FLOOR="none"
CLASSIFIER_PATH="$CWD/.claude/project-classifier.md"
if [ -f "$CLASSIFIER_PATH" ]; then
  FLOOR_NUM=$(awk '
    /^## *Default Minimum Tier/ {inSection=1; next}
    inSection && /^## / {inSection=0}
    inSection && /^T[1-7][[:space:]]*[-—]/ {sub(/^T/,""); print substr($0,1,1); exit}
    inSection && /^[1-7][[:space:]]*[-—]/ {print substr($0,1,1); exit}
  ' "$CLASSIFIER_PATH" 2>/dev/null)
  if [[ "$FLOOR_NUM" =~ ^[1-7]$ ]]; then
    PROJECT_FLOOR="T${FLOOR_NUM}"
  fi
fi

NL=$'\n'

# Always include the minimal heartbeat directive
HEARTBEAT_BLOCK="FIRST-TURN DIRECTIVE (heartbeat): if no \`/loop\` is active in this session, run \`/loop 40m /architectus:heartbeat\` now."

if [ "$MATCHER" = "clear" ]; then
  # Narrow: heartbeat only
  CTX="<architectus-session source=\"clear\">${NL}${HEARTBEAT_BLOCK}${NL}</architectus-session>"
  jq -n --arg ctx "$CTX" '{
    hookSpecificOutput: {
      hookEventName: "SessionStart",
      additionalContext: $ctx
    }
  }'
  exit 0
fi

# Full briefing for startup / resume
CLASSIFIER_STATUS="present"
if [ ! -f "$CLASSIFIER_PATH" ]; then
  CLASSIFIER_STATUS="missing — run /architectus:plan-with-testing to generate it using $PLUGIN_ROOT/templates/project-classifier.md; block other work until done"
fi

MEMCOMP_STATUS="absent (memory-compiler layer disabled)"
if [ -f "$HOME/.claude/memory-compiler/pyproject.toml" ]; then
  MEMCOMP_STATUS="present (memory-compiler layer active; transcripts captured on Stop/PreCompact)"
fi

BRIEF=""
if [ -f "$MAIN_BRIEF" ]; then
  BRIEF=$(cat "$MAIN_BRIEF")
fi

CTX="<architectus-session source=\"${MATCHER}\" plugin-root=\"${PLUGIN_ROOT}\">"
CTX="${CTX}${NL}SUBAGENTS: argus (tester, sonnet), mercurius (image analyst, sonnet), explorator (codebase explorer, haiku)."
CTX="${CTX}${NL}Spawn via the Agent tool, e.g. Agent(subagent_type=\"argus\", prompt=\"...\")."
CTX="${CTX}${NL}SKILLS: /architectus:heartbeat, /architectus:reclassify, /architectus:rootcause, /architectus:plan-with-testing, /architectus:quality-gate."
CTX="${CTX}${NL}ADVISOR: advisor() is globally opus — call before substantive T3+ work and before declaring done."
CTX="${CTX}${NL}"
CTX="${CTX}${NL}PROJECT CLASSIFIER: ${CLASSIFIER_STATUS}. Floor: ${PROJECT_FLOOR}."
CTX="${CTX}${NL}MEMORY: auto-memory on; memory-compiler ${MEMCOMP_STATUS}."
CTX="${CTX}${NL}"
CTX="${CTX}${NL}${HEARTBEAT_BLOCK}"
if [ "$CLASSIFIER_STATUS" != "present" ]; then
  CTX="${CTX}${NL}FIRST-TURN DIRECTIVE (bootstrap): .claude/project-classifier.md is missing — run /architectus:plan-with-testing to generate it before anything else."
fi
if [ -n "$BRIEF" ]; then
  CTX="${CTX}${NL}${NL}--- OPERATING BRIEF ---${NL}${BRIEF}"
fi
CTX="${CTX}${NL}</architectus-session>"

jq -n --arg ctx "$CTX" '{
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    additionalContext: $ctx
  }
}'

exit 0
