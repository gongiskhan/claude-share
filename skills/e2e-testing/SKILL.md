---
name: e2e-testing
description: End-to-end testing using real browser/app automation. Use this skill when asked to test, verify, or validate web applications or Electron apps. ALWAYS uses real automation - NEVER writes Playwright scripts or unit tests. For web apps uses Claude for Chrome (mcp__claude-in-chrome__*), for Electron apps uses electron MCP server (mcp__electron__*), with agent-browser CLI as fallback.
---

# E2E Testing Skill

**This skill performs REAL browser/app automation to test applications.**

## ABSOLUTE RULES - VIOLATIONS ARE FORBIDDEN

1. **NEVER write Playwright test scripts** - Do not write .spec.ts files, do not write test() blocks
2. **NEVER write unit tests** - This skill uses REAL browsers/apps, not test frameworks
3. **NEVER create test files** - No files in __tests__, no .test.ts, no .spec.ts
4. **USE MCP TOOLS DIRECTLY** - Call `mcp__claude-in-chrome__*` for web apps or `mcp__electron__*` for Electron apps. Do not write code that calls them.
5. **TAKE SCREENSHOTS** - Always capture visual proof of test results
6. **DETECT APP TYPE** - Determine if you are testing a web app or an Electron app and use the correct MCP tools accordingly

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

## Electron App Testing

**For Electron apps, use the `mcp__electron__*` MCP tools instead of Chrome MCP tools.** The Electron MCP server connects to any Electron app with remote debugging enabled (port 9222).

### Step 1: Get Window Info

```
mcp__electron__get_electron_window_info
```

This detects running Electron apps and returns window information.

### Step 2: Take a Screenshot

```
mcp__electron__take_screenshot
```

Optionally specify a `windowTitle` to target a specific window. Returns base64 image data for analysis.

### Step 3: Discover Page Elements

```
mcp__electron__send_command_to_electron with command="get_page_structure"
```

This returns an organized overview of all buttons, inputs, selects, and links on the page.

For more detail on specific element types:

```
mcp__electron__send_command_to_electron with command="find_elements"
mcp__electron__send_command_to_electron with command="debug_elements"
```

### Step 4: Interact with Elements

Click by visible text or aria-label:

```
mcp__electron__send_command_to_electron with command="click_by_text", args={"text": "Submit"}
```

Click by CSS selector:

```
mcp__electron__send_command_to_electron with command="click_by_selector", args={"selector": "button.submit-btn"}
```

Fill input fields (by placeholder, selector, or label):

```
mcp__electron__send_command_to_electron with command="fill_input", args={"placeholder": "Enter name", "value": "John Doe"}
mcp__electron__send_command_to_electron with command="fill_input", args={"selector": "#email", "value": "user@example.com"}
```

Select dropdown options:

```
mcp__electron__send_command_to_electron with command="select_option", args={"selector": "#role", "value": "admin"}
```

Send keyboard shortcuts:

```
mcp__electron__send_command_to_electron with command="send_keyboard_shortcut", args={"text": "Enter"}
mcp__electron__send_command_to_electron with command="send_keyboard_shortcut", args={"text": "Meta+N"}
```

Navigate to hash routes:

```
mcp__electron__send_command_to_electron with command="navigate_to_hash", args={"text": "#settings"}
```

### Step 5: Get Page Content

```
mcp__electron__send_command_to_electron with command="get_body_text"
mcp__electron__send_command_to_electron with command="get_title"
mcp__electron__send_command_to_electron with command="get_url"
```

### Step 6: Run Custom JavaScript

```
mcp__electron__send_command_to_electron with command="eval", args={"code": "document.querySelectorAll('.item').length"}
```

### Step 7: Check Console Logs

```
mcp__electron__read_electron_logs with logType="all"
```

Useful for debugging errors or verifying app behavior.

### Step 8: Verify Form State

```
mcp__electron__send_command_to_electron with command="verify_form_state"
```

### Complete Example: Testing an Electron App Settings Page

1. Call `mcp__electron__get_electron_window_info` to find the app
2. Call `mcp__electron__take_screenshot` to see current state
3. Call `mcp__electron__send_command_to_electron` with command="get_page_structure" to discover elements
4. Call `mcp__electron__send_command_to_electron` with command="click_by_text", args={"text": "Settings"}
5. Call `mcp__electron__take_screenshot` to verify navigation
6. Call `mcp__electron__send_command_to_electron` with command="fill_input", args={"placeholder": "Display name", "value": "Test User"}
7. Call `mcp__electron__send_command_to_electron` with command="click_by_text", args={"text": "Save"}
8. Call `mcp__electron__take_screenshot` to verify save worked
9. Call `mcp__electron__read_electron_logs` with logType="console" to check for errors

### Quick Reference: Electron MCP Tool Names

| Task | MCP Tool | Command |
|------|----------|---------|
| Get window info | `mcp__electron__get_electron_window_info` | - |
| Take screenshot | `mcp__electron__take_screenshot` | - |
| Read logs | `mcp__electron__read_electron_logs` | - |
| Page structure | `mcp__electron__send_command_to_electron` | `get_page_structure` |
| Find elements | `mcp__electron__send_command_to_electron` | `find_elements` |
| Click by text | `mcp__electron__send_command_to_electron` | `click_by_text` |
| Click by selector | `mcp__electron__send_command_to_electron` | `click_by_selector` |
| Fill input | `mcp__electron__send_command_to_electron` | `fill_input` |
| Select option | `mcp__electron__send_command_to_electron` | `select_option` |
| Keyboard shortcut | `mcp__electron__send_command_to_electron` | `send_keyboard_shortcut` |
| Navigate hash | `mcp__electron__send_command_to_electron` | `navigate_to_hash` |
| Get page text | `mcp__electron__send_command_to_electron` | `get_body_text` |
| Get title | `mcp__electron__send_command_to_electron` | `get_title` |
| Get URL | `mcp__electron__send_command_to_electron` | `get_url` |
| Run JS | `mcp__electron__send_command_to_electron` | `eval` |
| Check form state | `mcp__electron__send_command_to_electron` | `verify_form_state` |
| Debug elements | `mcp__electron__send_command_to_electron` | `debug_elements` |

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

## How to Choose the Right Tools

| App Type | MCP Tools | How to Detect |
|----------|-----------|---------------|
| **Web app** (Next.js, React, etc.) | `mcp__claude-in-chrome__*` | Runs in browser, has URL with localhost or domain |
| **Electron app** | `mcp__electron__*` | Has `electron` in package.json, runs as desktop app |
| **Capacitor app** | Simulator screenshots, user verification | Capacitor shell app, CSS/JS injections |

When in doubt, check `package.json` for `electron` or `@capacitor/core` dependencies.

## Summary

1. **USE THE RIGHT MCP TOOLS** - `mcp__claude-in-chrome__*` for web apps, `mcp__electron__*` for Electron apps
2. **DO NOT WRITE TEST FILES** - No Playwright, no Jest, no test frameworks
3. **TAKE SCREENSHOTS** - Visual verification is required
4. **FALLBACK TO agent-browser** - Only if Chrome MCP tools are unavailable (web apps only)
