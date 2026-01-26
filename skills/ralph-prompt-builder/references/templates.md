# Prompt Templates

## Full Structure Template

```
"ultrathink [TITLE/SUMMARY]. PLAN FIRST then AUTO-ACCEPT and implement without waiting for confirmation.

CONTEXT: [Describe what you see in UI/screenshots - page, URL, components, current state, error messages with exact text, what works and what does not]

ISSUE/REQUIREMENTS: [Numbered list of what needs to be done]
1) First requirement with specific details
2) Second requirement
3) Third requirement...

IMPLEMENTATION HINTS: [File paths if known, component names, patterns to follow]

VERIFICATION: FIRST check .env for UI_PORT. After implementation, use Claude for Chrome MCP tools to verify - NEVER write Playwright scripts. Use mcp__claude-in-chrome__tabs_context_mcp, mcp__claude-in-chrome__navigate, mcp__claude-in-chrome__read_page, mcp__claude-in-chrome__computer for interactions and screenshots. If MCP tools unavailable, use agent-browser CLI. Test on the correct port:
1) Navigate to [page]
2) Perform [action]
3) VERIFY [expected result]
4) VERIFY [another result]
5) Take screenshot to confirm

Output <promise>TAG</promise> ONLY after browser verification with screenshot confirms the feature works - never output the promise based on assumptions or code analysis alone."
```

---

## Task Type Templates

### FEATURE - New Functionality

```
/ralph-loop:ralph-loop "ultrathink FEATURE: [Feature Name]. PLAN FIRST then AUTO-ACCEPT and implement without waiting for confirmation. CONTEXT: [Current state of the app, what exists, what is missing]. REQUIREMENTS: 1) [First requirement], 2) [Second requirement], 3) [Third requirement]. VERIFICATION: FIRST check .env for UI_PORT. After implementation, use Claude for Chrome MCP tools to verify - NEVER write Playwright scripts. Use mcp__claude-in-chrome__tabs_context_mcp, mcp__claude-in-chrome__navigate, mcp__claude-in-chrome__read_page, mcp__claude-in-chrome__computer for interactions and screenshots. If MCP tools unavailable, use agent-browser CLI. Test on the correct port: 1) Navigate to [page], 2) [Perform action], 3) VERIFY [expected result], 4) VERIFY [another result], 5) Take screenshot to confirm. Output <promise>FEATURE_NAME_COMPLETE</promise> ONLY after browser verification with screenshot confirms the feature works." --max-iterations [6-10] --completion-promise "FEATURE_NAME_COMPLETE"
```

### BUG - Bug Fix

```
/ralph-loop:ralph-loop "ultrathink BUG FIX: [Bug Description]. PLAN FIRST then AUTO-ACCEPT and implement without waiting for confirmation. CONTEXT: [What page, what happens, what should happen, error messages with exact text]. ISSUE: [Root cause if known]. FIX: 1) [First fix step], 2) [Second fix step]. VERIFICATION: FIRST check .env for UI_PORT. After implementation, use Claude for Chrome MCP tools to verify - NEVER write Playwright scripts. Use mcp__claude-in-chrome__tabs_context_mcp, mcp__claude-in-chrome__navigate, mcp__claude-in-chrome__read_page, mcp__claude-in-chrome__computer for interactions and screenshots. If MCP tools unavailable, use agent-browser CLI. Test on the correct port: 1) Navigate to [page], 2) [Reproduce the bug scenario], 3) VERIFY [bug is fixed], 4) VERIFY [no regressions], 5) Take screenshot to confirm. Output <promise>BUG_NAME_FIXED</promise> ONLY after browser verification with screenshot confirms the fix works." --max-iterations [4-6] --completion-promise "BUG_NAME_FIXED"
```

### CRITICAL BUG - Breaking Issue

