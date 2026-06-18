#!/bin/bash
# csg-complete — recreate the Mac change set on the corporate machine through
# cursor-agent (the sanctioned tool), branch + commit + verify it byte-exactly.
#
#   preconditions (tunnel, syncthing, baseline, sync-current, cursor canary)
#   -> gen-spec -> corp-reset -> cursor loop (verify <= --max-iters, default 3)
#   -> lint gate (run by THIS script, not trusted from cursor's claim)
#   -> report. NOTHING is pushed here: finalize.sh runs only after the user
#   explicitly confirms. --dry-run stops after verification just the same but
#   labels the run as a probe.
#
# usage: complete.sh --ticket N --desc "short description" [--dry-run] [--max-iters N]
set -euo pipefail

CSG_LIB="$HOME/.claude/skills/csg-common/lib"
. "$CSG_LIB/env.sh"
. "$CSG_LIB/log.sh"
. "$CSG_LIB/remote.sh"
. "$CSG_LIB/manifest.sh"
. "$CSG_LIB/rsyncw.sh"
. "$CSG_LIB/gitbase.sh"

SCRIPTS_DIR=$(cd "$(dirname "$0")" && pwd)

TICKET=""; DESC=""; DRY_RUN=0; MAX_ITERS=3
while [ $# -gt 0 ]; do
  case "$1" in
    --ticket) TICKET="${2:?}"; shift 2 ;;
    --desc) DESC="${2:?}"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --max-iters) MAX_ITERS="${2:?}"; shift 2 ;;
    -h|--help) echo 'usage: complete.sh --ticket N --desc "..." [--dry-run] [--max-iters N]'; exit 0 ;;
    *) die "unknown flag: $1" ;;
  esac
done
[ -n "$TICKET" ] || die "--ticket is required (numeric, e.g. 1202066)"
printf '%s' "$TICKET" | grep -qE '^[0-9]+$' || die "--ticket must be numeric, got: $TICKET"
[ -n "$DESC" ] || die "--desc is required (short description, e.g. 'align numeric input sizing')"
printf '%s' "$MAX_ITERS" | grep -qE '^[1-9][0-9]*$' || die "--max-iters must be a positive integer"

KEBAB=$(kebab "$DESC")
[ -n "$KEBAB" ] || die "--desc must contain at least one alphanumeric character"
BRANCH="spcm-$TICKET-$KEBAB"
COMMIT_MSG="#$TICKET SPCM-UI: $DESC"
log "ticket #$TICKET -> branch '$BRANCH', commit msg '$COMMIT_MSG'"

# --- preconditions ---------------------------------------------------------
ensure_state_dir
[ -f "$BASELINE_ENV" ] || die "no session baseline — run csg-setup first"
# shellcheck disable=SC1090
. "$BASELINE_ENV"
[ -n "${CORP_HEAD_SHA:-}" ] || die "baseline.env has no CORP_HEAD_SHA — re-run csg-setup"
csg_ref_exists baseline || die "refs/csg/baseline missing — re-run csg-setup"
backchannel_check
syncthing_guard

log "precondition: sync-current (corporate tree must equal the Mac tree)..."
MAC_UNI=$(csg_mktemp); mac_universe > "$MAC_UNI"
MAC_MF=$(csg_mktemp); mac_manifest "$MAC_UNI" > "$MAC_MF"
DEL_SINCE=$(csg_mktemp)
if [ -s "$CORP_LAST_SYNC_MANIFEST" ]; then
  cut -f2 "$CORP_LAST_SYNC_MANIFEST" | sort -u | comm -23 - "$MAC_UNI" > "$DEL_SINCE"
fi
UNION=$(csg_mktemp); cat "$MAC_UNI" "$DEL_SINCE" | sort -u > "$UNION"
CORP_MF=$(csg_mktemp); corp_manifest "$UNION" > "$CORP_MF"
EXPECT_MF=$(csg_mktemp)
{ cat "$MAC_MF"; sed "s/^/MISSING$TAB/" "$DEL_SINCE"; } | manifest_sort > "$EXPECT_MF"
if ! manifests_equal "$CORP_MF" "$EXPECT_MF"; then
  SDIFF=$(csg_mktemp); manifest_diff "$EXPECT_MF" "$CORP_MF" > "$SDIFF"
  die "corporate and Mac trees differ — run csg-sync first:"$'\n'"$(diff_table "$SDIFF" "Mac" "corp")"
