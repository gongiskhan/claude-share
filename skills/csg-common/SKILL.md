---
name: csg-common
description: INTERNAL LIBRARY for the CSG remote-dev workflow (csg-setup / csg-sync / csg-complete). Documentation only — do not invoke this skill directly; it has no entry point. Holds the shared bash libraries (lib/) and the daily-workflow README.
---

# csg-common — shared library (do not invoke)

This is not a runnable skill. It is the shared home for the CSG remote-dev
workflow that `csg-setup`, `csg-sync` and `csg-complete` source:

- `lib/env.sh` — all constants: machine IPs, repo paths (Mac + corporate
  WSL/Windows), PMI paths, spec-bundle dir, ports, ssh option set, state-dir
  layout under `<mac-repo>/.claude/csg-state/`.
- `lib/log.sh` — `log`/`warn`/`die` + the failure-message catalog. Catalog IDs
  double as exit codes (10–21); every message names the exact next manual action.
- `lib/remote.sh` — tunnel probe/triage, `wsl_exec` (back-channel ssh),
  `win_ps` (PowerShell via UTF-16LE base64 `-EncodedCommand` — no quoting
  tower), corp git engine (WSL git, Windows git.exe fallback; `corp_git_win`
  for credentialed push/pull), syncthing guard, service/PMI probes,
  detached Start-Process launchers.
- `lib/manifest.sh` — file universes and `sha\tpath` manifests on both
  machines, `manifest_diff`, ls-tree manifests; everything exclude-filtered
  consistently (see `csg-state/csg-excludes.txt`).
- `lib/rsyncw.sh` — openrsync pull/push wrappers (`-rltz`, `--files-from`,
  NEVER `--delete`) + explicit NUL-safe rm-by-list on both sides.
- `lib/gitbase.sh` — gc-proof tree snapshots at `refs/csg/*` via a temp
  GIT_INDEX_FILE, and the changed-paths → root-lint-script mapping.

The daily-workflow guide for humans lives in `README.md` next to this file.
If a user asks how the CSG remote workflow works, read that README and answer
from it.
