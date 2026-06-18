#!/bin/bash
# csg-complete/scripts/gen-spec.sh — build the change-spec bundle from the
# session baseline vs the current Mac tree, and transfer it to the corporate
# machine at C:\Users\gomgon01\dev\csg-spec\<ticket>\ (Windows-visible,
# WSL-writable, outside the repo).
#
# Bundle contents:
#   SPEC.md            human-readable summary (ticket, branch, commit msg, lists)
#   files/<path>       FULL final content of every added/modified file (AUTHORITATIVE)
#   deleted.list       paths to delete (may be empty)
#   changes.patch      git diff --binary baseline..current (context only)
#   manifest.expected  expected corp ls-tree manifest after the change
#
# usage: gen-spec.sh --ticket N --branch B --commit-msg M --desc D
set -euo pipefail

CSG_LIB="$HOME/.claude/skills/csg-common/lib"
. "$CSG_LIB/env.sh"
. "$CSG_LIB/log.sh"
. "$CSG_LIB/remote.sh"
. "$CSG_LIB/manifest.sh"
. "$CSG_LIB/rsyncw.sh"
. "$CSG_LIB/gitbase.sh"

TICKET=""; BRANCH=""; COMMIT_MSG=""; DESC=""
while [ $# -gt 0 ]; do
  case "$1" in
    --ticket) TICKET="${2:?}"; shift 2 ;;
    --branch) BRANCH="${2:?}"; shift 2 ;;
    --commit-msg) COMMIT_MSG="${2:?}"; shift 2 ;;
    --desc) DESC="${2:?}"; shift 2 ;;
    *) die "unknown flag: $1" ;;
  esac
done
[ -n "$TICKET" ] && [ -n "$BRANCH" ] && [ -n "$COMMIT_MSG" ] || die "gen-spec.sh needs --ticket/--branch/--commit-msg"

ensure_state_dir
csg_ref_exists baseline || die "refs/csg/baseline missing — run csg-setup first"

# --- snapshot the current Mac tree and diff against the baseline ---
MAC_UNI=$(csg_mktemp); mac_universe > "$MAC_UNI"
snapshot_ref "$MAC_UNI" current "csg current tree for #$TICKET" >/dev/null
CHANGES=$(git -C "$MAC_REPO" diff-tree -r --name-status refs/csg/baseline refs/csg/current)
[ -n "$CHANGES" ] || die "no changes between the session baseline and the current Mac tree — nothing to complete"

SPEC_STATE="$SPEC_STATE_DIR/$TICKET"
rm -rf "$SPEC_STATE"; mkdir -p "$SPEC_STATE"
AM_LIST="$SPEC_STATE/am.list"
DEL_LIST="$SPEC_STATE/deleted.list"
printf '%s\n' "$CHANGES" | awk -F'\t' '$1 ~ /^(A|M|T)/ {print $2}' | sort > "$AM_LIST"
printf '%s\n' "$CHANGES" | awk -F'\t' '$1 == "D" {print $2}' | sort > "$DEL_LIST"
AM_COUNT=$(wc -l < "$AM_LIST" | tr -d ' ')
DEL_COUNT=$(wc -l < "$DEL_LIST" | tr -d ' ')
log "change set: $AM_COUNT added/modified, $DEL_COUNT deleted"

# --- build the bundle ---
BUNDLE="$TMP_DIR/spec-$TICKET"
rm -rf "$BUNDLE"; mkdir -p "$BUNDLE/files"

while IFS= read -r p; do
  [ -n "$p" ] || continue
  mkdir -p "$BUNDLE/files/$(dirname "$p")"
  git -C "$MAC_REPO" show "refs/csg/current:$p" > "$BUNDLE/files/$p"
  # integrity: extracted bytes must hash back to the snapshot's blob sha
  want=$(git -C "$MAC_REPO" rev-parse "refs/csg/current:$p")
  got=$(git -C "$MAC_REPO" hash-object --no-filters -- "$BUNDLE/files/$p")
  [ "$want" = "$got" ] || die_catalog 19 "bundled file does not hash back to its blob: $p ($got != $want)"
done < "$AM_LIST"

cp "$DEL_LIST" "$BUNDLE/deleted.list"
git -C "$MAC_REPO" diff --binary refs/csg/baseline refs/csg/current > "$BUNDLE/changes.patch"

