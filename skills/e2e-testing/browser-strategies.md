# Browser Strategies Reference

Detailed configuration and troubleshooting for E2E testing browser strategies.

## Strategy 1: agent-browser --headed (PRIMARY)

agent-browser in **headed mode** is the primary and preferred tool for all web app E2E testing. It is fast, reliable, and does not require manual permission acceptance. Always use `--headed` so the browser is visible on screen and captured by the ffmpeg screen recording.

### Authentication Flow

For apps that require login, follow this priority order:

#### 1a. Connect to Existing Browser via CDP

If the user has Chrome running with remote debugging (port 9222):

```bash
agent-browser --cdp 9222 snapshot -i
```

This connects to the user's live browser with all cookies and auth state intact. Best option when available.

#### 1b. Load Saved Auth State

If a previous session was saved:

```bash
agent-browser state load ~/.e2e-testing/auth.json
agent-browser open http://localhost:3000 --headed
agent-browser snapshot -i
```

Check if the page shows authenticated content. If yes, continue testing.

#### 1c. Headed Mode with User Login

When no existing session is available:

```bash
agent-browser open http://localhost:3000/login --headed
```

This opens a visible browser window. Ask the user to log in:

> "I have opened a browser window at the login page. Please log in with your credentials. Let me know when you are done and I will continue testing."

After user confirms:

```bash
agent-browser snapshot -i
agent-browser state save ~/.e2e-testing/auth.json
```

### Core Commands

```bash
# Navigation
agent-browser open <url> --headed  # Navigate to URL (always use --headed)
agent-browser back                # Go back
agent-browser forward             # Go forward
agent-browser reload              # Reload page
agent-browser close               # Close browser

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
agent-browser open http://localhost:3000/login --headed

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

### Debugging

```bash
agent-browser open example.com --headed    # Show browser window
agent-browser console                      # View console messages
agent-browser errors                       # View page errors
```

---

## Strategy 2: Electron MCP Tools

For Electron apps, use `mcp__electron__*` MCP tools. See the main SKILL.md for full details.

---

## Session Directory Structure

```
~/.e2e-testing/
└── auth.json                    # Saved auth state from agent-browser
```

---

## Strategy 2: Claude for Chrome (FALLBACK ONLY)

Use `mcp__claude-in-chrome__*` MCP tools ONLY when agent-browser cannot accomplish the task:
- Interacting with user's existing authenticated Chrome session when CDP is unavailable
- Browser extension-dependent flows
- Complex multi-tab scenarios
- User explicitly requests it

See SKILL.md for the full Claude for Chrome workflow.

---

## Strategy Selection Summary

| Scenario | Strategy |
|----------|----------|
| Web app testing | agent-browser --headed (PRIMARY) |
| Web app, agent-browser insufficient | Claude for Chrome mcp__claude-in-chrome__* (FALLBACK) |
| Web app needing auth (user has Chrome with CDP) | agent-browser --cdp 9222 |
| Web app needing auth (saved state exists) | agent-browser state load |
| Web app needing auth (first time) | agent-browser --headed + user login |
| Electron app testing | mcp__electron__* MCP tools |
| Capacitor app testing | Simulator screenshots + user verification |

**NEVER write Playwright test scripts. Always use agent-browser --headed for web apps (primary), Claude for Chrome as fallback, and mcp__electron__* for Electron apps. ALWAYS record the screen with ffmpeg and serve the recording at the end.**
