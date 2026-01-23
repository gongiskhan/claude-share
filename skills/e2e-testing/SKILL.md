---
name: e2e-testing
description: End-to-end browser testing with intelligent fallback strategies. Use this skill when asked to test, verify, or validate web applications through browser automation. Always performs E2E tests (never unit tests, never Playwright test scripts). Supports automatic fallback: Claude for Chrome → Chrome debug mode (retry extension) → Chromium (retry extension) → agent-browser skill. Maintains persistent sessions for authenticated testing.
---

# E2E Testing Skill

End-to-end browser testing with intelligent fallback strategies.

## CRITICAL RULES

1. **E2E only** - This skill is exclusively for browser-based end-to-end testing
2. **NEVER write Playwright test scripts** - Always use browser automation directly via the fallback chain
3. **NEVER write unit tests** - This skill is for E2E browser testing only
4. **Visible browser** - Always run non-headless so user can observe
5. **Follow the fallback chain** - Try each strategy in order until one works
6. **agent-browser is the FINAL fallback** - If all else fails, use the agent-browser skill

## Browser Strategy Fallback Chain

**IMPORTANT: Follow this exact order. Do NOT skip to Playwright tests.**

```
User requests E2E test
    │
    ▼
┌─────────────────────────────────────────────────────────────────────┐
│ STRATEGY 1: Claude for Chrome (MCP Extension)                       │
│ Check: Are Claude for Chrome MCP tools available?                   │
│        (tabs_context_mcp, read_page, navigate, computer, find)      │
│ ├─ Yes → Use Claude for Chrome tools directly                       │
│ │        Wait up to 30s for user to accept permission prompt        │
│ └─ No/Timeout/Declined → Continue to Strategy 2                     │
└─────────────────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────────────────┐
│ STRATEGY 2: Launch Chrome Debug Mode + Retry Extension              │
│ Action: Launch Chrome with --remote-debugging-port=9222             │
│         Then RETRY Claude for Chrome MCP tools                      │
│ ├─ Extension works → Use Claude for Chrome tools                    │
│ └─ Still fails → Continue to Strategy 3                             │
└─────────────────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────────────────┐
│ STRATEGY 3: Launch Chromium + Retry Extension                       │
│ Action: Launch Chromium via Playwright                              │
│         Then RETRY Claude for Chrome MCP tools                      │
│ ├─ Extension works → Use Claude for Chrome tools                    │
│ └─ Still fails → Continue to Strategy 4                             │
└─────────────────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────────────────┐
│ STRATEGY 4: agent-browser Skill (FINAL FALLBACK)                    │
│ Action: Use the agent-browser skill CLI commands                    │
│         This is a CLI-based browser automation tool                 │
│ ├─ Success → Complete test via agent-browser commands               │
│ └─ Fail → Report all strategies exhausted                           │
└─────────────────────────────────────────────────────────────────────┘

⚠️  DO NOT fall back to writing Playwright test scripts!
⚠️  agent-browser skill is the FINAL option, not Playwright!
```

## Strategy Implementation

### Strategy 1: Claude for Chrome (MCP)

If Claude for Chrome MCP tools are available (`read_page`, `navigate`, `computer`, `find`, etc.):

1. Use `tabs_context_mcp` to get/create tab context
2. Use `navigate` to go to test URL
3. Use `read_page` or `find` to locate elements
4. Use `computer` for interactions (clicks, typing)
5. Take screenshots with `computer` action="screenshot" to verify results

This is the preferred method - it uses the user's actual Chrome browser with all sessions intact.

**If user doesn't accept permissions within 30 seconds or extension is unavailable, proceed to Strategy 2.**

### Strategy 2: Chrome Debug Mode + Retry Extension

Launch Chrome with remote debugging, then retry the Claude for Chrome extension:

```bash
# macOS
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --remote-debugging-port=9222 \
  --user-data-dir="$HOME/.e2e-testing/chrome-profile" \
  --no-first-run \
  --no-default-browser-check &

# Linux
google-chrome \
  --remote-debugging-port=9222 \
  --user-data-dir="$HOME/.e2e-testing/chrome-profile" \
  --no-first-run \
  --no-default-browser-check &

# Wait for Chrome to start
sleep 3
```

After Chrome launches, **retry using Claude for Chrome MCP tools**. The extension may now be available.

If the extension still doesn't work, you can connect via CDP as fallback:

