# Ralph Loop Prompting System - Complete Guide v4.0

Detailed explanations for creating effective Claude Code prompts using the Ralph Loop plugin with Claude for Chrome MCP tools for browser verification.

## Table of Contents

1. [Why These Rules Exist](#why-these-rules-exist)
2. [Command Format Rules](#command-format-rules)
3. [Planning and Auto-Acceptance](#planning-and-auto-acceptance)
4. [Browser Verification with MCP Tools](#browser-verification-with-mcp-tools)
5. [Describing Images for Claude Code](#describing-images-for-claude-code)
6. [Max Iterations Guidelines](#max-iterations-guidelines)
7. [Completion Promise System](#completion-promise-system)
8. [Mobile Testing](#mobile-testing)
9. [Troubleshooting](#troubleshooting)
10. [Checklist Before Running](#checklist-before-running)

---

## Why These Rules Exist

### Why Auto-Accept Plans?

Without auto-acceptance, Claude Code pauses after creating a plan and waits for human confirmation. In a ralph-loop automated flow, this causes the loop to stall on every iteration waiting for approval that never comes. By instructing Claude to auto-accept its own plan, the loop runs continuously until completion or max iterations.

### Why Use Claude for Chrome MCP Tools?

Claude has direct access to browser automation through the `mcp__claude-in-chrome__*` MCP tools. These tools allow:
- **Direct browser control** - navigate, click, type, screenshot without writing code
- **Real browser testing** - uses actual Chrome with all sessions intact
- **Visual verification** - take screenshots to prove features work
- **No Playwright scripts** - interact with tools directly, not by writing test files

**CRITICAL:** Always instruct Claude to use MCP tools directly. NEVER tell Claude to write Playwright test scripts or test files.

### Why Check Ports First?

When working with multiple worktrees, each runs on different ports. The MCP tools need to navigate to the correct URL. Always check .env for UI_PORT to ensure browser verification runs against the correct instance.

### Why Validate Before Stopping?

Claude Code might assume code works based on static analysis, but runtime behavior often differs. The completion promise should ONLY be output after browser verification with screenshots confirms the feature works. This prevents loops from ending prematurely with broken code.

### Why Describe Images as Text?

Claude Code cannot see images - it only receives text. Screenshots showing bugs, UI states, or error messages must be transcribed into detailed text descriptions, or the context is lost and Claude Code cannot fix the actual problem.

---

## Command Format Rules

### Everything on ONE LINE

The command, prompt, and flags must all be on a single line. If flags are on separate lines, the shell interprets them as separate commands and fails.

**Reason:** Shell parsing treats newlines as command separators. Multi-line prompts break execution.

### Syntax Rules

- Prompt wrapped in double quotes `"..."`
- No single quotes inside the prompt - causes shell parsing issues
- No apostrophes - use `I am` not `I'm`, `do not` not `don't`
- Avoid backticks, dollar signs, and special shell characters

**Reason:** These characters have special meaning in shells and can cause the prompt to be interpreted incorrectly or fail entirely.

### Structure

```
/ralph-loop:ralph-loop "ultrathink [PROMPT]" --max-iterations [N] --completion-promise "[TAG]"
```

---

## Planning and Auto-Acceptance

### The Instruction

Every prompt MUST include:

```
PLAN FIRST then AUTO-ACCEPT and implement without waiting for confirmation.
```

### Why This Matters

- **Without auto-accept:** Claude Code creates a plan, then waits for human approval. In automated loops, no human is watching, so the loop stalls forever.
- **With auto-accept:** Claude Code plans, immediately approves its own plan, and proceeds with implementation. The loop continues autonomously.

### What Claude Code Does

1. Analyzes the task
2. Creates a structured implementation plan
3. Automatically accepts the plan (no pause)
4. Executes the plan step by step
5. Uses Claude for Chrome MCP tools for browser verification
6. Outputs promise only after screenshot confirms success

---

## Browser Verification with MCP Tools

### Available MCP Tools

Claude has direct access to these browser automation tools:

| Tool | Purpose |
|------|---------|
| `mcp__claude-in-chrome__tabs_context_mcp` | Get/create browser tab context |
| `mcp__claude-in-chrome__tabs_create_mcp` | Create new tab for testing |
| `mcp__claude-in-chrome__resize_window` | Set viewport size (default: 1440x900) |
| `mcp__claude-in-chrome__navigate` | Navigate to URL |
| `mcp__claude-in-chrome__read_page` | Get page accessibility tree |
| `mcp__claude-in-chrome__find` | Find specific elements |
| `mcp__claude-in-chrome__form_input` | Fill form fields |
| `mcp__claude-in-chrome__computer` | Click, type, screenshot, scroll |
| `mcp__claude-in-chrome__get_page_text` | Extract page text content |

### How to Include in Prompts

**Always use this pattern - explicitly naming the MCP tools:**

```
BROWSER VERIFICATION: FIRST check .env for UI_PORT. After implementation, use Claude for Chrome MCP tools to verify - NEVER write Playwright scripts. Steps: 1) Call mcp__claude-in-chrome__tabs_context_mcp with createIfEmpty=true, 2) Call mcp__claude-in-chrome__tabs_create_mcp, 3) Call mcp__claude-in-chrome__resize_window with width=1440 height=900, 4) Call mcp__claude-in-chrome__navigate to app URL, 5) [Test actions using MCP tools], 6) Call mcp__claude-in-chrome__computer with action=screenshot to capture proof. If MCP tools unavailable, use agent-browser CLI.
```

### Verification Steps Format

Be specific about what MCP tools to use:

```
Browser verification steps:
1) Get tab context with mcp__claude-in-chrome__tabs_context_mcp
2) Navigate to [specific page/route] with mcp__claude-in-chrome__navigate
3) Find elements with mcp__claude-in-chrome__read_page or mcp__claude-in-chrome__find
4) [Specific action - click, type, scroll using mcp__claude-in-chrome__computer]
5) Take screenshot with mcp__claude-in-chrome__computer action=screenshot
```

### CRITICAL: What NOT to Do

**NEVER tell Claude to write test scripts.** These instructions cause Claude to create Playwright files instead of using MCP tools:
- ~~"write Playwright tests"~~
- ~~"create e2e tests"~~
- ~~"write .spec.ts files"~~
- ~~"use test() blocks"~~

Instead, always be explicit: **"use Claude for Chrome MCP tools directly"**

### Fallback: agent-browser CLI

If Claude for Chrome MCP tools are unavailable (permission denied, extension not installed), fall back to agent-browser:

```bash
agent-browser open http://localhost:PORT
agent-browser set viewport 1440 900
agent-browser snapshot -i
agent-browser [interaction commands]
agent-browser screenshot result.png
```

---

## Describing Images for Claude Code

### Why This Matters

**Claude Code cannot see images.** When you have a screenshot showing a bug or UI state, YOU must describe it in text and incorporate that description directly into the prompt. Without this, Claude Code has no idea what the actual problem looks like.

### How to Handle Images

1. **Look at the image yourself**
2. **Extract ALL relevant details:**
   - What page/URL is shown
   - What UI elements are visible
   - What error messages appear (copy exact text)
   - What is broken or unexpected
   - What the current state looks like
   - What SHOULD happen vs what IS happening
3. **Write it as CONTEXT in the prompt**

### Example - Converting Image to Prompt Context

**Instead of:** "Here is a screenshot of the bug" (useless for Claude Code)

**Write this in your prompt:**

```
CONTEXT: On the Chat page at /chat, user asked about Stripe payments. The agent responded with a card showing Stripe Payments title, message saying no customers in Stripe account, suggestions to verify correct account and check test mode vs live mode. Below that, an error card appeared with coral/red background, title Erro na Integracao with error code NO_ADAPTER and a Transferir Logs button that does not work when clicked.
```

### What to Include From Screenshots

- **URL/route** shown in browser address bar
- **Page title** and main headings
- **UI components** visible (buttons, cards, forms, tables, etc.)
- **Error messages** - copy EXACT text including error codes
- **Data shown** - table contents, list items, values displayed
- **Button labels** - exact text on buttons
- **State indicators** - loading, success, error, disabled states
- **Spacing/layout issues** - describe what looks wrong
- **What works** and **what does not work**
- **Mobile vs desktop** - specify the viewport if relevant

---

## Max Iterations Guidelines

Infer complexity based on task scope:

| Complexity | Iterations | Examples |
|------------|------------|----------|
| Simple | 4-5 | Single bug fix, small UI tweak, text change |
| Medium | 6-7 | Feature fix, component update, single-page changes |
| Complex | 8-10 | Multi-file refactor, new feature, multiple components |
| Major | 10-15 | Architecture changes, new pages, system-wide updates |

Add +2-3 iterations when e2e testing might find issues that need fixing.

### Why These Numbers?

- **Too few iterations:** Loop ends before the feature is complete or verified
- **Too many iterations:** Wastes time if the task is simpler than expected
- **Right balance:** Allows for initial implementation, bug fixes discovered during e2e testing, and final verification

### Factors that Increase Complexity

- Multiple files to modify
- Frontend + backend changes
- New components to create
- State management changes
- API endpoint changes
- Database/model changes
- Mobile responsiveness requirements
- Multiple verification scenarios

---

## Completion Promise System

### Why Promises Exist

The promise system tells the ralph-loop when to stop. Without it, the loop either:
- Runs forever until max iterations
- Stops too early before verification

### Two Parts Required

1. **Flag:** `--completion-promise "TAG"` tells the stop hook what pattern to look for
2. **Instruction in prompt:** Tell Claude to output `<promise>TAG</promise>` when done

### Critical Rule: Screenshot Before Promise

```
Output <promise>TAG</promise> ONLY after browser verification with screenshot confirms the feature works - never output the promise based on assumptions or code analysis alone.
```

**Why:** Claude Code might believe code works based on reading it, but runtime behavior often differs. The promise must only appear after Claude for Chrome MCP tools confirm success through actual browser testing with screenshots.

### Example

```
... Output <promise>BUG_FIXED</promise> ONLY after browser verification with screenshot confirms the fix works." --max-iterations 5 --completion-promise "BUG_FIXED"
```

### Tag Naming Convention

Use descriptive, uppercase tags with underscores:
- `BUG_FIXED`
- `FEATURE_COMPLETE`
- `REFACTOR_DONE`
- `UI_UPDATED`
- `E2E_TESTS_PASSING`
- `MOBILE_RESPONSIVE_FIXED`

---

## Mobile Testing

### Special Considerations

Mobile bugs require specific testing approaches. Include viewport resizing using `mcp__claude-in-chrome__resize_window` in the browser verification steps.

### Mobile-Specific Verification Steps

```
Browser verification for mobile:
1) Call mcp__claude-in-chrome__tabs_context_mcp with createIfEmpty=true
2) Call mcp__claude-in-chrome__navigate to page on correct port
3) Call mcp__claude-in-chrome__resize_window with width=375 height=667 (iPhone)
4) Verify [mobile-specific behavior]
5) Call mcp__claude-in-chrome__computer action=screenshot for mobile proof
6) Call mcp__claude-in-chrome__resize_window with width=1440 height=900 (desktop)
7) Verify desktop layout still works
8) Call mcp__claude-in-chrome__computer action=screenshot for desktop proof
```

---

## Troubleshooting

### Loop runs forever

- Check that `--completion-promise` flag is on same line as prompt
- Ensure prompt includes instruction to output `<promise>TAG</promise>`
- Verify TAG matches exactly between prompt and flag
- Check if Claude for Chrome MCP tools are returning errors

### Shell parsing errors

- Remove any single quotes from inside the prompt
- Remove apostrophes (use `do not` instead of `don't`)
- Check for unescaped special characters

### Wrong worktree being tested

- Always include .env port check as FIRST verification step
- Explicitly state which port to test on in verification steps

### Claude outputs promise too early

- Make prompt more explicit: "ONLY after browser verification with screenshot confirms"
- Add "never output the promise based on assumptions or code analysis alone"
- Include more specific MCP tool usage steps

### Claude for Chrome MCP tools not working

1. Check if Claude for Chrome extension is installed and active
2. Ensure Chrome is open
3. Try accepting permissions when prompted
4. Fall back to agent-browser CLI commands

### Claude writes Playwright scripts instead of using MCP tools

This is the most common issue. Fix by being MORE EXPLICIT in your prompt:
- Add "NEVER write Playwright test scripts or test files"
- Add "use Claude for Chrome MCP tools directly"
- Name the specific MCP tools: `mcp__claude-in-chrome__tabs_context_mcp`, `mcp__claude-in-chrome__navigate`, etc.
- Add "call the MCP tools, do not write code that calls them"

### Browser verification failing repeatedly

- Ensure app is built and running before verification
- Increase max iterations to allow for fix cycles
- Make MCP tool steps more specific
- Check if the app URL and port are correct

---

## Checklist Before Running

- [ ] Prompt starts with `ultrathink`
- [ ] Includes `PLAN FIRST then AUTO-ACCEPT and implement without waiting for confirmation`
- [ ] Image/UI context fully described in text
- [ ] Everything on ONE line
- [ ] Prompt wrapped in double quotes
- [ ] No single quotes or apostrophes inside prompt
- [ ] Error messages copied with exact text
- [ ] File paths included where known
- [ ] Port check included (check .env for UI_PORT first)
- [ ] Explicit MCP tool names included (`mcp__claude-in-chrome__*`)
- [ ] "NEVER write Playwright scripts" is explicitly stated
- [ ] Browser verification steps use specific MCP tool names
- [ ] Screenshot step included (`mcp__claude-in-chrome__computer action=screenshot`)
- [ ] Completion promise uses `<promise>TAG</promise>` format
- [ ] Promise explicitly tied to screenshot confirmation (not assumptions)
- [ ] `--max-iterations` set based on complexity (+2-3 for verification cycles)
- [ ] `--completion-promise` flag matches tag in prompt

---

## Canceling a Loop

If you need to stop a running loop:

```
/ralph-loop:cancel-ralph
```
