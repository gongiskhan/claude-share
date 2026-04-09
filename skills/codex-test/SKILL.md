---
name: codex-test
description: "Primary testing tool: delegate browser testing to OpenAI Codex CLI using playwright-cli. Use FIRST for any testing, verification, or validation of web applications. Codex runs playwright-cli independently in a headed browser (visible to user), takes screenshots, and reports results back. Trigger phrases: test the app, verify it works, check the preview, run e2e test. Always prefer this over direct playwright-cli or Chrome extension."
---

# Codex Browser Testing

Delegates browser testing to OpenAI Codex CLI, which uses `playwright-cli` to automate a real **headed** browser (visible to the user). Codex runs independently, takes screenshots to a shared folder, and returns a structured test report.

**This is the PRIMARY testing tool.** Use this first. Fall back to direct playwright-cli only if Codex fails. Do NOT use `mcp__claude-in-chrome__*` tools for testing unless both codex-test and playwright-cli fail.

## When to Use

- After building or modifying a web app, to verify it works
- When the user asks to "test", "verify", or "check" an app
- To validate a preview URL renders correctly
- For end-to-end testing of forms, navigation, and interactions
- **Anytime you need to verify UI changes** -- this is the default choice

## How It Works

1. Claude Code creates a timestamped screenshot folder under `.codex-screenshots/` in the project root
2. Claude Code formulates a test prompt telling Codex to save screenshots there
3. Codex CLI runs non-interactively with `codex exec --dangerously-bypass-approvals-and-sandbox`
4. Codex opens a **headed** browser (`--browser=chrome`), performs the test, saves screenshots
5. Results are written to `.codex-screenshots/codex-test-result.md` in the project root
6. Claude Code reads the result file, **displays the full report** in conversation, and **reads screenshots inline** using the Read tool on each PNG

## Execution Steps

### Step 1: Create screenshot folder

```bash
SCREENSHOTS=".codex-screenshots/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$SCREENSHOTS"
```

### Step 2: Run Codex (background, no timeout)

Run via Bash with `run_in_background: true`. Tests can take anywhere from 1 to 20 minutes -- never use a fixed timeout. You will be automatically notified when the command finishes. Do NOT poll or sleep while waiting.

```bash
# run_in_background: true
codex exec \
  --dangerously-bypass-approvals-and-sandbox \
  -o .codex-screenshots/codex-test-result.md \
  "<test prompt with $SCREENSHOTS path>"
```

Tell the user Codex is running and they can watch the headed browser. Continue with other work or wait for the background notification.

### Step 3: Read results and list screenshots (after background completes)

Once notified that the background command finished:

```bash
cat .codex-screenshots/codex-test-result.md
ls -la "$SCREENSHOTS/"
```

### Step 4: Report to user

Tell the user:
- The PASS/FAIL result from the test report
- The screenshot folder path so they can review visuals
- Any errors found

## Test Prompt Template

Always include the screenshot folder path, `--browser=chrome` for headed mode, and explicit `--filename` flags. Tell Codex to be **very verbose** in its report:

```
Use playwright-cli to test the web app at <URL>.
Save all screenshots to <SCREENSHOTS_FOLDER>/.
IMPORTANT: Use --browser=chrome when opening the browser so it runs headed (visible).

Steps:
1. playwright-cli open <URL> --browser=chrome
2. playwright-cli resize 1440 900
3. playwright-cli snapshot
4. playwright-cli screenshot --filename=<SCREENSHOTS_FOLDER>/01-initial-load.png
5. <specific interaction steps, with screenshots at each milestone>
6. playwright-cli console
7. playwright-cli screenshot --filename=<SCREENSHOTS_FOLDER>/99-final-state.png
8. playwright-cli close

VERBOSE REPORT (include ALL of the following):
- Every action you took and what happened (step by step)
- Every element you found in each snapshot (list key UI components)
- Every assertion you made and whether it passed or failed
- Full console output (errors, warnings, and info)
- Any network errors or unexpected behavior
- End with: PASS or FAIL with detailed explanation
```

## Complete Example: Testing a Built App

