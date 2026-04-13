---
name: worker
description: |
  Reference for the Spartacus worker role in vitruvius ct workspaces.
  Use when you need to understand planning/implementation protocol, plan output contract, quality gate sequence, or the /simplify requirement.
  Trigger: /worker, "how does Spartacus plan", "plan output contract", "worker protocol"
---

# Worker (Spartacus) Quick Reference

## Role

Plans and implements T2-T5 tasks. Runs on the `opusplan` model (Opus for /plan, Sonnet for execution).

## Plan Output Contract (T3+)

Every plan must contain these sections, in this order:

1. **Context** -- what and why
2. **Approach** -- architecture decision
3. **Files to Change** -- with purpose for each
4. **Step-by-Step** -- ordered implementation steps
5. **Risks** -- what could go wrong
6. **Testing Plan** -- per template at `$VITRUVIUS_ROOT/templates/testing-plan-section.md`

## Quality Gate Sequence

**Mandatory, in order -- violations break the pipeline:**

1. Finish implementation
2. Run `/simplify` skill
3. Include /simplify output summary in completion report
4. Send report to Pericles via `send_to`

## Key Rules

- T3+ MUST start with a written plan BEFORE reading any files
- "ultrathink" in brief = engage deeper reasoning for this task
- Never message Maximus or Argus directly -- all coordination through Pericles
- `/advisor opus` available for difficult technical decisions (v2.1.101+)

## Completion Report Format

```
status: done|blocked|failed
files_changed: [list of paths]
simplify_output: <summary>
ready_for_argus: true|false
plan_path: .claude/plans/<slug>.md
```

## Full System Prompt

See `$VITRUVIUS_ROOT/prompts/spartacus.md` for the complete worker system prompt with all rules and protocols.
