---
name: e2e-testing
description: End-to-end browser testing using Claude for Chrome MCP tools. Use this skill when asked to test, verify, or validate web applications. ALWAYS uses real browser automation - NEVER writes Playwright scripts or unit tests. Primary tool is Claude for Chrome (mcp__claude-in-chrome__*), with agent-browser CLI as fallback.
---

# E2E Testing Skill

**This skill performs REAL browser automation to test web applications.**

## ABSOLUTE RULES - VIOLATIONS ARE FORBIDDEN

1. **NEVER write Playwright test scripts** - Do not write .spec.ts files, do not write test() blocks
2. **NEVER write unit tests** - This skill uses REAL browsers, not test frameworks
3. **NEVER create test files** - No files in __tests__, no .test.ts, no .spec.ts
4. **USE MCP TOOLS DIRECTLY** - Call the `mcp__claude-in-chrome__*` tools, do not write code that calls them
5. **TAKE SCREENSHOTS** - Always capture visual proof of test results

## How to Perform E2E Tests

### Step 1: Get Browser Tab Context

ALWAYS start by calling this MCP tool:

```
mcp__claude-in-chrome__tabs_context_mcp with createIfEmpty=true
```

This gives you a tab ID to use with all other browser tools.

### Step 2: Create a New Tab (if needed)

```
mcp__claude-in-chrome__tabs_create_mcp
```

### Step 3: Set Viewport Size (CRITICAL)

Default to 1440x900 (laptop screen) to catch responsive issues:

```
mcp__claude-in-chrome__resize_window with width=1440, height=900, tabId=<your_tab_id>
```

### Step 4: Navigate to the Test URL

```
mcp__claude-in-chrome__navigate with url="http://localhost:3000", tabId=<your_tab_id>
```

### Step 5: Discover Elements

Use read_page to get the accessibility tree:

```
mcp__claude-in-chrome__read_page with tabId=<your_tab_id>, filter="interactive"
```

Or find specific elements:

```
mcp__claude-in-chrome__find with query="login button", tabId=<your_tab_id>
```

### Step 6: Interact with Elements

Click using element refs:

```
mcp__claude-in-chrome__computer with action="left_click", ref="ref_5", tabId=<your_tab_id>
```

Or type text:

```
mcp__claude-in-chrome__computer with action="type", text="test@example.com", tabId=<your_tab_id>
```

Fill form fields:

```
mcp__claude-in-chrome__form_input with ref="ref_3", value="password123", tabId=<your_tab_id>
```

### Step 7: Take Screenshots to Verify

```
mcp__claude-in-chrome__computer with action="screenshot", tabId=<your_tab_id>
```

## Complete Example: Testing a Login Flow

Here is the CORRECT way to test a login:

1. Call `mcp__claude-in-chrome__tabs_context_mcp` with createIfEmpty=true
2. Call `mcp__claude-in-chrome__tabs_create_mcp`
3. Call `mcp__claude-in-chrome__resize_window` with width=1440, height=900
4. Call `mcp__claude-in-chrome__navigate` with url="http://localhost:3000/login"
5. Call `mcp__claude-in-chrome__computer` with action="screenshot" to see the page
6. Call `mcp__claude-in-chrome__read_page` with filter="interactive" to find form fields
7. Call `mcp__claude-in-chrome__form_input` with ref="email_field_ref", value="test@example.com"
8. Call `mcp__claude-in-chrome__form_input` with ref="password_field_ref", value="password123"
9. Call `mcp__claude-in-chrome__computer` with action="left_click", ref="login_button_ref"
10. Call `mcp__claude-in-chrome__computer` with action="wait", duration=2
11. Call `mcp__claude-in-chrome__computer` with action="screenshot" to verify success

## WRONG vs RIGHT

### WRONG - Do NOT do this:

```typescript
// DO NOT WRITE PLAYWRIGHT SCRIPTS
import { test, expect } from '@playwright/test';

test('login works', async ({ page }) => {
  await page.goto('http://localhost:3000/login');
  await page.fill('#email', 'test@example.com');
  // ... THIS IS WRONG!
});
```

### RIGHT - Do this instead:

Call the MCP tools directly as tool invocations. Do not write code files.

## Fallback: agent-browser CLI

If Claude for Chrome MCP tools are unavailable (permission denied, extension not installed, etc.), fall back to the agent-browser CLI:

```bash
agent-browser open http://localhost:3000/login
agent-browser snapshot -i
agent-browser fill @e1 "test@example.com"
agent-browser fill @e2 "password123"
agent-browser click @e3
agent-browser wait --load networkidle
agent-browser screenshot login-result.png
```

## Viewport Sizes Reference

| Viewport | Dimensions | When to Use |
|----------|------------|-------------|
| **Laptop (DEFAULT)** | 1440x900 | Always start here |
| Desktop | 1920x1080 | Large monitor testing |
| Tablet | 768x1024 | Tablet portrait |
| Mobile | 375x667 | Small mobile |

## Quick Reference: MCP Tool Names

| Task | MCP Tool |
|------|----------|
| Get tab context | `mcp__claude-in-chrome__tabs_context_mcp` |
| Create new tab | `mcp__claude-in-chrome__tabs_create_mcp` |
| Navigate | `mcp__claude-in-chrome__navigate` |
| Read page elements | `mcp__claude-in-chrome__read_page` |
| Find element | `mcp__claude-in-chrome__find` |
| Click/type/screenshot | `mcp__claude-in-chrome__computer` |
| Fill form | `mcp__claude-in-chrome__form_input` |
| Resize window | `mcp__claude-in-chrome__resize_window` |
| Get page text | `mcp__claude-in-chrome__get_page_text` |

## Summary

1. **USE MCP TOOLS** - Call `mcp__claude-in-chrome__*` tools directly
2. **DO NOT WRITE TEST FILES** - No Playwright, no Jest, no test frameworks
3. **TAKE SCREENSHOTS** - Visual verification is required
4. **FALLBACK TO agent-browser** - Only if MCP tools are unavailable
