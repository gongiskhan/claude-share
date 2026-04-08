---
name: dev
description: "Development workflow for coding tasks using agent teams. MUST be invoked for ANY coding task beyond trivial complexity. This includes: implementing features, refactoring code, building new apps or modules, complex bug fixes, repeated bug fix iterations, adding integrations, migrating code, restructuring projects, creating APIs, building UI components, setting up infrastructure, writing complex scripts, and any task requiring multiple files or coordinated changes. Do NOT invoke ONLY for: single-line edits, trivial typo fixes, small doc edits, running a simple bash command, reading/explaining code without changes, or answering a direct question. When in doubt, invoke this skill -- it is better to use it unnecessarily than to skip it when needed."
---

# Dev Workflow

Execute coding tasks through agent teams with mandatory quality gates.

## Hard Rules

Non-negotiable. Every invocation of this skill MUST follow these.

1. **Create an agent team.** Single-agent execution is not allowed for this workflow.
2. **The main agent (you) MUST NOT do implementation, testing, or other task work directly.** Your only job: create the team, spawn the team lead and teammates, monitor progress, and clean up when done. ALL work -- coding, testing, reviewing, documenting -- is done by agents in the team. This keeps the main context window clean.
3. **The team lead MUST NOT do any work either.** The team lead is a coordinator: it holds knowledge of what needs to be done, breaks down tasks, assigns them to teammates, tracks progress, resolves blockers, and synthesizes results. It never writes code, never runs tests, never edits files. It delegates everything to specialized teammates who talk to each other directly.
4. **A tester agent is ALWAYS required.** See the Quality Gates section below. The tester is the critical gate for completion -- nothing is done until the tester confirms.
5. **The task is NOT complete until the tester validates it thoroughly.** No exceptions. No assumptions. No "it should work." Only confirmed with evidence (screenshots, test output, logs).

## Quality Gates (Non-Negotiable)

The tester agent is the final authority on whether a task is complete. The tester MUST:

1. **Use the `/e2e-testing` skill** for web application testing (playwright-cli for web apps, `mcp__electron__*` tools for Electron apps, simulator screenshots for Capacitor apps).
2. **Check `.env` for `UI_PORT`** before testing any web app -- never assume the port.
3. **Test ALL stated requirements** -- every single one, individually verified.
4. **Test for regressions** in related areas that the changes may have affected.
5. **Capture screenshots** as proof for every test assertion. Screenshots are mandatory evidence.
6. **Iterate with the implementer** when tests fail. The tester reports failures with details (what failed, screenshots, expected vs actual). The implementer fixes. The tester re-tests. This loop continues until ALL tests pass.
7. **Never approve partial completion.** If 9 out of 10 requirements pass but 1 fails, the task is not done.
8. **Report the final test results** with screenshots to the team lead before the task is marked complete.
9. **Use codex-test as the primary testing tool.** The tester MUST use `/codex-test` skill first (Codex CLI + playwright-cli in headed mode). Fall back to direct playwright-cli only if Codex fails. Do NOT use `mcp__claude-in-chrome__*` tools unless both codex-test and playwright-cli fail.

### Authentication Strategy for Testing

When the app requires login, the tester should try in this order:
1. Connect to existing browser session via CDP (`playwright-cli --cdp 9222`)
2. Load saved auth state (`playwright-cli state load`)
3. If neither works, open a headed browser (`playwright-cli open <url> --headed`) and ask the user to log in before continuing

### Platform-Specific Testing

| Platform | Testing Tool | Notes |
|----------|-------------|-------|
| Web apps | `playwright-cli` via `/e2e-testing` skill | Default approach |
| Electron | `mcp__electron__*` MCP tools | `take_screenshot`, `send_command_to_electron`, `read_electron_logs` |
| Capacitor | Simulator screenshots | Do NOT use playwright-cli; use `./scripts/screenshot.sh` |

## Workflow

### Phase 1: Understand

Before creating the team, quickly assess:
- What is the task? What are the explicit requirements?
- What project type is this? (Next.js, Node.js, Electron, Capacitor, other)
- What is the current state? (What exists, what is broken, what needs to change)
- How complex is this? (Determines team size)

### Phase 2: Create the Team

Create an agent team with at minimum a team lead and a tester. Beyond that, decide the right composition based on task complexity:

**Always required:**
- **Team Lead** -- coordinates in delegate mode. Breaks down work, assigns tasks, tracks progress. Never writes code.
- **Tester** -- uses `/e2e-testing` skill. Validates everything. The quality gate.

**Spawn as needed based on the task:**
- **Implementer(s)** -- writes the code. For larger tasks, spawn multiple with distinct file ownership to avoid conflicts.
- **Planner/Architect** -- for non-trivial tasks, have an agent analyze the codebase and design the approach before anyone writes code.
- **UI Agent** -- when the task touches frontend, use an agent that invokes `/polish-ui` and `/frontend-design` skills to ensure professional, responsive results.
- **Docs Agent** -- for significant changes, an agent that keeps CLAUDE.md minimal (index with links) and puts detailed docs in `docs/` folder.

Let the team lead decide the exact breakdown and sequencing. Teammates talk to each other directly.

### Phase 3: Execute

The team lead coordinates execution:
1. If a planning phase is warranted, the planner analyzes first and shares findings with the team.
2. Implementer(s) build the solution. Multiple implementers get distinct file ownership.
3. If UI work is involved, the UI agent reviews and polishes.
4. The tester validates everything against requirements + regressions.
5. If tests fail, the tester reports back to implementer(s). They fix. Tester re-tests.
6. This continues until the tester confirms ALL tests pass with screenshots.

### Phase 4: Confirm and Clean Up

Only when the tester reports all tests passing with evidence:
1. Team lead confirms all agents have completed their work.
2. Docs agent (if present) has updated documentation.
3. Clean up the team.
4. Report results to the user with a summary of what was done and test evidence.

## Preferences

These describe how the user likes to work. Not rules -- use judgment on when they apply.

- **Frontend quality matters.** When a task touches UI, prefer a dedicated agent using `/polish-ui` and `/frontend-design` skills. Avoid generic AI aesthetics.
- **Plan before building.** For non-trivial tasks, a planning phase before implementation produces better results.
- **Document significant changes.** Keep CLAUDE.md minimal (index with links). Detailed docs go in `docs/` folder covering architecture, functionality, and API changes.
- **Common stacks:** Next.js, Node.js, Electron, Capacitor. Agents should be aware of these ecosystems.
- **Distinct file ownership** for multiple implementers to avoid conflicts.

## Complexity Guide

Use this to calibrate team size and approach:

| Complexity | Examples | Team Size | Planning Phase? |
|-----------|---------|-----------|----------------|
| Moderate | Single-component feature, focused refactor, API endpoint | Lead + 1 implementer + tester | Optional |
| Medium | Multi-file feature, new module, cross-cutting refactor | Lead + 1-2 implementers + tester + optional UI agent | Recommended |
| Complex | Full-stack feature, new subsystem, major refactor | Lead + 2-3 implementers + tester + planner + optional UI/docs agents | Yes |
| Major | New app, large migration, architecture overhaul | Lead + 3+ implementers + tester + planner + UI + docs agents | Yes |
