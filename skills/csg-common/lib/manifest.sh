#!/bin/bash
# csg-common/lib/manifest.sh — universe lists, manifest build (Mac/corp),
# manifest_diff, corp ls-tree manifests. ALL outputs are exclude-filtered
# consistently (cookies.txt is tracked at the baseline commit, so corp ls-tree
# output must be filtered too).
#
# Manifest line format: "<blob-sha>\t<path>", sorted by path (LC_ALL=C).
# Missing-on-disk files appear as "MISSING\t<path>" — drift evidence, not a crash.
# .gitattributes pins `* text=auto eol=lf`, so clean-filtered blob SHAs are
# EOL-stable across machines/engines.
#
# CAVEAT (verified live): four legacy apps/smsws/fix-*.cjs files were committed
# WITH CRLF inside their blobs; git suppresses text=auto conversion for those,
# so their historical ls-tree SHAs differ from any clean-filtered hash.
# Consequences honored throughout the suite:
#   - worktree-hash manifests (mac_manifest/corp_manifest) are comparable with
#     EACH OTHER and with ls-tree of snapshots WE build from a worktree
#     (refs/csg/*), on any machine;
#   - ls-tree manifests of HISTORICAL corp commits are comparable only with
#     other historical-commit manifests (verify-tree's expected manifest is
#     therefore COMPOSED from corp's baseline tree + our changed-file blobs).
#
# Requires env.sh + log.sh + remote.sh sourced first.

# Drop excluded paths from a path-per-line stream (exact match).
filter_excludes_paths() {
  grep -v -x -F -f "$EXCLUDES_FILE" || true
}

# Drop excluded paths from a manifest (sha\tpath) stream.
filter_excludes_manifest() {
  awk -F'\t' 'NR==FNR { ex[$0]=1; next } !($2 in ex)' "$EXCLUDES_FILE" -
}

manifest_sort() { sort -t"$TAB" -k2,2; }

# ---------------------------------------------------------------------------
# Mac side
# ---------------------------------------------------------------------------

# Tracked + untracked-not-ignored files, minus excludes, existing on disk, sorted.
# A tracked file deleted from disk drops out (it will sync as a deletion) with a
# warning.
mac_universe() {
  ( cd "$MAC_REPO" || exit 1
    git ls-files -co --exclude-standard | filter_excludes_paths | while IFS= read -r p; do
      if [ -f "$p" ]; then
        printf '%s\n' "$p"
      else
        printf '[csg WARN] missing on Mac disk (treated as deleted): %s\n' "$p" >&2
      fi
    done | sort -u )
}

# mac_manifest [path-list-file] — manifest of the Mac working tree over the
# given paths (default: mac_universe). Clean filters applied (hash-object on
# worktree paths), so SHAs match ls-tree of a commit of the same content.
mac_manifest() {
  local paths exist missing shas
  paths=$(csg_mktemp); exist=$(csg_mktemp); missing=$(csg_mktemp); shas=$(csg_mktemp)
  if [ -n "${1:-}" ]; then sort -u "$1" > "$paths"; else mac_universe > "$paths"; fi
  ( cd "$MAC_REPO" || exit 1
    while IFS= read -r p; do
      if [ -f "$p" ]; then printf '%s\n' "$p" >> "$exist"
      else printf 'MISSING\t%s\n' "$p" >> "$missing"; fi
    done < "$paths"
    if [ -s "$exist" ]; then
      git hash-object --stdin-paths < "$exist" > "$shas"
    fi
  )
  { if [ -s "$exist" ]; then paste "$shas" "$exist"; fi
    cat "$missing"; } | manifest_sort
  rm -f "$paths" "$exist" "$missing" "$shas"
}

# Manifest of a local commit/ref's tree (exclude-filtered).
mac_lstree_manifest() {
  ( cd "$MAC_REPO" && git ls-tree -r "$1" ) \
    | awk -F'\t' '{ split($1,a," "); print a[3] "\t" $2 }' \
    | filter_excludes_manifest | manifest_sort
}