fi
log "precondition: sync-current OK"

# --- cursor canary: once per state dir, BEFORE any reset -------------------
# Headless shell-exec is the one cursor capability the findings could not
# verify (§11.8). Prove it by making cursor run a command whose output we can
# independently check.
if [ ! -f "$CANARY_OK_MARKER" ]; then
  log "cursor canary: proving headless shell-exec (once per state dir)..."
  CANARY_EXPECTED=$(corp_git rev-parse HEAD)
  CANARY_PROMPT='Run the shell command "git rev-parse HEAD" in this repository and print its output on a single line formatted exactly as CSG_CANARY=<output-of-the-command>. Do not modify, create, or delete any files. Do not run any other commands.'
  CANARY_PS="\$ErrorActionPreference = 'Continue'
Set-Location '$CORP_REPO_WIN'
\$prompt = @'
$CANARY_PROMPT
'@
cursor-agent -p --force --trust --output-format text \$prompt
exit \$LASTEXITCODE"
  CRC=0
  COUT=$(win_ps_timeout 300 "$CANARY_PS") || CRC=$?
  CANARY_LOG="$CURSOR_LOG_DIR/canary-$(date +%Y%m%d-%H%M%S).log"
  printf '%s\n' "$COUT" > "$CANARY_LOG"
  if [ "$CRC" -ne 0 ] || ! printf '%s' "$COUT" | tr -d '\r' | grep -q "CSG_CANARY=$CANARY_EXPECTED"; then
    die_catalog 20 "expected CSG_CANARY=$CANARY_EXPECTED (rc=$CRC); transcript: $CANARY_LOG"
  fi
  touch "$CANARY_OK_MARKER"
  log "cursor canary OK (transcript: $CANARY_LOG)"
else
  log "cursor canary: already proven for this state dir"
fi

# --- spec bundle ------------------------------------------------------------
bash "$SCRIPTS_DIR/gen-spec.sh" --ticket "$TICKET" --branch "$BRANCH" --commit-msg "$COMMIT_MSG" --desc "$DESC"
SPEC_STATE="$SPEC_STATE_DIR/$TICKET"

# --- reset corporate to the baseline ---------------------------------------
bash "$SCRIPTS_DIR/corp-reset.sh" --branch "$BRANCH"

# --- cursor loop -------------------------------------------------------------
RESIDUAL_REPORT="$SPEC_STATE/residual.report"
MODE=initial
VERIFIED=0
ITER=1
while [ "$ITER" -le "$MAX_ITERS" ]; do
  log "=== cursor iteration $ITER/$MAX_ITERS ($MODE) ==="
  if [ "$MODE" = "retry" ]; then
    bash "$SCRIPTS_DIR/run-cursor.sh" --ticket "$TICKET" --iter "$ITER" --mode retry \
      --branch "$BRANCH" --commit-msg "$COMMIT_MSG" --residual "$RESIDUAL_REPORT"
  else
    bash "$SCRIPTS_DIR/run-cursor.sh" --ticket "$TICKET" --iter "$ITER" --mode initial \
      --branch "$BRANCH" --commit-msg "$COMMIT_MSG"
  fi
  VRC=0
  bash "$SCRIPTS_DIR/verify-tree.sh" --ticket "$TICKET" --branch "$BRANCH" \
    --commit-msg "$COMMIT_MSG" --report "$RESIDUAL_REPORT" || VRC=$?
  case "$VRC" in
    0) VERIFIED=1; break ;;
    2) MODE=retry ;;
    3)
      warn "manifest regression — full corporate reset (counts as an iteration)"
      bash "$SCRIPTS_DIR/corp-reset.sh" --branch "$BRANCH"
      MODE=initial
      ;;
    *) die "verify-tree.sh failed internally (rc=$VRC)" "$VRC" ;;
  esac
  ITER=$((ITER + 1))
