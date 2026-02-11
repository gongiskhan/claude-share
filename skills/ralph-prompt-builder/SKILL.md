---
name: ralph-prompt-builder
description: Build structured prompts for the /ralph-loop:ralph-loop command using Claude Code agent teams. Use when user asks to create a ralph-loop prompt, build an agentic loop task, automate a feature with browser verification, or run a task with Chrome extension testing. Always spawns agent teams with specialized roles for implementation, testing, UI/UX, and documentation.
---

# Ralph Loop Prompt Builder (Agent Teams Edition)

Build `/ralph-loop:ralph-loop` prompts that leverage **Claude Code agent teams** for parallel development.

## Hard Rules

These are non-negotiable. Everything else is guidance.

1. **Every ralph-loop prompt MUST create an agent team.** Single-agent execution is not allowed.
2. **The main agent (you) MUST NOT do any implementation, testing, or other task work directly.** Your only job is to: create the team, spawn the team lead and teammates, and clean up the team when done. ALL actual work - coding, testing, reviewing, documenting - is done by agents in the team. This keeps the main agent context window clean and avoids bloating it with implementation details.
3. **The team lead MUST NOT do any work either.** The team lead is a coordinator: it holds knowledge of what needs to be done, breaks down tasks, assigns them to teammates, tracks progress, resolves blockers, and synthesizes results. It never writes code, never runs tests, never edits files. It delegates everything to specialized teammates who talk to each other directly.
4. **A tester agent is ALWAYS required.** It uses the `/e2e-testing` skill (mcp__claude-in-chrome__* tools). It iterates with other agents until ALL tests pass - task features AND related area regressions. Screenshots are required as proof. The tester is the critical gate for completion.
5. **The promise MUST NOT be output until the tester confirms full test passage.** No exceptions. No assumptions. No "it should work" - only confirmed with screenshots.
6. **For Capacitor apps, do NOT use Chrome MCP tools.** Use simulator screenshots instead.

## Our Preferences (not rules - Claude Code should use its judgment)

These describe how we like to work. Include them in the prompt as context for Claude Code to consider when assembling the team:

- **We care a lot about frontend quality.** When a task touches UI, we prefer having a dedicated agent that uses the `/polish-ui` and `/frontend-design` skills to ensure the result looks professional, is responsive, and avoids generic AI aesthetics.
- **Planning before implementation is valuable.** For non-trivial tasks, having an agent analyze the codebase and design the approach before anyone writes code tends to produce better results.
- **Documentation matters for significant changes.** We prefer a docs agent that keeps CLAUDE.md minimal (just an index with links) and puts detailed documentation in a `docs/` folder covering architecture, functional details, and API changes.
- **We mostly work on Next.js apps, Node.js backends, and Capacitor mobile apps.** Agents should be aware of these ecosystems.
- **Multiple implementers should have distinct file ownership** to avoid conflicts.

## What Claude Code Decides

The prompt should explicitly tell Claude Code to **decide for itself**:

- How many agents to spawn (beyond the mandatory team lead and tester)
- Which additional roles to fill
- How to structure the work and dependencies between agents
- What instructions each agent needs
- When a planning phase is warranted vs diving straight in

Do not micromanage the team structure. Describe the task, state our preferences, enforce the hard rules, and let Claude Code figure out the best team composition.

## Prompt Building Workflow

1. Get task description from user
2. If user provides screenshot/image, ask them to describe it in text (Claude Code cannot see images)
3. Identify project type (Next.js / Node.js / Capacitor)
4. Generate the prompt incorporating hard rules, preferences as context, and task details
5. **Present TWO versions** (see Output Format below)

## Output Format (MANDATORY)

**You MUST always present the prompt in TWO formats. This is not optional.**

### 1. Human-Readable Version

Present the prompt formatted with line breaks, indentation, and sections so the user can review and understand it. Use a fenced code block:

