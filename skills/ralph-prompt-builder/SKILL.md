---
name: ralph-prompt-builder
description: Build structured prompts for the /ralph-loop:ralph-loop command. Use when user asks to create a ralph-loop prompt, build an agentic loop task, automate a feature with browser verification, or run a task with Chrome extension testing. Generates prompts that use the /e2e-testing skill for browser verification.
---

# Ralph Loop Prompt Builder

Build `/ralph-loop:ralph-loop` prompts for iterative development with automated browser testing.

## Quick Start Template

```
/ralph-loop:ralph-loop "ultrathink [TASK TITLE]. PLAN FIRST then AUTO-ACCEPT and implement without waiting for confirmation. [CONTEXT]. [REQUIREMENTS]. BROWSER VERIFICATION: FIRST check .env file to confirm UI_PORT for this worktree. After implementation, invoke the /e2e-testing skill to verify the feature works. Test steps: [DESCRIBE WHAT TO TEST]. The e2e-testing skill will handle browser automation and screenshots. Output <promise>YOUR_TAG</promise> ONLY after e2e-testing confirms the feature works with a screenshot - never output the promise based on assumptions or code analysis alone." --max-iterations [N] --completion-promise "YOUR_TAG"
```

## Workflow

1. Get task description from user
2. If user provides screenshot/image, ask them to describe it in text (Claude Code cannot see images)
3. Clarify scope, port, and project context if ambiguous
4. Generate prompt with /e2e-testing skill verification instructions
5. Present ready to copy/paste

## Prompt Structure

### Required Elements

1. **Start with** `ultrathink`
2. **Include** `PLAN FIRST then AUTO-ACCEPT and implement without waiting for confirmation`
3. **Context section** - describe current state, what works, what is broken
4. **Requirements** - numbered list of what needs to be done
5. **Port check** - always check .env for UI_PORT first
6. **Browser verification** - invoke `/e2e-testing` skill for verification
7. **Test steps** - describe what to verify (the skill handles the how)
8. **Promise instruction** - output `<promise>TAG</promise>` ONLY after e2e-testing confirms success
9. **Everything on ONE line** - no newlines in the command

### Syntax Rules

- Prompt wrapped in double quotes
- No single quotes or apostrophes inside (use `do not` not `don't`)
- Avoid backticks, dollar signs, special shell characters
- Completion tag: SCREAMING_SNAKE_CASE, must match `--completion-promise` exactly

## Browser Verification with /e2e-testing Skill

**CRITICAL: Always instruct to invoke the /e2e-testing skill for browser verification.**

The /e2e-testing skill handles all browser automation including:
- Opening browser tabs
- Navigating to URLs
- Interacting with elements (click, type, scroll)
- Taking screenshots as proof
- Reading page content

**Always include this instruction pattern in prompts:**

```
BROWSER VERIFICATION: After implementation, invoke the /e2e-testing skill to verify. Test steps: 1) Navigate to app URL using UI_PORT from .env, 2) [Your specific verification steps], 3) Capture screenshot as proof. The e2e-testing skill handles all browser automation.
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
/ralph-loop:ralph-loop "ultrathink Fix sidebar navigation scrolling on smaller screens. PLAN FIRST then AUTO-ACCEPT and implement without waiting for confirmation. CONTEXT: Sidebar navigation shows logo at top, menu icons for Orchestration, Examples, Agents, Platform, Branding, Users, Artifacts, Integrations, Resources, Tunnel, and user avatar at bottom. On smaller viewport heights, bottom items are cut off with no scrolling. REQUIREMENTS: 1) Add vertical scrolling to sidebar nav area, 2) Hide scrollbar visually with CSS, 3) Keep logo fixed at top, 4) Only modify sidebar component. BROWSER VERIFICATION: FIRST check .env for UI_PORT. After implementation, invoke the /e2e-testing skill to verify. Test steps: 1) Navigate to app on UI_PORT, 2) Resize viewport to 1440x600 to simulate small screen, 3) Scroll within sidebar area, 4) Verify all items including Tunnel and avatar are accessible, 5) Capture screenshot as proof. Output <promise>SIDEBAR_SCROLL_FIXED</promise> ONLY after e2e-testing confirms scrolling works with screenshot." --max-iterations 5 --completion-promise "SIDEBAR_SCROLL_FIXED"
```

