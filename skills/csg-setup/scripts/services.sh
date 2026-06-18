#!/bin/bash
# csg-setup/scripts/services.sh — dev servers (webpack, yarn dev:all) + PMI.
# Per port: probe via the tunnel (Mac loopback); if down, probe via the WSL
# Tailscale-IP hairpin to disambiguate "service down" vs "forward missing"
# (forward missing -> F10 with the full tunnel command). Truly down -> start
# detached via the verified Start-Process patterns, then poll readiness.
#
# Flags: --check-only   probe + report; exit 0 all-up / 3 something-down
set -euo pipefail

CSG_LIB="$HOME/.claude/skills/csg-common/lib"
. "$CSG_LIB/env.sh"
. "$CSG_LIB/log.sh"
. "$CSG_LIB/remote.sh"

CHECK_ONLY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --check-only) CHECK_ONLY=1; shift ;;
    -h|--help) echo "usage: services.sh [--check-only]"; exit 0 ;;
    *) die "unknown flag: $1" ;;
  esac
done

ensure_state_dir
backchannel_check

NEEDS_DEV=0
NEEDS_PMI=0

for p in $DEV_PORTS; do
  if http_up_mac "$p"; then
    log "dev :$p — up (via tunnel)"
  elif http_up_hairpin "$p"; then
    die_catalog 10 "dev :$p is LIVE on corporate but NOT forwarded to the Mac — the tunnel is up for $BACKCHANNEL_PORT but incomplete. Restart it with the full command above (all -R forwards)."
  else
    warn "dev :$p — down"
    NEEDS_DEV=1
  fi
done

if pmi_health_mac; then
  log "PMI :$PMI_PORT — UP (via tunnel)"
elif pmi_health_hairpin; then
  die_catalog 10 "PMI is UP on corporate but :$PMI_PORT is NOT forwarded to the Mac — the tunnel is incomplete. Restart it with the full command above."
else
  warn "PMI :$PMI_PORT — down"
  NEEDS_PMI=1
fi

if [ "$CHECK_ONLY" = 1 ]; then
  if [ "$NEEDS_DEV" = 0 ] && [ "$NEEDS_PMI" = 0 ]; then
    log "all services up"
    exit 0
  fi
  exit 3
fi

if [ "$NEEDS_DEV" = 1 ]; then
  # predev:all (kill:ports) skips 3002 — stop any partial set ourselves so the
  # fresh dev:all never hits EADDRINUSE on the shell port.
  log "services: stopping any partially-running dev servers on corporate..."
  for p in $DEV_PORTS; do
    stop_port_windows "$p" || true
  done
  log "services: launching 'yarn dev:all > servers.log' detached (Start-Process)..."
  start_dev_servers
  log "services: polling readiness via hairpin — cold 5x webpack is slow (up to 240 s)..."
  DEADLINE=$(( $(date +%s) + 240 ))
  for p in $DEV_PORTS; do
    until http_up_hairpin "$p" >/dev/null 2>&1; do
      if [ "$(date +%s)" -ge "$DEADLINE" ]; then
        die "dev server :$p did not come up within 240 s — check the log: ssh -p $BACKCHANNEL_PORT $BACKCHANNEL_USER@localhost 'tail -n 60 $SERVERS_LOG_WSL'"
      fi
      sleep 5
    done
    if ! http_up_mac "$p"; then
      die_catalog 10 "dev :$p is up on corporate but unreachable through the tunnel"
    fi
    log "dev :$p — up"
  done
fi

if [ "$NEEDS_PMI" = 1 ]; then
  log "services: launching start-pmi.bat detached (it self-kills any old :$PMI_PORT instance)..."
  start_pmi
  log "services: polling /pmi/actuator/health (up to 180 s)..."
  if ! wait_for 180 5 "pmi" pmi_health_hairpin; then
    die_catalog 18
  fi
  pmi_health_mac || die_catalog 10 "PMI is UP on corporate but unreachable through the tunnel"
  log "PMI :$PMI_PORT — UP"
fi

log "services: all up (shell :3002, MFEs :3001/:3003/:3004/:3007, PMI :$PMI_PORT)"
