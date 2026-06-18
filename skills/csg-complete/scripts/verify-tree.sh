#!/bin/bash
# csg-complete/scripts/verify-tree.sh — judge whether cursor-agent reproduced
# the change set exactly:
#   corp `ls-tree -r HEAD` manifest (exclude-filtered) == manifest.expected
#   + corp tracked status clean, branch name and commit subject byte-exact.
#
# Exit codes:
#   0  verified
#   2  residual, retry-able (problems confined to the spec's change set)
#   3  regression (unrelated paths touched / wrong branch) -> full reset needed
#
# usage: verify-tree.sh --ticket N --branch B --commit-msg M --report OUT
set -euo pipefail

CSG_LIB="$HOME/.claude/skills/csg-common/lib"
. "$CSG_LIB/env.sh"
. "$CSG_LIB/log.sh"
. "$CSG_LIB/remote.sh"
. "$CSG_LIB/manifest.sh"

TICKET=""; BRANCH=""; COMMIT_MSG=""; REPORT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --ticket) TICKET="${2:?}"; shift 2 ;;
    --branch) BRANCH="${2:?}"; shift 2 ;;
    --commit-msg) COMMIT_MSG="${2:?}"; shift 2 ;;
    --report) REPORT="${2:?}"; shift 2 ;;
    *) die "unknown flag: $1" ;;
  esac
done
[ -n "$TICKET" ] && [ -n "$BRANCH" ] && [ -n "$COMMIT_MSG" ] && [ -n "$REPORT" ] || die "verify-tree.sh missing required flags"

ensure_state_dir
SPEC_STATE="$SPEC_STATE_DIR/$TICKET"
EXPECTED="$SPEC_STATE/expected.manifest"
AM_LIST="$SPEC_STATE/am.list"
DEL_LIST="$SPEC_STATE/deleted.list"
[ -s "$EXPECTED" ] || die_catalog 19 "expected manifest missing: $EXPECTED — run gen-spec.sh first"

: > "$REPORT"
RESIDUAL=0
REGRESSION=0

BRANCH_NOW=$(corp_git rev-parse --abbrev-ref HEAD)
MSG_NOW=$(corp_git "log -1 --pretty=%s")
TRACKED_DIRTY=$(corp_git "status --porcelain --untracked-files=no")

if [ "$BRANCH_NOW" != "$BRANCH" ]; then
  printf 'wrong branch: on "%s", expected "%s"\n' "$BRANCH_NOW" "$BRANCH" >> "$REPORT"
  REGRESSION=1
fi

CORP_TREE=$(csg_mktemp); corp_lstree_manifest HEAD > "$CORP_TREE"
D=$(csg_mktemp); manifest_diff "$EXPECTED" "$CORP_TREE" > "$D"

while IFS="$TAB" read -r kind p; do
  [ -n "$kind" ] || continue
  case "$kind" in
    CHANGED)
      if grep -qxF "$p" "$AM_LIST" 2>/dev/null; then
        printf 'content mismatch (re-copy byte-for-byte from spec files\\): %s\n' "$p" >> "$REPORT"
        RESIDUAL=1
      else
        printf 'REGRESSION — unrelated file modified: %s\n' "$p" >> "$REPORT"
        REGRESSION=1
      fi
      ;;
    ONLY_A)  # in expected, missing from corp HEAD tree
      if grep -qxF "$p" "$AM_LIST" 2>/dev/null; then
        printf 'missing from commit (copy from spec files\\ and git add): %s\n' "$p" >> "$REPORT"
        RESIDUAL=1
      else
        printf 'REGRESSION — unrelated file lost from the tree: %s\n' "$p" >> "$REPORT"
        REGRESSION=1
      fi
      ;;
    ONLY_B)  # extra in corp HEAD tree
      if grep -qxF "$p" "$DEL_LIST" 2>/dev/null; then
        printf 'must be deleted (rm + git add): %s\n' "$p" >> "$REPORT"
        RESIDUAL=1
      else
        printf 'REGRESSION — unexpected extra file committed: %s\n' "$p" >> "$REPORT"
        REGRESSION=1
      fi
      ;;
  esac
done < "$D"

if [ -n "$TRACKED_DIRTY" ]; then
  {
    echo 'uncommitted tracked changes present (stage the spec paths, then git commit --amend --no-edit):'
    printf '%s\n' "$TRACKED_DIRTY" | sed 's/^/    /'
  } >> "$REPORT"
  RESIDUAL=1
fi

if [ "$MSG_NOW" != "$COMMIT_MSG" ]; then
  printf 'commit message mismatch: "%s" (must be exactly: %s)\n' "$MSG_NOW" "$COMMIT_MSG" >> "$REPORT"
  RESIDUAL=1
fi

# cursor litter check: new untracked paths vs the pre-reset snapshot (warn-only)
PRE_UNTRACKED="$TMP_DIR/corp-untracked.pre"
if [ -f "$PRE_UNTRACKED" ]; then
  NOW_UNTRACKED=$(csg_mktemp)
  corp_git "status --porcelain" | grep '^??' | sed 's/^?? //' | sort > "$NOW_UNTRACKED" || true
  NEW_LITTER=$(comm -13 <(sort "$PRE_UNTRACKED") "$NOW_UNTRACKED" || true)
  if [ -n "$NEW_LITTER" ]; then
    warn "new untracked file(s) appeared on corporate during the cursor run (left alone):"
    printf '%s\n' "$NEW_LITTER" | sed 's/^/    /' >&2
  fi
fi

if [ "$REGRESSION" -eq 1 ]; then
  warn "verify-tree: REGRESSION — see $REPORT"
  exit 3
fi
if [ "$RESIDUAL" -eq 1 ]; then
  warn "verify-tree: residual problems — see $REPORT"
  exit 2
fi
log "verify-tree: corporate HEAD tree == expected manifest; branch '$BRANCH'; commit message byte-exact; status clean"
exit 0