## References

- **Complete guide**: See [references/complete-guide.md](references/complete-guide.md) for detailed explanations
- **Templates**: See [references/templates.md](references/templates.md) for task-type templates
- **Examples**: See [references/examples.md](references/examples.md) for complete working examples

## Mobile App Development (Capacitor/Indy)

For **Capacitor shell apps** like indy-mobileapps, use a different testing and finalization approach.

### Mobile App Template

```
/ralph-loop:ralph-loop "ultrathink [TASK TITLE]. PLAN FIRST then AUTO-ACCEPT and implement without waiting for confirmation. CONTEXT: This is a Capacitor shell app that loads remote cinema websites. All fixes are CSS/JS injections via custom plugin - we do not control source HTML. Key files: CSS fixes in dev-server/adjustments/css/, JS fixes in dev-server/adjustments/js/, DEV_MODE in ios/App/App/Info.plist. [DESCRIBE THE ISSUE]. REQUIREMENTS: [NUMBERED LIST]. VERIFICATION LOOP: For each task: 1) Make the change, 2) Wait for hot reload, 3) Request screenshot verification from user, 4) Do NOT proceed until visual confirmation received. TEST URLS: After implementation, test against [CINEMA_URL_1], [CINEMA_URL_2]. For each: navigate to affected page, take screenshot with ./scripts/screenshot.sh [cinema]-[feature], confirm fix works, confirm no regressions. FINALIZATION: Only when ALL tests pass: 1) Disable DEV_MODE - edit ios/App/App/Info.plist set DEV_MODE to false, 2) Run yarn finalize:bundle and npx cap sync, 3) Run app WITHOUT dev server to confirm bundled CSS/JS works, 4) Take final screenshot as proof, 5) Commit with git add . and git commit -m fix: [description] and git push. Output <promise>YOUR_TAG</promise> ONLY after: all cinema test URLs verified, DEV_MODE set to false, finalize:bundle and cap sync successful, app works without dev server, changes committed and pushed." --max-iterations [N] --completion-promise "YOUR_TAG"
```

### Mobile App Workflow

| Phase | Actions |
|-------|---------|
| Planning | Analyze problem, identify CSS/JS files, list side effects on other cinemas |
| Implementation | Make change, wait for hot reload, STOP for screenshot verification |
| Testing | Test each cinema URL, take screenshots, check for regressions |
| Finalization | DEV_MODE=false, finalize:bundle, cap sync, verify without dev server |

### Mobile App Verification (NOT Chrome MCP)

**Do NOT use Claude for Chrome MCP tools for mobile apps.** Instead:

1. **Hot reload testing**: Dev server auto-reloads, request user screenshot
2. **Simulator screenshots**: `./scripts/screenshot.sh [cinema]-[feature]`
3. **Multi-cinema testing**: Test against all affected cinema URLs
4. **Bundled verification**: Final test without dev server running

### Mobile App Finalization Checklist

```
FINALIZATION SEQUENCE:
1. Edit ios/App/App/Info.plist - set DEV_MODE to false
2. Run: yarn finalize:bundle && npx cap sync
3. Kill dev server, run app, verify CSS/JS still works
4. Screenshot proof of working bundled app
5. git add . && git commit -m "fix: [description]" && git push
```

### Mobile App Example