```
/ralph-loop:ralph-loop "[TASK TITLE].

PLAN FIRST then AUTO-ACCEPT and implement without waiting for confirmation.

DELEGATION RULE: You (the main agent) MUST NOT do any implementation,
testing, or task work directly. Your ONLY job is to create the agent
team, spawn the team lead and teammates, then wait. All actual work
happens inside the team. This keeps your context window clean.

AGENT TEAM SETUP:
Create an agent team for this task. Spawn a team lead that uses
delegate mode - the team lead coordinates ONLY: it breaks down work,
assigns tasks, tracks progress, and synthesizes results, but NEVER
writes code, runs tests, or edits files. All work is done by
specialized teammates that the team lead spawns and coordinates.
Teammates talk to each other directly.
Decide the right number and types of teammates based on the task
complexity. [Preferences context]. A tester agent is REQUIRED...

CONTEXT:
[Current state...]

REQUIREMENTS:
1) ...
2) ...

TESTER INSTRUCTIONS:
[Tester hard rules...]

COMPLETION:
The team lead outputs <promise>TAG</promise> ONLY when the tester
confirms ALL tests pass with screenshots and all other agents
confirm done. Then clean up the team."
--max-iterations [N]
--completion-promise "TAG"
```

### 2. Copy-Paste Version

Immediately after, present the **exact same content** collapsed into a single line inside a fenced code block, prefixed with:

**Copy-paste version (single line):**

**Both versions MUST contain identical content.** The readable version is for review, the copy-paste version is for execution. Always present both.

## Prompt Structure

### Required Elements

1. **Include** `PLAN FIRST then AUTO-ACCEPT and implement without waiting for confirmation`
3. **Agent team setup** - tell Claude Code to create a team, state preferences, let it decide composition
4. **Context** - describe current state, what works, what is broken
5. **Requirements** - numbered list
6. **Tester instructions** - MUST use /e2e-testing skill, MUST check .env for UI_PORT, MUST iterate until ALL pass with screenshots
7. **Completion** - promise ONLY after tester confirms AND all other agents confirm done, then clean up team

### Syntax Rules

- Prompt wrapped in double quotes
- No single quotes or apostrophes inside (use `do not` not `don't`)
- Avoid backticks, dollar signs, special shell characters
- Completion tag: SCREAMING_SNAKE_CASE, must match `--completion-promise` exactly
- Copy-paste version on ONE line

### Iteration Guidance (approximate)

Simple ~5-7 | Medium ~8-12 | Complex ~12-18 | Major ~18-25

## Examples

### Example 1: Simple Bug Fix

```
/ralph-loop:ralph-loop "Fix sidebar navigation scrolling on smaller screens. PLAN FIRST then AUTO-ACCEPT and implement without waiting for confirmation. DELEGATION RULE: You (the main agent) MUST NOT do any implementation or testing directly. Create the agent team and let it handle everything. Your only job is team setup and cleanup. AGENT TEAM SETUP: Create an agent team for this task. Spawn a team lead in delegate mode - it coordinates only, never writes code. This is a simple bug fix so keep the team lean - but you must include a tester. We care about frontend quality so consider if a UI polish pass is warranted. This is a Next.js project. Teammates talk to each other directly. CONTEXT: Sidebar navigation shows logo at top, menu icons for pages, and user avatar at bottom. On smaller viewport heights, bottom items are cut off with no scrolling. REQUIREMENTS: 1) Add vertical scrolling to sidebar nav area, 2) Hide scrollbar visually with CSS, 3) Keep logo fixed at top, 4) Only modify sidebar component. TESTER INSTRUCTIONS: A tester agent MUST be spawned that invokes the /e2e-testing skill. FIRST check .env for UI_PORT. Test: 1) Navigate to app on UI_PORT, 2) Resize viewport to 1440x600 and verify all sidebar items accessible by scrolling, 3) Resize to 1440x900 and verify normal view still works, 4) Take screenshots of both. Report failures to implementer. Only confirm when ALL pass with screenshots. COMPLETION: The team lead outputs <promise>SIDEBAR_SCROLL_FIXED</promise> ONLY when tester confirms ALL tests pass with screenshots and all agents confirm done. Then clean up the team." --max-iterations 7 --completion-promise "SIDEBAR_SCROLL_FIXED"
```

