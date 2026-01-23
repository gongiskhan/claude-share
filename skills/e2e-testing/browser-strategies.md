# Browser Strategies Reference

Detailed configuration and troubleshooting for each E2E testing browser strategy.

## Strategy 1: Claude for Chrome MCP

### Available Tools

When Claude for Chrome is active, these MCP tools are available:

| Tool | Purpose |
|------|---------|
| `tabs_context_mcp` | Get/create tab context for the session |
| `tabs_create_mcp` | Create new tab in MCP group |
| `navigate` | Go to URL or back/forward |
| `read_page` | Get accessibility tree of page elements |
| `find` | Natural language element search |
| `form_input` | Set form field values |
| `computer` | Mouse/keyboard actions, screenshots |
| `get_page_text` | Extract text content from page |

### Workflow Example

```
1. tabs_context_mcp(createIfEmpty: true)  → Get tabId
2. navigate(tabId, url)                    → Load page
3. read_page(tabId) or find(tabId, query) → Locate elements
4. form_input(tabId, ref, value)          → Fill forms
5. computer(tabId, action: "left_click", ref) → Click
6. computer(tabId, action: "screenshot")  → Verify result
```

### Permission Configuration

To skip permission prompts, configure in `~/.claude/settings.json`:

```json
{
  "permissions": {
    "allow": [
      "mcp__Claude in Chrome__*"
    ]
  }
}
```

### Detecting Extension Availability

