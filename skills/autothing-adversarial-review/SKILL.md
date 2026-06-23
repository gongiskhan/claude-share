---
name: autothing-adversarial-review
description: Adversarial CROSS-MODEL code review — have OpenAI Codex (via the local codex CLI, serialized) try to break the current diff and return a structured verdict, iterating with fixes until both models agree (approve). In an autothing build, real findings go back to autothing-implement; standalone, report the verdict and findings. Use for "have codex review this", "adversarial review", "second-model/cross-model review of this change", or as the cross-model review gate of a build. Serializes every codex call (concurrent calls revoke the shared token). NOT Claude's own review (use autothing-review).
---

# autothing-adversarial-review

Cross-model adversarial review — a SECOND model (OpenAI Codex, via the `codex` CLI) tries to break the current diff. The cross-model review gate of an autothing build, and a standalone second-opinion reviewer. Full operational rules, schema, loop ceiling, appeal valve, and durable-record shape: `~/.claude/skills/autothing/references/codex-verification.md` (section 3A).

## Hard rules (empirically required — do not skip)
- **Serialize every `codex exec`** — one at a time, run-wide. Concurrent codex processes rotate and REVOKE the shared OAuth token and kill the gate.
- **Always redirect stdin from `/dev/null`** — `codex exec` otherwise blocks forever on "Reading additional input from stdin...". Read the result from `--output-last-message <file>`; never pipe stdout into tail/head.
- **Preflight once:** `codex --version`; confirm auth with `codex exec -m gpt-5.4 -c model_reasoning_effort=low 'reply OK' </dev/null`. Missing binary → self-unblock (`npm i -g @openai/codex`). A genuine `codex login` failure is an **external blocker** for this gate — never silently skip and report approve.
- **Pin model + effort (cost-aware):** always pass `-m gpt-5.4 -c model_reasoning_effort=low` (an unpinned call inherits the account default, which can silently run xhigh — the dominant token burn). Escalate effort to `medium` (keep the model `gpt-5.4`) only when the low pass surfaces a plausible material finding, the change touches **auth/tenant/data/security/payments/migrations**, or the first output is low-confidence/invalid. Full policy: `~/.claude/skills/autothing/references/codex-verification.md`.

## The review (read-only), per round
```bash
BASE=<slice base sha>   # capture BEFORE editing, so the review sees only this change
EFFORT=low   # -> medium on escalation (model stays gpt-5.4)
DIFFSTAT="$(git --no-pager diff <BASE>...HEAD --shortstat 2>/dev/null | sed 's/^[[:space:]]*//')"
echo "CODEX CALL: gate=3A-review model=gpt-5.4 effort=${EFFORT} round=<round> diff=[${DIFFSTAT:-no committed diff}]"
codex exec -s read-only -m gpt-5.4 -c model_reasoning_effort="${EFFORT}" \
  --skip-git-repo-check -C "<projectDir>" \
  --output-schema "$HOME/.claude/skills/autothing/assets/codex-review.schema.json" \
  --output-last-message "<runDir>/codex-review-r<round>.json" \
  "ADVERSARIAL review of this change. Inspect ONLY its diff: run \`git --no-pager diff <BASE>...HEAD\` and \`git --no-pager diff\`. Acceptance: <acceptance>. Find the strongest MATERIAL reasons it should not ship (auth/tenant isolation, data loss, rollback/idempotency, races, empty/null/timeout paths, schema/version skew, observability gaps). Return ONLY JSON per schema. verdict=approve only if no material finding holds; else needs-attention with grounded findings." </dev/null
```
Read the JSON (`verdict`, `findings[]`):
- **approve** → both models agree; the gate passes.
- **needs-attention** → triage each finding: real & material → fix; demonstrable false positive → a one-line rebuttal (`file:line` + why it does not apply).
- **Ceiling 3 rounds**, re-reviewing after each fix. Still real-and-unfixed after 3 → not done (keep fixing within the slice ceiling, or block via the genuine-external-blocker path). All remaining rebutted → `approve-with-override` (record the rebuttals; this is NOT a clean approve and keeps a build's global gate out of `passed`).

## Loop role + output
- **In an autothing build:** real findings send the slice back to `autothing-implement` (consumes the slice retry ceiling); re-review after each fix. Record `codexReview` in the slice gate-status.
- **Standalone:** run one or more rounds and report the verdict + findings; do not auto-fix unless asked.

Print in the lead context, BEFORE the call the `CODEX CALL: gate=3A-review model=… effort=… round=… diff=[…]` line, and after it the verdict: `GATE codex-review: <approve|approve-with-override|needs-attention(r<n>)> — <summary>`.
