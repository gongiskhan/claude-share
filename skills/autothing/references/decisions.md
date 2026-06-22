# autothing — design decisions

A log of non-obvious design decisions for the autothing skill family. Referenced by `build-loop.md`. Newest last.

---

## 2026-06-21 — ultracode is ULTRACODE-SAFE (the lead-print invariant)

**Decision.** ultracode (`/effort ultracode` = `xhigh` effort + automatic per-task workflow orchestration) may stay ON during an autothing run. It is **additive**: it operates per *task*, not per *skill*, so it does not wrap autothing's flow — it only lets the lead fan an individual substantive task out into a background workflow. The workflow contract returns control to the lead between phases, so a workflow spawned inside one gate step cannot reach across into the next gate. **This holds only because every gate line is printed in the lead context** — promoted to an explicit invariant in `build-loop.md` ("Gate lines must print in the lead context (ultracode-safe)").

**Evidence (two arms).**
- **Corroborating (behavioral).** A live 2-slice test under `/effort ultracode` (Claude Code 2.1.183, Opus 4.8 1M) had build-1 and verify-1 genuinely fan out to task-scoped workflows while build-2 and verify-2 ran inline; all four `GATE` lines reached the main transcript in order; no workflow spanned more than one named task.
- **Actual evidence (mechanical hazard probe).** A gate line whose only print-site is *inside* a workflow agent reaches the lead ONLY as the workflow script's return value and is otherwise lost — a silent gate disappearance. This is the mechanism the invariant guards against, and it is the real proof: the behavioral arm corroborates, the hazard probe is the controlled demonstration.

**Honest confound (recorded).** The only environment genuinely in `/effort ultracode` was the test session itself; headless subprocesses cannot reproduce the mode, so the behavioral arm could not be reproduced under controlled subprocess conditions — it is corroborated by the mechanical arm, which depends on a harness property (a workflow's only channel back to the lead is its return value) not under the author's control.

**Known limitation (open).** The test exercised only single-phase fan-outs. A multi-phase workflow that internally chains understand→change→verify within ONE named task was NOT exercised. The lead-print invariant protects that case in principle, but a `GATE` line meant to print *between* a workflow's internal phases is untested.

**Consequence in code.** `build-loop.md` now mandates that every `GATE <name>:`, `PROGRESS:`, `GATE codex-review:`/`GATE codex-pwtest:`, and the terminal `GLOBAL GATE:` line print in the lead context, never from inside a workflow agent. The terminal verdict must keep its `videos:<verified>/<total>` token — the goal-loop `Stop` hook (`hooks/goal-stop.sh`) keys on `GLOBAL GATE: … videos:<n>/<n>` to distinguish the real verdict from the quoted `/goal` target.

---

## 2026-06-21 — goal loop reproduced by a deterministic command Stop hook (not /goal, not a prompt hook)

**Decision.** The manual `/goal` step is replaced by a `type: "command"` Stop hook (`hooks/goal-stop.sh`) armed by a run sentinel (`~/.autothing/goal-sentinel.json`) that autothing writes in Phase 0. The hook is **deterministic** — it does a transcript read, never a model call and never `claude -p` (the PTY/billing fence forbids `type: "prompt"` Stop hooks and Agent-SDK calls against Anthropic endpoints). This is feasible because autothing's completion condition is already transcript-provable: the terminal `GLOBAL GATE: … videos:<n>/<n>` line.

**Why not the literal "exit 0 when stop_hook_active" + default cap.** Confirmed against the official hooks guide (Claude Code 2.1.185): `stop_hook_active` is true for the *entire* forced-continuation chain, so an early-exit on it would release the loop after a single turn; and Claude Code overrides a Stop hook after it blocks **8 times in a row** by default. A 50–250-turn build needs many more iterations. The documented remedy is used: *"If your hook legitimately needs more than eight iterations to converge, raise the cap with `CLAUDE_CODE_STOP_HOOK_BLOCK_CAP`."* So `CLAUDE_CODE_STOP_HOOK_BLOCK_CAP` is raised to the turn cap in `settings.json`, and the hook self-terminates on: the terminal `GLOBAL GATE` verdict, an absent/foreign-session sentinel, or its own iteration counter reaching the turn cap. `stop_hook_active` is logged for visibility but is NOT the terminator. The hook fails SAFE (any error → allow the stop).

**Stale-sentinel safety.** (Superseded by the 2026-06-22 concurrency entry below — the sentinel is now per-session, not a single global file.)

---

## 2026-06-22 — concurrency-safe by construction (per-session sentinel + per-run state)

**Problem.** The first cut used a SINGLE global sentinel (`~/.autothing/goal-sentinel.json`) and a shared plan (`docs/FLOW_PLAN.md`). Two autothing runs in different sessions at the same time would clobber both — session B's Phase 0 overwrote A's sentinel, releasing A's loop early, and both wrote the same plan/evidence files.

**Fix — two changes, no shared mutable path anywhere:**
1. **Per-session sentinel.** The sentinel is now `~/.autothing/sentinels/<session_id>.json`. Phase 0 keys it by `$CLAUDE_CODE_SESSION_ID` (always set in the Claude Code shell); the Stop hook keys it by the Stop event's `session_id` (the same id). Each session reads only its own file, so concurrent runs cannot interfere. This also removed the old `current-session` file, the sessionId-mismatch check, and the bind-on-first-fire logic — the hook is simpler and has no arm-time race. `hooks/goal-sessionstart.sh` now only sweeps orphaned sentinels untouched for >2 days (an active run rewrites its sentinel every turn, so it is never swept).
2. **Per-run state directory.** All durable run state lives under `docs/autothing/runs/<runId>/` (`runId = <timestamp>-<sid8>`): `FLOW_PLAN.md`, `slices/<slice>/gate-status.json`, `evidence-index.json`. autothing-plan writes the plan there (never the shared `docs/FLOW_PLAN.md`); standalone autothing-plan uses a unique `~/.claude/plans/<slug>-<timestamp>.md`. Resume in the same session reads `runDir` from the per-session sentinel; a fresh session resuming an interrupted run picks the newest `runs/<runId>/` whose `evidence-index.json` globalGate is not `passed`.

**Assumption (verified once).** `$CLAUDE_CODE_SESSION_ID` (shell) equals the Stop hook's JSON `session_id` (both are the session uuid; the transcript dir is named by it). If a future version diverged, the loop would simply not fire (fails safe to "no loop", never to "wrong loop"), and the printed `/goal` fallback would cover the run. Verified by 10/10 branch tests incl. a concurrency case (session A's stop leaves session B's sentinel untouched).

## 2026-06-22 — full standalone decomposition + drop automation-testing

The per-slice loop is now seven standalone skills autothing orchestrates (`autothing-implement` / `-test` / `-review` / `-adversarial-review` / `-adversarial-test` / `-design-audit` / `-walkthrough`), each usable on its own; a failing gate loops back to `autothing-implement`. **`automation-testing` was removed** (the operator's projects have UI and prefer e2e through the UI); `autothing-test` defaults to e2e-through-the-UI + unit tests, with a committed-driver+asciinema path for CLI/TUI. Design audit was decomposed into `autothing-design-audit`. FLOW_PLAN `kind` is now `ui | mixed` (no `automation`).
