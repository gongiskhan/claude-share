# Ralph Loop Prompting System - Complete Guide v3.2

Detailed explanations for creating effective Claude Code prompts using the Ralph Loop plugin with e2e-testing skill integration.

## Table of Contents

1. [Why These Rules Exist](#why-these-rules-exist)
2. [Command Format Rules](#command-format-rules)
3. [Planning and Auto-Acceptance](#planning-and-auto-acceptance)
4. [E2E Testing Skill Integration](#e2e-testing-skill-integration)
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

### Why Use the E2E Testing Skill?

The e2e-testing skill at `~/.claude/skills/e2e-testing` provides:
- **Automatic browser strategy selection** - tries Claude for Chrome, dev-browser, Chrome debug mode, Chromium, and Agent Browser in sequence
- **Persistent sessions** - reuses login sessions across tests
- **Visible browser** - runs non-headless so you can observe
- **Graceful fallback** - automatically moves to next strategy if one fails

This eliminates the need to manually specify browser setup in every prompt.

### Why Check Ports First?

When working with multiple worktrees, each runs on different ports. The e2e-testing skill needs to know which port to test. Always check .env for UI_PORT to ensure tests run against the correct instance.

### Why Validate Before Stopping?

Claude Code might assume code works based on static analysis, but runtime behavior often differs. The completion promise should ONLY be output after the e2e-testing skill confirms the feature works through actual browser testing. This prevents loops from ending prematurely with broken code.

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
5. Uses e2e-testing skill for verification
6. Outputs promise only after e2e tests pass

---

## E2E Testing Skill Integration

### The Skill Location

```
~/.claude/skills/e2e-testing/SKILL.md
```

### What It Does

The e2e-testing skill handles all browser automation with an intelligent fallback chain:

```
Strategy 1: Claude for Chrome (MCP)
    ↓ (if unavailable or timeout)
Strategy 2: dev-browser skill (Chrome Extension)
    ↓ (if unavailable)
Strategy 3: Chrome Debug Mode
    ↓ (if fails)
Strategy 4: Chromium Persistent Context (Playwright)
    ↓ (if fails)
Strategy 5: Agent Browser (Final Fallback)
```

### How to Include in Prompts

**Always use this pattern:**

```
VERIFICATION: FIRST check .env for UI_PORT. After implementation, use the e2e-testing skill from ~/.claude/skills/e2e-testing to verify on the correct port: 1) [Navigate action], 2) [Test action], 3) [Verify expected result], 4) Take screenshot to confirm.
```

### Verification Steps Format

Be specific about what the e2e-testing skill should verify:

```
Verification steps for e2e-testing:
1) Navigate to [specific page/route]
2) [Specific action - resize viewport, click button, fill form, scroll]
3) Verify [specific expected result - element visible, text appears, behavior works]
4) Take screenshot to confirm the result
```

### What NOT to Include

Do NOT manually specify browser setup. These are handled automatically by the e2e-testing skill:
- ~~Claude for Chrome setup~~
- ~~Chrome debug mode commands~~
- ~~Playwright MCP fallback~~
- ~~Browser strategy selection~~

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

### Critical Rule: E2E Tests Before Promise

```
Output <promise>TAG</promise> ONLY after e2e tests confirm the feature works - never output the promise based on assumptions or code analysis alone.
```

**Why:** Claude Code might believe code works based on reading it, but runtime behavior often differs. The promise must only appear after the e2e-testing skill confirms success through actual browser testing.

### Example

```
... Output <promise>BUG_FIXED</promise> ONLY after e2e tests confirm the fix works." --max-iterations 5 --completion-promise "BUG_FIXED"
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

Mobile bugs require specific testing approaches. Include viewport resizing in the e2e-testing verification steps.

### Mobile-Specific Verification Steps

```
Verification steps for e2e-testing:
1) Navigate to page on correct port
2) Resize viewport to mobile size (375x667 for iPhone, 360x640 for Android)
3) Verify [mobile-specific behavior]
4) Test with both portrait and landscape orientations
5) Verify touch targets are at least 44px
6) Resize back to desktop (1280x720)
7) Verify desktop layout still works
8) Take screenshots at both sizes
```

---

## Troubleshooting

### Loop runs forever

- Check that `--completion-promise` flag is on same line as prompt
- Ensure prompt includes instruction to output `<promise>TAG</promise>`
- Verify TAG matches exactly between prompt and flag
- Check if e2e-testing skill is failing silently

### Shell parsing errors

- Remove any single quotes from inside the prompt
- Remove apostrophes (use `do not` instead of `don't`)
- Check for unescaped special characters

### Wrong worktree being tested

- Always include .env port check as FIRST verification step
- Explicitly state which port to test on in verification steps

### Claude outputs promise too early

- Make prompt more explicit: "ONLY after e2e tests confirm"
- Add "never output the promise based on assumptions or code analysis alone"
- Include more specific verification steps

### E2E testing skill not working

The skill has automatic fallback. If all strategies fail:
1. Check if Chrome is installed
2. Run `npx playwright install chromium`
3. Check if any browser instance is blocking (close other Chromes)
4. Check `~/.e2e-testing/` for corrupted profiles, delete if needed

### E2E tests failing repeatedly

- Check if the e2e-testing skill is properly installed at `~/.claude/skills/e2e-testing`
- Ensure app is built and running before tests
- Increase max iterations to allow for test/fix cycles
- Make verification steps more specific

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
- [ ] E2E testing skill referenced (`~/.claude/skills/e2e-testing`)
- [ ] Verification steps are specific and numbered
- [ ] Completion promise uses `<promise>TAG</promise>` format
- [ ] Promise explicitly tied to e2e tests passing (not assumptions)
- [ ] `--max-iterations` set based on complexity (+2-3 for e2e cycles)
- [ ] `--completion-promise` flag matches tag in prompt

---

## Canceling a Loop

If you need to stop a running loop:

```
/ralph-loop:cancel-ralph
```