# ---------------------------------------------------------------------------
# corp side — one ssh round-trip each
# ---------------------------------------------------------------------------

# Tracked file list from the corporate index, exclude-filtered, sorted.
corp_tracked_list() {
  corp_git ls-files | filter_excludes_paths | sort -u
}

# corp_manifest <path-list-file> — manifest of the corporate working tree over
# the given paths. Single round-trip: ships the list, hashes remotely with the
# cached git engine, emits MISSING for absent files.
corp_manifest() {
  local list="$1" engine gitcmd script
  engine=$(corp_git_engine)
  if [ "$engine" = "wsl" ]; then
    gitcmd="git -c 'safe.directory=*'"
  else
    gitcmd="\"$GIT_EXE_WSL\""
  fi
  script="
set -e
cd \"$CORP_REPO_WSL\"
t=\$(mktemp -d)
trap 'rm -rf \"\$t\"' EXIT
cat > \"\$t/paths\"
: > \"\$t/exist\"; : > \"\$t/missing\"
while IFS= read -r p; do
  if [ -f \"\$p\" ]; then printf '%s\n' \"\$p\" >> \"\$t/exist\"
  else printf 'MISSING\t%s\n' \"\$p\" >> \"\$t/missing\"; fi
done < \"\$t/paths\"
if [ -s \"\$t/exist\" ]; then
  $gitcmd hash-object --stdin-paths < \"\$t/exist\" > \"\$t/shas\"
  paste \"\$t/shas\" \"\$t/exist\"
fi
cat \"\$t/missing\"
"
  sort -u "$list" | wsl_exec "$script" | tr -d '\r' | manifest_sort
}

# Manifest of a corporate commit's tree (exclude-filtered).
corp_lstree_manifest() {
  corp_git "ls-tree -r $1" \
    | awk -F'\t' '{ split($1,a," "); print a[3] "\t" $2 }' \
    | filter_excludes_manifest | manifest_sort
}

# ---------------------------------------------------------------------------
# diff
# ---------------------------------------------------------------------------

# manifest_diff <A> <B> — compares two manifest FILES. Output lines:
#   CHANGED\t<path>   present in both, different sha
#   ONLY_A\t<path>    only in A
#   ONLY_B\t<path>    only in B
# Empty output = identical path sets and contents.
manifest_diff() {
  local A="$1" B="$2" ap bp aw bw
  ap=$(csg_mktemp); bp=$(csg_mktemp); aw=$(csg_mktemp); bw=$(csg_mktemp)
  cut -f2 "$A" | sort > "$ap"
  cut -f2 "$B" | sort > "$bp"
  awk -F'\t' '{print $2 "\t" $1}' "$A" | sort -t"$TAB" -k1,1 > "$aw"
  awk -F'\t' '{print $2 "\t" $1}' "$B" | sort -t"$TAB" -k1,1 > "$bw"
  {
    comm -23 "$ap" "$bp" | awk '{print "ONLY_A\t" $0}'
    comm -13 "$ap" "$bp" | awk '{print "ONLY_B\t" $0}'
    join -t"$TAB" "$aw" "$bw" | awk -F'\t' '$2 != $3 {print "CHANGED\t" $1}'
  } | sort -t"$TAB" -k2,2
  rm -f "$ap" "$bp" "$aw" "$bw"
}

manifests_equal() { cmp -s "$1" "$2"; }

# Pretty-print a manifest_diff with side labels, e.g.
#   diff_table "<file>" "Mac" "corp"
diff_table() {
  local file="$1" aname="${2:-A}" bname="${3:-B}"
  awk -F'\t' -v a="$aname" -v b="$bname" '
    $1=="CHANGED" { printf "  content differs        : %s\n", $2; next }
    $1=="ONLY_A"  { printf "  only on %-14s: %s\n", a, $2; next }
    $1=="ONLY_B"  { printf "  only on %-14s: %s\n", b, $2; next }
  ' "$file"
}
