---
name: e2e-testing
description: End-to-end testing using real browser/app automation. Use this skill when asked to test, verify, or validate web applications or Electron apps. ALWAYS uses real automation - NEVER writes Playwright scripts or unit tests. For web apps uses agent-browser CLI, for Electron apps uses electron MCP server (mcp__electron__*).
---

# E2E Testing Skill

**This skill performs REAL browser/app automation to test applications.**

## ABSOLUTE RULES - VIOLATIONS ARE FORBIDDEN

1. **NEVER write Playwright test scripts** - Do not write .spec.ts files, do not write test() blocks
2. **NEVER write unit tests** - This skill uses REAL browsers/apps, not test frameworks
3. **NEVER create test files** - No files in __tests__, no .test.ts, no .spec.ts
4. **USE agent-browser --headed FOR WEB APPS (PRIMARY)** - Call agent-browser CLI in headed mode directly via Bash. This is the preferred and default tool.
5. **USE Claude for Chrome (mcp__claude-in-chrome__*) AS FALLBACK** - Only when agent-browser cannot accomplish something (e.g., interacting with the user's existing authenticated session, complex multi-tab scenarios, or extensions-dependent flows).
6. **USE mcp__electron__* FOR ELECTRON APPS** - Call Electron MCP tools directly
7. **TAKE SCREENSHOTS** - Always capture visual proof of test results
8. **DETECT APP TYPE** - Determine if you are testing a web app or an Electron app and use the correct tools accordingly
9. **RECORD THE SCREEN (NON-NEGOTIABLE)** - You MUST record the screen during the entire browser automation session and serve the recording at the end. See "Screen Recording" section below. This is not optional.
10. **SERVE AND LINK THE RECORDING (NON-NEGOTIABLE)** - At the end of every E2E testing task, you MUST serve the recording over HTTP and provide the link in your answer. No exceptions.

---

## Screen Recording (NON-NEGOTIABLE)

Every E2E testing session MUST be screen-recorded. This is mandatory and cannot be skipped.

### How It Works

Uses `ffmpeg` with macOS AVFoundation to record the screen where the headed browser is visible. The recording is saved to `/tmp/e2e-recordings/` and served via a Python HTTP server so it can be accessed remotely (e.g., over Tailscale).

### Step 1: Start Recording BEFORE Any Browser Automation

Run this BEFORE opening the browser or performing any actions:

```bash
mkdir -p /tmp/e2e-recordings
RECORDING_FILE="/tmp/e2e-recordings/e2e-$(date +%Y%m%d-%H%M%S).mp4"
ffmpeg -f avfoundation -i "2:none" -r 15 -pix_fmt yuv420p -y "$RECORDING_FILE" </dev/null >/dev/null 2>&1 &
FFMPEG_PID=$!
echo "Recording PID: $FFMPEG_PID -> $RECORDING_FILE"
```

Notes:
- `-i "2:none"` captures screen 0 with no audio. If the browser appears on a different screen, adjust the device index (run `ffmpeg -f avfoundation -list_devices true -i "" 2>&1` to list devices).
- `-r 15` = 15 fps (good balance between quality and file size).
- The `</dev/null` prevents ffmpeg from reading stdin which would conflict with the shell.

### Step 2: Run All Browser Automation

Perform all agent-browser or Claude for Chrome actions as described in the sections below.

### Step 3: Stop Recording AFTER All Automation Is Done

```bash
kill -INT $FFMPEG_PID 2>/dev/null
wait $FFMPEG_PID 2>/dev/null
echo "Recording saved: $RECORDING_FILE"
```

Use `-INT` (SIGINT) so ffmpeg finalizes the MP4 file properly. Do NOT use `kill -9` as it will corrupt the file.

### Step 4: Serve the Recording and Provide the Link

```bash
# Kill any previous e2e file server on port 8765
lsof -ti:8765 | xargs kill 2>/dev/null
# Start HTTP server
python3 -m http.server 8765 --directory /tmp/e2e-recordings </dev/null >/dev/null 2>&1 &
echo "File server PID: $!"
HOSTNAME=$(hostname)
BASENAME=$(basename "$RECORDING_FILE")
echo "Recording URL: http://${HOSTNAME}:8765/${BASENAME}"
```

The recording will be accessible at `http://<hostname>:8765/<filename>.mp4`. With Tailscale, this is accessible from any device on the tailnet.

### MANDATORY: Final Output

At the END of your response, you MUST include the recording link in this format:

> Screen recording: http://<hostname>:8765/<filename>.mp4

If the recording failed for any reason, explicitly state WHY it failed. Do not silently skip it.

---

## Web App Testing with agent-browser (PRIMARY)

agent-browser in **headed mode** is the primary tool for all web app E2E testing. It is fast, reliable, and does not require manual permission acceptance. Always use `--headed` so the browser window is visible and captured by the screen recording.

### Important: Always Use --headed

All `agent-browser open` commands MUST include `--headed` so the browser is visible on screen and captured by the ffmpeg screen recording. A headless run defeats the purpose of the recording.

### Session & Authentication Strategy

agent-browser does not connect to the user's existing browser session by default. For apps that require authentication, follow this pattern:

#### Step 1: Try Connecting to Existing Browser Session via CDP

If the user already has Chrome/Chromium running with remote debugging enabled (port 9222), connect to it:

```bash
agent-browser --cdp 9222 snapshot -i
```

If this succeeds, you are connected to the user's live browser session with all their cookies and auth state intact. Continue testing from there.

#### Step 2: If CDP Fails, Try Loading Saved Auth State

```bash
agent-browser state load ~/.e2e-testing/auth.json
agent-browser open http://localhost:3000 --headed
agent-browser snapshot -i
```

If the page shows the authenticated state, continue testing.

#### Step 3: If No Saved State, Launch Headed Browser and Ask User to Log In

```bash
agent-browser open http://localhost:3000/login --headed
```

This opens a visible browser window. Then tell the user:

> "I have opened a browser window at the login page. Please log in with your credentials. Let me know when you are done and I will continue testing."

Wait for the user to confirm they have logged in, then:

```bash
agent-browser snapshot -i
agent-browser state save ~/.e2e-testing/auth.json
```

Save the auth state so future test runs can skip the login step.

#### Step 4: Continue Testing

After authentication is established (via any of the above steps), proceed with the actual test workflow.

### Core Workflow

1. **Start recording** (see Screen Recording section above)
2. **Navigate**: `agent-browser open <url> --headed`
3. **Snapshot**: `agent-browser snapshot -i` (returns interactive elements with refs like `@e1`, `@e2`)
4. **Interact**: Use refs from the snapshot to click, fill, etc.
5. **Re-snapshot**: After navigation or significant DOM changes
6. **Screenshot**: `agent-browser screenshot result.png` for visual proof
7. **Stop recording, serve, and provide link** (see Screen Recording section above)

### Step-by-Step: How to Perform E2E Tests

#### Step 1: Set Viewport Size

Default to 1440x900 (laptop screen) to catch responsive issues:

```bash
agent-browser set viewport 1440 900
```

#### Step 2: Navigate to the Test URL

```bash
agent-browser open http://localhost:3000 --headed
```

#### Step 3: Discover Elements

Get interactive elements with refs:

```bash
agent-browser snapshot -i
```

Output shows elements like: `textbox "Email" [ref=e1]`, `button "Submit" [ref=e3]`

#### Step 4: Interact with Elements

Click using element refs:

```bash
agent-browser click @e1
```

Fill form fields:

```bash
agent-browser fill @e1 "test@example.com"
```

Press keys:

```bash
agent-browser press Enter
```

#### Step 5: Wait for Results

```bash
agent-browser wait --load networkidle
agent-browser wait --text "Success"
agent-browser wait --url "**/dashboard"
```

#### Step 6: Take Screenshots to Verify

```bash
agent-browser screenshot test-result.png
```

### Complete Example: Testing a Login Flow

```bash
# 1. Start screen recording
mkdir -p /tmp/e2e-recordings
RECORDING_FILE="/tmp/e2e-recordings/e2e-$(date +%Y%m%d-%H%M%S).mp4"
ffmpeg -f avfoundation -i "2:none" -r 15 -pix_fmt yuv420p -y "$RECORDING_FILE" </dev/null >/dev/null 2>&1 &
FFMPEG_PID=$!

# 2. Run the test (always --headed)
agent-browser set viewport 1440 900
agent-browser open http://localhost:3000/login --headed
agent-browser screenshot login-page.png
agent-browser snapshot -i
# Output: textbox "Email" [ref=e1], textbox "Password" [ref=e2], button "Login" [ref=e3]
agent-browser fill @e1 "test@example.com"
agent-browser fill @e2 "password123"
agent-browser click @e3
agent-browser wait --load networkidle
agent-browser snapshot -i
agent-browser screenshot login-result.png

# 3. Stop recording
kill -INT $FFMPEG_PID && wait $FFMPEG_PID 2>/dev/null

# 4. Serve and provide link
lsof -ti:8765 | xargs kill 2>/dev/null
python3 -m http.server 8765 --directory /tmp/e2e-recordings </dev/null >/dev/null 2>&1 &
HOSTNAME=$(hostname)
echo "Screen recording: http://${HOSTNAME}:8765/$(basename $RECORDING_FILE)"
```

### WRONG vs RIGHT

#### WRONG - Do NOT do this:

```typescript
// DO NOT WRITE PLAYWRIGHT SCRIPTS
import { test, expect } from '@playwright/test';

test('login works', async ({ page }) => {
  await page.goto('http://localhost:3000/login');
  await page.fill('#email', 'test@example.com');
  // ... THIS IS WRONG!
});
```

#### RIGHT - Do this instead:

Call agent-browser commands directly via Bash. Do not write code files.

### agent-browser Command Reference

| Task | Command |
|------|---------|
| Navigate | `agent-browser open <url> --headed` |
| Snapshot elements | `agent-browser snapshot -i` |
| Click element | `agent-browser click @e1` |
| Fill input | `agent-browser fill @e1 "text"` |
| Press key | `agent-browser press Enter` |
| Set viewport | `agent-browser set viewport 1440 900` |
| Take screenshot | `agent-browser screenshot path.png` |
| Wait for element | `agent-browser wait @e1` |
| Wait for text | `agent-browser wait --text "Success"` |
| Wait for URL | `agent-browser wait --url "**/dashboard"` |
| Wait for idle | `agent-browser wait --load networkidle` |
| Get element text | `agent-browser get text @e1` |
| Get page title | `agent-browser get title` |
| Get current URL | `agent-browser get url` |
| Check visibility | `agent-browser is visible @e1` |
| Scroll | `agent-browser scroll down 500` |
| Full page screenshot | `agent-browser screenshot --full path.png` |
| Connect to existing browser | `agent-browser --cdp 9222 snapshot` |
| Save auth state | `agent-browser state save auth.json` |
| Load auth state | `agent-browser state load auth.json` |
| Headed mode (DEFAULT) | `agent-browser open <url> --headed` |
| Console logs | `agent-browser console` |
| Page errors | `agent-browser errors` |

---

## Web App Testing with Claude for Chrome (FALLBACK ONLY)

Use `mcp__claude-in-chrome__*` MCP tools ONLY when agent-browser cannot accomplish the task. Common reasons to fall back:

- The test requires interaction with the user's existing authenticated Chrome session and CDP is not available
- The test involves browser extensions that agent-browser cannot access
- Complex multi-tab scenarios where agent-browser's tab management falls short
- The user explicitly requests Claude for Chrome

### When Using Claude for Chrome

Follow the standard Claude for Chrome workflow:
1. `mcp__claude-in-chrome__tabs_context_mcp` to see current tabs
2. `mcp__claude-in-chrome__navigate` or `mcp__claude-in-chrome__tabs_create_mcp` to navigate
3. `mcp__claude-in-chrome__read_page` to analyze page content
4. `mcp__claude-in-chrome__computer` for clicks and interactions
5. `mcp__claude-in-chrome__form_input` for form filling
6. `mcp__claude-in-chrome__javascript_tool` for custom JS execution

Note: The screen recording (ffmpeg) still applies when using Claude for Chrome. The Chrome window must be visible on the recorded screen.

---

## Electron App Testing

**For Electron apps, use the `mcp__electron__*` MCP tools.** The Electron MCP server connects to any Electron app with remote debugging enabled (port 9222).

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

---

## Viewport Sizes Reference

| Viewport | Dimensions | When to Use |
|----------|------------|-------------|
| **Laptop (DEFAULT)** | 1440x900 | Always start here |
| Desktop | 1920x1080 | Large monitor testing |
| Tablet | 768x1024 | Tablet portrait |
| Mobile | 375x667 | Small mobile |

## How to Choose the Right Tools

| App Type | Tools | How to Detect |
|----------|-------|---------------|
| **Web app** (Next.js, React, etc.) | `agent-browser --headed` (PRIMARY), `mcp__claude-in-chrome__*` (FALLBACK) | Runs in browser, has URL with localhost or domain |
| **Electron app** | `mcp__electron__*` | Has `electron` in package.json, runs as desktop app |
| **Capacitor app** | Simulator screenshots, user verification | Capacitor shell app, CSS/JS injections |

When in doubt, check `package.json` for `electron` or `@capacitor/core` dependencies.

## Summary

1. **RECORD THE SCREEN (NON-NEGOTIABLE)** - Start ffmpeg BEFORE any automation, stop AFTER, serve via HTTP, provide link
2. **USE agent-browser --headed FOR WEB APPS** - Primary tool for browser-based testing. Always headed mode.
3. **USE Claude for Chrome AS FALLBACK** - Only when agent-browser cannot do what's needed
4. **USE mcp__electron__* FOR ELECTRON APPS** - MCP tools for desktop app testing
5. **DO NOT WRITE TEST FILES** - No Playwright, no Jest, no test frameworks
6. **HANDLE AUTH PROPERLY** - Try CDP connection first, then saved state, then headed mode with user login
7. **TAKE SCREENSHOTS** - Visual verification is required
8. **ALWAYS END WITH THE RECORDING LINK** - Your final output MUST include `Screen recording: http://<hostname>:8765/<filename>.mp4`
