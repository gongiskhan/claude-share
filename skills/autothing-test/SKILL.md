---
name: autothing-test
description: Write a COMMITTED, re-runnable correctness test for the current change and run it, plus clean build/typecheck/lint — the objective correctness gate. The default is end-to-end THROUGH THE UI (Playwright / playwright-cli) plus unit tests; a CLI/TUI deliverable uses a committed driver + asciinema capture. In an autothing build a failure sends the slice back to autothing-implement (autothing owns the retry ceiling); standalone it just reports the findings. Use for "write and run tests for this change", "add a committed e2e test", or as the test gate of a build. NOT a one-off manual run (use /run or /verify) and NOT the cross-model test (use autothing-adversarial-test).
---

# autothing-test

The objective correctness gate — write a COMMITTED, re-runnable test for the current change and run it, plus a clean build/typecheck/lint. A standalone test-writer/runner, and the test gate of an autothing build.

## What "test" means here (committed, not ephemeral) — prefer e2e through the UI
A test that survives the run and catches regressions. **Default to end-to-end through the UI** — most projects have a UI, and exercising a change through the real UI is the truest proof (it even covers the backend/API a flow touches):
- **Web flow** → a spec file (Playwright / vitest / jest), or a committed **playwright-cli driver** that re-drives the flow and asserts where no runner ships. Drive the real UI; ephemeral `.playwright-cli/` logs are exploration, NOT the gate.
- **CLI/TUI deliverable** → a committed driver + an asciinema capture of the real flow.

Plus unit tests where they fit. **No committed re-runnable assertion ⇒ the change is not done.**

## Run + gates
Run the test and the objective gates — `tests`, `e2e` (where applicable), `typecheck`, `lint`, `build` — and capture each exit code. Respect the dev-server hazard in `~/.claude/skills/autothing/references/build-loop.md` ("Gate builds must not clobber a live dev server").

## Loop role + output
- **In an autothing build:** any non-zero gate or failing assertion **sends the slice back to `autothing-implement`** to fix (autothing owns the retry ceiling, default 5); re-run after each fix. Record the gate exits in the slice gate-status.
- **Standalone:** write + run the test and **report the findings** (pass/fail + exit codes + what failed); do not loop to fix unless asked.

Print in the lead context: `GATE test: <pass|fail> — tests:<exit> typecheck:<exit> lint:<exit> build:<exit> <summary>`. Distinct from `autothing-adversarial-test` (the CROSS-MODEL functional pass).
