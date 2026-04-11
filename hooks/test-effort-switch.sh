#!/bin/bash
# Read the prompt from stdin
INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.prompt')

# Only trigger on our test phrase
if echo "$PROMPT" | grep -q "EFFORT_TEST"; then
  # Change effort to max mid-hook
  SETTINGS_FILE="$HOME/.claude/settings.json"
  # Use jq to update effortLevel to "high"
  tmpfile=$(mktemp)
  jq '.effortLevel = "high"' "$SETTINGS_FILE" > "$tmpfile" && mv "$tmpfile" "$SETTINGS_FILE"
  
  echo '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"[EFFORT_TEST: Hook changed effort from low to high via settings.json edit]"}}' 
  exit 0
fi

exit 0