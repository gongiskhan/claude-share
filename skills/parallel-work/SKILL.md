---
name: parallel-work
description: Decide HOW to split multi-step work across agents and run it safely — agent teams vs dynamic workflows vs sequential, the disjoint-files rule, and which shared runtime must serialize. Use BEFORE fanning a batch of work out to subagents/teammates/workflows (new modules, multi-slice builds, verification/research/design-audit fan-out, migrations), or when deciding whether two units of work can run concurrently at all. Encodes the standing preference: agent teams whenever they fit, workflows where teams don't, sequential only for genuinely shared work. autothing uses this for its build loop; usable directly for any parallelizable task. Do NOT use for the actual editing/testing of a single unit (that is an area/testing skill) or for recording evidence (that is walkthrough).
---

# parallel-work

Parallelize aggressively where it is SAFE; serialize only what genuinely must be. The lesson driving this skill: parallelism is blocked by **shared files** and **shared stateful runtime**, NOT by the agent mechanism. No mechanism makes two agents editing the same file safe — you EARN parallelism by decomposing work into disjoint file ownership.

This is a standalone capability. `autothing` calls it to parallelize its build loop, but use it directly any time you are about to fan work out across subagents, teammates, or workflows.

## The one rule
Parallelize a set of work units only when BOTH hold:
1. **Disjoint files** — each unit owns a different set of files. Two agents editing the same file overwrite each other. This is true for agent teams (official docs: "Break the work so each teammate owns a different set of files") AND for workflows.
2. **No shared stateful runtime during the parallel phase** — one dev-serve port, one bundle/build output, and one recorder each serve ONE thing at a time.

A monolith file housing several work units (e.g. one `screens.jsx` with prospects + clients) is a PLANNING problem, not a build-time surprise: split it so the units own disjoint files, THEN parallelize.

## Decompose up front — this is how you get MORE parallelism
- Map each work unit to the files it will edit. If two units touch the same file, either (a) split that file so each owns its piece, or (b) put them in one sequential group.
- Record the chosen group per unit with a ONE-LINE reason ("group A: disjoint screen files"; "S1+S3 share screens-internal.jsx → serial until split"). The parallel-vs-serial choice must be EXPLICIT and logged — never a silent default. (In an autothing build this goes in `FLOW_PLAN.md`'s parallel-group column.)
- Bias toward arranging the work so more of it is parallelizable. If a prototype monolith is the only blocker, plan the split as an early unit of work.

## Pick the mechanism

| Situation | Use | Why |
|---|---|---|
| Parallel IMPLEMENTATION of disjoint-file units (teams enabled) | **Agent team** (preferred) | Teammates coordinate via a shared task list + direct messaging; each owns its files. The "new modules/features, each owns a piece" sweet spot. |
| Parallel verification / research / design-audit fan-out; any unattended/resumable parallel step; implementation when teams are off | **Workflow** | Deterministic, journaled/**resumable** (survives compaction), fire-and-forget. Use `isolation: 'worktree'` for file isolation (needs git). |
| Shared file, single dev-serve/bundle/recorder, or heavy cross-deps | **Sequential** | No mechanism makes same-file edits or one runtime safe. |

Standing preference: **agent teams whenever they fit, workflows where teams don't, sequential only for genuinely shared work.**

## Agent teams — how the lead uses them
Preconditions are OPERATOR-set (a skill cannot enable them): `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` (experimental) and Claude Code ≥ 2.1.32. If unset, fall back to workflows.
- The orchestrator is the LEAD. Create a team for a BATCH of disjoint-file units: one teammate per unit. Teammates load CLAUDE.md + skills themselves but NOT the lead's history — so PASTE into each spawn prompt: the relevant area skill (or path + read directive), the acceptance, and the exact file-ownership boundary.
- The lead GATES each teammate's result (committed test green + build/lint clean + design audit + verified walkthrough, as applicable) before marking that task complete. A `TaskCompleted` hook can enforce the gate (exit 2 to reject and send feedback).
- **Keep bursts SHORT-LIVED**: create team → run the disjoint batch → gate each → shut down teammates → clean up the team → continue. This sidesteps the documented limit that in-process teammates do NOT survive `/resume`/`/rewind`. Never hold long-lived teammates across a compaction/resume boundary.
- Respect the limits: one team at a time; teammates cannot spawn their own teams; team creation may prompt for approval (confirm it passes under auto mode — if it blocks unattended, use a workflow instead); token cost scales per teammate (fine under ultracode).

## Always serialize (regardless of mechanism)
- The single dev-serve / app server (one port).
- The single bundle/build output. Two builds — or a build over a live dev server — sharing one output dir (e.g. `.next/`) poison each other's incremental cache. Give any concurrently-running dev server or build its **own isolated dist dir** (or a `git worktree` copy), or serialize them.
- The single recorder (one recording at a time; unique ports + run dirs).

Pattern: teammates/workers implement N disjoint-file units in parallel, then the lead runs each unit's **build → verify → record** tail one at a time. Parallelize the EDITING; serialize the VERIFY/RECORD.

## Honest fit note
For a FULLY UNATTENDED multi-hour loop, **workflows are the safer default** (no approval gate, resumable across compaction). **Agent teams** shine for bounded parallel bursts and attended work. Prefer teams where they fit; do not wrap a whole long build in one long-lived team.
