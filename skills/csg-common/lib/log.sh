#!/bin/bash
# csg-common/lib/log.sh — log/warn/die + the failure-message catalog.
# Catalog IDs double as exit codes. Every message names the exact next manual action.
# Requires env.sh sourced first.

C_RED=$'\033[31m'; C_YEL=$'\033[33m'; C_GRN=$'\033[32m'; C_OFF=$'\033[0m'
if [ ! -t 2 ]; then C_RED=""; C_YEL=""; C_GRN=""; C_OFF=""; fi

log()  { printf '%s[csg]%s %s\n' "$C_GRN" "$C_OFF" "$*" >&2; }
warn() { printf '%s[csg WARN]%s %s\n' "$C_YEL" "$C_OFF" "$*" >&2; }

# die "message" [exit-code]
die() {
  printf '%s[csg FAIL]%s %s\n' "$C_RED" "$C_OFF" "$1" >&2
  exit "${2:-1}"
}

# die_catalog <code> [extra detail]
# Prints the canonical failure message for <code>, then optional detail, exits <code>.
die_catalog() {
  local code="$1"; shift || true
  printf '\n%s[csg FAIL F%s]%s\n' "$C_RED" "$code" "$C_OFF" >&2
  catalog_message "$code" >&2
  if [ "$#" -gt 0 ] && [ -n "$*" ]; then
    printf -- '\n--- detail ---\n%s\n' "$*" >&2
  fi
  exit "$code"
}

catalog_message() {
  case "$1" in
    10) cat <<'EOF'
TUNNEL DOWN — the reverse tunnel from corporate WSL is not up (or is incomplete).
On the corporate Windows machine, open Windows Terminal -> type `wsl`, then run:

  1) one-time per boot (asks your sudo password):
       sudo service ssh start

  2) the tunnel itself (ideally inside tmux so it survives the terminal):
       AUTOSSH_GATETIME=0 autossh -M 0 -N \
         -o ServerAliveInterval=15 -o ServerAliveCountMax=3 -o ExitOnForwardFailure=yes -o BatchMode=yes \
         -R 3001:100.120.116.31:3001 -R 3002:100.120.116.31:3002 -R 3003:100.120.116.31:3003 \
         -R 3004:100.120.116.31:3004 -R 3007:100.120.116.31:3007 -R 8080:100.120.116.31:8080 \
         -R 2223:localhost:22 \
         ggomes@100.108.210.116

Then re-run csg-setup.
EOF
    ;;
    11) cat <<'EOF'
BACK-CHANNEL AUTH REFUSED — port 2223 answers but the Mac's key is not authorized
in corporate WSL. On the corporate machine, inside WSL, run this one-liner (it
fetches the Mac's public key over the already-working WSL->Mac direction and
authorizes it):

  ssh ggomes@100.108.210.116 'cat ~/.ssh/id_ed25519.pub' >> ~/.ssh/authorized_keys

Then re-run csg-setup.
EOF
    ;;
    12) cat <<'EOF'
MAC PORT COLLISION — the tunnel is down, and something on this Mac is already
listening on one or more of the ports the tunnel must bind (3001-3004, 3007,
8080, 2223). With ExitOnForwardFailure=yes the tunnel will DIE on connect if any
-R bind fails. Stop the listed processes (kill <pid>), then start the tunnel
(see failure F10 for the exact command) and re-run csg-setup.
EOF
    ;;
    13) cat <<'EOF'
SYNCTHING IS RUNNING on the corporate machine. It is configured to sync the
pnmui-monorepo tree and will fight csg-sync/rsync for the same files.
Stop it via the back-channel or at the machine:

  powershell: Stop-Process -Name syncthing -Force

Disable autostart: check shell:startup (Win+R -> shell:startup) and
HKCU\Software\Microsoft\Windows\CurrentVersion\Run for a Syncthing entry and
remove it. Then re-run.
EOF
    ;;
    14) cat <<'EOF'
CORPORATE REPO NOT CLEAN / NOT ON main — the corporate checkout has tracked
modifications or sits on the wrong branch. csg-setup refuses to baseline from a
dirty tree. Inspect over the back-channel:

  ssh -p 2223 ggomes@localhost
  cd /mnt/c/Users/gomgon01/dev/pnmui-monorepo && git -c safe.directory='*' status

Commit/stash/restore as appropriate and get on main, then re-run csg-setup.
(If a previous csg-complete left a work branch there, `git checkout -f main`
and delete the branch once you no longer need it.)
EOF
    ;;
    15) cat <<'EOF'
MAC HAS UNSYNCED LOCAL WORK — your Mac working tree differs from the session
baseline (or from HEAD, if no baseline exists yet). Pulling now would overwrite
that work with the corporate tree. Either finish the current cycle first
(csg-sync to push, csg-complete to land it), or re-run with --overwrite-local
to deliberately discard the listed local differences and take corporate's tree.
EOF
    ;;
    16) cat <<'EOF'
CORPORATE DRIFT — files on the corporate machine changed since the last sync
(see the per-file table below). Two ways out:
  - corporate wins: re-run csg-setup (pulls corporate's tree, re-baselines)
  - Mac wins:       re-run csg-sync --force (overwrites corporate's copies)
EOF
    ;;
    17) cat <<'EOF'
CURSOR VERIFICATION EXHAUSTED — cursor-agent could not reproduce the change set
exactly within the allowed iterations. NOTHING was pushed. The corporate repo is
left on the work branch for inspection. See the residual table and the
transcripts below, then either fix by hand over the back-channel or re-run
csg-complete (it resets corporate and starts over).
EOF
    ;;
    18) cat <<'EOF'
PMI HEALTH TIMEOUT — PMI did not report {"status":"UP"} within the wait window.
Check the startup log over the back-channel:

  ssh -p 2223 ggomes@localhost 'tail -n 80 /mnt/c/Users/gomgon01/dev/ui-pmi/pmi-startup.log'

Fix whatever it complains about (port, MySQL, properties), then re-run.
EOF
    ;;
    19) cat <<'EOF'
SPEC / MANIFEST INTEGRITY ERROR — an internal consistency check failed (manifest
mismatch after a transfer, corrupt spec bundle, or a tree that should match but
does not). This is a stop-the-line error: nothing destructive proceeds. Read the
detail below; re-running the failing skill is safe.
EOF
    ;;
    20) cat <<'EOF'
CURSOR CANARY FAILED — cursor-agent could not demonstrably run a shell command
in headless mode (the one capability the findings could not verify). csg-complete
will not hand it the real change until this works. Check manually over the
back-channel:

  ssh -p 2223 ggomes@localhost
  /mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -NoProfile -Command \
    "Set-Location 'C:\Users\gomgon01\dev\pnmui-monorepo'; cursor-agent -p --force --trust --output-format text 'Run git rev-parse HEAD and print the output.'"

If cursor-agent asks for login or errors, fix that on the corporate machine.
EOF
    ;;
    21) cat <<'EOF'
HOST KEY MISMATCH on the back-channel — the key presented at localhost:2223
changed (WSL reinstalled, or something else answered on 2223). If you trust the
change, clear the old key and re-run:

  ssh-keygen -R '[localhost]:2223'
EOF
    ;;
    *) printf 'unknown failure code %s\n' "$1" ;;
  esac
}
