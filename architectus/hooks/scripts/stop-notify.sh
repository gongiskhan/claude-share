#!/usr/bin/env bash
# Architectus Stop hook — adapted verbatim from vitruvius.
# Reads transcript, extracts last assistant message, notifies + plays sound.

read -r HOOK_JSON

TRANSCRIPT=$(echo "$HOOK_JSON" | jq -r '.transcript_path')
PROJECT=$(echo "$HOOK_JSON" | jq -r '.cwd')

SUMMARY=$(grep '"type":"assistant"' "$TRANSCRIPT" 2>/dev/null \
          | tail -n 1 \
          | jq -r '.message.content[] | select(.type == "text") | .text' 2>/dev/null \
          | head -c 200)

if [ -z "$SUMMARY" ]; then
  SUMMARY="Task completed"
fi

terminal-notifier -title "Architectus done: $(basename "$PROJECT")" \
                  -message "$SUMMARY" 2>/dev/null

afplay -v 4 /System/Library/Sounds/Glass.aiff &>/dev/null &
