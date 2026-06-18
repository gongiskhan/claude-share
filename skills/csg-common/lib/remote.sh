#!/bin/bash
# csg-common/lib/remote.sh — tunnel probe/triage, back-channel exec (wsl_exec),
# Windows control (win_ps via -EncodedCommand), corp git (WSL git with Windows
# git.exe fallback), syncthing guard, service/PMI probes, start/stop helpers.
# Requires env.sh + log.sh sourced first.

# ---------------------------------------------------------------------------
# low-level exec
# ---------------------------------------------------------------------------

# Run a command line in corporate WSL over the back-channel. stdin passes through.
wsl_exec() {
  ssh -p "$BACKCHANNEL_PORT" "${SSH_OPTS[@]}" "$BACKCHANNEL_USER@localhost" "$@"
}

# Same, stdin detached — safe inside while-read loops and for commands that
# must not consume the caller's stdin.
wsl_exec_n() { wsl_exec "$@" < /dev/null; }

# Run a PowerShell script (one UTF-8 string) on Windows. The bash->ssh->bash->
# powershell quoting tower is eliminated structurally: the script is encoded to
# UTF-16LE base64 ON THE MAC and executed with -EncodedCommand.
win_ps() {
  local b64
  b64=$(printf '$ProgressPreference = "SilentlyContinue"\n%s' "$1" | iconv -f UTF-8 -t UTF-16LE | base64 | tr -d '\n')
  wsl_exec_n "$POWERSHELL_WSL -NoProfile -ExecutionPolicy Bypass -EncodedCommand $b64"
}

# win_ps with a WSL-side wall-clock timeout (seconds). Returns 124 on timeout.
win_ps_timeout() {
  local secs="$1" b64
  b64=$(printf '$ProgressPreference = "SilentlyContinue"\n%s' "$2" | iconv -f UTF-8 -t UTF-16LE | base64 | tr -d '\n')
  wsl_exec_n "timeout $secs $POWERSHELL_WSL -NoProfile -ExecutionPolicy Bypass -EncodedCommand $b64"
}

# ---------------------------------------------------------------------------
# tunnel probe / triage
# ---------------------------------------------------------------------------

mac_port_listening() { nc -z -w 2 127.0.0.1 "$1" >/dev/null 2>&1; }

mac_port_owner() {
  lsof -nP -iTCP:"$1" -sTCP:LISTEN 2>/dev/null | awk 'NR>1 {print $2 "\t" $1; exit}'
}

# Port-level probe of the back-channel forward. Dies F10 (tunnel down) or
# F12 (something else squats the ports the tunnel needs).
tunnel_probe() {
  if mac_port_listening "$BACKCHANNEL_PORT"; then return 0; fi
  local busy="" p owner
  for p in $ALL_TUNNEL_PORTS; do
    if mac_port_listening "$p"; then
      owner=$(mac_port_owner "$p")
      busy="${busy}port $p${TAB}pid/cmd: ${owner:-unknown}"$'\n'
    fi
  done
  if [ -n "$busy" ]; then
    die_catalog 12 "Listeners already on Mac loopback:"$'\n'"$busy"
  fi
  die_catalog 10
}

# Auth-level probe: ssh through the forward and sanity-check it is really
# corporate WSL with the repo mounted. Dies F11 / F21 / F10 as appropriate.
backchannel_auth() {
  local err rc=0
  err=$(ssh -p "$BACKCHANNEL_PORT" "${SSH_OPTS[@]}" "$BACKCHANNEL_USER@localhost" true 2>&1 </dev/null) || rc=$?
  if [ "$rc" -ne 0 ]; then
    case "$err" in
      *"REMOTE HOST IDENTIFICATION HAS CHANGED"*|*"Host key verification failed"*)
        die_catalog 21 "$err" ;;
      *"Permission denied"*|*"Too many authentication failures"*)
        die_catalog 11 "$err" ;;
      *)
        die_catalog 10 "ssh -p $BACKCHANNEL_PORT localhost failed:"$'\n'"$err" ;;
    esac
  fi
  if ! wsl_exec_n "test -d '$CORP_REPO_WSL/.git' || test -f '$CORP_REPO_WSL/.git'" 2>/dev/null; then
    die "back-channel is up but $CORP_REPO_WSL/.git was not found — wrong machine or repo moved" 10
  fi
}

backchannel_check() { tunnel_probe; backchannel_auth; }

# ---------------------------------------------------------------------------
# syncthing guard
# ---------------------------------------------------------------------------