done

if [ "$VERIFIED" -ne 1 ]; then
  die_catalog 17 "residual after $MAX_ITERS iteration(s):
$(sed 's/^/  /' "$RESIDUAL_REPORT" 2>/dev/null)
transcripts:
$(ls -1 "$CURSOR_LOG_DIR"/cursor-"$TICKET"-iter*.log 2>/dev/null | sed 's/^/  /')
corporate left on branch '$BRANCH' for inspection."
fi

# --- lint gate: this script is the gate, not cursor's claim ------------------
LINT_CMDS_FILE="$SPEC_STATE/lint.cmds"
if [ -s "$LINT_CMDS_FILE" ]; then
  while IFS= read -r cmd; do
    [ -n "$cmd" ] || continue
    log "lint gate: $cmd (on corporate, from repo root)"
    LRC=0
    LOUT=$(win_ps_timeout 900 "Set-Location '$CORP_REPO_WIN'; cmd /c '$cmd'; exit \$LASTEXITCODE" 2>&1) || LRC=$?
    if [ "$LRC" -ne 0 ]; then
      if printf '%s' "$LOUT" | grep -q "find a configuration file"; then
        # Pre-existing repo condition (verified live): NO eslint config exists
        # anywhere in the repo, so this command cannot succeed for anyone.
        # Broken lint infra is not a property of the change set — warn, don't block.
        warn "lint gate: '$cmd' cannot run — the repo ships no ESLint config (pre-existing). Skipping this command."
        continue
      fi
      printf '%s\n' "$LOUT" | tail -40 >&2
      if [ "$LRC" -eq 124 ]; then warn "lint hit the 900 s timeout"; fi
      die "lint gate FAILED: '$cmd' (rc=$LRC). Corporate is left on branch '$BRANCH'. Fix the lint problem on the Mac, csg-sync, and re-run csg-complete. Nothing was pushed."
    fi
  done < "$LINT_CMDS_FILE"
  log "lint gate: all commands passed"
else
  warn "lint gate: no root lint script maps to the changed paths — skipped"
fi

# --- record what finalize.sh needs ------------------------------------------
cat > "$PENDING_FINALIZE_ENV" <<EOF
TICKET=$TICKET
DESC='$(printf '%s' "$DESC" | sed "s/'/'\\\\''/g")'
BRANCH=$BRANCH
COMMIT_MSG='$(printf '%s' "$COMMIT_MSG" | sed "s/'/'\\\\''/g")'
COMPLETED_AT=$(date '+%Y-%m-%dT%H:%M:%S')
DRY_RUN=$DRY_RUN
EOF

CORP_LOG1=$(corp_git "log -1 --oneline")
cat >&2 <<EOF

============================================================
 csg-complete: VERIFIED
   ticket      : #$TICKET — $DESC
   branch      : $BRANCH (on corporate, NOT pushed)
   commit      : $CORP_LOG1
   tree check  : corp ls-tree HEAD == expected manifest (byte-exact)
   lint gate   : $(if [ -s "$LINT_CMDS_FILE" ]; then paste -sd'~' - < "$LINT_CMDS_FILE" | sed 's/~/, /g'; else echo "skipped (no mapping)"; fi)
   transcripts : $CURSOR_LOG_DIR/cursor-$TICKET-iter*.log
EOF
if [ "$DRY_RUN" = 1 ]; then
  cat >&2 <<EOF
   mode        : DRY RUN — stopping here. Nothing pushed, no PR.
   note        : the branch + commit exist on corporate; delete with
                 'git checkout -f main && git branch -D $BRANCH' over the
                 back-channel when done inspecting (or just re-run csg-complete).
============================================================
EOF
else
  cat >&2 <<EOF
   next        : NOTHING has been pushed. To push the branch and open the
                 Azure DevOps PR, confirm explicitly and run:
                   bash ~/.claude/skills/csg-complete/scripts/finalize.sh
============================================================
EOF
fi