```
/ralph-loop:ralph-loop "ultrathink CRITICAL BUG: [Bug Description]. PLAN FIRST then AUTO-ACCEPT and implement without waiting for confirmation. CONTEXT: [What is broken, impact, error messages with exact text]. ISSUE: [What causes the break]. FIX: 1) [First fix step], 2) [Second fix step]. VERIFICATION: FIRST check .env for UI_PORT. After implementation, use Claude for Chrome MCP tools to verify - NEVER write Playwright scripts. Use mcp__claude-in-chrome__tabs_context_mcp, mcp__claude-in-chrome__navigate, mcp__claude-in-chrome__read_page, mcp__claude-in-chrome__computer for interactions and screenshots. If MCP tools unavailable, use agent-browser CLI. Test on the correct port: 1) Navigate to affected page, 2) VERIFY the critical functionality works, 3) VERIFY no data loss or corruption, 4) Take screenshot to confirm. Output <promise>CRITICAL_FIX_COMPLETE</promise> ONLY after browser verification with screenshot confirms the fix works." --max-iterations [5-8] --completion-promise "CRITICAL_FIX_COMPLETE"
```

### REFACTOR - Code Improvement

```
/ralph-loop:ralph-loop "ultrathink REFACTOR: [What is being refactored]. PLAN FIRST then AUTO-ACCEPT and implement without waiting for confirmation. CONTEXT: [Current code state, why refactor is needed]. GOALS: 1) [First improvement], 2) [Second improvement]. CONSTRAINTS: [What must not break]. VERIFICATION: FIRST check .env for UI_PORT. After implementation, use Claude for Chrome MCP tools to verify - NEVER write Playwright scripts. Use mcp__claude-in-chrome__tabs_context_mcp, mcp__claude-in-chrome__navigate, mcp__claude-in-chrome__read_page, mcp__claude-in-chrome__computer for interactions and screenshots. If MCP tools unavailable, use agent-browser CLI. Test on the correct port: 1) Navigate to affected pages, 2) VERIFY all existing functionality still works, 3) VERIFY no visual regressions, 4) Take screenshots to confirm. Output <promise>REFACTOR_COMPLETE</promise> ONLY after browser verification with screenshot confirms no regressions." --max-iterations [6-10] --completion-promise "REFACTOR_COMPLETE"
```

### UI FIX - Visual/Layout Issues

```
/ralph-loop:ralph-loop "ultrathink UI FIX: [UI Issue Description]. PLAN FIRST then AUTO-ACCEPT and implement without waiting for confirmation. CONTEXT: [What component, what is wrong visually, what it should look like]. REQUIREMENTS: 1) [First fix], 2) [Second fix], 3) [Third fix]. VERIFICATION: FIRST check .env for UI_PORT. After implementation, use Claude for Chrome MCP tools to verify - NEVER write Playwright scripts. Use mcp__claude-in-chrome__tabs_context_mcp, mcp__claude-in-chrome__navigate, mcp__claude-in-chrome__read_page, mcp__claude-in-chrome__computer for interactions and screenshots. If MCP tools unavailable, use agent-browser CLI. Test on the correct port: 1) Navigate to [page], 2) [Resize/scroll/interact as needed], 3) VERIFY [visual fix is correct], 4) VERIFY [no other elements affected], 5) Take screenshot to confirm. Output <promise>UI_FIX_COMPLETE</promise> ONLY after browser verification with screenshot confirms the UI is correct." --max-iterations [4-6] --completion-promise "UI_FIX_COMPLETE"
```

### CHORE - Maintenance/Config

```
/ralph-loop:ralph-loop "ultrathink CHORE: [Maintenance task]. PLAN FIRST then AUTO-ACCEPT and implement without waiting for confirmation. CONTEXT: [What needs updating, current state]. TASKS: 1) [First task], 2) [Second task]. VERIFICATION: FIRST check .env for UI_PORT. After implementation, use Claude for Chrome MCP tools to verify - NEVER write Playwright scripts. Use mcp__claude-in-chrome__tabs_context_mcp, mcp__claude-in-chrome__navigate, mcp__claude-in-chrome__read_page, mcp__claude-in-chrome__computer for interactions and screenshots. If MCP tools unavailable, use agent-browser CLI. Test on the correct port: 1) Navigate to app, 2) VERIFY app still runs correctly, 3) VERIFY no regressions introduced, 4) Take screenshot to confirm. Output <promise>CHORE_COMPLETE</promise> ONLY after browser verification with screenshot confirms the app works." --max-iterations [3-5] --completion-promise "CHORE_COMPLETE"
```

