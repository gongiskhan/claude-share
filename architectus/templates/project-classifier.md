# Project Classifier: <project-name>

<!-- This file lives at .claude/project-classifier.md in each project root.
     The Architectus UserPromptSubmit classifier reads the Default Minimum Tier
     as a floor on every prompt. The SessionStart hook surfaces the rest of
     this file so the main session can ground routing decisions.
     Keep it accurate and terse. -->

## Summary

<!-- One short paragraph: what the project does, the primary tech stack, and rough
     size (e.g. "~20 files, no external deps" or "medium Rails monolith, Postgres, Redis").
     This is the single most important section — it anchors every routing decision. -->

<what-the-project-does>. Built with <tech-stack>. Approximately <size-and-complexity>.

## Default Minimum Tier

<!-- Pick a number 1–7 and give a one-sentence justification.
     Rule of thumb: small/isolated = 1–2, medium/interconnected = 3–4, large/critical = 5–7.
     Format must be either "T<n> — ..." or "<n> — ..." on its own line so the hook can parse it. -->

T<tier-number> — <one-sentence-justification>

## Classification Overrides

<!-- List patterns where the default tier is wrong. Format:
     - <keyword or area> -> minimum tier <N>: <why>
     Omit this section entirely if no overrides are needed. -->

- <area-or-keyword> -> minimum tier <N>: <rationale>
- <area-or-keyword> -> minimum tier <N>: <rationale>

## Dev Environment

<!-- How to start, restart, and verify the dev environment for this project.
     The main session uses this to ensure services are live before running /architectus:quality-gate.
     Fill in what applies; delete what doesn't. -->

- Start command: `<e.g. npm run dev, docker-compose up, make serve>`
- Ports: `<e.g. 3111 (UI), 4111 (API)>`
- Health check: `<URL like http://localhost:3111 or port lsof check>`
- Restart strategy: `<"kill and re-run start command" or path to a restart script>`
- Env file: `<.env path or "none">`
- Startup time: `<approximate seconds until healthy, e.g. "~8s">`

## Testing Setup

<!-- How Argus runs validation. Dev environment must be running first. -->

- Test command: `<test-command-or-"none">`
- Playwright config: `<path-or-"none">`
- Preconditions: `<required-state-or-"none">`

## Key Files

<!-- path: purpose — list only architecturally load-bearing files, not every file. -->

- `<path>`: <purpose>
- `<path>`: <purpose>

## Common Task Patterns

<!-- Recurring work categories and the tier they typically warrant.
     Helps the classifier tune routing for this project's specific shape. -->

- <task-type>: tier <N> — <why>
- <task-type>: tier <N> — <why>
