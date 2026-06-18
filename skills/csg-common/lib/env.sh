#!/bin/bash
# csg-common/lib/env.sh — every constant for the CSG remote-dev workflow.
# Authoritative source of these values: REMOTE_DEV_FINDINGS.md at the Mac repo root.
# bash 3.2 compatible (macOS /bin/bash). Source this before the other lib files.

# Stable, byte-wise sort/comm/join everywhere — manifests depend on it.
export LC_ALL=C

TAB=$'\t'

# --- machines (Tailscale) ---
CORP_IP="100.120.116.31"     # corporate Windows machine (WSL2 inside)
MAC_IP="100.108.210.116"     # this Mac

# --- repos & paths ---
MAC_REPO="/Users/ggomes/dev/pnmui-mon"
CORP_REPO_WSL="/mnt/c/Users/gomgon01/dev/pnmui-monorepo"
CORP_REPO_WIN='C:\Users\gomgon01\dev\pnmui-monorepo'
PMI_DIR_WSL="/mnt/c/Users/gomgon01/dev/ui-pmi"
PMI_DIR_WIN='C:\Users\gomgon01\dev\ui-pmi'
PMI_PROPS_WSL="/mnt/c/tango/config/pmi/pmi.properties"
PMI_PROPS_WIN='C:\tango\config\pmi\pmi.properties'
PMI_LOG_WSL="$PMI_DIR_WSL/pmi-startup.log"
SPEC_DIR_WSL="/mnt/c/Users/gomgon01/dev/csg-spec"
SPEC_DIR_WIN='C:\Users\gomgon01\dev\csg-spec'
SERVERS_LOG_WSL="$CORP_REPO_WSL/servers.log"
GIT_EXE_WSL="/mnt/c/Program Files/Git/cmd/git.exe"
POWERSHELL_WSL="/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"

# --- ports ---
DEV_PORTS="3001 3002 3003 3004 3007"   # webpack dev servers (shell :3002 + 4 MFEs)
PMI_PORT=8080
BACKCHANNEL_PORT=2223                  # reverse-forwarded WSL sshd
ALL_TUNNEL_PORTS="3001 3002 3003 3004 3007 8080 2223"
BACKCHANNEL_USER="ggomes"              # WSL user (Windows user is gomgon01)

# --- Azure DevOps ---
ADO_ORG="https://dev.azure.com/CSGDevOpsAutomation"
ADO_PROJECT="RMDM-PNM-Dev"
ADO_REPO="pnmui-monorepo"

# --- ssh: one option set for every back-channel call. ControlMaster multiplexing
# because setup/complete make dozens of calls over the same 2223 forward. ---
SSH_OPTS=(
  -o BatchMode=yes
  -o StrictHostKeyChecking=accept-new
  -o ConnectTimeout=10
  -o ServerAliveInterval=15
  -o ServerAliveCountMax=3
  -o ControlMaster=auto
  -o "ControlPath=$HOME/.ssh/csg-cm-%r-%h-%p"
  -o ControlPersist=120
)
# Same options as a flat string for rsync -e / scp wrappers (no spaces inside any value).
SSH_OPTS_STR="-o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -o ServerAliveInterval=15 -o ServerAliveCountMax=3 -o ControlMaster=auto -o ControlPath=$HOME/.ssh/csg-cm-%r-%h-%p -o ControlPersist=120"

# --- repo-local state (repo .gitignore covers .claude → never syncs anywhere) ---
STATE_DIR="$MAC_REPO/.claude/csg-state"
EXCLUDES_FILE="$STATE_DIR/csg-excludes.txt"
BASELINE_ENV="$STATE_DIR/baseline.env"
CORP_GIT_ENV="$STATE_DIR/corp-git.env"
MANIFEST_DIR="$STATE_DIR/manifests"
SPEC_STATE_DIR="$STATE_DIR/spec"
CURSOR_LOG_DIR="$STATE_DIR/cursor"
TMP_DIR="$STATE_DIR/tmp"
SYNC_LOG="$STATE_DIR/sync.log"
PMI_BACKUPS_LOG="$STATE_DIR/pmi-backups.log"
PENDING_FINALIZE_ENV="$STATE_DIR/pending-finalize.env"
CANARY_OK_MARKER="$STATE_DIR/cursor-canary.ok"

CORP_LAST_SYNC_MANIFEST="$MANIFEST_DIR/corp-last-sync.manifest"
MAC_LAST_PUSH_MANIFEST="$MANIFEST_DIR/mac-last-push.manifest"

ensure_state_dir() {
  mkdir -p "$STATE_DIR" "$MANIFEST_DIR" "$SPEC_STATE_DIR" "$CURSOR_LOG_DIR" "$TMP_DIR"
  if [ ! -f "$EXCLUDES_FILE" ]; then
    # Default excludes. cookies.txt is TRACKED in git at the shared baseline commit
    # (pre-existing hygiene issue) but holds live session cookies — it must never
    # ride a sync in either direction, and every manifest comparison filters it
    # consistently on both sides.
    cat > "$EXCLUDES_FILE" <<'EOF'
cookies.txt
REMOTE_DEV_FINDINGS.md
CSG-SETUP.md
EOF
  fi
}

csg_mktemp() { mktemp "$TMP_DIR/csg.XXXXXX"; }

# kebab "Some Desc Here" → some-desc-here (for branch names)
kebab() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//; s/-*$//'
}

# Escape a value for embedding inside a PowerShell single-quoted string.
ps_squote() { printf '%s' "$1" | sed "s/'/''/g"; }

# wait_for <total-secs> <interval-secs> <label> <cmd> [args...]
# Polls <cmd> until it succeeds or the deadline passes. Returns 0/1.
wait_for() {
  local total="$1" interval="$2" label="$3" deadline
  shift 3
  deadline=$(( $(date +%s) + total ))
  while [ "$(date +%s)" -lt "$deadline" ]; do
    if "$@" >/dev/null 2>&1; then return 0; fi
    sleep "$interval"
  done
  return 1
}
