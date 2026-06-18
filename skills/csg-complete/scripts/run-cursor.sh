#!/bin/bash
# csg-complete/scripts/run-cursor.sh — one headless cursor-agent invocation on
# the corporate Windows machine, transcript captured to csg-state/cursor/.
#
# The prompt is rendered from a template and embedded in a PowerShell
# single-quoted here-string; the whole PS script travels as UTF-16LE base64
# (-EncodedCommand), so no quoting tower exists. Runs under WSL `timeout 900`.
#
# Always exits 0 unless the transport itself breaks — verify-tree.sh is the
# judge of whether cursor did the job, not cursor's own exit code.
#
# usage: run-cursor.sh --ticket N --iter I --mode initial|retry
#                      --branch B --commit-msg M [--residual FILE]
set -euo pipefail

CSG_LIB="$HOME/.claude/skills/csg-common/lib"
. "$CSG_LIB/env.sh"
. "$CSG_LIB/log.sh"
. "$CSG_LIB/remote.sh"

TEMPLATES_DIR="$HOME/.claude/skills/csg-complete/templates"

TICKET=""; ITER=""; MODE=""; BRANCH=""; COMMIT_MSG=""; RESIDUAL=""
while [ $# -gt 0 ]; do
  case "$1" in
    --ticket) TICKET="${2:?}"; shift 2 ;;
    --iter) ITER="${2:?}"; shift 2 ;;
    --mode) MODE="${2:?}"; shift 2 ;;
    --branch) BRANCH="${2:?}"; shift 2 ;;
    --commit-msg) COMMIT_MSG="${2:?}"; shift 2 ;;
    --residual) RESIDUAL="${2:?}"; shift 2 ;;
    *) die "unknown flag: $1" ;;
  esac
done
[ -n "$TICKET" ] && [ -n "$ITER" ] && [ -n "$BRANCH" ] && [ -n "$COMMIT_MSG" ] || die "run-cursor.sh missing required flags"
case "$MODE" in initial|retry) ;; *) die "--mode must be initial or retry" ;; esac

ensure_state_dir

SPEC_WIN="$SPEC_DIR_WIN\\$TICKET"
LINT_CMDS_FILE="$SPEC_STATE_DIR/$TICKET/lint.cmds"
LINT_JOINED="(none mapped — skip this step)"
if [ -s "$LINT_CMDS_FILE" ]; then
  LINT_JOINED=$(paste -sd'~' - < "$LINT_CMDS_FILE" | sed 's/~/, then /g')
fi

TEMPLATE="$TEMPLATES_DIR/cursor-prompt-initial.txt"
if [ "$MODE" = "retry" ]; then
  TEMPLATE="$TEMPLATES_DIR/cursor-prompt-retry.txt"
  [ -n "$RESIDUAL" ] && [ -s "$RESIDUAL" ] || die "retry mode needs --residual <non-empty file>"
fi

PROMPT=$(cat "$TEMPLATE")
PROMPT=${PROMPT//'{SPEC_DIR}'/$SPEC_WIN}
PROMPT=${PROMPT//'{BRANCH}'/$BRANCH}
PROMPT=${PROMPT//'{COMMIT_MSG}'/$COMMIT_MSG}
PROMPT=${PROMPT//'{LINT_COMMANDS}'/$LINT_JOINED}
if [ "$MODE" = "retry" ]; then
  PROMPT=${PROMPT//'{RESIDUAL}'/$(cat "$RESIDUAL")}
fi

# here-string safety: the prompt must not contain a line starting with '@
if printf '%s\n' "$PROMPT" | grep -q "^'@"; then
  die_catalog 19 "rendered prompt contains a line starting with '@ — would break the PowerShell here-string"
fi

PS_SCRIPT="\$ErrorActionPreference = 'Continue'
Set-Location '$CORP_REPO_WIN'
\$prompt = @'
$PROMPT
'@
cursor-agent -p --force --trust --output-format text \$prompt
exit \$LASTEXITCODE"

TRANSCRIPT="$CURSOR_LOG_DIR/cursor-$TICKET-iter$ITER.log"
log "cursor-agent ($MODE, iter $ITER) running headless on corporate (timeout 900 s)..."
RC=0
OUT=$(win_ps_timeout 900 "$PS_SCRIPT") || RC=$?
{
  printf '=== csg cursor transcript — ticket %s iter %s mode %s rc %s @ %s ===\n' \
    "$TICKET" "$ITER" "$MODE" "$RC" "$(date '+%F %T')"
  printf -- '--- prompt ---\n%s\n--- output ---\n%s\n' "$PROMPT" "$OUT"
} > "$TRANSCRIPT"

if [ "$RC" -eq 124 ]; then
  warn "cursor-agent hit the 900 s timeout — verify-tree will judge what landed"
elif [ "$RC" -ne 0 ]; then
  warn "cursor-agent exited rc=$RC — verify-tree will judge what landed"
fi
log "transcript: $TRANSCRIPT"
