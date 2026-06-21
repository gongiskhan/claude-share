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

**Stale-sentinel safety.** The sentinel is bound to the arming session's id (recorded by `hooks/goal-sessionstart.sh` at `~/.autothing/current-session`); the Stop hook never blocks a session whose id does not match, and `SessionStart` deletes a sentinel left by a different (crashed) session. Residual: a single global sentinel assumes one autothing run per machine at a time (true by design); a sub-second arm-time race between concurrent unrelated sessions is accepted and documented.
