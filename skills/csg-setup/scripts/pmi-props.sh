#!/bin/bash
# csg-setup/scripts/pmi-props.sh — verify (and only if drifted, restore)
# C:\tango\config\pmi\pmi.properties for tunnel mode.
#
# Findings §5: in tunnel mode the change list is EMPTY — "change NOTHING".
# This script therefore *verifies* the localhost inventory still holds and only
# repairs drift: timestamped backup -> sed -i -> PMI restart. No change -> no
# restart, said explicitly.
#
# The file contains plaintext default credentials (external.auth.default.*):
# it is streamed into memory only — never written to Mac disk, never logged
# wholesale. Only URL-valued keys are ever printed.
#
# Flags: --check-only   verify + report; exit 0 ok / 3 drift found
set -euo pipefail

CSG_LIB="$HOME/.claude/skills/csg-common/lib"
. "$CSG_LIB/env.sh"
. "$CSG_LIB/log.sh"
. "$CSG_LIB/remote.sh"

CHECK_ONLY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --check-only) CHECK_ONLY=1; shift ;;
    -h|--help) echo "usage: pmi-props.sh [--check-only]"; exit 0 ;;
    *) die "unknown flag: $1" ;;
  esac
done

ensure_state_dir
backchannel_check

PROPS=$(wsl_exec_n "cat \"$PMI_PROPS_WSL\"" | tr -d '\r')
[ -n "$PROPS" ] || die "could not read $PMI_PROPS_WIN over the back-channel"

get_prop() {
  printf '%s\n' "$PROPS" | grep "^$1=" | tail -1 | cut -d= -f2-
}

# Browser-dereferenced keys — exact-assert (findings §5 localhost inventory).
expected_pairs() {
  cat <<'EOF'
client.pmcs.mfe.url	http://localhost:3004/remoteEntry.js
client.spcm.mfe.url	http://localhost:3007/remoteEntry.js
client.sms.mfe.url	http://localhost:8298/smsws/ui/remoteEntry.js
client.ussd.mfe.url	http://localhost:8293/ussdws/ui/remoteEntry.js
server.port	8080
server.servlet.context-path	/pmi
EOF
}

DRIFTED=$(csg_mktemp); : > "$DRIFTED"
while IFS="$TAB" read -r key want; do
  have=$(get_prop "$key")
  if [ "$have" != "$want" ]; then
    warn "DRIFT: $key='${have:-<absent>}' (expected '$want')"
    printf '%s\t%s\n' "$key" "$want" >> "$DRIFTED"
  fi
done < <(expected_pairs)

# Server-side-dereferenced keys — warn only, NEVER auto-edit (PMI dereferences
# these on the corporate machine, where localhost is correct).
for key in client.ims.base.url client.hrg.base.url client.smsws.base.url \
           pmcs.base.url smsws.base.url \
           ims.client.primary.service.url ims.client.secondary.service.url; do
  v=$(get_prop "$key")
  case "$v" in
    "")           warn "server-side key absent (left alone): $key" ;;
    *localhost*)  : ;;
    *)            warn "server-side key not localhost (left alone — PMI resolves it on corporate): $key=$v" ;;
  esac
done
sso=$(get_prop external.sso.auth.url.mappings)
case "$sso" in
  *localhost:8080*) : ;;
  *) warn "external.sso.auth.url.mappings does not reference localhost:8080 (left alone)" ;;
esac

if [ ! -s "$DRIFTED" ]; then
  log "pmi.properties matches the tunnel-mode inventory — no change, no restart (findings §5: change NOTHING)"
  exit 0
fi

if [ "$CHECK_ONLY" = 1 ]; then
  warn "pmi.properties drift found (check-only — not fixing)"
  exit 3
fi

# --- restore: timestamped backup -> targeted sed -> verify -> restart ---
TS=$(date +%Y%m%d-%H%M%S)
BAK="$PMI_PROPS_WSL.csg-bak-$TS"
log "backing up pmi.properties -> ${PMI_PROPS_WIN}.csg-bak-$TS"
wsl_exec_n "cp \"$PMI_PROPS_WSL\" \"$BAK\""
printf '%s backup %s.csg-bak-%s fixing: %s\n' "$(date '+%F %T')" "$PMI_PROPS_WIN" "$TS" \
  "$(cut -f1 "$DRIFTED" | tr '\n' ' ')" >> "$PMI_BACKUPS_LOG"

while IFS="$TAB" read -r key want; do
  ekey=$(printf '%s' "$key" | sed 's/\./\\./g')
  if printf '%s\n' "$PROPS" | grep -q "^$key="; then
    wsl_exec_n "sed -i \"s|^$ekey=.*|$key=$want|\" \"$PMI_PROPS_WSL\""
  else
    wsl_exec_n "printf '%s=%s\n' \"$key\" \"$want\" >> \"$PMI_PROPS_WSL\""
  fi
  log "fixed: $key=$want"
done < "$DRIFTED"

# re-verify
PROPS=$(wsl_exec_n "cat \"$PMI_PROPS_WSL\"" | tr -d '\r')
while IFS="$TAB" read -r key want; do
  have=$(get_prop "$key")
  [ "$have" = "$want" ] || die_catalog 19 "pmi.properties repair did not stick: $key='$have' (wanted '$want'). Backup: ${PMI_PROPS_WIN}.csg-bak-$TS"
done < "$DRIFTED"

log "restarting PMI to pick up property changes (kill-by-port -> start-pmi.bat -> health poll)..."
stop_port_windows "$PMI_PORT" || true
sleep 3
start_pmi
if ! wait_for 180 5 "pmi" pmi_health_hairpin; then
  die_catalog 18
fi
pmi_health_mac || die_catalog 10 "PMI restarted UP on corporate but unreachable through the tunnel"
log "PMI restarted and UP — pmi.properties restored ($(wc -l < "$DRIFTED" | tr -d ' ') key(s); backup ${PMI_PROPS_WIN}.csg-bak-$TS)"
