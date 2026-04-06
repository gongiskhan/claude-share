---
name: codex-test
description: Delegate browser testing to OpenAI Codex CLI using playwright-cli. Use when you need to test, verify, or validate a web application with real browser automation. Codex runs playwright-cli commands independently and reports results back. Trigger phrases include "test the app", "verify it works", "check the preview", "run e2e test".
---

# Codex Browser Testing

Delegates browser testing to OpenAI Codex CLI, which uses `playwright-cli` to automate a real browser. Codex runs independently, executes the test, and returns structured results.

## When to Use

- After building or modifying a web app, to verify it works
- When the user asks to "test", "verify", or "check" an app
- To validate a preview URL renders correctly
- For end-to-end testing of forms, navigation, and interactions

## How It Works

1. Claude Code formulates a test prompt describing what to verify
2. Codex CLI runs non-interactively with `codex exec` and the playwright skill
3. Codex opens a browser, performs the test, takes screenshots
4. Results are written to a file and read back by Claude Code

## Execution

Run Codex with full access so it can use playwright-cli:

```bash
codex exec \
  --full-auto \
  -o /tmp/codex-test-result.md \
  "<test prompt here>"
```

### Test Prompt Template

Always structure the prompt like this:

```
Use playwright-cli to test the web app at <URL>.

Steps:
1. Open the URL with: playwright-cli open <URL>
2. Take a snapshot: playwright-cli snapshot
3. <specific test steps>
4. Take a screenshot: playwright-cli screenshot
5. Close the browser: playwright-cli close

Report:
- Whether the page loaded successfully
- What elements are visible (from snapshot)
- Any errors in the console (playwright-cli console)
- PASS or FAIL with explanation
```

### Reading Results

After codex finishes, read the output:

```bash
cat /tmp/codex-test-result.md
```

## Complete Example: Testing a Built App

```bash
# After building an app at http://localhost:4111/apps/<id>/
codex exec \
  --full-auto \
  -o /tmp/codex-test-result.md \
  "Use playwright-cli to test the web app at http://localhost:4111/apps/abc123/.

Steps:
1. Open: playwright-cli open http://localhost:4111/apps/abc123/
2. Resize: playwright-cli resize 1440 900
3. Snapshot the page: playwright-cli snapshot
4. Check for errors: playwright-cli console
5. Screenshot: playwright-cli screenshot
6. Close: playwright-cli close

Report whether the app loaded correctly, what UI elements are visible, and any console errors. End with PASS or FAIL."
```

Then read the result:

```bash
cat /tmp/codex-test-result.md
```

## Complete Example: Testing Login Flow

```bash
codex exec \
  --full-auto \
  -o /tmp/codex-test-result.md \
  "Use playwright-cli to test login at http://localhost:3111.

Steps:
1. playwright-cli open http://localhost:3111
2. playwright-cli snapshot (find username/password fields)
3. playwright-cli fill <username-ref> \"admin\"
4. playwright-cli fill <password-ref> \"tmp12345\"
5. playwright-cli click <login-button-ref>
6. Wait 2 seconds, then: playwright-cli snapshot
7. playwright-cli screenshot
8. playwright-cli close

Report: did login succeed? What page loaded after login? Any errors? PASS or FAIL."
```

## Rules

1. Always use `--full-auto` for non-interactive execution
2. Always use `-o /tmp/codex-test-result.md` to capture output
3. Always include `playwright-cli close` at the end of test steps
4. Always ask for PASS/FAIL in the report
5. Read `/tmp/codex-test-result.md` after codex finishes to get results
6. Set a reasonable timeout (120s default is fine for most tests)
