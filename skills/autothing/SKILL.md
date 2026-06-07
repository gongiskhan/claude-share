---
name: autothing
description: Set up and then autonomously build a web project (NEW or EXISTING) to a hard quality bar with self-verified video evidence. EXPLICIT-INVOCATION ONLY — run when the operator launches an unattended build with /effort ultracode, auto mode, and an active /goal. Idempotently bootstraps a per-project foundation (lean root CLAUDE.md + routing index, living /docs, area-skills under the project's .claude/skills/), plans slices in docs/FLOW_PLAN.md, then builds each slice through gates — vision-first exploration, Playwright + unit tests written AFTER exploring (the correctness gate), clean build/typecheck/lint, a design audit, and a self-verified walkthrough evidence video — writing durable gate-status + evidence-index files the /goal evaluator can confirm. Invoke for "set up and build this project", "autonomously implement to done with proof", or to resume such a build. Delegates research, prototype, run/verify, video, and design audit to existing skills; never fakes a gate.
disable-model-invocation: true
---

# autothing

Orchestrates an unattended, gated build of a web project and proves each slice with a self-verified video. This skill is USER-scope; the foundation it writes is PROJECT-scope (inside the target repo). The `walkthrough` skill is SEPARATE — call it, never rebuild it.

## Operating assumptions (the operator sets these; autothing cannot set session switches)
- Launched under **/effort ultracode + auto mode + an active /goal** whose condition is the global gate (including "a self-verified evidence video exists for every slice") plus a turn cap.
- autothing **cannot set `/goal` itself** — no Claude Code mechanism lets a skill set a session goal — so its FIRST output is the exact `/goal` line for the operator to paste (see *On invocation* below). `/effort` and auto mode are session toggles the operator flips once.
- **Parallelism (optional, operator-set):** if `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` is set, prefer **agent teams** for parallel slice implementation; otherwise use **dynamic workflows**. autothing cannot enable that env var itself. See `references/parallelism.md`.
- Therefore behave **fully autonomously**: never pause for approval, never ask the user, fix forward, log blockers and continue.
- **Trade-off (noted):** no `allowed-tools` restriction — it both sets up and builds, so it may use any tool. That is why it is explicit-invocation-only and operator-gated.

## Owns vs delegates
- **Owns:** the manifest/idempotency, foundation generation, the gated build loop, and durable evidence.
- **Delegates (do not reimplement):** research → `deep-research`; prototype/design tokens → `frontend-design`, `huashu-design`; run/verify → `/run`, `/verify`; per-slice evidence video → `walkthrough`; design audit → `frontend-design`, `polish-ui`, `huashu-design`.

## Workflow

### On invocation — FIRST, print the operator handoff
You cannot set `/goal` yourself, so before any work print the one line the operator pastes to run you unattended. Fill `<project>` from the repo; pick a turn cap (default **150**; scale to ≈15–25 turns × expected slices for large builds). Print exactly:

```
─── OPERATOR: to run me unattended, set /effort ultracode + auto mode, then paste this one line ───
/goal autothing has printed "GLOBAL GATE: passed" for <project> — every slice shows tests/e2e/typecheck/lint/build exit 0, design audit clean, and a VERIFIED walkthrough video — OR it has printed "GLOBAL GATE: completed-with-blockers" with the blockers listed. Stop after 150 turns regardless.
───────────────────────────────────────────────────────────────────────────────
```

Then continue to Phase 0 immediately — do not wait for the operator. (The `/goal` they paste keeps the session taking turns until you print the `GLOBAL GATE:` verdict; its evaluator reads only the transcript, which is why that verdict is printed, not just written to file.)

### Phase 0 — Detect (read-only)
Run the manifest detection in `references/manifest.md`. Produce a gap list (`present | missing | partial` per element) + a role map for existing docs + any refresh recommendations. **Detection never edits.**

### Phase 1 — Bootstrap the gaps ONLY (a HARD prerequisite for Phase 3)
Per `references/foundation.md`, create only what Phase 0 marked missing/partial. **Do not enter Phase 3 until the foundation manifest is satisfied or each missing item is logged in `docs/decisions.md` with a reason** — a build will be tempted to skip ahead to the app; do not.
- **Git: `git init` + an initial commit if the repo is not already a git work tree.** Mandatory — version control/rollback for an unattended build, `git diff` flow-selection for `walkthrough`, and `isolation: 'worktree'` for parallel workflows all require it.
- New/empty repo: `deep-research` brief → `frontend-design`/`huashu-design` prototype + design tokens.
- Generate missing `/docs` from `assets/docs/`, the lean `CLAUDE.md` from `assets/CLAUDE.md.template` (routing index with the real skill names), and author the area skills into `<project>/.claude/skills/<proj>-<area>/` from the exemplar `assets/area-skills/testing.SKILL.md`. These are NOT optional: area skills are what parallel teammates/workers load (they don't inherit the lead's context).
- Ensure `/run` + `/verify` resolve and the dev command/port are known; ensure `walkthrough`'s preflight passes (`brew install asciinema agg` on macOS if missing).
- **Never rewrite an existing canonical file.** Additive, clearly-owned edits only; log slim/refresh ideas to `docs/autothing/REFRESH-RECOMMENDATIONS.md`.

### Phase 2 — Plan
Write/update `docs/FLOW_PLAN.md` (`assets/docs/FLOW_PLAN.md`): slices with id, title, kind (`ui | automation | mixed`), route, parallel group, acceptance, status. If it exists and is current, reuse it.

### Phase 3 — Build loop
Per `references/build-loop.md`. **Resume from durable files first** (FLOW_PLAN + gate-status + evidence-index), then for each non-done slice: explore (vision-first) → **write a COMMITTED, re-runnable test** + run it → objective gates (tests/e2e/typecheck/lint/build exit 0) → design audit → `walkthrough` evidence → write `gate-status.json` + upsert `evidence-index.json`. Bounded retry **5**, fix-forward, log-and-continue. **Parallelize by default** where slices own disjoint files — **agent teams when enabled, else dynamic workflows** — and serialize only the shared runtime (one dev-serve / bundle / recorder). Decompose at plan time to EARN parallelism; log the parallel-vs-serial choice. See `references/parallelism.md`. Automation slices use `references/automations-testing.md`.

### Phase 4 — Global gate + handover
Per `references/build-loop.md`. Decide the terminal state and write `globalGate.status` to `evidence-index.json`: **`passed`** only when full e2e + `/verify` + build/typecheck/lint exit 0, the design audit is clean, AND **every slice's video is `verified`** (matching the `/goal` condition); otherwise **`completed-with-blockers`** (≥1 slice blocked or its video unverified) — never spin to the turn cap, never fake `passed`. Then, in order: **(1)** print the handover as prose — stack + why, install/invoke, evidence-gallery URL, an explicit enumeration of blockers, known limits; **(2)** as the LAST action, print `GLOBAL GATE: <status> — <checklist>`. The handover comes first because the verdict line is the completion signal: the `/goal` evaluator clears on it and the session stops, so nothing after it runs. Don't put an assertive `GLOBAL GATE:` line in the handover. (The same token in the invocation handoff is a quoted target, not a verdict; the evaluator distinguishes the two.)

## Durable markers — the contract
Every gate (objective AND subjective) leaves **two** traces:
- **A durable file** — so the build resumes after compaction and the human can inspect it:
  - per slice → `docs/autothing/slices/<slice>/gate-status.json` (schema: `assets/gate-status.example.json`)
  - per project → `docs/autothing/evidence-index.json` (schema: `assets/evidence-index.example.json`)
- **A printed line in the transcript** — because the `/goal` evaluator is a small fast model that reads ONLY the conversation; it does not open files or run commands. Print each gate's exit code inline (`GATE <name>: exit <code> — <summary>`), and as the **last line of the run (after the handover)** print the final `GLOBAL GATE: <status> — <checklist>` block. The evaluator can confirm only what autothing has surfaced in the transcript.

Never claim a gate passed without both its file trace and its printed line.

## Non-negotiables
- **Idempotent + non-clobbering** (`references/manifest.md`): missing → create; existing canonical file → never autonomously rewrite.
- **Autonomous**: never pause; fix forward; append blockers to `docs/decisions.md` and continue. A `walkthrough` STUCK/ask-user return becomes `video.status: failed-but-unblocking` + a logged blocker — never a wait for input.
- **Honest**: a failing slice is shown failing and flagged, never edited to look passed.
- **The correctness gate is a COMMITTED, re-runnable assertion** — a test file, or (where no runner ships, e.g. a Cortex/artifact bundle) a committed `playwright-cli` driver script that re-drives the flow and asserts. Ephemeral `.playwright-cli/` logs and the walkthrough video are EXPLORATION/EVIDENCE, never the gate. No committed re-runnable assertion ⇒ the slice is not done. (Resolves the tension with the `e2e-testing` skill: drive with playwright-cli, but COMMIT the driver + assertions so later slices catch regressions.)
- **Foundation + git before build** — Phase 1 (lean CLAUDE.md, the docs, area skills, `git init`) is a hard prerequisite for Phase 3; a gap is filled or logged with a reason, never silently skipped.
- **Workers/teammates get explicit context** — they do not inherit the lead's history; paste the relevant skill/doc + acceptance + file-ownership boundary into each spawn prompt.
- **Record build friction as a signal — autothing never self-edits.** When you work around the skill being silent, missing a step, or wrong, append one line to `docs/autothing/friction-log.md`. autothing does NOT act on it and never edits any skill; the nightly `skill-improver` is the single mechanism that improves skills, and it reads this log as one feedback source.

## Files
- `references/manifest.md` — detection, idempotency, the non-clobber rule, staleness reporting.
- `references/foundation.md` — generating /docs, the lean CLAUDE.md, and the area-skill set (authored from the exemplar).
- `references/build-loop.md` — the per-slice gated loop, resume, the global gate, handover.
- `references/parallelism.md` — when/how to parallelize (agent teams vs workflows vs serial), disjoint-file decomposition, what must serialize.
- `references/automations-testing.md` — validating + filming non-UI automations (M365 webhooks/SSO/listeners).
- `assets/` — doc skeletons, the lean CLAUDE.md template, the worked testing-skill exemplar, and the two gate/evidence JSON schemas.
