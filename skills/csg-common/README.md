# CSG remote dev workflow — pnmui-monorepo from the Mac

Three Claude Code skills implement the daily loop for developing
`pnmui-monorepo` on this Mac while the runnable environment lives on the
corporate Windows machine: **csg-setup** (bring everything up + baseline),
**csg-sync** (push Mac edits for browser testing), **csg-complete**
(cursor-agent recreates the final change on corporate; push + Azure DevOps PR
only after explicit confirmation).

Authoritative environment findings: `REMOTE_DEV_FINDINGS.md` at the Mac repo
root (`/Users/ggomes/dev/pnmui-mon`).

## Topology

```
   Mac (100.108.210.116)                      Corporate Windows (100.120.116.31)
  ┌────────────────────────┐                 ┌─────────────────────────────────────┐
  │ Claude Code + editor   │                 │ Windows: repo checkout, node/yarn,  │
  │ repo: ~/dev/pnmui-mon  │                 │  webpack dev servers :3001-3007,    │
  │ browser:               │   reverse ssh   │  PMI :8080, git+CredMgr, az CLI,    │
  │  http://localhost:3002 │◄────tunnel──────│  cursor-agent                       │
  │                        │  (run in WSL)   │ WSL2 (NAT): sshd, rsync, autossh    │
  │ ssh -p 2223 localhost ─┼────────────────►│  hairpins to Windows via 100.120... │
  └────────────────────────┘   back-channel  └─────────────────────────────────────┘
```

- The tunnel forwards **the same port numbers** onto the Mac's loopback, so
  every hardcoded `http://localhost:<port>` URL (webpack `publicPath`, MFE
  remote entries, PMI properties) just works. Direct-IP mode is rejected —
  chunk loading breaks (findings §5). **pmi.properties needs NO changes in
  tunnel mode**; csg-setup only verifies it and repairs drift.
- `-R 2223:localhost:22` exposes WSL's sshd at Mac `localhost:2223` — the
  back-channel for rsync, remote git, and Windows control (PowerShell via
  interop).

## The one manual step (per corporate boot)

WSL has no systemd: sshd and the tunnel die on reboot/WSL shutdown. After each
corporate boot, in Windows Terminal → `wsl` (ideally inside `tmux`):

```bash
sudo service ssh start    # asks your sudo password

AUTOSSH_GATETIME=0 autossh -M 0 -N \
  -o ServerAliveInterval=15 -o ServerAliveCountMax=3 -o ExitOnForwardFailure=yes -o BatchMode=yes \
  -R 3001:100.120.116.31:3001 -R 3002:100.120.116.31:3002 -R 3003:100.120.116.31:3003 \
  -R 3004:100.120.116.31:3004 -R 3007:100.120.116.31:3007 -R 8080:100.120.116.31:8080 \
  -R 2223:localhost:22 \
  ggomes@100.108.210.116
```

Everything else is driven from the Mac.

## Daily workflow

```bash
bash ~/.claude/skills/csg-setup/scripts/setup.sh        # morning: env up, pull, baseline
# ... edit on the Mac with Claude Code ...
bash ~/.claude/skills/csg-sync/scripts/sync.sh          # push to corp; hot reload
# ... test at http://localhost:3002/ ...
bash ~/.claude/skills/csg-complete/scripts/complete.sh \
  --ticket 1202066 --desc "align numeric input sizing" --dry-run
# review the verification report, then confirm explicitly:
bash ~/.claude/skills/csg-complete/scripts/finalize.sh  # push + PR, prints URL
```

## Flags

| script | flag | meaning |
|---|---|---|
| setup.sh | `--overwrite-local` | discard unsynced Mac work; corporate wins |
| setup.sh | `--update-corp` | `git pull --ff-only origin main` on corporate first |
| setup.sh | `--skip-services` | skip dev-server/PMI startup + smoke |
| setup.sh | `--only <phase>` | re-run one phase (preflight/tunnel/backchannel/syncthing/corpstate/services/pmi/pull/baseline/smoke/summary) |
| sync.sh | `--force` | Mac wins over corporate drift (F16) |
| sync.sh | `--no-watch` | skip the recompile watch |
| complete.sh | `--dry-run` | stop after verification; nothing pushed; branch left on corporate |
| complete.sh | `--max-iters N` | cursor retry budget (default 3) |