# Dies F13 if syncthing is running on the corporate Windows side (it is
# configured to sync the repo tree and would fight rsync).
syncthing_guard() {
  local out
  out=$(win_ps 'Get-Process -Name syncthing -ErrorAction SilentlyContinue | ForEach-Object { $_.Id }' 2>/dev/null | tr -d '\r' | grep -E '^[0-9]+$' || true)
  if [ -n "$out" ]; then
    die_catalog 13 "syncthing PID(s): $(printf '%s' "$out" | tr '\n' ' ')"
  fi
}

# ---------------------------------------------------------------------------
# corp git — WSL git preferred (cheap over the back-channel), Windows git.exe
# via interop as fallback. Engine choice cached in corp-git.env.
# ---------------------------------------------------------------------------

corp_git_engine() {
  if [ -f "$CORP_GIT_ENV" ]; then
    # shellcheck disable=SC1090
    . "$CORP_GIT_ENV"
    if [ -n "${CORP_GIT_ENGINE:-}" ]; then printf '%s' "$CORP_GIT_ENGINE"; return 0; fi
  fi
  local probe engine=""
  probe=$(wsl_exec_n "cd \"$CORP_REPO_WSL\" && git -c 'safe.directory=*' rev-parse --is-inside-work-tree 2>/dev/null" || true)
  if [ "$probe" = "true" ]; then
    engine=wsl
  else
    probe=$(wsl_exec_n "cd \"$CORP_REPO_WSL\" && \"$GIT_EXE_WSL\" rev-parse --is-inside-work-tree 2>/dev/null" | tr -d '\r' || true)
    if [ "$probe" = "true" ]; then
      engine=win
    fi
  fi
  [ -n "$engine" ] || die "neither WSL git nor Windows git.exe can open $CORP_REPO_WSL — check the corporate checkout"
  printf 'CORP_GIT_ENGINE=%s\n' "$engine" > "$CORP_GIT_ENV"
  printf '%s' "$engine"
}

# corp_git <git args as one or more words> — runs git in the corporate checkout.
# Args are joined with spaces and interpreted by the remote shell: keep them
# simple (plumbing, refs, --porcelain). No stdin.
corp_git() {
  local engine; engine=$(corp_git_engine)
  if [ "$engine" = "wsl" ]; then
    wsl_exec_n "cd \"$CORP_REPO_WSL\" && git -c 'safe.directory=*' $*"
  else
    wsl_exec_n "cd \"$CORP_REPO_WSL\" && \"$GIT_EXE_WSL\" $*" | tr -d '\r'
  fi
}

# corp_git_win <git args> — force Windows git via PowerShell. This is the ONLY
# engine for credentialed operations (push/pull/fetch): the Windows Credential
# Manager holds the Azure DevOps credentials.
corp_git_win() {
  win_ps "Set-Location '$CORP_REPO_WIN'; & git $* ; exit \$LASTEXITCODE"
}

# ---------------------------------------------------------------------------
# service probes (tunnel = Mac loopback; hairpin = WSL -> Tailscale IP, the
# only WSL->Windows path that works) and detached starters (Start-Process
# survives WSL session exit — verified).
# ---------------------------------------------------------------------------

http_up_mac()      { curl -s -o /dev/null -m "${2:-5}" "http://127.0.0.1:$1/"; }
http_up_hairpin()  { wsl_exec_n "curl -s -o /dev/null -m ${2:-5} http://$CORP_IP:$1/"; }
http_code_mac()    { curl -s -o /dev/null -m "${3:-10}" -w '%{http_code}' "http://127.0.0.1:$1${2:-/}" 2>/dev/null || true; }

pmi_health_mac() {
  curl -s -m 10 "http://127.0.0.1:$PMI_PORT/pmi/actuator/health" 2>/dev/null | grep -q '"status":"UP"'
}
pmi_health_hairpin() {
  wsl_exec_n "curl -s -m 10 http://$CORP_IP:$PMI_PORT/pmi/actuator/health" 2>/dev/null | grep -q '"status":"UP"'
}

start_dev_servers() {
  win_ps "Start-Process -WindowStyle Hidden -WorkingDirectory '$CORP_REPO_WIN' cmd -ArgumentList '/c','yarn dev:all > servers.log 2>&1'"
}

start_pmi() {
  win_ps "Start-Process -WindowStyle Hidden -WorkingDirectory '$PMI_DIR_WIN' cmd -ArgumentList '/c','start-pmi.bat > pmi-startup.log 2>&1'"
}

stop_port_windows() {
  win_ps "Get-NetTCPConnection -LocalPort $1 -State Listen -ErrorAction SilentlyContinue | ForEach-Object { Stop-Process -Id \$_.OwningProcess -Force -ErrorAction SilentlyContinue }"
}