### Example 2: Medium Feature

```
/ralph-loop:ralph-loop "Add user profile settings page with avatar upload and theme preferences. PLAN FIRST then AUTO-ACCEPT and implement without waiting for confirmation. DELEGATION RULE: You (the main agent) MUST NOT do any implementation or testing directly. Create the agent team and let it handle everything. Your only job is team setup and cleanup. AGENT TEAM SETUP: Create an agent team for this task. Spawn a team lead in delegate mode - it coordinates only, never writes code. This is a medium-complexity feature with significant UI work. Our preferences: we care a lot about frontend quality (consider using /polish-ui and /frontend-design skills). This is a Next.js App Router project using Tailwind CSS and shadcn/ui. Decide the right teammates to spawn. Teammates talk to each other directly. CONTEXT: The app has a settings section at /settings but no profile page yet. Auth is handled via NextAuth with session management. REQUIREMENTS: 1) Create /settings/profile page, 2) Add avatar upload with preview, 3) Add theme preference toggle (light/dark/system), 4) Add display name edit field, 5) Save changes via API route, 6) Show success/error feedback. TESTER INSTRUCTIONS: A tester agent MUST be spawned that invokes the /e2e-testing skill. FIRST check .env for UI_PORT. Test all requirements plus regression test /settings and navigation. Take screenshots of each test. Report failures with details. Iterate until ALL pass. COMPLETION: The team lead outputs <promise>PROFILE_SETTINGS_DONE</promise> ONLY when tester confirms ALL tests pass with screenshots and all agents confirm done. Then clean up the team." --max-iterations 12 --completion-promise "PROFILE_SETTINGS_DONE"
```

### Example 3: Complex Feature

```
/ralph-loop:ralph-loop "Implement real-time notifications system with in-app bell icon, notification panel, and mark-as-read functionality. PLAN FIRST then AUTO-ACCEPT and implement without waiting for confirmation. DELEGATION RULE: You (the main agent) MUST NOT do any implementation or testing directly. Create the agent team and let it handle everything. Your only job is team setup and cleanup. AGENT TEAM SETUP: Create an agent team for this task. Spawn a team lead in delegate mode - it coordinates only, never writes code. This is a complex full-stack feature. Our preferences: a planning phase would be valuable before implementation starts, we care about frontend quality (consider /polish-ui and /frontend-design skills), this is significant enough to warrant documentation updates (keep CLAUDE.md minimal with links, put details in docs/ folder). This is a Next.js 14 App Router project with Prisma ORM and PostgreSQL. If using multiple implementers, assign distinct file ownership to avoid conflicts. Decide the right teammates to spawn. Teammates talk to each other directly. CONTEXT: No notification system exists yet. Auth via NextAuth. REQUIREMENTS: 1) Database schema for notifications, 2) API routes for fetching, creating, marking as read, 3) Bell icon in header with unread count badge, 4) Notification dropdown panel, 5) Mark individual or all as read, 6) Real-time updates via polling or SSE. TESTER INSTRUCTIONS: A tester agent MUST be spawned that invokes the /e2e-testing skill. FIRST check .env for UI_PORT. Test all requirements including empty state. Regression test header nav and other pages. Report failures with screenshots. Iterate until ALL pass. COMPLETION: The team lead outputs <promise>NOTIFICATIONS_DONE</promise> ONLY when tester confirms ALL tests pass with screenshots and all agents confirm done. Then clean up the team." --max-iterations 18 --completion-promise "NOTIFICATIONS_DONE"
```

## Capacitor Apps

For Capacitor shell apps, the testing approach is different. Include this context:

