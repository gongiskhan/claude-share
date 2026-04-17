#!/usr/bin/env bash
# strikes-util.sh — manage .claude/architectus/strikes.json
# Subcommands:
#   record-failure <slug> <reason>   Append a failure, increment strikes, mark active
#   clear          <slug>             Mark active → cleared; reset strikes to 0
#   count          <slug>             Print current strikes for slug (0 if missing or cleared)
#   list                              Print each active slug + strike count, one per line
#   active-slugs                      Print active slugs only (one per line), for scripting
#
# State file: $PWD/.claude/architectus/strikes.json
# Fails open: any error exits 0 with a message on stderr so the calling session
# is not blocked by a bookkeeping glitch.

set -u

CMD="${1:-}"
STATE_DIR=".claude/architectus"
STATE_FILE="${STATE_DIR}/strikes.json"

if ! command -v jq >/dev/null 2>&1; then
  echo "strikes-util: jq not found; skipping" >&2
  exit 0
fi

ensure_state() {
  mkdir -p "$STATE_DIR" 2>/dev/null || true
  if [ ! -f "$STATE_FILE" ]; then
    printf '%s\n' '{"issues":{}}' > "$STATE_FILE"
  fi
}

now_iso() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

case "$CMD" in
  record-failure)
    SLUG="${2:-}"
    REASON="${3:-unspecified}"
    if [ -z "$SLUG" ]; then
      echo "usage: strikes-util.sh record-failure <slug> <reason>" >&2
      exit 0
    fi
    ensure_state
    NOW=$(now_iso)
    TMP=$(mktemp)
    if jq --arg slug "$SLUG" --arg reason "$REASON" --arg now "$NOW" '
      .issues[$slug] = (
        (.issues[$slug] // {"strikes":0,"first_seen":$now,"failures":[],"status":"active"})
        | .strikes = (.strikes + 1)
        | .last_seen = $now
        | .status = "active"
        | .failures += [{"ts": $now, "reason": $reason}]
      )
    ' "$STATE_FILE" > "$TMP" 2>/dev/null; then
      mv "$TMP" "$STATE_FILE"
      COUNT=$(jq -r --arg slug "$SLUG" '.issues[$slug].strikes' "$STATE_FILE")
      echo "recorded strike $COUNT for $SLUG"
    else
      rm -f "$TMP"
      echo "strikes-util: failed to record failure" >&2
    fi
    ;;
  clear)
    SLUG="${2:-}"
    if [ -z "$SLUG" ]; then
      echo "usage: strikes-util.sh clear <slug>" >&2
      exit 0
    fi
    ensure_state
    TMP=$(mktemp)
    if jq --arg slug "$SLUG" '
      if .issues[$slug] then
        .issues[$slug].strikes = 0
        | .issues[$slug].status = "cleared"
      else . end
    ' "$STATE_FILE" > "$TMP" 2>/dev/null; then
      mv "$TMP" "$STATE_FILE"
      echo "cleared $SLUG"
    else
      rm -f "$TMP"
      echo "strikes-util: failed to clear" >&2
    fi
    ;;
  count)
    SLUG="${2:-}"
    if [ -z "$SLUG" ] || [ ! -f "$STATE_FILE" ]; then
      echo "0"
      exit 0
    fi
    jq -r --arg slug "$SLUG" '
      if .issues[$slug] and .issues[$slug].status == "active"
      then .issues[$slug].strikes else 0 end
    ' "$STATE_FILE"
    ;;
  list)
    if [ ! -f "$STATE_FILE" ]; then
      exit 0
    fi
    jq -r '.issues | to_entries[] | select(.value.status == "active") | "\(.value.strikes)\t\(.key)\t\(.value.last_seen)"' "$STATE_FILE"
    ;;
  active-slugs)
    if [ ! -f "$STATE_FILE" ]; then
      exit 0
    fi
    jq -r '.issues | to_entries[] | select(.value.status == "active") | .key' "$STATE_FILE"
    ;;
  *)
    cat <<USAGE >&2
strikes-util.sh — manage .claude/architectus/strikes.json

  strikes-util.sh record-failure <slug> <reason>
  strikes-util.sh clear          <slug>
  strikes-util.sh count          <slug>
  strikes-util.sh list
  strikes-util.sh active-slugs
USAGE
    exit 0
    ;;
esac
