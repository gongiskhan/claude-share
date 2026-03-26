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
4. **NEVER write programmatic test scripts as a workaround** - Do not write Node.js/Python scripts that test via WebSocket, HTTP API, or other programmatic means. This skill is about VISUAL browser automation, not programmatic testing.
5. **ALWAYS USE agent-browser --headed FOR WEB APPS FIRST** - This is NON-NEGOTIABLE. Call agent-browser CLI in headed mode directly via Bash. Do NOT skip to Chrome MCP or programmatic testing. agent-browser MUST be your first and primary tool. See "Resilience" section for what to do if it fails.
6. **Claude for Chrome (mcp__claude-in-chrome__*) is a RARE FALLBACK** - Only use it when agent-browser truly cannot accomplish the task (e.g., you need the user's existing authenticated session and CDP is unavailable, or the user explicitly requests it). Always try agent-browser first.
8. **USE mcp__electron__* FOR ELECTRON APPS** - Call Electron MCP tools directly
9. **TAKE SCREENSHOTS** - Always capture visual proof of test results
10. **DETECT APP TYPE** - Determine if you are testing a web app or an Electron app and use the correct tools accordingly
11. **RECORD THE BROWSER (NON-NEGOTIABLE)** - You MUST record the browser during the entire automation session using `agent-browser record start/stop` and serve the recording at the end. See "Screen Recording" section below. This is not optional.
12. **SERVE AND LINK THE RECORDING (NON-NEGOTIABLE)** - At the end of every E2E testing task, you MUST serve the recording over HTTP and provide the link in your answer. No exceptions.

---

## Screen Recording (NON-NEGOTIABLE)

Every E2E testing session MUST be screen-recorded. This is mandatory and cannot be skipped.

### How It Works

Uses `agent-browser record` (Playwright's built-in viewport recording) to capture the browser content directly. This records the actual page viewport -- it does NOT depend on screen positions, foreground/background state, or display configuration. The recording is saved to `/tmp/e2e-recordings/` and served via a Python HTTP server so it can be accessed remotely (e.g., over Tailscale).

### Step 1: Open the Browser and Start Recording

Open the headed browser and immediately start recording. The recording captures the browser viewport directly, so screen detection is unnecessary:

```bash
mkdir -p /tmp/e2e-recordings
RECORDING_FILE="/tmp/e2e-recordings/e2e-$(date +%Y%m%d-%H%M%S).webm"
agent-browser open <target-url> --headed
agent-browser record start "$RECORDING_FILE"
echo "Recording -> $RECORDING_FILE"
```

Notes:
- `agent-browser record` uses Playwright's built-in video capture -- it records the page viewport directly, not the screen.
- Works regardless of which monitor the browser is on, whether the window is in the foreground, or display configuration.
- Output format is WebM (playable in all modern browsers).

### Step 2: Run All Browser Automation

Perform all agent-browser actions as described in the sections below. The browser is already open from Step 1 -- continue interacting with it.

### Step 3: Stop Recording AFTER All Automation Is Done

```bash
agent-browser record stop
echo "Recording saved: $RECORDING_FILE"
```

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

The recording will be accessible at `http://<hostname>:8765/<filename>.webm`. With Tailscale, this is accessible from any device on the tailnet.

### MANDATORY: Final Output

At the END of your response, you MUST include the recording link in this format:

> Screen recording: http://<hostname>:8765/<filename>.webm

If the recording failed for any reason, explicitly state WHY it failed. Do not silently skip it.

### Fallback: ffmpeg Screen Recording (Claude for Chrome only)

When using Claude for Chrome (mcp__claude-in-chrome__*) instead of agent-browser, `agent-browser record` is not available. In that case, fall back to ffmpeg screen recording:

```bash
mkdir -p /tmp/e2e-recordings
FFMPEG_DEVICE=$(python3 ~/.claude/skills/e2e-testing/detect_recording_screen.py 2>/dev/null)
RECORDING_FILE="/tmp/e2e-recordings/e2e-$(date +%Y%m%d-%H%M%S).mp4"
ffmpeg -f avfoundation -i "${FFMPEG_DEVICE}:none" -r 15 -pix_fmt yuv420p -y "$RECORDING_FILE" </dev/null >/dev/null 2>&1 &
FFMPEG_PID=$!
```

Stop with `kill -INT $FFMPEG_PID && wait $FFMPEG_PID 2>/dev/null` (use SIGINT so ffmpeg finalizes the MP4 properly).

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

1. **Open browser headed + start recording**: `agent-browser open <url> --headed` then `agent-browser record start <path>.webm`
2. **Snapshot**: `agent-browser snapshot -i` (returns interactive elements with refs like `@e1`, `@e2`)
3. **Interact**: Use refs from the snapshot to click, fill, etc.
4. **Re-snapshot**: After navigation or significant DOM changes
5. **Screenshot**: `agent-browser screenshot result.png` for visual proof
6. **Stop recording**: `agent-browser record stop`
7. **Serve and provide link** (see Screen Recording section above)

### Resilience: Do NOT Give Up on agent-browser

agent-browser is reliable but may occasionally have transient issues. **You MUST persist through errors before considering any alternative.** Follow this escalation:

#### If `agent-browser open` fails:
1. **Retry once** -- transient failures happen (browser startup race conditions)
2. **Check if the server is running** -- `curl -s -o /dev/null -w "%{http_code}" <url>` to verify the URL is reachable
3. **Wait for the server** -- if it's still starting, `sleep 3` and retry
4. **Try a different port** -- the app may be on a non-standard port; check running processes with `lsof -i -P | grep LISTEN`
5. **Only after all retries fail**, report the error to the user and ask for guidance

#### If `agent-browser snapshot` returns empty or unexpected content:
1. **Wait for the page to load** -- `agent-browser wait --load networkidle` then retry snapshot
2. **Check for JavaScript errors** -- `agent-browser errors` to see if the app is crashing
3. **Try a full snapshot** -- `agent-browser snapshot` (without `-i`) to see ALL elements, not just interactive ones
4. **Take a screenshot** -- `agent-browser screenshot debug.png` to visually see what's rendered

#### If `agent-browser click` or `agent-browser fill` fails:
1. **Re-snapshot** -- element refs may have changed after DOM updates: `agent-browser snapshot -i`
2. **Wait for the element** -- `agent-browser wait @eN` before interacting
3. **Try a different selector** -- use CSS selector instead of ref: `agent-browser click "button.submit"`
4. **Use JavaScript as last resort** -- `agent-browser eval "document.querySelector('button').click()"`

#### NEVER do these as a "fallback":
- Do NOT switch to Claude for Chrome MCP for localhost URLs (it CANNOT reach localhost)
- Do NOT write programmatic test scripts (WebSocket clients, HTTP test scripts, etc.)
- Do NOT abandon browser automation and resort to `curl` or API-level testing
- Do NOT tell the user "browser automation failed" after only 1 attempt

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
# 1. Open browser headed and start recording
mkdir -p /tmp/e2e-recordings
RECORDING_FILE="/tmp/e2e-recordings/e2e-$(date +%Y%m%d-%H%M%S).webm"
agent-browser set viewport 1440 900
agent-browser open http://localhost:3000/login --headed
agent-browser record start "$RECORDING_FILE"

# 2. Run the test
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
agent-browser record stop

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
| Start recording | `agent-browser record start <path>.webm` |
| Stop recording | `agent-browser record stop` |
| Console logs | `agent-browser console` |
| Page errors | `agent-browser errors` |

---

## Web App Testing with Claude for Chrome (RARE FALLBACK ONLY)

**You MUST try agent-browser first.** Only fall back to Chrome MCP after agent-browser has been attempted and cannot accomplish the task.

### When Chrome MCP is appropriate (rare)

Use `mcp__claude-in-chrome__*` MCP tools ONLY when:
1. You need the user's **existing authenticated Chrome session** (cookies, login state) AND CDP is unavailable
2. The test involves **browser extensions** that agent-browser cannot access
3. The user **explicitly requests** Claude for Chrome

### When Using Claude for Chrome

Follow the standard Claude for Chrome workflow:
1. `mcp__claude-in-chrome__tabs_context_mcp` to see current tabs
2. `mcp__claude-in-chrome__navigate` or `mcp__claude-in-chrome__tabs_create_mcp` to navigate
3. `mcp__claude-in-chrome__read_page` to analyze page content
4. `mcp__claude-in-chrome__computer` for clicks and interactions
5. `mcp__claude-in-chrome__form_input` for form filling
6. `mcp__claude-in-chrome__javascript_tool` for custom JS execution

Note: When using Claude for Chrome, `agent-browser record` is NOT available. Use the ffmpeg fallback described in the Screen Recording section. The Chrome window must be visible on the recorded screen.

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
| **Web app** (Next.js, React, etc.) | `agent-browser --headed` (PRIMARY, always try first), Chrome MCP (rare fallback) | Runs in browser, has URL with localhost or domain |
| **Electron app** | `mcp__electron__*` | Has `electron` in package.json, runs as desktop app |
| **Capacitor app** | Simulator screenshots, user verification | Capacitor shell app, CSS/JS injections |

When in doubt, check `package.json` for `electron` or `@capacitor/core` dependencies.

## Summary

1. **ALWAYS USE agent-browser --headed FOR WEB APPS FIRST** - This is the primary tool. Always try it before Chrome MCP. No exceptions.
2. **BE RESILIENT** - If agent-browser fails, retry, debug, check the server, wait. Do NOT give up after 1 attempt. See the Resilience section.
3. **NEVER WRITE PROGRAMMATIC TEST SCRIPTS** - No WebSocket clients, no HTTP test scripts, no Node.js test files. This skill is about visual browser automation.
4. **Chrome MCP is a RARE FALLBACK** - Only when you need existing auth session and CDP unavailable, or user explicitly requests it.
5. **RECORD THE BROWSER (NON-NEGOTIABLE)** - Use `agent-browser record start/stop` to capture the viewport directly. Serve via HTTP, provide link.
6. **USE mcp__electron__* FOR ELECTRON APPS** - MCP tools for desktop app testing.
7. **HANDLE AUTH PROPERLY** - Try CDP connection first, then saved state, then headed mode with user login.
8. **TAKE SCREENSHOTS** - Visual verification is required.
9. **ALWAYS END WITH THE RECORDING LINK** - Your final output MUST include `Screen recording: http://<hostname>:8765/<filename>.webm`
