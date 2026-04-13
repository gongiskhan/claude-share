---
name: classify
description: |
  Task classification reference for vitruvius ct workspaces.
  Use to understand the T1-T7 tier system, escalation signals, routing decisions, and project classifier format.
  Trigger: /classify, "what tier is this", "task classification", "tier system"
---

# Task Classification (T1-T7)

## Tier Definitions

| Tier | Name | Description | Agent | Model | Effort |
|------|------|-------------|-------|-------|--------|
| T1 | TRIVIAL | Questions, lookups, status checks | Pericles (direct) | sonnet | medium |
| T2 | SIMPLE | Single-line mechanical changes | Spartacus | opusplan | high |
| T3 | MODERATE | Single-component bug fix or small feature | Spartacus (plan first) | opusplan | high |
| T4 | SIGNIFICANT | Multi-file, compound fix+feature, retries | Spartacus (plan + ultrathink) | opusplan | high |
| T5 | MAJOR | New module, 10+ files, architectural touch | Spartacus (plan + ultrathink always) | opusplan | high |
| T6 | CRITICAL | Architectural change, high risk, large scope | Maximus | opus[1m] | max |
| T7 | NEW PROJECT | Entire new project or full rewrite | Maximus (fresh plan) | opus[1m] | max |

## Automatic Escalation Triggers

**Frustration signals -> minimum T4:**
- "like I asked", "I told you", "you missed", "you forgot", "you ignored"
- "should have", "still not", "still broken", "still wrong", "not working yet"
- `!!!` (triple exclamation)
- `NEVER`, `ALWAYS`, `WRONG` in uppercase

**Compound task -> minimum T4:**
- Contains BOTH a fix-verb (fix, correct, repair, debug, broken, bug) AND an add-verb (add, create, build, implement, new feature)

**Retry escalation -> previous tier + 1:**
- Same problem routed again after Argus failure or user "still not working"

## Project Classifier

Each project can have a `.claude/project-classifier.md` that sets a minimum tier floor and provides dev environment details. Template at `$VITRUVIUS_ROOT/templates/project-classifier.md`.

Key sections: Summary, Default Minimum Tier, Classification Overrides, Dev Environment, Testing Setup, Key Files, Common Task Patterns.

## Validation Gate

After implementation, the pipeline is: implement -> restart dev (if runtime code changed) -> /simplify -> report to Pericles -> Argus validation (T4+).
