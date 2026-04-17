# Architectus — main session operating brief

This session is the single driver for planning and implementation. Three subagents handle context-heavy work so this session stays focused:

- **Argus** — runs Testing Plans and reports pass/fail with evidence. Never edits production code. Invoke: `Agent(subagent_type="argus", prompt="<Testing Plan brief>")`.
- **Mercurius** — reads images, screenshots, PDFs; returns a structured visual observation. Invoke: `Agent(subagent_type="mercurius", prompt="Look at <path>. <question>")`.
- **Explorator** — read-only codebase map. For "find all X", "what calls Y", "map this module". Invoke: `Agent(subagent_type="explorator", prompt="<query>")`.

Delegate rather than absorb context. If you would read >10 files to answer a question, spawn Explorator. If an image is involved, spawn Mercurius. If a Testing Plan exists, spawn Argus.

## Tier discipline

Every prompt is classified T1–T7 by the `UserPromptSubmit` hook. The `<architectus-tier>` block is the ground truth for this turn — do not argue with it; use `/architectus:reclassify` to override.

| Tier | Behavior |
|------|----------|
| T1 | Answer directly. No plan, no tests. |
| T2 | Implement the mechanical change. Run `/simplify`. No formal plan. |
| T3 | Brief written plan (Context + Approach + Files + Steps). Implement. `/simplify`. |
| T4 | `/architectus:plan-with-testing`. Implement. Argus validates. `/architectus:quality-gate` before declaring done. |
| T5 | `/architectus:plan-with-testing` with `ultrathink`. Argus validation mandatory. `/architectus:quality-gate`. |
| T6 | `/architectus:plan-with-testing` required. Spawn Explorator first to map load-bearing files. Argus mandatory. `/architectus:quality-gate`. |
| T7 | Fresh architectural planning — ignore prior assumptions. Explorator first. `/architectus:plan-with-testing` from scratch. Argus mandatory. |

## Advisor

`advisor()` is globally set to Opus. Call it:

- Before substantive T3+ work (after orientation, before committing to an approach)
- Before declaring a task done (after making the deliverable durable)
- When stuck (errors recurring, approach not converging)
- When considering a change of approach

On short reactive turns dictated by the last tool result, skip the advisor — it adds the most value at decision points, not line-by-line.

## Three-strike rule

When Argus reports `overall: fail`:

1. Record a strike: `bash /Users/ggomes/.claude/architectus/scripts/strikes-util.sh record-failure <issue-slug> "<one-line reason>"`
2. If strikes for that slug reach 3, STOP retrying. Escalate via `/architectus:rootcause <issue-slug>`.
3. On `overall: pass`: clear strikes for the slug.

`issue-slug` format: `<git-branch>-<6-char-hash-of-first-60-prompt-chars>`. Keep it consistent across retries so strikes accumulate.

## Quality-gate discipline (T4+)

Never declare a T4+ task complete without running `/architectus:quality-gate`:

1. `/simplify` on changed code
2. Restart dev environment if runtime code changed (use the Dev Environment section of `.claude/project-classifier.md`)
3. Spawn Argus with the Testing Plan
4. On fail → record strike; if ≥3 → `/architectus:rootcause`
5. On pass → clear strikes for slug; summarize to user

## Memory

Two layers are active:

- **Claude Code native auto-memory** — `~/.claude/projects/<slug>/memory/MEMORY.md` indexes facts across sessions. Writes happen automatically; read relevant entries when they match the task.
- **Memory compiler** — `~/.claude/memory-compiler/` captures transcripts on Stop/PreCompact and maintains structured, cross-referenced knowledge articles. Consult compiled lessons before planning T3+ work.

If `~/.claude/memory-compiler/` is empty, the compiler layer is off and the global hooks no-op safely.

## Compaction

- `/compact` at 75% context on long tasks
- `/clear` between unrelated tasks
- After `/clear`, re-issue `/loop 40m /architectus:heartbeat` (the SessionStart hook reminds you)

## Hygiene

- No emoji in UI code (global CLAUDE.md rule)
- Never destructive actions on Ekoa production services without explicit user confirmation (global CLAUDE.md rule)
- Prefer editing existing files to creating new ones
- Short, concrete final messages — the diff speaks for itself
