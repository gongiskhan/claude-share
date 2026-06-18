#!/bin/bash
# csg-setup — bring the CSG remote dev environment up:
#   tunnel/back-channel checks -> syncthing guard -> corporate repo state ->
#   dev servers + PMI -> pmi.properties verification -> pull clean copy
#   corp->Mac -> session baseline -> smoke test -> summary.
#
# Flags:
#   --only <phase>      run a single phase (preflight/tunnel/backchannel are
#                       always run first as prerequisites)
#   --overwrite-local   allow the pull to discard unsynced Mac work (F15)
#   --update-corp       git pull --ff-only origin main on corporate first
#   --skip-services     skip the services and smoke phases
set -euo pipefail

CSG_LIB="$HOME/.claude/skills/csg-common/lib"
. "$CSG_LIB/env.sh"
. "$CSG_LIB/log.sh"
. "$CSG_LIB/remote.sh"
. "$CSG_LIB/manifest.sh"
. "$CSG_LIB/rsyncw.sh"
. "$CSG_LIB/gitbase.sh"

SCRIPTS_DIR=$(cd "$(dirname "$0")" && pwd)
PHASES="preflight tunnel backchannel syncthing corpstate services pmi pull baseline smoke summary"

usage() {
  cat <<EOF
usage: setup.sh [--only <phase>] [--overwrite-local] [--update-corp] [--skip-services]
phases: $PHASES
EOF
}

ONLY=""; OVERWRITE_LOCAL=0; UPDATE_CORP=0; SKIP_SERVICES=0
while [ $# -gt 0 ]; do
  case "$1" in
    --only) ONLY="${2:?--only needs a phase name}"; shift 2 ;;
    --overwrite-local) OVERWRITE_LOCAL=1; shift ;;
    --update-corp) UPDATE_CORP=1; shift ;;
    --skip-services) SKIP_SERVICES=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage; die "unknown flag: $1" ;;
  esac
done

CORP_HEAD=""
ensure_corp_head() {
  if [ -z "$CORP_HEAD" ]; then
    CORP_HEAD=$(corp_git rev-parse HEAD)
    [ -n "$CORP_HEAD" ] || die "could not read corporate HEAD"
  fi
}

# ---------------------------------------------------------------------------

phase_preflight() {
  ensure_state_dir
  [ -d "$MAC_REPO/.git" ] || die "Mac repo missing at $MAC_REPO"
  local c
  for c in rsync curl nc lsof iconv base64 ssh scp git tar shasum python3; do
    command -v "$c" >/dev/null 2>&1 || die "required tool missing on Mac: $c"
  done
  git -C "$MAC_REPO" config user.email >/dev/null 2>&1 \
    || die "git identity missing in $MAC_REPO (needed for baseline commit-tree)"
  # sweep stale temp files from previous runs (keeps spec-* dirs)
  find "$TMP_DIR" -maxdepth 1 -type f -name 'csg.*' -delete 2>/dev/null || true
  log "preflight OK — state dir: $STATE_DIR"
}

phase_tunnel() {
  tunnel_probe
  log "tunnel: back-channel port $BACKCHANNEL_PORT is listening on Mac loopback"
}

phase_backchannel() {
  backchannel_auth
  log "back-channel: ssh -p $BACKCHANNEL_PORT OK (corp git engine: $(corp_git_engine))"
}

phase_syncthing() {
  syncthing_guard
  log "syncthing: not running on corporate"
}

phase_corpstate() {
  local branch status untracked
  branch=$(corp_git rev-parse --abbrev-ref HEAD)
  status=$(corp_git "status --porcelain --untracked-files=no")
  if [ "$branch" != "main" ] || [ -n "$status" ]; then
    die_catalog 14 "branch: $branch"$'\n'"tracked changes:"$'\n'"${status:-<none>}"
  fi
  if [ "$UPDATE_CORP" = 1 ]; then
    log "corpstate: pulling latest main on corporate (Windows git, ff-only)..."
    corp_git_win "pull --ff-only origin main" \
      || die "corporate 'git pull --ff-only origin main' failed — resolve over the back-channel, then re-run"
    status=$(corp_git "status --porcelain --untracked-files=no")
    [ -z "$status" ] || die_catalog 14 "tree dirty after pull:"$'\n'"$status"
  fi
  untracked=$(corp_git "status --porcelain" | grep -c '^??' || true)
  if [ "${untracked:-0}" -gt 0 ]; then
    warn "corpstate: $untracked untracked file(s) on corporate — left alone (explicit-rm design never touches them)"
  fi
  ensure_corp_head
  log "corpstate: clean on main @ $CORP_HEAD"
}

phase_services() {
  if [ "$SKIP_SERVICES" = 1 ]; then
    log "services: skipped (--skip-services)"
    return 0
  fi
  bash "$SCRIPTS_DIR/services.sh"
}