**Step A: Create folder and store path**
```bash
SCREENSHOTS=".codex-screenshots/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$SCREENSHOTS" && echo "$SCREENSHOTS"
```

**Step B: Run Codex (use Bash with `run_in_background: true`)**
```bash
# run_in_background: true
codex exec \
  --dangerously-bypass-approvals-and-sandbox \
  -o .codex-screenshots/codex-test-result.md \
  "Use playwright-cli to test the web app at http://localhost:4111/apps/abc123/.
Save all screenshots to $SCREENSHOTS/.
IMPORTANT: Use --browser=chrome when opening the browser so it runs headed (visible).

Steps:
1. playwright-cli open http://localhost:4111/apps/abc123/ --browser=chrome
2. playwright-cli resize 1440 900
3. playwright-cli snapshot
4. playwright-cli screenshot --filename=$SCREENSHOTS/01-initial-load.png
5. playwright-cli console
6. playwright-cli screenshot --filename=$SCREENSHOTS/02-final.png
7. playwright-cli close

VERBOSE REPORT: List every action taken, every element found in snapshots, every assertion made (pass/fail), full console output. End with PASS or FAIL with detailed explanation."
```

**Step C: After background notification, read results**
```bash
cat .codex-screenshots/codex-test-result.md
ls "$SCREENSHOTS/"
```

**After Codex finishes:** Read `.codex-screenshots/codex-test-result.md` and output the FULL report to the conversation. Then use the Read tool on each screenshot PNG to display them inline.

## Complete Example: Testing Login Flow

**Step A: Create folder and store path**
```bash
SCREENSHOTS=".codex-screenshots/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$SCREENSHOTS" && echo "$SCREENSHOTS"
```

**Step B: Run Codex (use Bash with `run_in_background: true`)**
```bash
# run_in_background: true
codex exec \
  --dangerously-bypass-approvals-and-sandbox \
  -o .codex-screenshots/codex-test-result.md \
  "Use playwright-cli to test login at http://localhost:3111.
Save all screenshots to $SCREENSHOTS/.
IMPORTANT: Use --browser=chrome when opening the browser so it runs headed (visible).

Steps:
1. playwright-cli open http://localhost:3111 --browser=chrome
2. playwright-cli resize 1440 900
3. playwright-cli snapshot
4. playwright-cli screenshot --filename=$SCREENSHOTS/01-login-page.png
5. Fill username and password fields from the snapshot refs, then click login
6. Wait 3 seconds
7. playwright-cli snapshot
8. playwright-cli screenshot --filename=$SCREENSHOTS/02-after-login.png
9. playwright-cli console
10. playwright-cli close

VERBOSE REPORT: List every action taken, every element found, all assertions (pass/fail), full console output. End with PASS or FAIL with detailed explanation."
```

**Step C: After background notification, read results**
```bash
cat .codex-screenshots/codex-test-result.md
ls "$SCREENSHOTS/"
```

**After Codex finishes:** Read `.codex-screenshots/codex-test-result.md` and output the FULL report. Then Read each screenshot PNG to display inline.

## Rules

1. Always use `--dangerously-bypass-approvals-and-sandbox` for non-interactive execution (needed for localhost access and playwright-cli sockets)
2. Always use `-o .codex-screenshots/codex-test-result.md` to capture output
3. Always create a timestamped folder under `.codex-screenshots/` for screenshots (project-relative, never `/tmp/`)
4. Always run the `codex exec` command with Bash `run_in_background: true` -- tests can take 1-20 minutes, never use a fixed timeout. Wait for background completion notification before reading results
4. Always tell Codex to use `--filename=<folder>/NN-description.png` for screenshots
5. Always tell Codex to use `--browser=chrome` when opening the browser (headed mode, visible to user)
6. Always include `playwright-cli close` at the end of test steps
7. Always ask for a VERBOSE PASS/FAIL report (every action, every element, every assertion)
8. After Codex finishes, **output the FULL test report** into the conversation (not a summary)
9. After reporting, **Read each screenshot PNG** using the Read tool to display them inline in the conversation
10. Report the screenshot folder path so the user can review them in Finder too
