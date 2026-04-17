---
name: plan-with-testing
description: Produce a structured plan that MUST include a ## Testing Plan section Argus can execute verbatim. Use for T3+ tasks. Invoke with /architectus:plan-with-testing or phrases like "make a plan with tests".
effort: high
argument-hint: "[slug]"
---

# Plan With Testing

Write a plan with these sections, in order. Do not skip any. Do not reorder.

ultrathink

## Required sections (in order)

1. **Context** — why this change, the problem it addresses
2. **Approach** — the architectural decision and why
3. **Files to Change** — absolute path + one-line purpose per file
4. **Step-by-Step** — ordered, concrete implementation steps
5. **Risks** — what could break, mitigations
6. **Testing Plan** — follow the template at `/Users/ggomes/.claude/architectus/templates/testing-plan-section.md` verbatim. Every VERIFY line must be directly observable (visible text, HTTP status, test pass/fail). Argus will execute this section step-by-step — if Argus cannot do so deterministically, the plan is incomplete.

## Save location

Save the plan to `.claude/plans/<slug>.md` in the project. If `$0` is provided, use it as the slug. Otherwise derive one from the current task (`<git-branch>-<short-hash-of-task-summary>`). If `.claude/plans/` does not exist, create it.

## Project classifier bootstrap

If `.claude/project-classifier.md` does not exist in the project, the very first plan you write is the project-classifier itself. Use the template at `/Users/ggomes/.claude/architectus/templates/project-classifier.md`. Fill in every section using what you've learned about the project. Save to `.claude/project-classifier.md`, not `.claude/plans/`. Then return — do not proceed to the user's actual planning task in the same turn.

## Quality bar

- No vague "works as expected" VERIFY lines
- No VERIFY lines that merely restate the action (e.g. "click button; VERIFY: button was clicked")
- Regression checks must name the feature area and the observable signal
- If the change touches UI, include Browser Flows with exact selectors
- Include Test Commands only if the project has a real test suite

## Advisor gate for T5+

If the task is T5 or higher, call `advisor()` after drafting the plan and before saving. Incorporate the advisor's response into the plan or explicitly note why you chose not to.

## Output

Save the plan file, then emit a one-line confirmation:

```
Plan saved to <path>. <n> steps, <m> verify checks. Ready for implementation.
```

Do not paste the full plan into the transcript — the file is the artifact.
