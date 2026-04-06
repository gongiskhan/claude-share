---
name: codex-test
description: Delegate browser testing to OpenAI Codex CLI using playwright-cli. Use when you need to test, verify, or validate a web application with real browser automation. Codex runs playwright-cli commands independently, takes screenshots, and reports results back. Trigger phrases include "test the app", "verify it works", "check the preview", "run e2e test".
---

# Codex Browser Testing

Delegates browser testing to OpenAI Codex CLI, which uses `playwright-cli` to automate a real browser. Codex runs independently, takes screenshots to a shared folder, and returns a structured test report.

## When to Use

- After building or modifying a web app, to verify it works
- When the user asks to "test", "verify", or "check" an app
- To validate a preview URL renders correctly
- For end-to-end testing of forms, navigation, and interactions

## How It Works

1. Claude Code creates a timestamped screenshot folder under `/tmp/codex-screenshots/`
2. Claude Code formulates a test prompt telling Codex to save screenshots there
3. Codex CLI runs non-interactively with `codex exec --full-auto`
4. Codex opens a browser, performs the test, saves screenshots to the folder
5. Results are written to `/tmp/codex-test-result.md`
6. Claude Code reads the result file and tells the user where screenshots are

## Execution Steps

### Step 1: Create screenshot folder

```bash
SCREENSHOTS="/tmp/codex-screenshots/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$SCREENSHOTS"
```

### Step 2: Run Codex

```bash
codex exec \
  --dangerously-bypass-approvals-and-sandbox \
  -o /tmp/codex-test-result.md \
  "<test prompt with $SCREENSHOTS path>"
```

### Step 3: Read results and list screenshots

```bash
cat /tmp/codex-test-result.md
ls -la "$SCREENSHOTS/"
```

### Step 4: Report to user

Tell the user:
- The PASS/FAIL result from the test report
- The screenshot folder path so they can review visuals
- Any errors found

## Test Prompt Template

Always include the screenshot folder path and explicit `--filename` flags:

```
Use playwright-cli to test the web app at <URL>.
Save all screenshots to <SCREENSHOTS_FOLDER>/.

Steps:
1. playwright-cli open <URL>
2. playwright-cli resize 1440 900
3. playwright-cli snapshot
4. playwright-cli screenshot --filename=<SCREENSHOTS_FOLDER>/01-initial-load.png
5. <specific interaction steps, with screenshots at each milestone>
6. playwright-cli console
7. playwright-cli screenshot --filename=<SCREENSHOTS_FOLDER>/99-final-state.png
8. playwright-cli close

Report:
- Whether the page loaded successfully
- What elements are visible (list key UI components from snapshot)
- Any console errors or warnings
- End with: PASS or FAIL with explanation
```

## Complete Example: Testing a Built App

```bash
SCREENSHOTS="/tmp/codex-screenshots/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$SCREENSHOTS"

codex exec \
  --dangerously-bypass-approvals-and-sandbox \
  -o /tmp/codex-test-result.md \
  "Use playwright-cli to test the web app at http://localhost:4111/apps/abc123/.
Save all screenshots to $SCREENSHOTS/.

Steps:
1. playwright-cli open http://localhost:4111/apps/abc123/
2. playwright-cli resize 1440 900
3. playwright-cli snapshot
4. playwright-cli screenshot --filename=$SCREENSHOTS/01-initial-load.png
5. playwright-cli console
6. playwright-cli screenshot --filename=$SCREENSHOTS/02-final.png
7. playwright-cli close

Report whether the app loaded correctly, list the main UI elements visible, note any console errors. End with PASS or FAIL."

# Read results
cat /tmp/codex-test-result.md
echo "Screenshots saved to: $SCREENSHOTS"
ls "$SCREENSHOTS/"
```

## Complete Example: Testing Login Flow

```bash
SCREENSHOTS="/tmp/codex-screenshots/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$SCREENSHOTS"

codex exec \
  --dangerously-bypass-approvals-and-sandbox \
  -o /tmp/codex-test-result.md \
  "Use playwright-cli to test login at http://localhost:3111.
Save all screenshots to $SCREENSHOTS/.

Steps:
1. playwright-cli open http://localhost:3111
2. playwright-cli resize 1440 900
3. playwright-cli snapshot
4. playwright-cli screenshot --filename=$SCREENSHOTS/01-login-page.png
5. Fill username and password fields from the snapshot refs, then click login
6. Wait 3 seconds
7. playwright-cli snapshot
8. playwright-cli screenshot --filename=$SCREENSHOTS/02-after-login.png
9. playwright-cli console
10. playwright-cli close

Report: did login succeed? What page loaded after login? Any errors? PASS or FAIL."

cat /tmp/codex-test-result.md
echo "Screenshots: $SCREENSHOTS"
ls "$SCREENSHOTS/"
```

## Rules

1. Always use `--dangerously-bypass-approvals-and-sandbox` for non-interactive execution (needed for localhost access and playwright-cli sockets)
2. Always use `-o /tmp/codex-test-result.md` to capture output
3. Always create a timestamped folder under `/tmp/codex-screenshots/` for screenshots
4. Always tell Codex to use `--filename=<folder>/NN-description.png` for screenshots
5. Always include `playwright-cli close` at the end of test steps
6. Always ask for PASS/FAIL in the report
7. After Codex finishes, read the result file AND list the screenshots folder
8. Report both the test result and the screenshot folder path to the user