---

## Mobile Responsiveness Template

```
/ralph-loop:ralph-loop "ultrathink MOBILE FIX: [Mobile Issue Description]. PLAN FIRST then AUTO-ACCEPT and implement without waiting for confirmation. CONTEXT: [What page, what is broken on mobile, what viewport size]. REQUIREMENTS: 1) [First fix], 2) [Second fix]. CONSTRAINTS: Must not break desktop layout. VERIFICATION: FIRST check .env for UI_PORT. After implementation, use Claude for Chrome MCP tools to verify - NEVER write Playwright scripts. Use mcp__claude-in-chrome__tabs_context_mcp, mcp__claude-in-chrome__navigate, mcp__claude-in-chrome__read_page, mcp__claude-in-chrome__computer for interactions and screenshots. If MCP tools unavailable, use agent-browser CLI. Test on the correct port: 1) Navigate to [page], 2) Resize viewport to mobile (375x667), 3) VERIFY [mobile fix works], 4) Resize viewport to desktop (1280x720), 5) VERIFY desktop layout still works, 6) Take screenshots at both sizes. Output <promise>MOBILE_FIX_COMPLETE</promise> ONLY after browser verification with screenshot confirms both mobile and desktop work." --max-iterations [6-8] --completion-promise "MOBILE_FIX_COMPLETE"
```

---

## Viewport/Scrolling Template

```
/ralph-loop:ralph-loop "ultrathink FIX: [Scrolling/Viewport Issue]. PLAN FIRST then AUTO-ACCEPT and implement without waiting for confirmation. CONTEXT: [What component, what is cut off or inaccessible, what viewport size triggers the issue]. REQUIREMENTS: 1) [Add scrolling or fix overflow], 2) [Hide scrollbar if needed], 3) [Keep header/footer fixed if applicable]. VERIFICATION: FIRST check .env for UI_PORT. After implementation, use Claude for Chrome MCP tools to verify - NEVER write Playwright scripts. Use mcp__claude-in-chrome__tabs_context_mcp, mcp__claude-in-chrome__navigate, mcp__claude-in-chrome__read_page, mcp__claude-in-chrome__computer for interactions and screenshots. If MCP tools unavailable, use agent-browser CLI. Test on the correct port: 1) Navigate to [page], 2) Resize viewport to constrained size ([width]x[height]), 3) VERIFY all content is accessible by scrolling, 4) VERIFY scrollbar visibility matches requirements, 5) Take screenshot to confirm. Output <promise>SCROLL_FIX_COMPLETE</promise> ONLY after browser verification with screenshot confirms scrolling works." --max-iterations [4-6] --completion-promise "SCROLL_FIX_COMPLETE"
```

---

## Quick Reference: Verification Block

Always include this pattern (customize the steps):

```
VERIFICATION: FIRST check .env for UI_PORT. After implementation, use Claude for Chrome MCP tools to verify - NEVER write Playwright scripts. Use mcp__claude-in-chrome__tabs_context_mcp, mcp__claude-in-chrome__navigate, mcp__claude-in-chrome__read_page, mcp__claude-in-chrome__computer for interactions and screenshots. If MCP tools unavailable, use agent-browser CLI. Test on the correct port: 1) [Navigate action], 2) [Test action], 3) VERIFY [expected result], 4) Take screenshot to confirm.
```

---

## Quick Reference: Promise Block

Always include near the end (customize TAG):

```
Output <promise>TAG</promise> ONLY after browser verification with screenshot confirms the feature works - never output the promise based on assumptions or code analysis alone.
```
