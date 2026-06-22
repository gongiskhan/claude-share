---
name: autothing-review
description: Code-review the current change or diff for correctness bugs and quality cleanups (reuse, simplification, efficiency) using Claude Code's built-in review mechanism (the code-review skill). In an autothing build it reviews the slice diff and real findings send the slice back to autothing-implement to fix; standalone it just reports the findings. Use for "review this code", "review my diff/PR", "code review before shipping", or as the same-model review gate inside a build. NOT the cross-model Codex review (use autothing-adversarial-review) and NOT a test runner (use autothing-test).
---

# autothing-review

Same-model (Claude) code review of the current change. The review gate of an autothing build, and a standalone code reviewer.

## What it runs
Invoke the built-in **`code-review`** skill on the current diff — it reviews for correctness bugs first, then reuse/simplification/efficiency cleanups, at the session effort. (`--comment` posts inline PR comments; `--fix` applies findings — use only when asked.)

If `code-review` is unavailable, run the equivalent yourself: read the diff (`git --no-pager diff <base>...HEAD` + uncommitted), and report **correctness bugs first**, then quality cleanups, each with `file:line` and a concrete fix. That is what the built-in does.

## Scope
- **In an autothing build:** review the SLICE diff only — capture `BASE=$(git rev-parse HEAD)` before the slice, review `git diff $BASE...HEAD` + uncommitted.
- **Standalone:** review the diff/PR/range the user names (default: uncommitted + last commit).

## Loop role + output
- **In an autothing build:** report findings; **real correctness findings send the slice back to `autothing-implement`** to fix (autothing owns the retry ceiling). Cheap quality nits are applied; larger ones are logged. Re-review after a fix.
- **Standalone:** report the findings and stop — do not auto-fix unless asked.

Print one line in the lead context: `GATE review: <clean|findings(n)> — <summary>`. In a build, fold the result into the slice gate-status. Distinct from `autothing-adversarial-review` (the CROSS-MODEL Codex review).
