---
name: autothing-adversarial-test
description: Independent CROSS-MODEL functional test — have OpenAI Codex (via the local codex CLI, serialized) drive the running app/feature through the acceptance with its OWN test pass that never saw Claude's test, returning pass or fail with what it observed. In an autothing build a failure sends the slice back to autothing-implement; standalone, report what Codex saw. Use for "have codex test this", "independent functional test", "second-model/cross-model test", or as the cross-model test gate of a build. Serializes every codex call. NOT Claude's own test (use autothing-test).
---

# autothing-adversarial-test

Cross-model functional test — a SECOND model (OpenAI Codex, via the `codex` CLI) independently drives the running app/feature through the acceptance with its OWN pass that never saw Claude's committed test, so it catches "the code and its test share the same wrong assumption." The cross-model test gate of an autothing build, and a standalone second-opinion tester. Full rules + schema: `~/.claude/skills/autothing/references/codex-verification.md` (section 3B).

## Hard rules (empirically required)
- **Serialize every `codex exec`** — one at a time, run-wide. Concurrent calls revoke the shared OAuth token.
- **Redirect stdin from `/dev/null`**; read the result from `--output-last-message`, never via a pipe.
- The dev server must be up (from `autothing-test` / `/run`, known port).

## The independent pass
```bash
codex exec -s workspace-write -c sandbox_workspace_write.network_access=true \
  --skip-git-repo-check -C "<projectDir>" \
  --output-schema "$HOME/.claude/skills/autothing/assets/codex-pwtest.schema.json" \
  --output-last-message "<runDir>/codex-pwtest.json" \
  "Use your playwright skill to INDEPENDENTLY test the running app at <devUrl> for this change. Acceptance: <acceptance>. Open the page, snapshot for refs, exercise the flow (click/fill/navigate), re-snapshot, and ASSERT the acceptance actually held. Watch for console errors. Return ONLY JSON per schema: result=pass only if every assertion held with no console error, else fail with what you saw." </dev/null
```
Browser automation needs localhost network + a browser process; the flags above are the principled choice on a trusted machine. If the browser cannot reach localhost in your environment, escalate THAT one call to `-s danger-full-access` (still non-interactive). Read the JSON (`result`, `failures[]`).

## Loop role + output
- **In an autothing build:** `fail` with a real defect **sends the slice back to `autothing-implement`** (consumes the slice retry ceiling); re-run after each fix. A flaky/env failure (not a product defect) is re-run, not counted as a fix-attempt. Record `codexPwTest` in the slice gate-status.
- **Standalone:** run the pass and report `pass|fail` + what Codex saw.

Print in the lead context: `GATE codex-pwtest: <pass|fail> — <summary>`.
