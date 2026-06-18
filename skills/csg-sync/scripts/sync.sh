#!/bin/bash
# csg-sync — push the Mac working tree to the corporate checkout for browser
# testing through the tunnel. Mac wins.
#
#   drift check (corp changed since last sync? -> F16 unless --force)
#   -> rsync push (full universe; rsync delta makes it cheap)
#   -> explicit corp-side deletions (never rsync --delete)
#   -> post-verify byte-identical manifests (catches DrvFs surprises)
#   -> hot-reload watch on servers.log (warn-only on timeout)
#
# Flags: --force      Mac wins over corporate drift
#        --no-watch   skip the recompile watch
set -euo pipefail

CSG_LIB="$HOME/.claude/skills/csg-common/lib"
. "$CSG_LIB/env.sh"
. "$CSG_LIB/log.sh"
. "$CSG_LIB/remote.sh"
. "$CSG_LIB/manifest.sh"
. "$CSG_LIB/rsyncw.sh"

FORCE=0; NO_WATCH=0
while [ $# -gt 0 ]; do
  case "$1" in
    --force) FORCE=1; shift ;;
    --no-watch) NO_WATCH=1; shift ;;
    -h|--help) echo "usage: sync.sh [--force] [--no-watch]"; exit 0 ;;
    *) die "unknown flag: $1" ;;
  esac
done

ensure_state_dir
[ -s "$CORP_LAST_SYNC_MANIFEST" ] || die "no sync state yet — run csg-setup first"
backchannel_check
syncthing_guard

# --- 1. drift check: recompute corp manifest over the last-sync paths ---
PREV_PATHS=$(csg_mktemp); cut -f2 "$CORP_LAST_SYNC_MANIFEST" > "$PREV_PATHS"
CORP_NOW=$(csg_mktemp); corp_manifest "$PREV_PATHS" > "$CORP_NOW"
DRIFT=$(csg_mktemp); manifest_diff "$CORP_LAST_SYNC_MANIFEST" "$CORP_NOW" > "$DRIFT"
if [ -s "$DRIFT" ]; then
  if [ "$FORCE" = 1 ]; then
    warn "corporate drift detected — overridden by --force (Mac wins):"
    diff_table "$DRIFT" "last-sync" "corp-now" >&2
  else
    die_catalog 16 "$(diff_table "$DRIFT" "last-sync" "corp-now")"
  fi
else
  log "drift check: corporate matches last sync"
fi

# --- 2. record servers.log position for the hot-reload watch ---
START_LINE=$(wsl_exec_n "wc -l < \"$SERVERS_LOG_WSL\" 2>/dev/null || echo 0" | tr -cd '0-9')
[ -n "$START_LINE" ] || START_LINE=0

# --- 3. what changes (report), then push ---
MAC_UNI=$(csg_mktemp); mac_universe > "$MAC_UNI"
MAC_MF=$(csg_mktemp); mac_manifest "$MAC_UNI" > "$MAC_MF"
REPORT=$(csg_mktemp); manifest_diff "$CORP_LAST_SYNC_MANIFEST" "$MAC_MF" > "$REPORT"

if [ ! -s "$REPORT" ] && [ "$FORCE" != 1 ]; then
  log "nothing to sync — corporate already matches the Mac tree"
  exit 0
fi

NCH=$(grep -c "^CHANGED" "$REPORT" || true)
NADD=$(grep -c "^ONLY_B" "$REPORT" || true)
NDEL=$(grep -c "^ONLY_A" "$REPORT" || true)
log "pushing Mac -> corp: ${NCH:-0} changed, ${NADD:-0} new, ${NDEL:-0} deleted"
if [ -s "$REPORT" ]; then diff_table "$REPORT" "corp" "Mac" >&2; fi

rsync_push "$MAC_UNI"

# --- 4. corp-side deletions: previously-synced paths no longer on the Mac ---
PREV_UNION=$(csg_mktemp)
{ cut -f2 "$MAC_LAST_PUSH_MANIFEST"; cut -f2 "$CORP_LAST_SYNC_MANIFEST"; } | sort -u > "$PREV_UNION"
DEL=$(csg_mktemp); comm -23 "$PREV_UNION" "$MAC_UNI" > "$DEL"
if [ -s "$DEL" ]; then
  log "deleting on corporate:"
  sed 's/^/    rm /' "$DEL" >&2
  rm_by_list_corp "$DEL"
fi

# --- 5. post-verify: corp tree must now be byte-identical to the Mac tree ---
CORP_AFTER=$(csg_mktemp); corp_manifest "$MAC_UNI" > "$CORP_AFTER"
if ! manifests_equal "$CORP_AFTER" "$MAC_MF"; then
  VDIFF=$(csg_mktemp); manifest_diff "$MAC_MF" "$CORP_AFTER" > "$VDIFF"
  die_catalog 19 "post-push verification failed (Mac vs corp):"$'\n'"$(diff_table "$VDIFF" "Mac" "corp")"
fi
if [ -s "$DEL" ]; then
  DEL_CHECK=$(csg_mktemp); corp_manifest "$DEL" > "$DEL_CHECK"
  LEFT=$(grep -v "^MISSING$TAB" "$DEL_CHECK" || true)
  [ -z "$LEFT" ] || die_catalog 19 "deletion verification failed — still present on corporate:"$'\n'"$LEFT"
fi

# --- 6. store manifests ---
cp "$MAC_MF" "$CORP_LAST_SYNC_MANIFEST"
cp "$MAC_MF" "$MAC_LAST_PUSH_MANIFEST"
printf '%s push Mac -> corp (%s changed, %s new, %s deleted)\n' \
  "$(date '+%F %T')" "${NCH:-0}" "${NADD:-0}" "${NDEL:-0}" >> "$SYNC_LOG"
log "sync verified byte-identical"

# --- 7. hot-reload watch (warn-only; never fails the sync) ---
if [ "$NO_WATCH" = 1 ]; then exit 0; fi
if [ "${NCH:-0}" = "0" ] && [ "${NADD:-0}" = "0" ] && [ "${NDEL:-0}" = "0" ]; then exit 0; fi

log "watching servers.log for webpack recompile (up to 150 s — watcher events for WSL-side writes can lag)..."
DEADLINE=$(( $(date +%s) + 150 ))
TAGS=""
while [ "$(date +%s)" -lt "$DEADLINE" ]; do
  NEW=$(wsl_exec_n "tail -n +$((START_LINE + 1)) \"$SERVERS_LOG_WSL\" 2>/dev/null" | tr -d '\r' \
        | grep -E 'compiled successfully|compiled in' || true)
  if [ -n "$NEW" ]; then
    sleep 5  # short grace: a packages/common change recompiles several MFEs
    NEW=$(wsl_exec_n "tail -n +$((START_LINE + 1)) \"$SERVERS_LOG_WSL\" 2>/dev/null" | tr -d '\r' \
          | grep -E 'compiled successfully|compiled in' || true)
    TAGS=$(printf '%s\n' "$NEW" | grep -E -o '\[(shell|smsws|ussd|pmcs|spcm)\]' | sort -u | tr '\n' ' ')
    break
  fi
  sleep 5
done
if [ -n "$TAGS" ]; then
  log "hot reload: recompiled ${TAGS}— refresh http://localhost:3002/ if HMR didn't apply"
else
  warn "no recompile seen in servers.log within 150 s (HMR may still have applied, or the change touched no served bundle)"
fi
