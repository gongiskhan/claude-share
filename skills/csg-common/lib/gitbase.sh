#!/bin/bash
# csg-common/lib/gitbase.sh — baseline/current tree snapshots via a temp index
# (worktree untouched, gc-proof via refs/csg/*), change-spec helpers, and the
# changed-paths -> root lint-script mapping.
# Requires env.sh + log.sh sourced first.

# snapshot_ref <path-list-file> <name> <message>
# Builds a tree from the CURRENT Mac working-tree content of the listed paths
# using a temporary GIT_INDEX_FILE, commits it, pins refs/csg/<name> (gc-proof).
# Prints the commit sha.
snapshot_ref() {
  local list="$1" name="$2" msg="$3" idx
  idx=$(csg_mktemp); rm -f "$idx"
  ( cd "$MAC_REPO" || exit 1
    tr '\n' '\0' < "$list" | GIT_INDEX_FILE="$idx" git update-index --add -z --stdin
    tree=$(GIT_INDEX_FILE="$idx" git write-tree)
    commit=$(GIT_INDEX_FILE="$idx" git commit-tree "$tree" -m "$msg")
    git update-ref "refs/csg/$name" "$commit"
    printf '%s\n' "$commit"
  )
  local rc=$?
  rm -f "$idx"
  return $rc
}

csg_ref_exists() {
  git -C "$MAC_REPO" show-ref --quiet "refs/csg/$1"
}

# affected_lint_cmds <changed-path-list-file>
# Maps changed paths to root package.json lint scripts (one command per line):
#   apps/spcm   -> yarn lint:spcm      apps/pmcs -> yarn lint:pmcs
#   apps/ussdws -> yarn lint:ussd      apps/smsws -> yarn lint
# shell/ + packages/common/ have no root lint script -> warn + run all four as
# the nearest proxies (common is consumed by every workspace).
affected_lint_cmds() {
  local list="$1" all=""
  if grep -q -e '^shell/' -e '^packages/common/' "$list"; then
    warn "changes touch shell/ or packages/common/ — no dedicated root lint script; running all workspace lints as proxies"
    all=1
  fi
  {
    if [ -n "$all" ] || grep -q '^apps/spcm/'   "$list"; then echo "yarn lint:spcm"; fi
    if [ -n "$all" ] || grep -q '^apps/pmcs/'   "$list"; then echo "yarn lint:pmcs"; fi
    if [ -n "$all" ] || grep -q '^apps/ussdws/' "$list"; then echo "yarn lint:ussd"; fi
    if [ -n "$all" ] || grep -q '^apps/smsws/'  "$list"; then echo "yarn lint"; fi
  } | sort -u
}
