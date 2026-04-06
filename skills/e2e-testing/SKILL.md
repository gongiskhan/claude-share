---
name: e2e-testing
description: End-to-end testing using real browser automation with playwright-cli. Use this skill when asked to test, verify, or validate web applications. ALWAYS uses real automation via playwright-cli - NEVER writes Playwright test scripts or unit tests.
---

# E2E Testing Skill

**This skill performs REAL browser automation to test applications using playwright-cli.**

## ABSOLUTE RULES

1. **NEVER write Playwright test scripts** - Do not write .spec.ts files, do not write test() blocks
2. **NEVER write unit tests** - This skill uses REAL browsers, not test frameworks
3. **NEVER create test files** - No files in __tests__, no .test.ts, no .spec.ts
4. **USE playwright-cli FOR ALL WEB TESTING** - Call playwright-cli commands directly via Bash
5. **TAKE SCREENSHOTS** - Always capture visual proof of test results
6. **RECORD VIDEO WHEN POSSIBLE** - Use playwright-cli video-start/video-stop for recordings

---

## Core Workflow

1. **Open browser**: `playwright-cli open <url>`
2. **Snapshot**: `playwright-cli snapshot` (returns element tree with refs like `e1`, `e2`)
3. **Interact**: Use refs from the snapshot to click, fill, etc.
4. **Re-snapshot**: After navigation or significant DOM changes
5. **Screenshot**: `playwright-cli screenshot` for visual proof
6. **Close**: `playwright-cli close`

---

## Step-by-Step: How to Perform E2E Tests

### Step 1: Open Browser and Navigate

```bash
playwright-cli open http://localhost:3000
```

### Step 2: Resize Viewport (Optional)

```bash
playwright-cli resize 1440 900
```

### Step 3: Discover Elements

Get elements with refs:

```bash
playwright-cli snapshot
```

Output shows elements like: `textbox "Email" [ref=e1]`, `button "Submit" [ref=e3]`

Use `--depth=N` to control snapshot depth for large pages:

```bash
playwright-cli snapshot --depth=5
```

### Step 4: Interact with Elements

Click using element refs:

```bash
playwright-cli click e1
```

Fill form fields (use `--submit` to press Enter after):

```bash
playwright-cli fill e1 "test@example.com" --submit
```

Press keys:

```bash
playwright-cli press Enter
```

Type text (types into focused element):

```bash
playwright-cli type "search query"
```

### Step 5: Take Screenshots

```bash
playwright-cli screenshot
# Screenshot a specific element
playwright-cli screenshot e5
```

### Step 6: Video Recording

```bash
# Start recording before test actions
playwright-cli video-start test-recording.webm

# Perform all test actions...

# Stop recording when done
playwright-cli video-stop
```

---

## Authentication Strategy

### Option 1: Log In Via Automation

```bash
playwright-cli open http://localhost:3000/login
playwright-cli snapshot
# Find the username/password fields and login button
playwright-cli fill e1 "admin"
playwright-cli fill e2 "password123"
playwright-cli click e3
playwright-cli snapshot
```

### Option 2: Save and Reuse Auth State

After logging in:

```bash
playwright-cli state-save auth.json
```

For future sessions:

```bash
playwright-cli state-load auth.json
playwright-cli goto http://localhost:3000
```

### Option 3: Set Cookies Directly

```bash
playwright-cli cookie-set session_id abc123 --domain=localhost
```

---

## Complete Example: Testing a Login Flow

```bash
# Open browser
playwright-cli open http://localhost:3000/login
playwright-cli resize 1440 900
playwright-cli screenshot

# Discover elements
playwright-cli snapshot
# Output: textbox "Email" [ref=e1], textbox "Password" [ref=e2], button "Login" [ref=e3]

# Fill and submit
playwright-cli fill e1 "test@example.com"
playwright-cli fill e2 "password123"
playwright-cli click e3

# Verify result
playwright-cli snapshot
playwright-cli screenshot

# Close browser
playwright-cli close
```

---

## playwright-cli Command Reference

| Task | Command |
|------|---------|
| Open browser | `playwright-cli open <url>` |
| Navigate | `playwright-cli goto <url>` |
| Snapshot elements | `playwright-cli snapshot` |
| Click element | `playwright-cli click e1` |
| Double-click | `playwright-cli dblclick e7` |
| Fill input | `playwright-cli fill e1 "text"` |
| Fill + submit | `playwright-cli fill e1 "text" --submit` |
| Type text | `playwright-cli type "text"` |
| Press key | `playwright-cli press Enter` |
| Hover | `playwright-cli hover e4` |
| Select option | `playwright-cli select e9 "value"` |
| Check/uncheck | `playwright-cli check e12` / `playwright-cli uncheck e12` |
| Drag | `playwright-cli drag e2 e8` |
| Resize viewport | `playwright-cli resize 1440 900` |
| Screenshot | `playwright-cli screenshot` |
| Element screenshot | `playwright-cli screenshot e5` |
| Go back/forward | `playwright-cli go-back` / `playwright-cli go-forward` |
| Reload | `playwright-cli reload` |
| Evaluate JS | `playwright-cli eval "document.title"` |
| Console logs | `playwright-cli console` |
| Network requests | `playwright-cli network` |
| Save auth state | `playwright-cli state-save auth.json` |
| Load auth state | `playwright-cli state-load auth.json` |
| Cookies | `playwright-cli cookie-list` / `playwright-cli cookie-get name` |
| LocalStorage | `playwright-cli localstorage-list` / `playwright-cli localstorage-get key` |
| Video recording | `playwright-cli video-start file.webm` / `playwright-cli video-stop` |
| New tab | `playwright-cli tab-new <url>` |
| List tabs | `playwright-cli tab-list` |
| Switch tab | `playwright-cli tab-select 0` |
| Close tab | `playwright-cli tab-close` |
| Close browser | `playwright-cli close` |

---

## WRONG vs RIGHT

### WRONG - Do NOT do this:

```typescript
// DO NOT WRITE PLAYWRIGHT SCRIPTS
import { test, expect } from '@playwright/test';

test('login works', async ({ page }) => {
  await page.goto('http://localhost:3000/login');
  // ... THIS IS WRONG!
});
```

### RIGHT - Do this instead:

Call playwright-cli commands directly via Bash. Do not write code files.
