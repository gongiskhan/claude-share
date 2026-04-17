#!/usr/bin/env bash
# Architectus UserPromptSubmit classifier.
# Reads hook input JSON from stdin, classifies the prompt into T1-T7,
# emits an <architectus-tier> block via hookSpecificOutput.additionalContext.
# Fails open: any error → exit 0 silently with no injection.

set -u

HOOK_JSON=$(cat)

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

PROMPT=$(printf '%s' "$HOOK_JSON" | jq -r '.prompt // empty' 2>/dev/null)
CWD=$(printf '%s' "$HOOK_JSON" | jq -r '.cwd // empty' 2>/dev/null)

if [ -z "$PROMPT" ]; then
  exit 0
fi

# --- Bypass: prompt starts with '!' ---
if [[ "$PROMPT" == \!* ]]; then
  exit 0
fi

PROMPT_LC=$(printf '%s' "$PROMPT" | tr '[:upper:]' '[:lower:]')
WORD_COUNT=$(printf '%s' "$PROMPT" | wc -w | tr -d ' ')

# --- 1. Base tier ---
BASE_TIER=3

# T1: short, question-shaped or no action verb
if [[ "$PROMPT" == *"?" ]] && [ "$WORD_COUNT" -lt 25 ]; then
  BASE_TIER=1
fi
if [ "$WORD_COUNT" -lt 10 ]; then
  if ! [[ "$PROMPT_LC" =~ (fix|add|create|build|implement|write|make|rewrite|refactor|migrate|remove|delete|update) ]]; then
    BASE_TIER=1
  fi
fi

# T2: trivial mechanical changes
if [[ "$PROMPT_LC" =~ (fix[[:space:]]+(a[[:space:]]+)?typo|typo[[:space:]]+in|rename[[:space:]]+[a-z]|reformat|format[[:space:]]+this|add[[:space:]]+a[[:space:]]+comment|one[[:space:]-]liner|single[[:space:]]line) ]]; then
  BASE_TIER=2
fi

# T3: default bug-fix / small-feature (already the default)

# T5: new module / refactor / migrate
if [[ "$PROMPT_LC" =~ (new[[:space:]]+module|large[[:space:]]+refactor|major[[:space:]]+refactor|migrate[[:space:]]+from|restructure) ]]; then
  BASE_TIER=5
fi

# T6: architecture / rewrite / redesign
if [[ "$PROMPT_LC" =~ (architectural[[:space:]]+change|rewrite[[:space:]]+the|redesign[[:space:]]+the|overhaul) ]]; then
  BASE_TIER=6
fi

# T7: greenfield / new project
if [[ "$PROMPT_LC" =~ (new[[:space:]]+app|new[[:space:]]+project|greenfield|from[[:space:]]+scratch|start[[:space:]]+a[[:space:]]+new[[:space:]]+(app|project)|build[[:space:]]+from[[:space:]]+the[[:space:]]+ground) ]]; then
  BASE_TIER=7
fi

# --- 2. Floor rules ---
TIER=$BASE_TIER
ESCALATION="none"

# Frustration keywords
FRUSTRATION_PATTERNS=("i told you" "i already told you" "like i asked" "you missed" "you forgot" "you ignored" "should have" "still not" "still broken" "still wrong" "not working yet")
for pat in "${FRUSTRATION_PATTERNS[@]}"; do
  if [[ "$PROMPT_LC" == *"$pat"* ]]; then
    [ "$TIER" -lt 4 ] && TIER=4
    ESCALATION="frustration"
    break
  fi
done

# Triple exclamation
if [[ "$PROMPT" == *"!!!"* ]]; then
  [ "$TIER" -lt 4 ] && TIER=4
  [ "$ESCALATION" = "none" ] && ESCALATION="triple_exclaim"
fi

# Literal uppercase screams (case-sensitive)
if printf '%s' "$PROMPT" | grep -E -q '\b(NEVER|ALWAYS|WRONG)\b'; then
  [ "$TIER" -lt 4 ] && TIER=4
  [ "$ESCALATION" = "none" ] && ESCALATION="caps_scream"