```
/ralph-loop:ralph-loop "ultrathink Fix bottom navigation overlap on Cinepolis USA mobile view. PLAN FIRST then AUTO-ACCEPT and implement without waiting for confirmation. CONTEXT: This is a Capacitor shell app that loads remote cinema websites. All fixes are CSS/JS injections via custom plugin - we do not control source HTML. Key files: CSS fixes in dev-server/adjustments/css/, JS fixes in dev-server/adjustments/js/, DEV_MODE in ios/App/App/Info.plist. The bottom navigation bar overlaps with the native tab bar on smaller iPhones. REQUIREMENTS: 1) Add bottom padding to prevent overlap, 2) Only affect mobile viewport widths, 3) Test on iPhone SE size. VERIFICATION LOOP: For each task: 1) Make the change, 2) Wait for hot reload, 3) Request screenshot verification from user, 4) Do NOT proceed until visual confirmation received. TEST URLS: After implementation, test against https://cinepolisusa.com. Navigate to home page and movie detail pages, take screenshots with ./scripts/screenshot.sh cinepolis-bottomnav, confirm fix works, confirm no regressions on other pages. FINALIZATION: Only when ALL tests pass: 1) Disable DEV_MODE - edit ios/App/App/Info.plist set DEV_MODE to false, 2) Run yarn finalize:bundle and npx cap sync, 3) Run app WITHOUT dev server to confirm bundled CSS/JS works, 4) Take final screenshot as proof, 5) Commit with git add . and git commit -m fix: bottom nav overlap on cinepolis and git push. Output <promise>BOTTOMNAV_FIXED</promise> ONLY after: all test URLs verified, DEV_MODE set to false, finalize:bundle and cap sync successful, app works without dev server, changes committed and pushed." --max-iterations 8 --completion-promise "BOTTOMNAV_FIXED"
```

---

## Quick Reference - Web Apps

```
ALWAYS INCLUDE:
- Start with "ultrathink"
- "PLAN FIRST then AUTO-ACCEPT and implement without waiting"
- Describe images/UI as detailed text
- Check .env for UI_PORT first
- Invoke /e2e-testing skill for browser verification
- Describe test steps (what to verify, not how)
- Promise ONLY after e2e-testing confirms with screenshot
- Everything on ONE line

VERIFICATION PATTERN:
"BROWSER VERIFICATION: After implementation, invoke the /e2e-testing skill to verify.
Test steps: 1) Navigate to [URL], 2) [Actions to test], 3) Capture screenshot as proof."

ITERATIONS: Simple=4-5 | Medium=6-7 | Complex=8-10 | Major=10-15 | +E2E=+2-3

PROMISE FORMAT:
  In prompt: "Output <promise>TAG</promise> ONLY after e2e-testing confirms"
  Flag: --completion-promise "TAG"
```

## Quick Reference - Mobile Apps (Capacitor)

```
ALWAYS INCLUDE:
- Start with "ultrathink"
- "PLAN FIRST then AUTO-ACCEPT and implement without waiting"
- Describe Capacitor shell app context
- List CSS/JS injection file locations
- Reference DEV_MODE in Info.plist
- Verification loop: change -> hot reload -> user screenshot -> proceed
- Test against multiple cinema URLs
- Finalization sequence required
- Promise ONLY after full finalization complete
- Everything on ONE line

DO NOT USE Chrome MCP tools for mobile apps

VERIFICATION FLOW:
1. Make change in dev-server/adjustments/
2. Wait for hot reload
3. Request screenshot from user
4. Do NOT proceed without confirmation

FINALIZATION SEQUENCE:
1. Set DEV_MODE=false in ios/App/App/Info.plist
2. yarn finalize:bundle && npx cap sync
3. Test app WITHOUT dev server running
4. Screenshot bundled app working
5. git commit and push

ITERATIONS: Simple=5-6 | Medium=7-8 | Complex=9-12 | +Multi-cinema=+2-3

PROMISE CONDITIONS:
- All cinema URLs tested
- DEV_MODE disabled
- Bundle created and synced
- Works without dev server
- Committed and pushed
```