- This is a Capacitor shell app that loads remote websites via CSS/JS injections
- Do NOT use Chrome MCP tools for testing - use simulator screenshots and user verification
- CSS fixes go in `dev-server/adjustments/css/`, JS fixes in `dev-server/adjustments/js/`
- DEV_MODE is in `ios/App/App/Info.plist`
- Verification loop: make change -> wait for hot reload -> screenshot -> user confirms
- Finalization: set DEV_MODE=false, run `yarn finalize:bundle && npx cap sync`, verify without dev server, commit and push

### Capacitor Example

```
/ralph-loop:ralph-loop "Fix bottom navigation overlap on Cinepolis USA mobile view. PLAN FIRST then AUTO-ACCEPT and implement without waiting for confirmation. DELEGATION RULE: You (the main agent) MUST NOT do any implementation or testing directly. Create the agent team and let it handle everything. Your only job is team setup and cleanup. AGENT TEAM SETUP: Create an agent team for this task. Spawn a team lead in delegate mode - it coordinates only, never writes code. This is a Capacitor shell app - do NOT use Chrome MCP tools for testing, use simulator screenshots instead. All fixes are CSS/JS injections - we do not control source HTML. Decide the right teammates for a mobile CSS fix. Teammates talk to each other directly. CONTEXT: Key files: CSS fixes in dev-server/adjustments/css/, JS fixes in dev-server/adjustments/js/, DEV_MODE in ios/App/App/Info.plist. The bottom navigation bar overlaps with the native tab bar on smaller iPhones. REQUIREMENTS: 1) Add bottom padding to prevent overlap, 2) Only affect mobile viewport widths, 3) Test on iPhone SE size. VERIFICATION: For each change: make it, wait for hot reload, take screenshot with ./scripts/screenshot.sh cinepolis-bottomnav, request user confirmation. Test against https://cinepolisusa.com home and movie detail pages. FINALIZATION: When tests pass: set DEV_MODE to false in Info.plist, run yarn finalize:bundle and npx cap sync, verify without dev server, take final screenshot, commit and push. COMPLETION: Output <promise>BOTTOMNAV_FIXED</promise> ONLY after all tests verified, finalized, and committed. Clean up the team." --max-iterations 10 --completion-promise "BOTTOMNAV_FIXED"
```

## Image Handling

Claude Code cannot see images. When user has a screenshot:

1. Ask user to describe what they see
2. Extract: URL, page title, UI components, error messages (exact text), what works vs broken
3. Include as CONTEXT in the prompt

## Quick Reference

```
HARD RULES:
  - Always create an agent team
  - Main agent does NO work - only team setup + cleanup
  - Team lead does NO work - only coordinates and delegates
  - All work happens inside the team via specialized agents
  - Teammates talk to each other directly
  - Always spawn a tester using /e2e-testing skill
  - Tester iterates until ALL tests pass with screenshots
  - Promise ONLY after tester confirms + all agents done
  - Capacitor: no Chrome MCP, use simulator screenshots

PREFERENCES (context for Claude Code, not rules):
  - Frontend quality matters: /polish-ui + /frontend-design
  - Non-trivial tasks: planning before implementation
  - Significant changes: docs agent (CLAUDE.md index + docs/ detail)
  - Stacks: Next.js, Node.js, Capacitor
  - Multiple implementers: distinct file ownership

LET CLAUDE CODE DECIDE:
  - Number of agents
  - Which roles to fill
  - Agent instructions
  - Work structure and dependencies
  - Whether planning phase is needed

OUTPUT: Always present BOTH human-readable AND copy-paste versions

SYNTAX:
  - Double quotes, no apostrophes, no backticks/dollar signs
  - Tag: SCREAMING_SNAKE_CASE, matches --completion-promise
  - Copy-paste version: ONE line

ITERATIONS: Simple ~5-7 | Medium ~8-12 | Complex ~12-18 | Major ~18-25
```
