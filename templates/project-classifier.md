# Project Classifier: <project-name>

<!-- This file lives at .claude/project-classifier.md in each project root.
     Pericles reads it on session start to calibrate routing decisions.
     Spartacus fills it in during /plan initialization. Keep it accurate and terse. -->

## Summary

<!-- One short paragraph: what the project does, the primary tech stack, and rough
     size (e.g. "~20 files, no external deps" or "medium Rails monolith, Postgres, Redis").
     This is the single most important section — it anchors every routing decision. -->

<what-the-project-does>. Built with <tech-stack>. Approximately <size-and-complexity>.

## Default Minimum Tier

<!-- Pick a number 1–7 and give a one-sentence justification.
     Rule of thumb: small/isolated = 1–2, medium/interconnected = 3–4, large/critical = 5–7. -->

<tier-number> — <one-sentence-justification>

## Classification Overrides

<!-- List patterns where the default tier is wrong. Format:
     - <keyword or area> -> minimum tier <N>: <why>
     Omit this section entirely if no overrides are needed. -->

- <area-or-keyword> -> minimum tier <N>: <rationale>
- <area-or-keyword> -> minimum tier <N>: <rationale>

## Testing Setup

<!-- Be specific. Argus uses this to start the environment before running checks. -->

- Dev server: `<start-command>`
- Test command: `<test-command-or-"none">`
- Health check: `<URL-or-log-pattern>`
- Playwright config: `<path-or-"none">`
- Preconditions: `<required-state-or-"none">`

## Key Files

<!-- path: purpose — list only architecturally load-bearing files, not every file. -->

- `<path>`: <purpose>
- `<path>`: <purpose>

## Common Task Patterns

<!-- Recurring work categories and the tier they typically warrant.
     Helps Pericles tune routing for this project's specific shape. -->

- <task-type>: tier <N> — <why>
- <task-type>: tier <N> — <why>
