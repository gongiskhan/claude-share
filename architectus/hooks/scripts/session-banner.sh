#!/usr/bin/env bash
# session-banner.sh — compact, visible confirmation that Architectus is active.
# Emits a single line of plain stdout, which Claude Code shows as hook output
# in the transcript. The full operating brief is still injected discretely by
# session-start.sh via hookSpecificOutput.additionalContext.
# Runs on SessionStart matchers: startup, resume.

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-/Users/ggomes/.claude/architectus}"
VERSION="0.1.2"
if [ -f "$PLUGIN_ROOT/.claude-plugin/plugin.json" ] && command -v jq >/dev/null 2>&1; then
  V=$(jq -r '.version // empty' "$PLUGIN_ROOT/.claude-plugin/plugin.json" 2>/dev/null)
  [ -n "$V" ] && VERSION="$V"
fi

echo "[architectus v${VERSION}] agents: argus, mercurius, explorator | skills: /architectus:heartbeat /architectus:reclassify /architectus:rootcause /architectus:plan-with-testing /architectus:quality-gate | bypass classifier: prefix prompt with !"
