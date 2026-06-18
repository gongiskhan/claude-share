---
name: csg-setup
description: Bring the CSG remote dev environment up for pnmui-monorepo — verify the reverse tunnel + back-channel to the corporate Windows machine, guard against syncthing, start the webpack dev servers and PMI, verify pmi.properties, pull a clean corporate copy onto the Mac, and record the session baseline. Use when the user says "set up remote dev", "csg setup", "bring up the corporate dev environment", "start my pnmui session", or at the start of a pnmui-monorepo work day.
---

# csg-setup

Run:

```bash
bash ~/.claude/skills/csg-setup/scripts/setup.sh
```

Flags (use only when the situation calls for them, and tell the user why):

| flag | meaning |
|---|---|
| `--overwrite-local` | discard unsynced Mac work and take corporate's tree (only after the user explicitly accepts losing the listed files) |
| `--update-corp` | `git pull --ff-only origin main` on corporate before baselining (use after a PR merged) |
| `--skip-services` | skip dev-server/PMI startup and the smoke test |
| `--only <phase>` | re-run one phase: preflight tunnel backchannel syncthing corpstate services pmi pull baseline smoke summary |

The script is idempotent — re-running it when everything is up is a fast
all-green no-op. A cold start can take minutes (5 webpack builds + Spring Boot).

## On failure

The script prints a catalog message (exit codes 10–21) that names the exact
next manual action — **relay it to the user verbatim**, especially:

| exit | meaning |
|---|---|
| 10 | tunnel down — the message contains the exact WSL `sudo service ssh start` + autossh command the user must run on the corporate machine (the one manual step of the whole workflow) |
| 11 | back-channel auth refused — message contains the one-liner to authorize the Mac key |
| 12 | Mac port collision — lists port/pid/cmd to kill before the tunnel can bind |
| 13 | syncthing running on corporate — message has stop/disable instructions |
| 14 | corporate repo dirty / not on main — must be fixed on corporate |
| 15 | Mac has unsynced local work — list shown; user chooses: finish the cycle, or re-run with `--overwrite-local` |
| 18 | PMI didn't come up — message has the log-tail command |
| 19 | manifest integrity error — safe to re-run after reading the detail |

Do not try to work around a failure by hand-running parts of the flow; fix the
named cause and re-run (phases are idempotent).

## On success

Summarize for the user: browser URL `http://localhost:3002/`, the corp HEAD
sha that was baselined, what the pull changed (counts), and the standing
limitation that the SMS/USSD MFE tiles won't load (their backends :8298/:8293
aren't running on corporate — SPCM/PMCS are fine).
