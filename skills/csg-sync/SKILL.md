---
name: csg-sync
description: Push the Mac working tree of pnmui-monorepo to the corporate Windows machine for browser testing through the tunnel (webpack hot reload picks it up). Use when the user says "sync to corporate", "csg sync", "push my changes to the corp machine", "let me test this in the browser", or after editing files during a CSG remote-dev session.
---

# csg-sync

Run:

```bash
bash ~/.claude/skills/csg-sync/scripts/sync.sh
```

Flags:

| flag | meaning |
|---|---|
| `--force` | Mac wins over corporate drift (only after the user has seen the drift table and chosen "Mac wins") |
| `--no-watch` | skip the 60 s webpack-recompile watch |

The sync is Mac→corp, byte-verified, and never deletes anything implicitly
(deletions are computed, printed, and applied as an explicit list; excluded
files like cookies.txt never travel).

## On failure

Relay the catalog message verbatim. Most relevant:

| exit | meaning |
|---|---|
| 10/11/21 | tunnel / back-channel problem — same remediations as csg-setup |
| 13 | syncthing woke up on corporate — must be stopped first |
| 16 | corporate drift since last sync — show the user the per-file table and the two options: re-run csg-setup (corporate wins) or `csg-sync --force` (Mac wins). Do not pick for them. |
| 19 | post-push verification failed — safe to re-run; if it persists, something on the corporate side is interfering |

If it says "no sync state yet — run csg-setup first", run csg-setup.

## On success

Tell the user: how many files changed/new/deleted, which dev servers
recompiled (`[shell] [spcm] ...`), and that the change is testable at
`http://localhost:3002/` (refresh if HMR didn't apply).
