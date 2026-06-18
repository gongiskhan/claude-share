#!/bin/bash
# csg-complete/scripts/corp-reset.sh — reset the corporate working tree to the
# session baseline (CORP_HEAD_SHA from baseline.env).
#
#   1. record corp `status --porcelain` for forensics (incl. the untracked set,
#      used later by verify-tree to spot cursor litter)
#   2. explicitly rm previously-pushed files that are not in ls-tree of
#      CORP_HEAD_SHA — NEVER `git clean`: corp-side untracked junk must survive
#   3. checkout -f main, delete the work branch if present, reset --hard
#   4. assert the corp tree now equals the baseline tree
#
# usage: corp-reset.sh [--branch <work-branch-to-delete>]
set -euo pipefail

CSG_LIB="$HOME/.claude/skills/csg-common/lib"
. "$CSG_LIB/env.sh"
. "$CSG_LIB/log.sh"
. "$CSG_LIB/remote.sh"
. "$CSG_LIB/manifest.sh"
. "$CSG_LIB/rsyncw.sh"
. "$CSG_LIB/gitbase.sh"

BRANCH=""
while [ $# -gt 0 ]; do
  case "$1" in
    --branch) BRANCH="${2:?}"; shift 2 ;;
    *) die "unknown flag: $1" ;;
  esac
done

ensure_state_dir
[ -f "$BASELINE_ENV" ] || die "no session baseline — run csg-setup first"
# shellcheck disable=SC1090
. "$BASELINE_ENV"
[ -n "${CORP_HEAD_SHA:-}" ] || die "baseline.env has no CORP_HEAD_SHA — re-run csg-setup"
csg_ref_exists baseline || die "refs/csg/baseline missing — re-run csg-setup"
backchannel_check

# --- 1. forensics ---
TS=$(date +%Y%m%d-%H%M%S)
FORENSICS="$TMP_DIR/corp-status.pre-reset-$TS"
corp_git "status --porcelain" > "$FORENSICS" || true
grep '^??' "$FORENSICS" 2>/dev/null | sed 's/^?? //' > "$TMP_DIR/corp-untracked.pre" || true
log "corp-reset: pre-reset status saved -> $FORENSICS"

# --- 2. explicit rm of previously-pushed, not-in-baseline files ---
HEAD_PATHS=$(csg_mktemp)
corp_git "ls-tree -r --name-only $CORP_HEAD_SHA" | sort -u > "$HEAD_PATHS"
PUSHED=$(csg_mktemp)
{ [ -s "$MAC_LAST_PUSH_MANIFEST" ] && cut -f2 "$MAC_LAST_PUSH_MANIFEST"
  [ -s "$CORP_LAST_SYNC_MANIFEST" ] && cut -f2 "$CORP_LAST_SYNC_MANIFEST"
  true; } | sort -u > "$PUSHED"
RMLIST=$(csg_mktemp); comm -23 "$PUSHED" "$HEAD_PATHS" > "$RMLIST"
if [ -s "$RMLIST" ]; then
  log "corp-reset: removing $(wc -l < "$RMLIST" | tr -d ' ') previously-pushed file(s) not in the baseline commit:"
  sed 's/^/    rm /' "$RMLIST" >&2
  rm_by_list_corp "$RMLIST"
fi

# --- 3. branch back to main and hard-reset to the baseline commit ---
corp_git "checkout -f main" >/dev/null 2>&1 || corp_git "checkout -f main"
if [ -n "$BRANCH" ]; then
  corp_git "branch -D \"$BRANCH\" 2>/dev/null || true" >/dev/null
fi
corp_git "reset --hard $CORP_HEAD_SHA" >/dev/null
log "corp-reset: checkout -f main && reset --hard $CORP_HEAD_SHA done"

# --- 4. assert the tree reproduces the baseline ---
BASE_PATHS=$(csg_mktemp)
git -C "$MAC_REPO" ls-tree -r --name-only refs/csg/baseline | sort -u > "$BASE_PATHS"
CORP_MF=$(csg_mktemp); corp_manifest "$BASE_PATHS" > "$CORP_MF"
BASE_MF=$(csg_mktemp); mac_lstree_manifest refs/csg/baseline > "$BASE_MF"
if ! manifests_equal "$CORP_MF" "$BASE_MF"; then
  VDIFF=$(csg_mktemp); manifest_diff "$BASE_MF" "$CORP_MF" > "$VDIFF"
  die_catalog 19 "corporate tree does not match the baseline after reset:"$'\n'"$(diff_table "$VDIFF" "baseline" "corp")"
fi
log "corp-reset: corporate tree verified == session baseline"
