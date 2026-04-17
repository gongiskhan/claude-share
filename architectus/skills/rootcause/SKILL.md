---
name: rootcause
description: Deep investigation when Argus has failed the same issue 3+ times. Escalates beyond patching symptoms — traces the issue to its architectural origin. Runs in a forked context with max effort. Invoke with /architectus:rootcause <issue-slug>.
context: fork
agent: general-purpose
effort: max
disable-model-invocation: true
argument-hint: "<issue-slug>"
---

# Root Cause

You are investigating issue `$0` exhaustively. This skill runs in a forked context — you do not share history with the parent session. The parent is waiting for a structured diagnosis.

ultrathink

## Context

The parent session has attempted to fix this issue at least three times and Argus has reported failure each time. Patching symptoms has not worked. Your job is to find the ACTUAL root cause — the underlying architectural reason the surface symptom keeps recurring — and propose a fix that addresses it, not a variant of what was already tried.

## Inputs available to you

- `.claude/architectus/strikes.json` — read the full failure history for `$0`
- Git history — `git log --all --oneline` to see what was already tried
- The plan file at `.claude/plans/*$0*.md` if one exists
- The full codebase via Read/Grep/Glob

## Investigation protocol

1. **Read the strike record.** Load `.claude/architectus/strikes.json`. Extract every failure reason for issue `$0`. Note timestamps and the span of time this has been live.
2. **Reconstruct the attempts.** Use `git log --all --since="<first_seen>"` to find commits that touched related files. For each attempt, identify: what was changed, why the fix was thought to work, what Argus saw when it failed.
3. **Look for the common thread.** The three+ failures almost always share structure: same file, same abstraction, same missing test coverage, same assumption. State the pattern explicitly.
4. **Name the root cause.** Not the symptom. Not a near-cause. The architectural reason the bug persists. Examples of good root causes:
   - "The component reads state from two sources of truth"
   - "The test suite never exercises the code path the bug lives on"
   - "The abstraction conflates two concerns and every fix breaks the other"
5. **Call advisor()** with a summary of the common thread and your proposed root cause. Treat the advisor's input seriously — they may see a different root cause than you.
6. **Propose an approach.** If the root cause implies a larger architectural change (T6/T7), say so. The fix should make this class of bug impossible, not just fix this instance.

## Output

Return to the parent session as your final message:

```
issue_slug: $0
symptoms:
  - "<what the user observed at each failure>"
common_thread: |
  <one paragraph describing the shared structure across all failures>
root_cause: |
  <one paragraph naming the underlying reason>
proposed_approach:
  tier: T<n>
  summary: "<one-line approach>"
  files: ["<path>", "<path>"]
  risk: "<highest risk of this approach>"
  test_plan_sketch: |
    <a rough Testing Plan for the parent to expand via /architectus:plan-with-testing>
advisor_feedback: "<one-line summary of what advisor() said, or 'skipped' if not called>"
confidence: low | medium | high
```

Do not patch code. Do not edit files. The parent session decides whether to act on your diagnosis.
