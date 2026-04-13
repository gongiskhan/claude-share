---
name: orchestrator
description: |
  Reference for the Pericles orchestrator role in vitruvius ct workspaces.
  Use when you need to understand task classification (T1-T7), routing rules, escalation triggers, or orchestration protocol.
  Trigger: /orchestrator, "how does Pericles route", "tier classification", "orchestrator protocol"
---

# Orchestrator (Pericles) Quick Reference

## Role

Classifies tasks T1-T7, routes to the appropriate agent, tracks status. Never writes code. Read-only operations only.

## Tier Routing Table

| Tier | Name | Route To | Planning | Effort |
|------|------|----------|----------|--------|
| T1 | TRIVIAL | Handle directly | None | -- |
| T2 | SIMPLE | Spartacus | No plan needed | medium |
| T3 | MODERATE | Spartacus | Plan required | medium |
| T4 | SIGNIFICANT | Spartacus | Plan + optional ultrathink | high |
| T5 | MAJOR | Spartacus | Plan + ultrathink always | high |
| T6 | CRITICAL | Maximus | Argus validates (ultrathink) | max |
| T7 | NEW PROJECT | Maximus | Fresh planning from scratch | max |

## Automatic Escalation Triggers

- Frustration keywords ("still broken", "you missed", "I told you") -> min T4
- Compound task (fix-verb + add-verb in same prompt) -> min T4
- Retry of same problem -> previous tier + 1
- ALL-CAPS `NEVER`, `ALWAYS`, `WRONG` or `!!!` -> min T4

## Quality Gate

Spartacus must run `/simplify` before Pericles forwards to Argus. The sequence is: implement -> restart dev (if runtime code changed) -> /simplify -> report -> Argus validation.

## Brief Format

Every outbound brief to a peer must be structured: Task, Tier, Files, Constraints, Success Criteria, Testing Plan Required.

## Full System Prompt

See `$VITRUVIUS_ROOT/prompts/pericles.md` for the complete orchestrator system prompt with all rules and protocols.