# manifest.expected — what corp `ls-tree -r HEAD` must show after cursor's
# commit. Composed from corp's OWN baseline tree for untouched files plus our
# snapshot's blobs for changed files: four legacy .cjs files carry CRLF inside
# their committed blobs (text=auto suppressed), so untouched files must be
# expected at their historical SHAs, not at clean-filtered ones.
[ -f "$BASELINE_ENV" ] || die "baseline.env missing — run csg-setup first"
# shellcheck disable=SC1090
. "$BASELINE_ENV"
[ -n "${CORP_HEAD_SHA:-}" ] || die "baseline.env has no CORP_HEAD_SHA — re-run csg-setup"
CHANGED_PATHS=$(csg_mktemp); cat "$AM_LIST" "$DEL_LIST" | sort -u > "$CHANGED_PATHS"
CORP_BASE_MF=$(csg_mktemp); corp_lstree_manifest "$CORP_HEAD_SHA" > "$CORP_BASE_MF"
{
  awk -F'\t' 'NR==FNR {p[$0]=1; next} !($2 in p)' "$CHANGED_PATHS" "$CORP_BASE_MF"
  mac_lstree_manifest refs/csg/current \
    | awk -F'\t' 'NR==FNR {p[$0]=1; next} ($2 in p)' "$AM_LIST" -
} | manifest_sort > "$BUNDLE/manifest.expected"
EXP_COUNT=$(wc -l < "$BUNDLE/manifest.expected" | tr -d ' ')
BASE_COUNT=$(wc -l < "$CORP_BASE_MF" | tr -d ' ')
DELTA_OK=$((BASE_COUNT - $(comm -12 "$CHANGED_PATHS" <(cut -f2 "$CORP_BASE_MF" | sort) | grep -c '' || true) + AM_COUNT))
[ "$EXP_COUNT" -eq "$DELTA_OK" ] || die_catalog 19 "expected-manifest composition is inconsistent ($EXP_COUNT entries, computed $DELTA_OK)"
cp "$BUNDLE/manifest.expected" "$SPEC_STATE/expected.manifest"

CHANGED_ALL=$(csg_mktemp); cat "$AM_LIST" "$DEL_LIST" > "$CHANGED_ALL"
LINT_CMDS_FILE="$SPEC_STATE/lint.cmds"
affected_lint_cmds "$CHANGED_ALL" > "$LINT_CMDS_FILE"
if [ ! -s "$LINT_CMDS_FILE" ]; then
  warn "no root lint script maps to the changed paths — lint gate will be skipped"
fi

{
  echo "# CSG change spec — ticket #$TICKET"
  echo
  echo "- description : $DESC"
  echo "- branch      : $BRANCH"
  echo "- commit msg  : $COMMIT_MSG   (byte-exact, single line)"
  echo "- generated   : $(date '+%Y-%m-%dT%H:%M:%S') on the Mac by csg-complete"
  echo
  echo "files/ holds the EXACT final content of every added/modified file at its"
  echo "repo-relative path — it is AUTHORITATIVE. changes.patch is context only."
  echo
  echo "## added/modified ($AM_COUNT)"
  sed 's/^/- /' "$AM_LIST"
  echo
  echo "## deleted ($DEL_COUNT)"
  sed 's/^/- /' "$DEL_LIST"
  echo
  echo "## lint commands (run from repo root)"
  sed 's/^/- /' "$LINT_CMDS_FILE"
} > "$BUNDLE/SPEC.md"

# --- transfer: tar -> scp -P 2223 -> extract on the corporate side ---
TGZ="$TMP_DIR/spec-$TICKET.tgz"
# COPYFILE_DISABLE: stop macOS bsdtar from emitting AppleDouble ._* entries
COPYFILE_DISABLE=1 tar -czf "$TGZ" -C "$BUNDLE" .
SHA=$(shasum -a 256 "$TGZ" | cut -d' ' -f1)
REMOTE_TGZ="/tmp/csg-spec-$TICKET.tgz"
log "transferring spec bundle ($(du -h "$TGZ" | cut -f1 | tr -d ' ')) -> $SPEC_DIR_WIN\\$TICKET ..."
scp_to_wsl "$TGZ" "$REMOTE_TGZ"
wsl_exec_n "
set -e
echo \"$SHA  $REMOTE_TGZ\" | sha256sum -c - >/dev/null
mkdir -p \"$SPEC_DIR_WSL\"
rm -rf \"$SPEC_DIR_WSL/$TICKET\"
mkdir -p \"$SPEC_DIR_WSL/$TICKET\"
tar -xzf \"$REMOTE_TGZ\" -C \"$SPEC_DIR_WSL/$TICKET\"
find \"$SPEC_DIR_WSL/$TICKET\" \\( -name '._*' -o -name '.DS_Store' \\) -delete
rm -f \"$REMOTE_TGZ\"
" || die_catalog 19 "spec bundle transfer/extract failed (sha256 or tar error on the corporate side)"

LOCAL_COUNT=$(find "$BUNDLE/files" -type f | wc -l | tr -d ' ')
REMOTE_COUNT=$(wsl_exec_n "find \"$SPEC_DIR_WSL/$TICKET/files\" -type f 2>/dev/null | wc -l" | tr -cd '0-9')
[ "$LOCAL_COUNT" = "$REMOTE_COUNT" ] || die_catalog 19 "spec file count mismatch after extract: local $LOCAL_COUNT vs corp $REMOTE_COUNT"

cat > "$SPEC_STATE/spec.env" <<EOF
SPEC_TICKET=$TICKET
SPEC_BRANCH=$BRANCH
SPEC_AM_COUNT=$AM_COUNT
SPEC_DEL_COUNT=$DEL_COUNT
SPEC_DIR_TICKET_WIN=$SPEC_DIR_WIN\\$TICKET
SPEC_GENERATED_AT=$(date '+%Y-%m-%dT%H:%M:%S')
EOF

log "spec bundle ready on corporate: $SPEC_DIR_WIN\\$TICKET ($AM_COUNT files, $DEL_COUNT deletions)"
