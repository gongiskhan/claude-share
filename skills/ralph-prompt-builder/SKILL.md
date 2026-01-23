---
name: ralph-prompt-builder
description: Build structured prompts for the /ralph-loop:ralph-loop command. Use when user asks to create a ralph-loop prompt, build an agentic loop task, automate a feature with browser verification, or run a task with Chrome extension testing. Generates prompts with proper e2e-testing skill integration, completion promises, port isolation, and verification steps.
---

# Ralph Loop Prompt Builder

Build `/ralph-loop:ralph-loop` prompts for iterative development with automated browser testing.

## Quick Start Template

```
/ralph-loop:ralph-loop "ultrathink [TASK TITLE]. PLAN FIRST then AUTO-ACCEPT and implement without waiting for confirmation. [CONTEXT]. [REQUIREMENTS]. VERIFICATION: FIRST check .env file to confirm UI_PORT for this worktree. After implementation, use the e2e-testing skill from ~/.claude/skills/e2e-testing to verify on the correct port: 1) [Test step], 2) [Test step], 3) [Verify expected result]. The e2e-testing skill will handle browser strategy selection automatically. Output <promise>YOUR_TAG</promise> ONLY after e2e tests confirm the feature works - never output the promise based on assumptions or code analysis alone." --max-iterations [N] --completion-promise "YOUR_TAG"
```

## Workflow

1. Get task description from user
2. If user provides screenshot/image, ask them to describe it in text (Claude Code cannot see images)
3. Clarify scope, port, and project context if ambiguous
4. Generate prompt with e2e-testing skill integration
5. Present ready to copy/paste

## Prompt Structure

### Required Elements

1. **Start with** `ultrathink`
2. **Include** `PLAN FIRST then AUTO-ACCEPT and implement without waiting for confirmation`
3. **Context section** - describe current state, what works, what is broken
4. **Requirements** - numbered list of what needs to be done
5. **Port check** - always check .env for UI_PORT first
6. **E2E testing skill** - use `~/.claude/skills/e2e-testing` for verification
7. **Verification steps** - specific test scenarios for the e2e-testing skill to execute
8. **Promise instruction** - output `<promise>TAG</promise>` ONLY after e2e tests pass
9. **Everything on ONE line** - no newlines in the command

### Syntax Rules

- Prompt wrapped in double quotes
- No single quotes or apostrophes inside (use `do not` not `don't`)
- Avoid backticks, dollar signs, special shell characters
- Completion tag: SCREAMING_SNAKE_CASE, must match `--completion-promise` exactly

## E2E Testing Skill Integration

The e2e-testing skill at `~/.claude/skills/e2e-testing` handles all browser automation with automatic fallback:

```
Claude for Chrome → dev-browser → Chrome Debug Mode → Chromium → Agent Browser
```

**Always include this pattern in prompts:**

```
After implementation, use the e2e-testing skill from ~/.claude/skills/e2e-testing to verify on the correct port. The skill will:
1) Select the best available browser strategy automatically
2) Navigate to the app on UI_PORT from .env
3) Execute the verification steps
4) Take screenshots to confirm results
```

### Verification Steps Format

Tell the e2e-testing skill what to verify:

```
Verification steps for e2e-testing:
1) Navigate to [page/route]
2) [Action to perform - click, type, scroll, resize]
3) Verify [expected result - element visible, text appears, behavior works]
4) Take screenshot to confirm
```

## Max Iterations

| Complexity | Iterations | Examples |
|------------|------------|----------|
| Simple | 4-5 | Single bug fix, UI tweak, text change |
| Medium | 6-7 | Feature fix, component update, single-page |
| Complex | 8-10 | Multi-file refactor, new feature |
| Major | 10-15 | Architecture changes, new pages |

Add +2-3 iterations for e2e test/fix cycles.

## Image Handling

Claude Code cannot see images. When user has a screenshot:

1. Ask user to describe what they see
2. Extract: URL, page title, UI components, error messages (exact text), what works vs broken
3. Include as CONTEXT in the prompt

## Quick Example

For the sidebar scrolling fix:

```
/ralph-loop:ralph-loop "ultrathink Fix sidebar navigation scrolling on smaller screens. PLAN FIRST then AUTO-ACCEPT and implement without waiting for confirmation. CONTEXT: Sidebar navigation shows logo at top, menu icons for Orchestration, Examples, Agents, Platform, Branding, Users, Artifacts, Integrations, Resources, Tunnel, and user avatar at bottom. On smaller viewport heights, bottom items are cut off with no scrolling. REQUIREMENTS: 1) Add vertical scrolling to sidebar nav area, 2) Hide scrollbar visually with CSS, 3) Keep logo fixed at top, 4) Only modify sidebar component. VERIFICATION: FIRST check .env for UI_PORT. After implementation, use the e2e-testing skill from ~/.claude/skills/e2e-testing to verify: 1) Navigate to app on correct port, 2) Resize viewport to 500-600px height, 3) Scroll sidebar and verify all items accessible including Tunnel and avatar at bottom, 4) Verify no visible scrollbar, 5) Take screenshot confirming scrolling works. Output <promise>SIDEBAR_SCROLL_FIXED</promise> ONLY after e2e tests confirm the fix works." --max-iterations 5 --completion-promise "SIDEBAR_SCROLL_FIXED"
```

## References

- **Complete guide**: See [references/complete-guide.md](references/complete-guide.md) for detailed explanations
- **Templates**: See [references/templates.md](references/templates.md) for task-type templates
- **Examples**: See [references/examples.md](references/examples.md) for complete working examples

## Quick Reference

```
ALWAYS INCLUDE:
- Start with "ultrathink"
- "PLAN FIRST then AUTO-ACCEPT and implement without waiting"
- Describe images/UI as detailed text
- Check .env for UI_PORT first
- Use e2e-testing skill for verification
- Promise ONLY after e2e tests pass
- Everything on ONE line

ITERATIONS: Simple=4-5 | Medium=6-7 | Complex=8-10 | Major=10-15 | +E2E=+2-3

PROMISE FORMAT:
  In prompt: "Output <promise>TAG</promise> ONLY after e2e tests confirm"
  Flag: --completion-promise "TAG"
```