fi

# Compound: fix-verb AND add-verb both present
HAS_FIX=0
HAS_ADD=0
for v in "fix" "correct" "repair" "debug" "broken" "bug" "not working"; do
  if [[ "$PROMPT_LC" == *"$v"* ]]; then HAS_FIX=1; break; fi
done
for v in "add" "create" "build" "implement" "new feature" "new endpoint" "new component"; do
  if [[ "$PROMPT_LC" == *"$v"* ]]; then HAS_ADD=1; break; fi
done
if [ "$HAS_FIX" -eq 1 ] && [ "$HAS_ADD" -eq 1 ]; then
  [ "$TIER" -lt 4 ] && TIER=4
  [ "$ESCALATION" = "none" ] && ESCALATION="compound"
fi

# --- 3. Retry escalation (full logic deferred to Phase 4 strikes-util) ---
RETRY="false"

# --- 4. Project floor ---
PROJECT_FLOOR="none"
if [ -n "$CWD" ] && [ -f "$CWD/.claude/project-classifier.md" ]; then
  # Look in the "Default Minimum Tier" section for a line starting with T<n> or bare digit followed by —/-
  FLOOR_NUM=$(awk '
    /^## *Default Minimum Tier/ {inSection=1; next}
    inSection && /^## / {inSection=0}
    inSection && /^T[1-7][[:space:]]*[-—]/ {sub(/^T/,""); print substr($0,1,1); exit}
    inSection && /^[1-7][[:space:]]*[-—]/ {print substr($0,1,1); exit}
  ' "$CWD/.claude/project-classifier.md" 2>/dev/null)
  if [[ "$FLOOR_NUM" =~ ^[1-7]$ ]] && [ "$FLOOR_NUM" -gt "$TIER" ]; then
    TIER=$FLOOR_NUM
    PROJECT_FLOOR="T${FLOOR_NUM}"
  fi
fi

# Cap
[ "$TIER" -gt 7 ] && TIER=7

# --- 5. Build hint and effort ---
EFFORT="medium"
HINT="handle directly"
NEEDS_ULTRATHINK=0
case "$TIER" in
  1) EFFORT="low";    HINT="trivial question — answer directly, no plan" ;;
  2) EFFORT="low";    HINT="mechanical change — implement directly; /simplify before done" ;;
  3) EFFORT="medium"; HINT="write a brief plan, implement, /simplify before done" ;;
  4) EFFORT="high";   HINT="/architectus:plan-with-testing, implement, Argus validates, /simplify before done"; NEEDS_ULTRATHINK=1 ;;
  5) EFFORT="high";   HINT="/architectus:plan-with-testing (Argus validation mandatory); /simplify before done"; NEEDS_ULTRATHINK=1 ;;
  6) EFFORT="max";    HINT="/architectus:plan-with-testing required; engage Explorator before implementing; Argus mandatory"; NEEDS_ULTRATHINK=1 ;;
  7) EFFORT="max";    HINT="fresh architectural planning; ignore prior assumptions; Explorator first; /architectus:plan-with-testing"; NEEDS_ULTRATHINK=1 ;;
esac

# --- 6. Compose additionalContext ---
NL=$'\n'
CTX="<architectus-tier tier=\"T${TIER}\" effort=\"${EFFORT}\" escalation=\"${ESCALATION}\" project_floor=\"${PROJECT_FLOOR}\" retry=\"${RETRY}\">${NL}ROUTING: ${HINT}"
if [ "$NEEDS_ULTRATHINK" -eq 1 ]; then
  CTX="${CTX}${NL}ultrathink"
fi
CTX="${CTX}${NL}</architectus-tier>"

# --- 7. Emit structured hookSpecificOutput ---
jq -n --arg ctx "$CTX" '{
  hookSpecificOutput: {
    hookEventName: "UserPromptSubmit",
    additionalContext: $ctx
  }
}'

exit 0