```typescript
import { chromium } from 'playwright';
const browser = await chromium.connectOverCDP('http://localhost:9222');
const context = browser.contexts()[0];
const page = context.pages()[0] || await context.newPage();
```

### Strategy 3: Chromium + Retry Extension

Launch Chromium via Playwright, then retry the extension:

```typescript
import { chromium } from 'playwright';

const userDataDir = process.env.HOME + '/.e2e-testing/chromium-profile';

const context = await chromium.launchPersistentContext(userDataDir, {
  headless: false,
  slowMo: 100,
  viewport: { width: 1280, height: 720 },
  args: [
    '--disable-blink-features=AutomationControlled',
    '--no-first-run',
    '--no-default-browser-check'
  ]
});

const page = context.pages()[0] || await context.newPage();
```

After launching, **retry using Claude for Chrome MCP tools** in case the extension is now available.

### Strategy 4: agent-browser Skill (FINAL FALLBACK)

**This is the FINAL fallback. Use the agent-browser skill, NOT Playwright test scripts.**

The agent-browser skill provides a CLI for browser automation. Use these commands:

```bash
# Navigate to page
agent-browser open <url>

# Get interactive elements with refs
agent-browser snapshot -i

# Interact using refs from snapshot
agent-browser click @e1
agent-browser fill @e2 "text"

# Take screenshot
agent-browser screenshot result.png

# Close browser
agent-browser close
```

**Example workflow:**
```bash
agent-browser open http://localhost:3000/login
agent-browser snapshot -i
# Output: textbox "Email" [ref=e1], textbox "Password" [ref=e2], button "Login" [ref=e3]
agent-browser fill @e1 "test@example.com"
agent-browser fill @e2 "password123"
agent-browser click @e3
agent-browser wait --load networkidle
agent-browser screenshot login-result.png
```

See the agent-browser skill for complete command reference.

## Session Persistence

All strategies use a common session directory structure:

```
~/.e2e-testing/
├── chrome-profile/      # Chrome debug mode sessions
└── chromium-profile/    # Chromium persistent context
```

**First-time setup**: When testing authenticated flows, manually log in once using the browser. The session will be preserved for subsequent test runs.

## Common Test Patterns (using agent-browser)

### Testing a Form Submission

```bash
agent-browser open http://localhost:3000/contact
agent-browser snapshot -i
# Output: textbox "Email" [ref=e1], textbox "Message" [ref=e2], button "Submit" [ref=e3]

agent-browser fill @e1 "test@example.com"
agent-browser fill @e2 "Test message"
agent-browser click @e3
agent-browser wait --text "Success"
agent-browser screenshot form-submitted.png
```

### Testing Authentication Flow

```bash
agent-browser open http://localhost:3000/login
agent-browser snapshot -i
# Output: textbox "Email" [ref=e1], textbox "Password" [ref=e2], button "Login" [ref=e3]

agent-browser fill @e1 "test@example.com"
agent-browser fill @e2 "password123"
agent-browser click @e3
agent-browser wait --url "**/dashboard"
agent-browser snapshot -i
agent-browser screenshot logged-in.png
```

### Visual Verification

```bash
# Full page screenshot
agent-browser screenshot --full full-page.png

# Screenshot after viewport change
agent-browser set viewport 375 800
agent-browser screenshot mobile.png

agent-browser set viewport 1440 900
agent-browser screenshot desktop.png
```

## Troubleshooting

### Permission Timeout (Strategy 1)
If Claude for Chrome permission prompt times out or user declines, proceed to Strategy 2 (Chrome debug mode).

### Chrome Already Running (Strategy 2)
Chrome debug mode requires no other Chrome instances using the same profile. Close existing Chrome windows or use a different profile directory.

### Profile Corruption
If persistent sessions become corrupted, delete the profile directory:
```bash
rm -rf ~/.e2e-testing/chrome-profile
rm -rf ~/.e2e-testing/chromium-profile
```

### Chromium Not Found (Strategy 3)
Install Playwright browsers:
```bash
npx playwright install chromium
```

### agent-browser Not Found (Strategy 4)
The agent-browser CLI should be available. Check the agent-browser skill for installation instructions.

## Companion Skills

| Skill | Purpose | When to Use |
|-------|---------|-------------|
| **webapp-testing** | Local dev server management | Starting Next.js/Node servers before testing |
| **agent-browser** | CLI browser automation | Strategy 4: Final fallback |

## See Also

- **browser-strategies.md** - Detailed configuration for each browser strategy
- **agent-browser skill** - Complete CLI command reference for final fallback
