---
name: ralph-prompt-builder
description: Build structured prompts for the /ralph-loop:ralph-loop command. Use when user asks to create a ralph-loop prompt, build an agentic loop task, automate a feature with browser verification, or run a task with Chrome extension testing. Generates prompts with Claude for Chrome MCP tools for browser verification.
---

# Ralph Loop Prompt Builder

Build `/ralph-loop:ralph-loop` prompts for iterative development with automated browser testing.

## Quick Start Template

```
/ralph-loop:ralph-loop "ultrathink [TASK TITLE]. PLAN FIRST then AUTO-ACCEPT and implement without waiting for confirmation. [CONTEXT]. [REQUIREMENTS]. BROWSER VERIFICATION: FIRST check .env file to confirm UI_PORT for this worktree. After implementation, verify using Claude for Chrome MCP tools (mcp__claude-in-chrome__*) - NEVER write Playwright test scripts. Steps: 1) Call mcp__claude-in-chrome__tabs_context_mcp to get tab context, 2) Call mcp__claude-in-chrome__tabs_create_mcp to create a new tab, 3) Call mcp__claude-in-chrome__resize_window with width=1440 height=900, 4) Call mcp__claude-in-chrome__navigate to go to the app URL using UI_PORT, 5) [Test step using MCP tools], 6) Call mcp__claude-in-chrome__computer with action=screenshot to capture proof. If Claude for Chrome is unavailable, use agent-browser CLI commands instead. Output <promise>YOUR_TAG</promise> ONLY after browser verification confirms the feature works with a screenshot - never output the promise based on assumptions or code analysis alone." --max-iterations [N] --completion-promise "YOUR_TAG"
```

## Workflow

1. Get task description from user
2. If user provides screenshot/image, ask them to describe it in text (Claude Code cannot see images)
3. Clarify scope, port, and project context if ambiguous
4. Generate prompt with explicit Claude for Chrome MCP tool instructions
5. Present ready to copy/paste

## Prompt Structure

### Required Elements

1. **Start with** `ultrathink`
2. **Include** `PLAN FIRST then AUTO-ACCEPT and implement without waiting for confirmation`
3. **Context section** - describe current state, what works, what is broken
4. **Requirements** - numbered list of what needs to be done
5. **Port check** - always check .env for UI_PORT first
6. **Browser verification using MCP tools** - explicit instructions to use `mcp__claude-in-chrome__*` tools
7. **NEVER write Playwright scripts** - must be stated explicitly
8. **Screenshot requirement** - always take screenshot as proof
9. **Promise instruction** - output `<promise>TAG</promise>` ONLY after screenshots confirm success
10. **Everything on ONE line** - no newlines in the command

### Syntax Rules

- Prompt wrapped in double quotes
- No single quotes or apostrophes inside (use `do not` not `don't`)
- Avoid backticks, dollar signs, special shell characters
- Completion tag: SCREAMING_SNAKE_CASE, must match `--completion-promise` exactly

## Browser Verification with Claude for Chrome MCP Tools

**CRITICAL: Always instruct to use MCP tools directly, not to write test scripts.**

The MCP tools to use (in order):

| Step | MCP Tool | Purpose |
|------|----------|---------|
| 1 | `mcp__claude-in-chrome__tabs_context_mcp` | Get browser tab context |
| 2 | `mcp__claude-in-chrome__tabs_create_mcp` | Create new tab for testing |
| 3 | `mcp__claude-in-chrome__resize_window` | Set viewport to 1440x900 |
| 4 | `mcp__claude-in-chrome__navigate` | Go to test URL |
| 5 | `mcp__claude-in-chrome__read_page` | Find interactive elements |
| 6 | `mcp__claude-in-chrome__find` | Find specific elements |
| 7 | `mcp__claude-in-chrome__form_input` | Fill form fields |
| 8 | `mcp__claude-in-chrome__computer` | Click, type, screenshot |

**Always include this instruction pattern in prompts:**