phase_pmi() {
  if [ "$SKIP_SERVICES" = 1 ]; then
    log "pmi: --skip-services — verifying pmi.properties in check-only mode"
    local rc=0
    bash "$SCRIPTS_DIR/pmi-props.sh" --check-only || rc=$?
    if [ "$rc" -eq 3 ]; then
      warn "pmi.properties has drifted — run 'pmi-props.sh' (or csg-setup without --skip-services) to restore"
    elif [ "$rc" -ne 0 ]; then
      return "$rc"
    fi
    return 0
  fi
  bash "$SCRIPTS_DIR/pmi-props.sh"
}

phase_pull() {
  ensure_corp_head

  # Safety stop first: any unsynced local work on the Mac?
  local mac_now safety_text=""
  mac_now=$(csg_mktemp); mac_manifest > "$mac_now"
  if csg_ref_exists baseline; then
    # Baseline is our own clean-filtered snapshot — comparable with mac_manifest.
    local base_mf safety
    base_mf=$(csg_mktemp); mac_lstree_manifest refs/csg/baseline > "$base_mf"
    safety=$(csg_mktemp); manifest_diff "$base_mf" "$mac_now" > "$safety"
    if [ -s "$safety" ]; then safety_text=$(diff_table "$safety" "baseline" "Mac-now"); fi
    log "pull: safety check against session baseline (refs/csg/baseline)"
  else
    # No baseline yet: `git status` is the correct worktree-vs-HEAD judge here
    # (it honors the CRLF-blob conversion suppression that manifest hashing
    # cannot — see manifest.sh CAVEAT). Excludes filtered out.
    safety_text=$(git -C "$MAC_REPO" status --porcelain | awk -v ex="$EXCLUDES_FILE" '
      BEGIN { while ((getline line < ex) > 0) excl[line]=1 }
      { p=substr($0,4); gsub(/^"|"$/, "", p); if (!(p in excl)) print "  " $0 }
    ')
    log "pull: no baseline yet — safety check against Mac HEAD (git status)"
  fi
  if [ -n "$safety_text" ]; then
    if [ "$OVERWRITE_LOCAL" != 1 ]; then
      die_catalog 15 "$safety_text"
    fi
    warn "pull: --overwrite-local — discarding the local differences listed below:"
    printf '%s\n' "$safety_text" >&2
  fi

  # Corporate wins, tracked-only. Truth = the corporate WORKTREE manifest
  # (hash-object), not ls-tree of corp HEAD: four legacy .cjs files carry CRLF
  # inside their committed blobs (text=auto conversion suppressed), so their
  # historical blob SHAs differ from any clean-filtered hash. Worktree-hash
  # manifests are consistent across machines; corpstate already guarantees the
  # corp worktree == corp HEAD content.
  local corp_list corp_truth
  corp_list=$(csg_mktemp); corp_tracked_list > "$corp_list"
  corp_truth=$(csg_mktemp); corp_manifest "$corp_list" > "$corp_truth"
  if grep -q "^MISSING$TAB" "$corp_truth"; then
    die_catalog 19 "tracked files missing from the corporate worktree (dirty tree slipped past corpstate?):"$'\n'"$(grep "^MISSING$TAB" "$corp_truth")"
  fi

  log "pull: rsyncing $(wc -l < "$corp_list" | tr -d ' ') tracked files corp -> Mac..."
  rsync_pull "$corp_list"

  # Mac-side deletions = Mac universe minus corp tracked list. Printed, then
  # explicitly rm'd — never rsync --delete (excludes protect the findings doc etc).
  local mac_uni del
  mac_uni=$(csg_mktemp); mac_universe > "$mac_uni"
  del=$(csg_mktemp); comm -23 "$mac_uni" "$corp_list" > "$del"
  if [ -s "$del" ]; then
    log "pull: deleting $(wc -l < "$del" | tr -d ' ') Mac file(s) not in corporate's tracked tree:"
    sed 's/^/    rm /' "$del" >&2
    rm_by_list_mac "$del"
  fi

  # Byte-identical verification against corp HEAD's tree.
  local mac_after vdiff
  mac_after=$(csg_mktemp); mac_manifest "$corp_list" > "$mac_after"
  if ! manifests_equal "$mac_after" "$corp_truth"; then
    vdiff=$(csg_mktemp); manifest_diff "$corp_truth" "$mac_after" > "$vdiff"
    die_catalog 19 "post-pull verification failed (corp worktree vs Mac):"$'\n'"$(diff_table "$vdiff" "corp" "Mac")"
  fi
  cp "$corp_truth" "$CORP_LAST_SYNC_MANIFEST"
  cp "$corp_truth" "$MAC_LAST_PUSH_MANIFEST"

  # Report what the pull changed on the Mac.
  local rdiff nch nadd ndel
  rdiff=$(csg_mktemp); manifest_diff "$mac_now" "$corp_truth" > "$rdiff"
  if [ -s "$rdiff" ]; then
    nch=$(grep -c "^CHANGED" "$rdiff" || true)
    nadd=$(grep -c "^ONLY_B" "$rdiff" || true)
    ndel=$(grep -c "^ONLY_A" "$rdiff" || true)
    log "pull: applied to Mac — ${nch:-0} changed, ${nadd:-0} added, ${ndel:-0} deleted:"
    diff_table "$rdiff" "Mac(was)" "corp" >&2
  else
    log "pull: no-op — Mac already matched corporate"
  fi
  printf '%s pull corp@%s -> Mac (%s diffs)\n' "$(date '+%F %T')" "$CORP_HEAD" "$(wc -l < "$rdiff" | tr -d ' ')" >> "$SYNC_LOG"
}

phase_baseline() {
  ensure_corp_head
  [ -s "$CORP_LAST_SYNC_MANIFEST" ] || die "no corp-last-sync manifest — run the pull phase first"
  local list commit tree base_mf vdiff
  list=$(csg_mktemp); cut -f2 "$CORP_LAST_SYNC_MANIFEST" > "$list"
  commit=$(snapshot_ref "$list" baseline "csg baseline of corp@$CORP_HEAD")
  tree=$(git -C "$MAC_REPO" rev-parse "refs/csg/baseline^{tree}")
  base_mf=$(csg_mktemp); mac_lstree_manifest refs/csg/baseline > "$base_mf"
  if ! manifests_equal "$base_mf" "$CORP_LAST_SYNC_MANIFEST"; then
    vdiff=$(csg_mktemp); manifest_diff "$CORP_LAST_SYNC_MANIFEST" "$base_mf" > "$vdiff"
    die_catalog 19 "baseline tree does not reproduce the pulled corporate tree:"$'\n'"$(diff_table "$vdiff" "corp" "baseline")"
  fi
  cat > "$BASELINE_ENV" <<EOF
CORP_HEAD_SHA=$CORP_HEAD
BASELINE_TREE=$tree
BASELINE_COMMIT=$commit
BASELINE_AT=$(date '+%Y-%m-%dT%H:%M:%S')
EOF
  log "baseline: refs/csg/baseline = $commit (corp HEAD $CORP_HEAD) — gc-proof"
}

phase_smoke() {
  if [ "$SKIP_SERVICES" = 1 ]; then
    log "smoke: skipped (--skip-services)"
    return 0
  fi
  local code
  code=$(http_code_mac 3002 /)
  [ "$code" = "200" ] || die "smoke: shell http://localhost:3002/ returned ${code:-no-response} (expected 200)"
  code=$(http_code_mac 3007 /remoteEntry.js)
  [ "$code" = "200" ] || die "smoke: SPCM remoteEntry (:3007) returned ${code:-no-response} (expected 200)"
  code=$(http_code_mac 3004 /remoteEntry.js)
  [ "$code" = "200" ] || die "smoke: PMCS remoteEntry (:3004) returned ${code:-no-response} (expected 200)"
  pmi_health_mac || die_catalog 18
  log "smoke: shell 200, SPCM+PMCS remoteEntry 200, PMI UP — all through the tunnel"
}

phase_summary() {
  local head="${CORP_HEAD:-?}" bts="?"
  if [ -f "$BASELINE_ENV" ]; then
    # shellcheck disable=SC1090
    . "$BASELINE_ENV"
    head="$CORP_HEAD_SHA"; bts="$BASELINE_AT"
  fi
  cat >&2 <<EOF

============================================================
 csg-setup complete
   browser     : http://localhost:3002/   (login + SPCM/PMCS work)
   baseline    : corp HEAD $head  (recorded $bts)
   state dir   : $STATE_DIR
   daily loop  : edit on Mac -> csg-sync -> test in browser ->
                 csg-complete --dry-run -> confirm -> finalize (push+PR)
   limitation  : SMS/USSD MFEs point at backends :8298/:8293 that are
                 not running on corporate — those tiles won't load.
============================================================
EOF
}

run_phase() {
  case "$1" in
    preflight)   phase_preflight ;;
    tunnel)      phase_tunnel ;;
    backchannel) phase_backchannel ;;
    syncthing)   phase_syncthing ;;
    corpstate)   phase_corpstate ;;
    services)    phase_services ;;
    pmi)         phase_pmi ;;
    pull)        phase_pull ;;
    baseline)    phase_baseline ;;
    smoke)       phase_smoke ;;
    summary)     phase_summary ;;
    *) die "unknown phase: $1 (phases: $PHASES)" ;;
  esac
}

if [ -n "$ONLY" ]; then
  case " $PHASES " in
    *" $ONLY "*) ;;
    *) die "unknown phase: $ONLY (phases: $PHASES)" ;;
  esac
  phase_preflight
  case "$ONLY" in
    preflight) ;;
    tunnel) phase_tunnel ;;
    backchannel) phase_tunnel; phase_backchannel ;;
    *) phase_tunnel; phase_backchannel; run_phase "$ONLY" ;;
  esac
  exit 0
fi

for p in $PHASES; do
  log "=== phase: $p ==="
  run_phase "$p"
done
