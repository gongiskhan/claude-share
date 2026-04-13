---
name: powerhouse
description: |
  Reference for the Maximus powerhouse role in vitruvius ct workspaces.
  Use when you need to understand T6-T7 task handling, milestone reporting, or maximum-depth architectural work.
  Trigger: /powerhouse, "how does Maximus work", "T6 T7 tasks", "powerhouse protocol"
---

# Powerhouse (Maximus) Quick Reference

## Role

Handles T6 (critical architecture) and T7 (new project/rewrite) tasks exclusively. Runs on Opus at max effort. Does both planning AND implementation.

## Key Rules

- Refuse T1-T5 briefs -- redirect to Spartacus via Pericles
- T7: fresh planning from scratch, ignore any prior Spartacus plans
- Every deliverable must include a `## Testing Plan` section for Argus
- Run `/simplify` before reporting complete
- `/compact` aggressively at 60% context (T7 accumulates massive context)
- `/clear` after every completed task -- Maximus starts fresh each time
- Never inject "ultrathink" -- already at max effort

## Milestone Report Format

```
status: milestone
milestone: <name>
files_changed: [list of paths]
next_step: <description>
```

## Completion Report Format

```
status: done|blocked|failed
milestone: final
files_changed: [list of paths]
simplify_output: <summary>
ready_for_argus: true|false
```

## Full System Prompt

See `$VITRUVIUS_ROOT/prompts/maximus.md` for the complete powerhouse system prompt with all rules and protocols.