```
BROWSER VERIFICATION: After implementation, use Claude for Chrome MCP tools to verify - NEVER write Playwright test scripts or test files. Steps: 1) Call mcp__claude-in-chrome__tabs_context_mcp with createIfEmpty=true, 2) Call mcp__claude-in-chrome__tabs_create_mcp to create a new tab, 3) Call mcp__claude-in-chrome__resize_window with width=1440 height=900, 4) Call mcp__claude-in-chrome__navigate to the app URL, 5) [Your specific test actions using MCP tools], 6) Call mcp__claude-in-chrome__computer with action=screenshot to capture proof. If Claude for Chrome MCP tools are unavailable, fall back to agent-browser CLI commands.
```

### Fallback: agent-browser CLI

If Claude for Chrome is unavailable, the prompt should specify using agent-browser:

```
agent-browser open http://localhost:PORT
agent-browser set viewport 1440 900
agent-browser snapshot -i
agent-browser [interaction commands]
agent-browser screenshot result.png
```

## Max Iterations

| Complexity | Iterations | Examples |
|------------|------------|----------|
| Simple | 4-5 | Single bug fix, UI tweak, text change |
| Medium | 6-7 | Feature fix, component update, single-page |
| Complex | 8-10 | Multi-file refactor, new feature |
| Major | 10-15 | Architecture changes, new pages |

Add +2-3 iterations for browser verification/fix cycles.

## Image Handling

Claude Code cannot see images. When user has a screenshot:

1. Ask user to describe what they see
2. Extract: URL, page title, UI components, error messages (exact text), what works vs broken
3. Include as CONTEXT in the prompt

## Quick Example

For the sidebar scrolling fix:

```
/ralph-loop:ralph-loop "ultrathink Fix sidebar navigation scrolling on smaller screens. PLAN FIRST then AUTO-ACCEPT and implement without waiting for confirmation. CONTEXT: Sidebar navigation shows logo at top, menu icons for Orchestration, Examples, Agents, Platform, Branding, Users, Artifacts, Integrations, Resources, Tunnel, and user avatar at bottom. On smaller viewport heights, bottom items are cut off with no scrolling. REQUIREMENTS: 1) Add vertical scrolling to sidebar nav area, 2) Hide scrollbar visually with CSS, 3) Keep logo fixed at top, 4) Only modify sidebar component. BROWSER VERIFICATION: FIRST check .env for UI_PORT. After implementation, use Claude for Chrome MCP tools - NEVER write Playwright scripts. Steps: 1) Call mcp__claude-in-chrome__tabs_context_mcp with createIfEmpty=true, 2) Call mcp__claude-in-chrome__tabs_create_mcp, 3) Call mcp__claude-in-chrome__resize_window with width=1440 height=600 to simulate small viewport, 4) Call mcp__claude-in-chrome__navigate to app on UI_PORT, 5) Call mcp__claude-in-chrome__read_page to find sidebar elements, 6) Call mcp__claude-in-chrome__computer with action=scroll on sidebar area, 7) Call mcp__claude-in-chrome__computer with action=screenshot to verify all items including Tunnel and avatar are accessible. If Claude for Chrome unavailable use agent-browser CLI instead. Output <promise>SIDEBAR_SCROLL_FIXED</promise> ONLY after screenshot confirms scrolling works." --max-iterations 5 --completion-promise "SIDEBAR_SCROLL_FIXED"
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
- Use Claude for Chrome MCP tools (mcp__claude-in-chrome__*)
- NEVER write Playwright test scripts
- Take screenshot as proof
- Promise ONLY after screenshot confirms success
- Everything on ONE line

MCP TOOLS ORDER:
1. mcp__claude-in-chrome__tabs_context_mcp (get context)
2. mcp__claude-in-chrome__tabs_create_mcp (new tab)
3. mcp__claude-in-chrome__resize_window (1440x900)
4. mcp__claude-in-chrome__navigate (go to URL)
5. mcp__claude-in-chrome__read_page / find (discover elements)
6. mcp__claude-in-chrome__form_input / computer (interact)
7. mcp__claude-in-chrome__computer action=screenshot (proof)

FALLBACK: agent-browser CLI if MCP tools unavailable

ITERATIONS: Simple=4-5 | Medium=6-7 | Complex=8-10 | Major=10-15 | +E2E=+2-3

PROMISE FORMAT:
  In prompt: "Output <promise>TAG</promise> ONLY after screenshot confirms"
  Flag: --completion-promise "TAG"
```
