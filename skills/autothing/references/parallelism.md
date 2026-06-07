# Parallelism: agent teams, workflows, and what must serialize

Parallelize aggressively where it is SAFE; serialize only what genuinely must be. The lesson driving this file: parallelism is blocked by **shared files** and **shared stateful runtime**, NOT by the agent mechanism. No mechanism makes two agents editing the same file safe — you EARN parallelism by decomposing work into disjoint file ownership.

## The one rule
Parallelize a set of work units only when BOTH hold:
1. **Disjoint files** — each unit owns a different set of files. Two agents editing the same file overwrite each other. This is true for agent teams (official docs: "Break the work so each teammate owns a different set of files") AND for workflows.
2. **No shared stateful runtime during the parallel phase** — one dev-serve port, one bundle/build output, and the `walkthrough` recorder each serve ONE thing at a time.

A monolith file housing several slices (e.g. one `screens.jsx` with prospects + clients) is a PLANNING problem, not a build-time surprise: split it so slices own disjoint files, THEN parallelize.

## Decompose at plan time (Phase 2) — this is how you get MORE parallelism
- Map each slice to the files it will edit. If two slices touch the same file, either (a) split that file so each owns its piece, or (b) put them in one sequential group.
- Record a `parallel group` per slice in `FLOW_PLAN.md` with a ONE-LINE reason ("group A: disjoint screen files"; "S1+S3 share screens-internal.jsx → serial until split"). The parallel-vs-serial choice must be EXPLICIT and logged — never a silent default.
- Bias toward arranging the work so more of it is parallelizable. If a prototype monolith is the only blocker, plan the split as an early slice.

## Pick the mechanism

| Situation | Use | Why |
|---|---|---|
| Parallel IMPLEMENTATION of disjoint-file slices (teams enabled) | **Agent team** (preferred) | Teammates coordinate via a shared task list + direct messaging; each owns its files. The "new modules/features, each owns a piece" sweet spot. |
| Parallel verification / research / design-audit fan-out; any unattended/resumable parallel step; implementation when teams are off | **Workflow** | Deterministic, journaled/**resumable** (survives compaction), fire-and-forget. Use `isolation: 'worktree'` for file isolation (needs git). |
| Shared file, single dev-serve/bundle/recorder, or heavy cross-deps | **Sequential** | No mechanism makes same-file edits or one runtime safe. |

Operator's standing preference: **agent teams whenever they fit, workflows where teams don't, sequential only for genuinely shared work.**

## Agent teams — how autothing (the lead) uses them
Preconditions are OPERATOR-set (like `/goal` — autothing cannot enable them): `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` (experimental) and Claude Code ≥ 2.1.32. If unset, fall back to workflows.
- autothing is the LEAD. Create a team for a BATCH of disjoint-file slices: one teammate per slice. Teammates load CLAUDE.md + skills themselves but NOT the lead's history — so PASTE into each spawn prompt: its area skill (or path + read directive), the slice acceptance, and its exact file-ownership boundary.
- The lead GATES each teammate's result (committed test green + build/lint clean + design audit + verified walkthrough) before marking that slice's task complete. A `TaskCompleted` hook can enforce the gate (exit 2 to reject and send feedback).
- **Keep bursts SHORT-LIVED**: create team → run the disjoint batch → gate each → shut down teammates → clean up the team → continue. This sidesteps the documented limit that in-process teammates do NOT survive `/resume`/`/rewind`. Never hold long-lived teammates across a compaction/resume boundary.
- Respect the limits: one team at a time; teammates cannot spawn their own teams; team creation may prompt for approval (confirm it passes under auto mode — if it blocks unattended, use a workflow instead); token cost scales per teammate (fine under ultracode).

## Always serialize (regardless of mechanism)
- The single dev-serve / app server (one port).
- The single bundle/build output.
- The `walkthrough` recorder (one recording at a time; unique ports + run dirs).

Pattern: teammates/workers implement N disjoint-file slices in parallel, then the lead runs each slice's **build → verify → record** tail one at a time. Parallelize the EDITING; serialize the VERIFY/RECORD.

## Honest fit note
For the FULLY UNATTENDED multi-hour loop, **workflows are the safer default** (no approval gate, resumable across compaction). **Agent teams** shine for bounded parallel bursts and attended work. Prefer teams where they fit; do not wrap the whole build in one long-lived team.
