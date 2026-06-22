---
name: autothing
description: Autonomously implement a SIGNIFICANT piece of software work end-to-end and prove it with self-verified evidence — a new feature, page, module, service, or endpoint, a behavior change or multi-file refactor, OR a whole new app. ANY size of significant code work, NOT only whole projects; web and non-web (browser walkthrough for web, asciinema for CLI/TUI). Runs a gated per-slice build loop (explore, committed re-runnable tests, clean build/typecheck/lint, cross-model Codex review + independent Codex test pass, design audit, verified evidence). Plans itself (invokes autothing-plan) and loops to completion via the goal-loop Stop hook; fills any missing project foundation but is a no-op when the repo is already set up. Best under /effort ultracode + auto mode. Triggers on "implement/build/add X", "ship this feature", "refactor X", or "build this project". Do NOT use for bug fixes, small or one-line edits, single-function tweaks, formatting/renames, running the app, tests alone, or pure research.
---

# autothing

Orchestrates an unattended, gated build of a **significant code change** — a feature, a module/service/page/endpoint, a substantial behavior change, a multi-file refactor, or a whole project — and proves each slice with a self-verified evidence artifact (a browser walkthrough video for web flows, an asciinema capture for CLI/TUI). This skill is USER-scope; the foundation it writes is PROJECT-scope (inside the target repo). The `walkthrough` skill is SEPARATE — call it, never rebuild it.

## Scope — use autothing for any non-trivial code work (NOT only whole projects)
autothing is the default for **work that meaningfully adds or restructures code, at ANY size**: a single feature or page, a new module/service/endpoint, a substantial change to existing behavior, a multi-file refactor, up to a whole new app. A one-slice feature is a valid, common autothing run — the same gates apply at every size, they just scale down (a small feature is often a single slice with one evidence artifact and a near-empty foundation step).

**Do NOT use autothing for** (use the normal tools, `/run`, `/verify`, or plan mode instead): bug fixes, one-line or small edits, single-function tweaks, formatting/renames/dependency bumps, running or starting the app, writing or running tests on their own, or pure research/exploration/questions. Rule of thumb: if it meaningfully writes or restructures code and deserves a committed test + evidence, autothing fits; if it is a quick fix, a tweak, or just running/looking at things, it does not.

**Never refuse a qualifying task because it is "not a whole project."** Scale the plan to the work — fewer slices, a lighter (often no-op) foundation step — but always run the full gate sequence on whatever you do build.

