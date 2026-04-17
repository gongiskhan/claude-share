#!/usr/bin/env bash
# Architectus SessionStart matcher=compact hook.
# Narrow re-injection of the heartbeat directive. Called after auto or manual compaction.
# Fails open.

set -u

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

NL=$'\n'
CTX="<architectus-session source=\"compact\">"
CTX="${CTX}${NL}Context was compacted. The /loop heartbeat scheduler survives compaction at the system level, but if you cannot see recent heartbeat activity, re-issue: /loop 40m /architectus:heartbeat"
CTX="${CTX}${NL}</architectus-session>"

jq -n --arg ctx "$CTX" '{
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    additionalContext: $ctx
  }
}'

exit 0