## State dir & recovery

`/Users/ggomes/dev/pnmui-mon/.claude/csg-state/` (repo `.gitignore` covers
`.claude`, so it never syncs):

- `csg-excludes.txt` — paths that never sync and are filtered from every
  comparison. Defaults: `cookies.txt` (tracked, holds live session cookies —
  pre-existing hygiene issue), `REMOTE_DEV_FINDINGS.md`.
- `baseline.env` — `CORP_HEAD_SHA` + the gc-proof snapshot refs
  (`refs/csg/baseline` in the Mac repo).
- `manifests/` — `corp-last-sync.manifest`, `mac-last-push.manifest`
  (`sha<TAB>path`, sorted; drift detection + deletion lists).
- `cursor/` — full cursor-agent transcripts per ticket/iteration.
- `pmi-backups.log`, `sync.log`, `corp-git.env`, `tmp/`, `spec/`.

Recovery rules:

- **Re-baseline = re-run csg-setup.** Always safe; it refuses to clobber
  unsynced Mac work (F15) unless you pass `--overwrite-local`.
- **F16 (corporate drift)**: someone/something changed corp files since the
  last sync. `csg-setup` = corporate wins; `csg-sync --force` = Mac wins.
- **After a PR merges**: `csg-setup --update-corp --overwrite-local` starts the
  next session from the new main.
- A `--dry-run` (or failed) csg-complete leaves the work branch on corporate
  by design; re-running csg-complete resets it, or clean manually:
  `ssh -p 2223 ggomes@localhost` → `cd /mnt/c/Users/gomgon01/dev/pnmui-monorepo`
  → `git -c safe.directory='*' checkout -f main && git -c safe.directory='*' branch -D <branch>`.

## Limitations (known, verified live)

- **SMS/USSD MFE tiles won't load**: their `client.*.mfe.url` point at backend
  webservices :8298/:8293 that aren't running on corporate. SPCM/PMCS are fine.
- **Hot-reload watcher lag**: webpack on Windows notices rsync-over-WSL writes,
  but the event can lag the push by a minute or more (9P -> NTFS notification
  quirk). The csg-sync watch waits 150 s and is warn-only; an incremental
  rebuild is ~1 s once triggered. When in doubt, just refresh the browser.
- **MFE deep links after a full reload can render blank**
  (`?app=spcm&page=planDefinitions`): navigate in-app instead (sidebar ->
  SPCM -> Plan Definitions). In-app navigation is fully verified.
- **First MFE load through the tunnel is heavy**: dev-mode chunks are tens of
  MB and Tailscale may route via a DERP relay (~1.2 MB/s observed) — expect
  ~30-60 s for the first SPCM open of a session.
- **`yarn lint:*` cannot succeed in this repo right now** — no ESLint config
  is tracked anywhere (pre-existing). The csg-complete lint gate detects this
  exact condition, warns, and continues; any real lint findings still block.
- **Vite standalone ports** (5173/5174/5175/5177) are not tunneled; standalone
  mode needs findings §3 variants.
- **The Mac git never pushes.** All credentialed git + az operations run on
  corporate (Windows git + Credential Manager).
- Corporate commits made by cursor-agent carry the **repo-local gmail identity**
  (`goncalo.p.gomes@gmail.com`) — fix the repo-local `user.email` on corporate
  if unintended.
- **Self-merge policy is inferred, not proven** (8/8 recent PRs self-created
  and completed); if a reviewer policy appears on main, add a human-merge step.
- Tunnel + WSL sshd die on corporate reboot — redo the one manual step.
- `cookies.txt` is tracked in the repo with captured session cookies — worth a
  separate normal ticket (`git rm --cached` + gitignore). The skills pin it in
  the excludes so it never syncs and never enters comparisons.

## Troubleshooting = the failure catalog

Every failure exits with a catalog code (10–21) and a message naming the exact
next manual action: 10 tunnel down (prints the full tunnel command), 11
back-channel auth (pubkey one-liner), 12 Mac port collision, 13 syncthing
running, 14 corporate repo dirty/not on main, 15 unsynced Mac work, 16
corporate drift, 17 cursor verification exhausted (nothing pushed), 18 PMI
health timeout, 19 spec/manifest integrity, 20 cursor canary failed, 21 host
key mismatch on 2223. The messages live in `lib/log.sh`.