## Operating assumptions (the operator sets these; autothing cannot set session switches)
- Launched under **/effort ultracode + auto mode**. The goal loop is **armed automatically** by autothing's Phase 0 run sentinel + the goal-loop `Stop` hook in `settings.json` (`hooks/goal-stop.sh`) — **no manual `/goal` needed**. **If the hook is not yet wired into this config, Phase 0 self-installs it** (`hooks/install.sh`) and carries on. The completion condition is the global gate (including "a self-verified evidence video exists for every slice") plus a turn cap.
- autothing **arms its own goal loop** (Phase 0 writes the run sentinel; the `Stop` hook keeps the session taking turns until the terminal `GLOBAL GATE:` verdict prints, then deletes the sentinel and releases the session). **It does NOT prompt for `/goal` when the hook is already active** — it prints a one-time `/goal` ONLY on a bootstrap run where Phase 0 just installed the hook (a freshly-added hook activates next session, so that one run can't auto-loop yet), or when hooks are disabled. Once the hook is in this machine's `settings.json` (committed/deployed), every run auto-loops with no `/goal`. `/effort` and auto mode are session toggles the operator flips once; autothing cannot set them. **autothing inherits the session effort (it does not pin its own); run it under `/effort ultracode` (or at least a high effort) — autothing does not self-escalate.**
- **Parallelism (optional, operator-set):** if `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` is set, prefer **agent teams** for parallel slice implementation; otherwise use **dynamic workflows**. autothing cannot enable that env var itself. See the **`autothing-parallel-work`** skill.
- **Cross-session coordination (advisory):** other Claude sessions may build in the same repo at once. When the **coord stack** is present (coord-mcp planning gate, agent-mail file leases, beads), use it — `autothing-plan` honors the planning gate (`begin_planning`) and parallel fan-out claims file leases + `declare_intent` per `autothing-parallel-work`. When it is absent (no Garrison / MCP not connected), fall back to the disjoint-files discipline — **never hard-block on it.**
- Therefore behave **fully autonomously**: never pause for approval, never ask the user, fix forward, log blockers and continue.
- **Trade-off (noted):** no `allowed-tools` restriction — it both sets up and builds, so it may use any tool. It is now **dual-mode** (slash- AND model-auto-invocable); the safety boundary is its own gates — its first real phase is read-only planning (`autothing-plan`) + writing the run sentinel, so auto-starting is not immediately destructive. **Optional operator hardening (documented, NOT built):** a single `UserPromptSubmit` hook that *suggests* autothing on matching prompts, if auto-trigger ever proves flaky — add it deliberately; do not rely on it by default.

## Owns vs delegates
autothing is the **orchestrator**: it arms the goal loop, sequences the per-slice pipeline, owns the retry ceiling + loop-back, and writes durable evidence. Each STEP of the pipeline is its own standalone `autothing-*` skill (each also usable on its own). autothing never reimplements a step — it invokes the step skill and, on a real failure, loops back to `autothing-implement`.
- **Owns:** arming the goal loop (Phase 0 sentinel + `hooks/install.sh`), the per-slice pipeline orchestration (sequence + 5-attempt ceiling + loop-back), and durable evidence (gate-status + evidence-index).
- **The pipeline (each a standalone skill autothing orchestrates):** plan → **`autothing-plan`**; implement → **`autothing-implement`**; correctness test (e2e through the UI) → **`autothing-test`**; same-model review → **`autothing-review`**; cross-model review → **`autothing-adversarial-review`**; cross-model test → **`autothing-adversarial-test`**; design audit → **`autothing-design-audit`**; evidence → **`autothing-walkthrough`**. A gate that finds real issues sends the slice back to `autothing-implement`. Once all slices are done, the run-end step is notify → **`autothing-report`** (Phase 5, before the terminal verdict).
- **Also delegates (do not reimplement):** foundation detect + scaffold → **`autothing-project-foundation`**; how to parallelize → **`autothing-parallel-work`**; cross-model engine → the **`codex` CLI** per `references/codex-verification.md` (via the two adversarial skills); same-model review engine → the built-in **`code-review`** skill (via `autothing-review`); design engines → `frontend-design` / `huashu-design` (via `autothing-design-audit`); evidence engine → `walkthrough` (via `autothing-walkthrough`); research → `deep-research`; run/verify → `/run`, `/verify`.

## Workflow

### On invocation — Phase 0: self-install, then arm the goal loop
**Step A — ensure autothing is wired into this Claude config (self-install).** Before anything else, run the idempotent installer so the goal loop works even on a machine/config where it was never set up:
```bash
bash ~/.claude/skills/autothing/hooks/install.sh
```
It is a no-op when already configured; otherwise it adds the `Stop` + `SessionStart` hooks and `CLAUDE_CODE_STOP_HOOK_BLOCK_CAP` to `settings.json` (idempotent, non-duplicating, backs up to `settings.json.autothing.bak`) and makes the hook scripts executable. **Capture WHICH it reported — this decides whether a `/goal` is needed:**
- **`already configured`** → the hook was in `settings.json` at session start, so it is **active now** and will drive the loop autonomously. **No `/goal` — do not prompt for one.**
- **`installed/repaired`** → the hook was added THIS session. A freshly-added hook does **not** take effect until a new session (hooks load at session start), so THIS run cannot auto-loop yet — it needs a **one-time** `/goal` (or a session restart). This is a bootstrap-only situation, not the normal path.

Either way **carry on with the run — never stop to ask.** If the installer warns that `disableAllHooks`/`allowManagedHooksOnly` is set, or that it cannot write `settings.json` (no `jq`), the hook cannot drive the loop → use the `/goal` fallback. (`install.sh --check` reports status without writing.)

**Step B — pick a run id + run directory (per run — never a shared path).** Concurrent autothing runs (in other sessions, even the same repo) must not clobber each other, so ALL of this run's durable state lives under a unique per-run directory:
- `SID="$CLAUDE_CODE_SESSION_ID"` (always set in the Claude Code shell — this is THIS session's id, and the same id the Stop hook receives).
- `runId="<YYYYMMDD-HHMMSS>-${SID:0:8}"` (timestamp + short session suffix — unique across concurrent sessions). `runDir="docs/autothing/runs/<runId>"`. `mkdir -p "<runDir>/slices"`.
- This run's plan is `<runDir>/FLOW_PLAN.md`; its evidence index is `<runDir>/evidence-index.json`; per-slice gate-status is `<runDir>/slices/<slice>/gate-status.json`. **Do not write to a shared `docs/FLOW_PLAN.md`.**

**Step C — arm the goal loop.** Pick a turn cap (default **250**; scale to ≈20–30 turns × expected slices for large builds). Write the **per-session** sentinel so the `Stop` hook (`hooks/goal-stop.sh`) loops the session to completion with **no manual `/goal`**:
- `mkdir -p ~/.autothing/sentinels`; write `~/.autothing/sentinels/$SID.json` (keyed by session id, so concurrent sessions never collide):
  ```json
  { "runId": "<runId>", "runDir": "<absolute runDir>", "project": "<project>", "turnCap": 250, "iteration": 0, "armedAt": "<iso>", "condition": "loop until a terminal GLOBAL GATE line (with videos:<n>/<n>) prints for this run" }
  ```
  The hook releases the session the moment the terminal `GLOBAL GATE: … videos:<n>/<n>` verdict appears in this session's transcript, OR at the turn cap; it then deletes the sentinel. **Resume:** in the same session (incl. after compaction) read `runDir` from `~/.autothing/sentinels/$SID.json`; in a fresh session resuming an interrupted run, pick the newest `docs/autothing/runs/<runId>/` whose `evidence-index.json` globalGate is not `passed`, and re-arm a sentinel for the new session pointing at it.

**Step D — finish Phase 0 per the Step-A signal. DO NOT prompt for `/goal` when the hook is already active.**

- **Hook already active** (Step A said `already configured`) — the normal path. The Stop hook drives the loop autonomously. Print ONE status line and move on; **do NOT print a `/goal` line** (printing one reads as a required operator step and reintroduces the manual handoff this skill exists to remove):
  ```
  Goal loop armed (run <runId>, cap 250) — auto-looping via the Stop hook; no /goal needed.
  ```
- **Hook just installed this session** (Step A said `installed/repaired`) OR hooks are disabled — the bootstrap/degraded path only. THIS run cannot auto-loop, so print a clearly one-time handoff and the `/goal` (fill `<project>`):
  ```
  ─── ONE-TIME: the goal-loop hook was just installed (active from your NEXT session). For THIS run only, paste this /goal once — or restart the session and re-run. Future runs auto-loop with no /goal. ───
  /goal autothing has printed "GLOBAL GATE: passed" for <project> with buildable-remaining 0 and every slice video verified — OR it has printed "GLOBAL GATE: completed-with-blockers" in which buildable-remaining is 0 AND every listed blocker names an external cause and the exact remediation command that failed. Stop after 250 turns regardless.
  ───────────────────────────────────────────────────────────────────────────────
  ```

Then continue to Phase 1 immediately — do not wait for the operator. (Both the hook and any `/goal` read ONLY the transcript, which is why the `GLOBAL GATE:` verdict is PRINTED, not just written to file. The quoted target above is NOT a verdict — it lacks the `videos:<n>/<n>` signature the hook keys on.)

### Phase 1 — Plan (invoke `autothing-plan`)
Invoke the **`autothing-plan`** skill (via the Skill tool) to reproduce native plan mode and write the durable plan to **this run's `<runDir>/FLOW_PLAN.md`** (the per-run path from Step B) — pass that exact path; **never the shared `docs/FLOW_PLAN.md`** (a concurrent run in another session would clobber it). This **replaces the operator's old manual plan-mode step**. autothing-plan explores the brief + code with read-only `Explore` subagents, designs with `Plan` subagents, resolves open questions by deciding (never asking), then writes a concise slice plan: slices with id, title, kind (`ui | mixed`), route, parallel group, acceptance, status (shape: `assets/docs/FLOW_PLAN.md`). It may name area skills that Phase 3 will create. If this run's `<runDir>/FLOW_PLAN.md` already exists (a resumed run), autothing-plan reads + refreshes it rather than starting over. autothing-plan is read-only except the plan file and **never** calls `EnterPlanMode`/`ExitPlanMode`.

### Phase 2 — Detect foundation (read-only)
Invoke the **`autothing-project-foundation`** skill's detect step. It produces a gap list (`present | missing | partial` per manifest element) + a role map for existing docs + any refresh recommendations. **Detection never edits.**

### Phase 3 — Bootstrap the foundation gaps ONLY (a HARD prerequisite for Phase 4)
Invoke the **`autothing-project-foundation`** skill to generate ONLY what Phase 2 marked missing/partial — it owns the manifest, `git init`, the non-clobber rule, the /docs + lean `CLAUDE.md` + area-skill generation (and carries those assets). **For a feature or change in an already-founded repo (the common case), Phase 2 finds the foundation present and this phase is a fast no-op — confirm it and move straight to the build; do NOT re-scaffold or rewrite anything.** Only a genuinely missing piece is filled. autothing layers the build-specific gates on top:
- **Do not enter Phase 4 until the foundation manifest is satisfied or each missing item is logged in `docs/decisions.md` with a reason** — a build will be tempted to skip ahead to the app; do not.
- Area skills are NOT optional: they are what parallel teammates/workers load (they don't inherit the lead's context).
- Confirm `/run` + `/verify` resolve and the dev command/port are known; ensure `walkthrough`'s preflight passes (`brew install asciinema agg` on macOS if missing).
- Refresh/slim recommendations go to `docs/autothing/REFRESH-RECOMMENDATIONS.md`; never rewrite an existing canonical file.

### Phase 4 — Build loop
Per `references/build-loop.md`. **Resume from durable files first** (FLOW_PLAN + gate-status + evidence-index), then for each non-done slice run the per-slice pipeline of standalone skills: **`autothing-implement`** → **`autothing-test`** (correctness gate) → **`autothing-review`** (same-model) → **`autothing-adversarial-review`** (Codex) → **`autothing-adversarial-test`** (Codex) → **`autothing-design-audit`** (where there is UI) → **`autothing-walkthrough`** → write `gate-status.json` + upsert `evidence-index.json` (under `<runDir>`). **Any gate that finds real issues sends the slice back to `autothing-implement`** — bounded retry **5**, fix-forward, log-and-continue. **Parallelize by default** where slices own disjoint files — **agent teams when enabled, else dynamic workflows** — and serialize only the shared runtime (one dev-serve / bundle / recorder, and **one `codex exec` at a time run-wide**). Decompose at plan time to EARN parallelism; log the parallel-vs-serial choice. See the **`autothing-parallel-work`** skill — incl. its cross-session rules (claim each unit's files via agent-mail leases + `declare_intent` when the coord stack is present; fall back to disjoint-files when absent). **Before the first parallel batch, preflight the mechanism:** probe once that agent-team creation does NOT raise an approval prompt under auto mode (a trivial throwaway team that proceeds, or the known approval behavior); if it would block a headless run, fall back to dynamic workflows for the whole run — an approval prompt that stalls unattended is itself a silent killer of autonomy.

### Phase 5 — Global gate + handover
Per `references/build-loop.md`. **A verdict line MAY NOT be printed while `buildable-remaining > 0`** — `buildable-remaining` = count of slices whose status is neither `passed` nor `blocked` (and `blocked` only counts when it carries the attempted-remediation evidence from the non-negotiables). If it is > 0, the run returns to the per-slice loop and builds the next buildable slice. Decide the terminal state and write `globalGate.status` to `evidence-index.json`:
- **`passed`** only when **buildable-remaining == 0**, zero blockers, full e2e + `/verify` + build/typecheck/lint exit 0, **every slice has a clean Codex `approve` + Codex Playwright `pass`** (two-model agreement), the design audit is clean, AND **every slice's video is `verified`** (matching the `/goal` condition).
- **`completed-with-blockers`** legitimate ONLY when **buildable-remaining == 0** AND ≥1 slice is `blocked` with a named external cause + the exact remediation command that failed. (A `failed-but-unblocking` video is recorded evidence but is NOT self-verified, so it keeps the gate out of `passed`.)

Never repeat failed work unproductively, but ALWAYS continue while any buildable (non-blocked) slice remains. The verdict is printed only when buildable work is exhausted — reaching the turn cap with buildable work left is a failure of the loop, not a stop condition. Never fake `passed`.

Then, in order: **(1)** print the handover as prose — stack + why, install/invoke, evidence-gallery URL, an explicit enumeration of blockers (each with its external cause + failed remediation command), known limits; **(2)** invoke **`autothing-report`** to send the operator a Slack notification (work summary + the walkthrough video-gallery Tailscale URL + Tailscale links to the run's logs/artifacts, served in place). This is a side-effect, not a transcript print, so it is safe before the verdict line; **(3)** as the LAST action, print `GLOBAL GATE: <status> — <checklist>`. The handover comes first because the verdict line is the completion signal: the `/goal` evaluator clears on it and the session stops, so nothing after it runs. Don't put an assertive `GLOBAL GATE:` line in the handover. (The same token in the invocation handoff is a quoted target, not a verdict; the evaluator distinguishes the two.)

## Durable markers — the contract
Every gate (objective AND subjective) leaves **two** traces:
- **A durable file** — so the build resumes after compaction and the human can inspect it:
  - per slice → `<runDir>/slices/<slice>/gate-status.json` (schema: `assets/gate-status.example.json`)
  - per run → `<runDir>/evidence-index.json` (schema: `assets/evidence-index.example.json`) — `<runDir>` is `docs/autothing/runs/<runId>/` from Phase 0, never a shared path
- **A printed line in the transcript** — because the `/goal` evaluator is a small fast model that reads ONLY the conversation; it does not open files or run commands. Print each gate's exit code inline (`GATE <name>: exit <code> — <summary>`), and as the **last line of the run (after the handover)** print the final `GLOBAL GATE: <status> — <checklist>` block. The evaluator can confirm only what autothing has surfaced in the transcript.
- **A per-turn progress ledger** — at the end of EVERY turn, after the resume scan, print one line: `PROGRESS: passed <p>/<total> · blocked <b> (remediation-attempted) · buildable-remaining <r>`. This makes exhaustion (or its absence) visible to the transcript-only evaluator. A `GLOBAL GATE:` verdict may NOT be printed while `buildable-remaining > 0`.

Never claim a gate passed without both its file trace and its printed line.

## Non-negotiables
- **Idempotent + non-clobbering** (enforced by `autothing-project-foundation`): missing → create; existing canonical file → never autonomously rewrite.
- **Autonomous**: never pause; fix forward; append blockers to `docs/decisions.md` and continue. A `walkthrough` STUCK/ask-user return becomes `video.status: failed-but-unblocking` + a logged blocker — never a wait for input.
- **No voluntary deferral.** A slice may end the run only as `passed` or `blocked`. "Deferred", "consolidated later", "interim proof", and "asserted-not-lived by choice" are NOT terminal states and are FORBIDDEN as blocker reasons. If work is buildable, it must be built before any verdict is printed.
- **Self-unblock before blocking.** Before marking any slice `blocked` on a missing tool, dependency, or binary, attempt to install it ONCE using the ecosystem's standard command (`uvx` / `pipx` / `brew` / `npm i -g` / `pip --break-system-packages` / `cargo install`). Only an install that FAILS and genuinely requires operator credentials or hardware the operator lacks is a legitimate blocker — and the blocker line must name the exact failed command and its error. "Not installed" alone is never a blocker.
- **Honest**: a failing slice is shown failing and flagged, never edited to look passed.
- **Cross-model gate is real, serial, and never silently skipped.** Every slice gets a second opinion from Codex — an adversarial review loop that iterates until both models agree (`approve`) and an independent Codex Playwright pass — before its design audit. **Serialize all Codex calls** (one `codex exec` at a time, run-wide; concurrent calls revoke the shared OAuth token). If Codex is missing, self-unblock the install; if `codex login` genuinely fails, that is an external blocker for the gate — log it and let the global gate fall to `completed-with-blockers`, never report a slice `passed` without its second opinion. Full recipe: `references/codex-verification.md`.
- **The correctness gate is a COMMITTED, re-runnable assertion** — a test file, or (where no runner ships, e.g. a Cortex/artifact bundle) a committed `playwright-cli` driver script that re-drives the flow and asserts. Ephemeral `.playwright-cli/` logs and the walkthrough video are EXPLORATION/EVIDENCE, never the gate. No committed re-runnable assertion ⇒ the slice is not done. (Resolves the tension with the `e2e-testing` skill: drive with playwright-cli, but COMMIT the driver + assertions so later slices catch regressions.)
- **Foundation + git before build** — Phase 3 via `autothing-project-foundation` (lean CLAUDE.md, the docs, area skills, `git init`) is a hard prerequisite for Phase 4; a gap is filled or logged with a reason, never silently skipped.
- **Workers/teammates get explicit context** — they do not inherit the lead's history; paste the relevant skill/doc + acceptance + file-ownership boundary into each spawn prompt.
- **Record build friction as a signal — autothing never self-edits.** When you work around the skill being silent, missing a step, or wrong, append one line to `docs/autothing/friction-log.md`. autothing does NOT act on it and never edits any skill; the nightly `skill-improver` is the single mechanism that improves skills, and it reads this log as one feedback source.

## Files (autothing owns)
- `references/build-loop.md` — the per-slice gated loop, resume, the global gate, handover. The core. Includes the **lead-print invariant** ("Gate lines must print in the lead context") the goal-loop hook depends on.
- `references/codex-verification.md` — the Codex cross-model gate: preflight/auth, the serial-call rule, the adversarial-review loop, the independent Playwright pass, durable record + printed lines.
- `references/decisions.md` — autothing's own design-decision log (e.g. the ULTRACODE-SAFE test record behind the lead-print invariant).
- `hooks/goal-stop.sh` — the goal-loop `Stop` hook (deterministic, no model call): reads the **per-session** sentinel `~/.autothing/sentinels/<session_id>.json` and blocks the stop until the terminal `GLOBAL GATE: … videos:<n>/<n>` verdict prints for this session, then releases. Per-session keying means concurrent runs never clobber each other. Registered in `settings.json`.
- `hooks/goal-sessionstart.sh` — `SessionStart` guard: sweeps orphaned per-session sentinels (untouched >2 days) left by crashed runs. Registered in `settings.json`.
- `hooks/install.sh` — idempotent self-installer (Phase 0 Step A): wires the `Stop` + `SessionStart` hooks and `CLAUDE_CODE_STOP_HOOK_BLOCK_CAP` into `settings.json` (non-duplicating, backs up first) and chmods the hooks. `--check` reports status without writing. This is what lets autothing configure itself on a fresh Claude config and then carry straight on with the run.
- `hooks/probe.sh` — goal-loop **liveness probe** (`arm` → end the turn → `check`): confirms Claude Code actually honors the Stop hook's `decision:block` auto-continue in a session (proves the no-`/goal` loop works end-to-end) using the real `goal-stop.sh`. Self-bounded (cap 2), refuses to clobber a live run. Run it in a session that is NOT executing a build, ideally before the first long unattended run on a machine.
- `assets/docs/FLOW_PLAN.md` — the Phase-1 slice-plan skeleton (written via `autothing-plan`).
- `assets/gate-status.example.json` + `assets/evidence-index.example.json` — the durable-marker schemas (incl. `codexReview` / `codexPwTest` / `crossModel`).
- `assets/codex-review.schema.json` + `assets/codex-pwtest.schema.json` — the JSON Schemas passed to `codex exec --output-schema` for the two sub-gates.

## Delegated skills (separate skills — invoke, never reimplement; each is usable on its own)
The per-slice pipeline (each a standalone `autothing-*` skill autothing orchestrates; a failing gate loops back to `autothing-implement`):
- **`autothing-plan`** — Phase 1 planning: reproduces Claude Code plan mode (read-only `Explore` + `Plan` subagents, then a concise durable plan) WITHOUT the native `EnterPlanMode`/`ExitPlanMode` tools. Writes the run's `<runDir>/FLOW_PLAN.md` (never a shared path).
- **`autothing-implement`** — the code-writing step: explore (vision-first for UI) then write the slice. The step every gate loops back to.
- **`autothing-test`** — the correctness gate: a COMMITTED re-runnable **e2e-through-the-UI** test (Playwright / playwright-cli) + unit tests + `typecheck`/`lint`/`build`. CLI/TUI deliverables use a committed driver + asciinema capture.
- **`autothing-review`** — same-model review via the built-in `code-review` skill.
- **`autothing-adversarial-review`** — cross-model review via the `codex` CLI (3A).
- **`autothing-adversarial-test`** — cross-model independent functional pass via the `codex` CLI (3B).
- **`autothing-design-audit`** — subjective design/UX gate (where there is UI) via `frontend-design` / `huashu-design`.
- **`autothing-walkthrough`** — self-verified evidence via the `walkthrough` skill; reconciles a STUCK to `failed-but-unblocking`.
- **`autothing-report`** — Phase 5 final step: Slack notification (work summary + the walkthrough video-gallery Tailscale URL + Tailscale links to the run's logs/artifacts, served in place via a small standing Node server; no duplication). Sends via a Slack incoming webhook, falls back to the Slack MCP. Standalone too.

Foundation + support:
- **`autothing-project-foundation`** — Phase 2 detect + Phase 3 scaffold: manifest/idempotency, /docs, lean CLAUDE.md, area skills, `git init`. Carries the doc/CLAUDE.md/area-skill assets.
- **`autothing-parallel-work`** — Phase 4 parallelization: agent teams vs workflows vs serial, disjoint-file decomposition, what must serialize, AND cross-session coordination (coord-mcp planning gate / agent-mail file leases / beads) when the coord stack is present.
- **`walkthrough`** — the evidence engine (used by `autothing-walkthrough`). **`code-review`** — the same-model review engine (used by `autothing-review`). **`frontend-design`** / **`huashu-design`** — design engines (used by `autothing-design-audit`). **`deep-research`** — research. **`/run`** + **`/verify`** — drive the running app.
