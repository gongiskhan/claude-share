#!/usr/bin/env bash
# notify.sh — Send a macOS notification with sound
# Usage: bash /Users/ggomes/.claude/architectus/scripts/notify.sh "Title" "Message"
TITLE="${1:-Claude Code}"
MSG="${2:-Task completed}"
terminal-notifier -title "$TITLE" -message "$MSG" -timeout 10 2>/dev/null
afplay -v 4 /System/Library/Sounds/Glass.aiff &>/dev/null &
