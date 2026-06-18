---
name: csg-complete
description: Complete a pnmui-monorepo ticket via the corporate machine — cursor-agent (the sanctioned tool) headlessly recreates the Mac change set on corporate, branches, commits and is byte-verified; push + Azure DevOps PR happen only after the user explicitly confirms. Use when the user says "complete the ticket", "csg complete", "make the PR for this", "land this change", or "finish ticket <number>".
---

# csg-complete

## Before running — ask the user (mandatory)

1. **Ticket number** (numeric, e.g. `1202066`).
2. **Short description** (becomes the branch `spcm-<ticket>-<kebab-desc>` and
   the commit/PR title `#<ticket> SPCM-UI: <desc>`).

If the user already stated both, confirm your reading of them; do not guess.
Suggest `--dry-run` for the first run of a session.

```bash
bash ~/.claude/skills/csg-complete/scripts/complete.sh \
  --ticket <N> --desc "<short description>" [--dry-run] [--max-iters 3]
```

What it does: checks preconditions (tunnel, syncthing, baseline, corp==Mac
sync-current, a one-time cursor-agent shell-exec canary), builds a byte-exact
change-spec bundle, resets corporate to the session baseline, has cursor-agent
recreate the change (copy files byte-for-byte, branch, lint, commit), verifies
the corporate HEAD tree against the expected manifest (retrying up to
`--max-iters`), then re-runs the mapped `yarn lint:*` itself as the gate.
**It never pushes.**

## Finalize — HARD GATE

`finalize.sh` pushes the branch and opens the Azure DevOps PR. **Never run it
unprompted.** Only run it after the user has seen the csg-complete verification
report **and explicitly confirms in this conversation** that they want to push
and open the PR. `--dry-run` output, silence, or a general "looks good" about
the code itself does not count — ask plainly: "Push the branch and open the
PR?" and wait for a yes.

```bash
bash ~/.claude/skills/csg-complete/scripts/finalize.sh
```

On success it prints the PR URL — give it to the user.

## On failure

Relay catalog messages verbatim. Most relevant:

| exit | meaning |
|---|---|
| 10/11/13/21 | tunnel / syncthing problems — same remediations as csg-setup |
| 17 | cursor could not reproduce the change set within max-iters — show the residual table + transcript paths; nothing was pushed; corporate is left on the branch for inspection |
| 19 | spec/manifest integrity error — safe to re-run after reading the detail |
| 20 | cursor canary failed — headless shell-exec unproven; message has the manual check command |

A "run csg-sync first" message means the Mac and corporate trees differ —
run csg-sync, then retry.

## On success

Summarize: branch name, the verified commit (`git log -1 --oneline` output is
in the report), that the tree check was byte-exact, lint-gate results,
transcript locations — and that nothing has been pushed yet. For `--dry-run`,
also mention the leftover branch on corporate and how it gets cleaned up
(re-running csg-complete resets it).