The extension is available if calling `tabs_context_mcp` succeeds. If it fails or times out (user doesn't accept permissions within 30s), proceed to Strategy 2.

---

## Strategy 2: Chrome Debug Mode + Retry Extension

### Purpose

Launch Chrome with remote debugging enabled, then retry the Claude for Chrome extension. This gives the extension another chance to connect.

### Launch Commands by Platform

**macOS:**
```bash
CHROME_PATH="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
USER_DATA="$HOME/.e2e-testing/chrome-profile"

"$CHROME_PATH" \
  --remote-debugging-port=9222 \
  --user-data-dir="$USER_DATA" \
  --no-first-run \
  --no-default-browser-check \
  --disable-background-networking \
  --disable-client-side-phishing-detection \
  --disable-default-apps \
  --disable-hang-monitor \
  --disable-popup-blocking \
  --disable-prompt-on-repost \
  --disable-sync \
  --metrics-recording-only \
  --safebrowsing-disable-auto-update &
```

**Linux:**
```bash
CHROME_PATH=$(which google-chrome || which google-chrome-stable || which chromium-browser)
USER_DATA="$HOME/.e2e-testing/chrome-profile"

"$CHROME_PATH" \
  --remote-debugging-port=9222 \
  --user-data-dir="$USER_DATA" \
  --no-first-run \
  --no-default-browser-check &
```

### After Launch

1. Wait 3 seconds for Chrome to start
2. **Retry Claude for Chrome MCP tools** (tabs_context_mcp, etc.)
3. If extension works, use it for testing
4. If extension still fails, connect via CDP as fallback:

```typescript
import { chromium } from 'playwright';

async function connectToChrome() {
  const browser = await chromium.connectOverCDP('http://localhost:9222');
  const contexts = browser.contexts();
  const context = contexts[0];
  const pages = context.pages();
  const page = pages[0] || await context.newPage();
  return { browser, context, page };
}
```

### Checking if Chrome is Running

```bash
# Check if debug port is open
curl -s http://localhost:9222/json/version && echo "Chrome debug mode active"

# List available pages
curl -s http://localhost:9222/json/list | jq '.[].url'
```

---

## Strategy 3: Chromium + Retry Extension

### Purpose

Launch Chromium via Playwright, then retry the Claude for Chrome extension one more time.

### Full Configuration

```typescript
import { chromium, type BrowserContext } from 'playwright';
import * as path from 'path';
import * as os from 'os';

const USER_DATA_DIR = path.join(os.homedir(), '.e2e-testing', 'chromium-profile');

async function launchChromium(): Promise<BrowserContext> {
  const context = await chromium.launchPersistentContext(USER_DATA_DIR, {
    // Visibility
    headless: false,
    slowMo: 100,

    // Viewport
    viewport: { width: 1280, height: 720 },

    // Anti-detection
    args: [
      '--disable-blink-features=AutomationControlled',
      '--no-first-run',
      '--no-default-browser-check',
      '--disable-infobars',
      '--disable-extensions',
      '--disable-dev-shm-usage',
      '--disable-gpu'
    ],

    // Permissions
    permissions: ['geolocation', 'notifications'],

    // Locale
    locale: 'en-US',
    timezoneId: 'America/New_York'
  });

  return context;
}
```

### After Launch

1. **Retry Claude for Chrome MCP tools** one more time
2. If extension works, use it
3. If not, use the Playwright page directly for basic automation
4. If that also fails, proceed to Strategy 4 (agent-browser)

### Session Inspection

```typescript
// View stored cookies
const cookies = await context.cookies();
console.log('Stored cookies:', cookies.map(c => c.name));

// View local storage (per origin)
const page = context.pages()[0];
const localStorage = await page.evaluate(() => {
  return Object.keys(window.localStorage);
});
console.log('Local storage keys:', localStorage);
```

---

## Strategy 4: agent-browser Skill (FINAL FALLBACK)

**IMPORTANT: This is the FINAL fallback. Do NOT fall back to writing Playwright test scripts.**

### Installation

The agent-browser CLI should be available. If not, check the agent-browser skill for installation.

### Core Commands

```bash
# Navigation
agent-browser open <url>      # Navigate to URL
agent-browser back            # Go back
agent-browser forward         # Go forward
agent-browser reload          # Reload page
agent-browser close           # Close browser

# Page analysis
agent-browser snapshot            # Full accessibility tree
agent-browser snapshot -i         # Interactive elements only (recommended)
agent-browser snapshot -c         # Compact output

# Interactions (use @refs from snapshot)
agent-browser click @e1           # Click
agent-browser fill @e2 "text"     # Clear and type
agent-browser type @e2 "text"     # Type without clearing
agent-browser press Enter         # Press key
agent-browser hover @e1           # Hover
agent-browser check @e1           # Check checkbox
agent-browser select @e1 "value"  # Select dropdown

# Get information
agent-browser get text @e1        # Get element text
agent-browser get value @e1       # Get input value
agent-browser get title           # Get page title
agent-browser get url             # Get current URL

# Wait
agent-browser wait @e1                     # Wait for element
agent-browser wait 2000                    # Wait milliseconds
agent-browser wait --text "Success"        # Wait for text
agent-browser wait --url "**/dashboard"    # Wait for URL pattern
agent-browser wait --load networkidle      # Wait for network idle

# Screenshots
agent-browser screenshot          # Screenshot to stdout
agent-browser screenshot path.png # Save to file
agent-browser screenshot --full   # Full page
```

### Example: Complete Login Flow

```bash
# Navigate to login page
agent-browser open http://localhost:3000/login

# Get interactive elements
agent-browser snapshot -i
# Output shows: textbox "Email" [ref=e1], textbox "Password" [ref=e2], button "Login" [ref=e3]

# Fill form
agent-browser fill @e1 "user@example.com"
agent-browser fill @e2 "password123"

# Submit
agent-browser click @e3

# Wait for redirect
agent-browser wait --url "**/dashboard"

# Verify result
agent-browser snapshot -i
agent-browser screenshot dashboard.png
```

### When to Use

agent-browser is the FINAL fallback when:
- Claude for Chrome extension is unavailable
- Chrome debug mode doesn't work
- Chromium launch fails
- All MCP-based approaches have been exhausted

**NEVER fall back to writing Playwright test scripts. Always use agent-browser as the final option.**

---

## Session Directory Structure

```
~/.e2e-testing/
├── chrome-profile/           # Strategy 2: Chrome debug mode
│   ├── Default/
│   │   ├── Cookies
│   │   ├── Local Storage/
│   │   └── Session Storage/
│   └── ...
└── chromium-profile/         # Strategy 3: Playwright persistent
    ├── Default/
    │   ├── Cookies
    │   ├── Local Storage/
    │   └── Session Storage/
    └── ...
```

---

## Strategy Selection Summary

| Scenario | Strategy |
|----------|----------|
| Extension available, user accepts permissions | Strategy 1 (Claude for Chrome MCP) |
| Extension timeout/declined | Strategy 2 (Chrome debug + retry) |
| Chrome debug fails | Strategy 3 (Chromium + retry) |
| All browser strategies fail | Strategy 4 (agent-browser) |

**Remember: NEVER write Playwright test scripts. The agent-browser skill is the final fallback.**
