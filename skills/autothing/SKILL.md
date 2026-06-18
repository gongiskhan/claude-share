---
name: autothing
description: Set up and then autonomously build a web project (NEW or EXISTING) to a hard quality bar with self-verified video evidence. EXPLICIT-INVOCATION ONLY — run when the operator launches an unattended build with /effort ultracode, auto mode, and an active /goal. Idempotently bootstraps a per-project foundation (lean root CLAUDE.md + routing index, living /docs, area-skills under the project's .claude/skills/), plans slices in docs/FLOW_PLAN.md, then builds each slice through gates — vision-first exploration, Playwright + unit tests written AFTER exploring (the correctness gate), clean build/typecheck/lint, cross-model verification (an OpenAI Codex adversarial-review loop that iterates until both models agree + an independent Codex Playwright test pass), a design audit, and a self-verified walkthrough evidence video — writing durable gate-status + evidence-index files the /goal evaluator can confirm. Invoke for "set up and build this project", "autonomously implement to done with proof", or to resume such a build. Delegates research, prototype, run/verify, video, and design audit to existing skills; never fakes a gate.
disable-model-invocation: true
---

# autothing

Orchestrates an unattended, gated build of a web project and proves each slice with a self-verified video. This skill is USER-scope; the foundation it writes is PROJECT-scope (inside the target repo). The `walkthrough` skill is SEPARATE — call it, never rebuild it.

## Operating assumptions (the operator sets these; autothing cannot set session switches)
- Launched under **/effort ultracode + auto mode + an active /goal** whose condition is the global gate (including "a self-verified evidence video exists for every slice") plus a turn cap.
- autothing **cannot set `/goal` itself** — no Claude Code mechanism lets a skill set a session goal — so its FIRST output is the exact `/goal` line for the operator to paste (see *On invocation* below). `/effort` and auto mode are session toggles the operator flips once.
- **Parallelism (optional, operator-set):** if `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` is set, prefer **agent teams** for parallel slice implementation; otherwise use **dynamic workflows**. autothing cannot enable that env var itself. See the **`parallel-work`** skill.
- Therefore behave **fully autonomously**: never pause for approval, never ask the user, fix forward, log blockers and continue.
- **Trade-off (noted):** no `allowed-tools` restriction — it both sets up and builds, so it may use any tool. That is why it is explicit-invocation-only and operator-gated.

## Owns vs delegates
- **Owns:** slice planning (Phase 2), the gated build loop (including orchestration of the Codex cross-model gate), and durable evidence (gate-status + evidence-index).
- **Delegates (do not reimplement):** foundation detect + scaffold → **`project-foundation`**; how to parallelize → **`parallel-work`**; non-UI automation slices → **`automation-testing`**; cross-model adversarial review + independent second test pass → the **`codex` CLI** (OpenAI Codex + its `playwright` skill) per `references/codex-verification.md`; research → `deep-research`; prototype/design tokens → `frontend-design`, `huashu-design`; run/verify → `/run`, `/verify`; per-slice evidence video → `walkthrough`; design audit → `frontend-design`, `polish-ui`, `huashu-design`.

## Workflow

### On invocation — FIRST, print the operator handoff
You cannot set `/goal` yourself, so before any work print the one line the operator pastes to run you unattended. Fill `<project>` from the repo; pick a turn cap (default **250**; scale to ≈20–30 turns × expected slices for large builds). Print exactly:

```
─── OPERATOR: to run me unattended, set /effort ultracode + auto mode, then paste this one line ───
/goal autothing has printed "GLOBAL GATE: passed" for <project> with buildable-remaining 0 and every slice video verified — OR it has printed "GLOBAL GATE: completed-with-blockers" in which buildable-remaining is 0 AND every listed blocker names an external cause and the exact remediation command that failed. A completed-with-blockers verdict with any buildable slice still open, or any blocker lacking a failed-remediation command, does NOT satisfy this goal. Stop after 250 turns regardless.
───────────────────────────────────────────────────────────────────────────────
```

Then continue to Phase 0 immediately — do not wait for the operator. (The `/goal` they paste keeps the session taking turns until you print the `GLOBAL GATE:` verdict; its evaluator reads only the transcript, which is why that verdict is printed, not just written to file.)

### Phase 0 — Detect (read-only)
Invoke the **`project-foundation`** skill's detect step. It produces a gap list (`present | missing | partial` per manifest element) + a role map for existing docs + any refresh recommendations. **Detection never edits.**

### Phase 1 — Bootstrap the gaps ONLY (a HARD prerequisite for Phase 3)
Invoke the **`project-foundation`** skill to generate ONLY what Phase 0 marked missing/partial — it owns the manifest, `git init`, the non-clobber rule, the /docs + lean `CLAUDE.md` + area-skill generation (and carries those assets). autothing layers the build-specific gates on top:
- **Do not enter Phase 3 until the foundation manifest is satisfied or each missing item is logged in `docs/decisions.md` with a reason** — a build will be tempted to skip ahead to the app; do not.
- Area skills are NOT optional: they are what parallel teammates/workers load (they don't inherit the lead's context).
- Confirm `/run` + `/verify` resolve and the dev command/port are known; ensure `walkthrough`'s preflight passes (`brew install asciinema agg` on macOS if missing).
- Refresh/slim recommendations go to `docs/autothing/REFRESH-RECOMMENDATIONS.md`; never rewrite an existing canonical file.

### Phase 2 — Plan
Write/update `docs/FLOW_PLAN.md` (`assets/docs/FLOW_PLAN.md`): slices with id, title, kind (`ui | automation | mixed`), route, parallel group, acceptance, status. If it exists and is current, reuse it.

### Phase 3 — Build loop
Per `references/build-loop.md`. **Resume from durable files first** (FLOW_PLAN + gate-status + evidence-index), then for each non-done slice: explore (vision-first) → **write a COMMITTED, re-runnable test** + run it → objective gates (tests/e2e/typecheck/lint/build exit 0) → **cross-model verification (Codex adversarial-review loop iterating until both models agree + an independent Codex Playwright pass; `references/codex-verification.md`)** → design audit → `walkthrough` evidence → write `gate-status.json` + upsert `evidence-index.json`. Bounded retry **5**, fix-forward, log-and-continue. **Parallelize by default** where slices own disjoint files — **agent teams when enabled, else dynamic workflows** — and serialize only the shared runtime (one dev-serve / bundle / recorder). Decompose at plan time to EARN parallelism; log the parallel-vs-serial choice. See the **`parallel-work`** skill. Automation slices use the **`automation-testing`** skill. **Before the first parallel batch, preflight the mechanism:** probe once that agent-team creation does NOT raise an approval prompt under auto mode (a trivial throwaway team that proceeds, or the known approval behavior); if it would block a headless run, fall back to dynamic workflows for the whole run — an approval prompt that stalls unattended is itself a silent killer of autonomy.

### Phase 4 — Global gate + handover
Per `references/build-loop.md`. **A verdict line MAY NOT be printed while `buildable-remaining > 0`** — `buildable-remaining` = count of slices whose status is neither `passed` nor `blocked` (and `blocked` only counts when it carries the attempted-remediation evidence from the non-negotiables). If it is > 0, the run returns to the per-slice loop and builds the next buildable slice. Decide the terminal state and write `globalGate.status` to `evidence-index.json`:
- **`passed`** only when **buildable-remaining == 0**, zero blockers, full e2e + `/verify` + build/typecheck/lint exit 0, **every slice has a clean Codex `approve` + Codex Playwright `pass`** (two-model agreement), the design audit is clean, AND **every slice's video is `verified`** (matching the `/goal` condition).
- **`completed-with-blockers`** legitimate ONLY when **buildable-remaining == 0** AND ≥1 slice is `blocked` with a named external cause + the exact remediation command that failed. (A `failed-but-unblocking` video is recorded evidence but is NOT self-verified, so it keeps the gate out of `passed`.)

Never repeat failed work unproductively, but ALWAYS continue while any buildable (non-blocked) slice remains. The verdict is printed only when buildable work is exhausted — reaching the turn cap with buildable work left is a failure of the loop, not a stop condition. Never fake `passed`.

Then, in order: **(1)** print the handover as prose — stack + why, install/invoke, evidence-gallery URL, an explicit enumeration of blockers (each with its external cause + failed remediation command), known limits; **(2)** as the LAST action, print `GLOBAL GATE: <status> — <checklist>`. The handover comes first because the verdict line is the completion signal: the `/goal` evaluator clears on it and the session stops, so nothing after it runs. Don't put an assertive `GLOBAL GATE:` line in the handover. (The same token in the invocation handoff is a quoted target, not a verdict; the evaluator distinguishes the two.)

## Durable markers — the contract
Every gate (objective AND subjective) leaves **two** traces:
- **A durable file** — so the build resumes after compaction and the human can inspect it:
  - per slice → `docs/autothing/slices/<slice>/gate-status.json` (schema: `assets/gate-status.example.json`)
  - per project → `docs/autothing/evidence-index.json` (schema: `assets/evidence-index.example.json`)
- **A printed line in the transcript** — because the `/goal` evaluator is a small fast model that reads ONLY the conversation; it does not open files or run commands. Print each gate's exit code inline (`GATE <name>: exit <code> — <summary>`), and as the **last line of the run (after the handover)** print the final `GLOBAL GATE: <status> — <checklist>` block. The evaluator can confirm only what autothing has surfaced in the transcript.
- **A per-turn progress ledger** — at the end of EVERY turn, after the resume scan, print one line: `PROGRESS: passed <p>/<total> · blocked <b> (remediation-attempted) · buildable-remaining <r>`. This makes exhaustion (or its absence) visible to the transcript-only evaluator. A `GLOBAL GATE:` verdict may NOT be printed while `buildable-remaining > 0`.

Never claim a gate passed without both its file trace and its printed line.

## Non-negotiables
- **Idempotent + non-clobbering** (enforced by `project-foundation`): missing → create; existing canonical file → never autonomously rewrite.
- **Autonomous**: never pause; fix forward; append blockers to `docs/decisions.md` and continue. A `walkthrough` STUCK/ask-user return becomes `video.status: failed-but-unblocking` + a logged blocker — never a wait for input.
- **No voluntary deferral.** A slice may end the run only as `passed` or `blocked`. "Deferred", "consolidated later", "interim proof", and "asserted-not-lived by choice" are NOT terminal states and are FORBIDDEN as blocker reasons. If work is buildable, it must be built before any verdict is printed.
- **Self-unblock before blocking.** Before marking any slice `blocked` on a missing tool, dependency, or binary, attempt to install it ONCE using the ecosystem's standard command (`uvx` / `pipx` / `brew` / `npm i -g` / `pip --break-system-packages` / `cargo install`). Only an install that FAILS and genuinely requires operator credentials or hardware the operator lacks is a legitimate blocker — and the blocker line must name the exact failed command and its error. "Not installed" alone is never a blocker.
- **Honest**: a failing slice is shown failing and flagged, never edited to look passed.
- **Cross-model gate is real, serial, and never silently skipped.** Every slice gets a second opinion from Codex — an adversarial review loop that iterates until both models agree (`approve`) and an independent Codex Playwright pass — before its design audit. **Serialize all Codex calls** (one `codex exec` at a time, run-wide; concurrent calls revoke the shared OAuth token). If Codex is missing, self-unblock the install; if `codex login` genuinely fails, that is an external blocker for the gate — log it and let the global gate fall to `completed-with-blockers`, never report a slice `passed` without its second opinion. Full recipe: `references/codex-verification.md`.
- **The correctness gate is a COMMITTED, re-runnable assertion** — a test file, or (where no runner ships, e.g. a Cortex/artifact bundle) a committed `playwright-cli` driver script that re-drives the flow and asserts. Ephemeral `.playwright-cli/` logs and the walkthrough video are EXPLORATION/EVIDENCE, never the gate. No committed re-runnable assertion ⇒ the slice is not done. (Resolves the tension with the `e2e-testing` skill: drive with playwright-cli, but COMMIT the driver + assertions so later slices catch regressions.)
- **Foundation + git before build** — Phase 1 via `project-foundation` (lean CLAUDE.md, the docs, area skills, `git init`) is a hard prerequisite for Phase 3; a gap is filled or logged with a reason, never silently skipped.
- **Workers/teammates get explicit context** — they do not inherit the lead's history; paste the relevant skill/doc + acceptance + file-ownership boundary into each spawn prompt.
- **Record build friction as a signal — autothing never self-edits.** When you work around the skill being silent, missing a step, or wrong, append one line to `docs/autothing/friction-log.md`. autothing does NOT act on it and never edits any skill; the nightly `skill-improver` is the single mechanism that improves skills, and it reads this log as one feedback source.

## Files (autothing owns)
- `references/build-loop.md` — the per-slice gated loop, resume, the global gate, handover. The core.
- `references/codex-verification.md` — the Codex cross-model gate: preflight/auth, the serial-call rule, the adversarial-review loop, the independent Playwright pass, durable record + printed lines.
- `assets/docs/FLOW_PLAN.md` — the Phase-2 slice-plan skeleton.
- `assets/gate-status.example.json` + `assets/evidence-index.example.json` — the durable-marker schemas (incl. `codexReview` / `codexPwTest` / `crossModel`).
- `assets/codex-review.schema.json` + `assets/codex-pwtest.schema.json` — the JSON Schemas passed to `codex exec --output-schema` for the two sub-gates.

## Delegated skills (separate skills — invoke, never reimplement; each is usable on its own)
- **`project-foundation`** — Phase 0 detect + Phase 1 scaffold: manifest/idempotency, /docs, lean CLAUDE.md, area skills, `git init`. Carries the doc/CLAUDE.md/area-skill assets.
- **`parallel-work`** — Phase 3 parallelization: agent teams vs workflows vs serial, disjoint-file decomposition, what must serialize.
- **`automation-testing`** — validating + filming non-UI automation slices (M365 webhooks/SSO/listeners).
- **`walkthrough`** — per-slice evidence video. **`deep-research`** / **`frontend-design`** / **`huashu-design`** / **`polish-ui`** — research, prototype, design audit. **`/run`** + **`/verify`** — drive the running app.
