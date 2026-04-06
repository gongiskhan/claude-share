# Prompts Manager Skill

## Overview

The Prompts Manager analyzes every user prompt and either passes it through (for quick tasks) or transforms it into a properly formatted Ralph Loop command (for substantial tasks). It runs as a sub-agent with a separate context window.

## When to Invoke

**ALWAYS** - This skill must be invoked as the **first action** for every user message. No exceptions.

## Sub-agent: prompts-manager

### Purpose

Analyze user prompts in a fresh context window, classify them, gather project context, and return either the original prompt or a fully-formatted Ralph Loop command ready for execution.

### Process

#### Step 1: Classify the Prompt

**Quick Prompts** (pass through unchanged):
- Questions about code, concepts, or project ("What does this function do?")
- Simple bash commands ("Start the server", "Kill port 3000", "Run tests")
- Git operations ("Commit this", "Push to main", "Show git status")
- Quick lookups ("What is in this file?", "Show me the config")
- Clarification requests ("What did you mean by X?")
- Confirmations ("Yes", "No", "Go ahead", "Looks good")

**Substantial Tasks** (require Ralph Loop transformation):
- Bug fixes ("Fix the login bug", "The form is not submitting")
- New features ("Add dark mode", "Create a new API endpoint")
- Refactoring ("Convert to TypeScript", "Reorganize the components")
- UI changes ("Update the layout", "Make this responsive")
- Architecture changes ("Implement caching", "Add WebSocket support")
- Multi-step implementations (anything requiring multiple file changes)

#### Step 2: For Quick Prompts

1. Log to PROMPTS.md with timestamp and classification
2. Return immediately with:

```
PROMPT_TYPE: quick
ORIGINAL_PROMPT: [the prompt]
ACTION: Proceed with original prompt directly.
```

#### Step 3: For Substantial Tasks

1. **Log the original prompt** to PROMPTS.md (create if needed)
2. **Gather project context**:
   - Read recent entries in PROMPTS.md for continuity
   - Scan docs/ folder for relevant markdown documentation
   - Check README.md, CLAUDE.md for project context
   - Read .env for UI_PORT and API_PORT values
3. **Determine complexity and iterations**:
   - Simple (4 iterations): Single bug fix, small UI tweak, text change
   - Medium (5-6 iterations): Feature fix, component update, single-page changes
   - Complex (7-8 iterations): Multi-file refactor, new feature, multiple components
   - Major (10+ iterations): Architecture changes, new pages, system-wide updates
4. **Generate completion tag**: Descriptive uppercase with underscores (e.g., LOGIN_BUG_FIXED)
5. **Build the Ralph Loop command** following exact format below

### Output Format for Substantial Tasks

```
PROMPT_TYPE: substantial
ORIGINAL_PROMPT: [the user original prompt]
COMPLEXITY: [simple|medium|complex|major]
ITERATIONS: [number]
TAG: [COMPLETION_TAG]

EXECUTE THIS RALPH LOOP COMMAND:

/ralph-loop:ralph-loop "[FULL_PROMPT_TEXT]" --max-iterations [N] --completion-promise "[TAG]"
```

---

## CRITICAL: Ralph Loop Command Format

The Ralph Loop command MUST follow this EXACT structure. This is non-negotiable.

### Command Structure

```
/ralph-loop:ralph-loop "ultrathink [TASK]. [PROBLEM DESCRIPTION]. [CONTEXT]. CREATE A PLAN BEFORE IMPLEMENTATION. MANDATORY VERIFICATION WITH CHROME EXTENSION: First check .env file for UI_PORT value. Navigate to [specific pages] on the correct port for this worktree. [Test steps]. Output <promise>[TAG]</promise> ONLY after Chrome verification passes." --max-iterations [N] --completion-promise "[TAG]"
```

### Absolute Requirements

1. **Everything on ONE LINE** - The entire command must be a single line. No line breaks anywhere.

2. **Starts with ultrathink** - Every prompt begins with `ultrathink` to trigger extended thinking.

3. **FORBIDDEN CHARACTERS** - These MUST NEVER appear inside the prompt:
   - Single quotes - use "do not" instead of "dont", "it is" instead of "its"
   - Apostrophes - same as single quotes
   - Curly braces {} - describe objects in words: "an object containing an id property"
   - Backticks
   - Dollar signs
   - Backslashes
   - Semicolons at certain positions

4. **Describe problems, NOT solutions** - Never include implementation details, code examples, or specific functions to create. Only describe WHAT is broken or needed, not HOW to fix it.

5. **Include CREATE A PLAN BEFORE IMPLEMENTATION** - This triggers plan mode. Do not ask for confirmation - plan is auto-approved.

6. **Include Chrome verification with port check** - Always verify on correct worktree port.

7. **Promise tag must match** - The tag in <promise>TAG</promise> must exactly match --completion-promise "TAG"

---

## Chrome Extension Verification (MANDATORY)

### Why Port Verification Matters

When working with multiple worktrees, each has different ports. Claude for Chrome might be looking at the wrong instance. ALWAYS include port verification.

### Required Verification Pattern

```
MANDATORY VERIFICATION WITH CHROME EXTENSION: First check .env file for UI_PORT value. Navigate to [specific page or pages] on the correct port for this worktree. [Specific test actions to perform]. [What to verify works correctly]. Output <promise>[TAG]</promise> ONLY after Chrome verification passes.
```

### Isolation for Testing

To avoid conflicts with active sessions:
- Always read .env FIRST to get the correct ports
- Explicitly state "on the correct port for this worktree"
- Test on the port specified in .env, not a hardcoded port
- Verify the specific functionality, not just that pages load

---

## Plan Mode

Including "CREATE A PLAN BEFORE IMPLEMENTATION" triggers Claude Code planning tool, which produces more structured and thorough work. The plan is auto-approved - no waiting for confirmation.

---

## Complete Examples

### Simple Bug Fix (4 iterations)

User prompt: "The submit button does not work"

Output:
```
PROMPT_TYPE: substantial
ORIGINAL_PROMPT: The submit button does not work
COMPLEXITY: simple
ITERATIONS: 4
TAG: SUBMIT_FIXED

EXECUTE THIS RALPH LOOP COMMAND:

/ralph-loop:ralph-loop "ultrathink BUG FIX: The submit button is not working. When users click the submit button nothing happens or it does not complete the expected action. The button should trigger form submission and provide appropriate feedback to the user. CREATE A PLAN BEFORE IMPLEMENTATION. MANDATORY VERIFICATION WITH CHROME EXTENSION: First check .env file for UI_PORT value. Navigate to the page with the submit button on the correct port for this worktree. Click the submit button and verify it now works correctly with proper feedback. Output <promise>SUBMIT_FIXED</promise> ONLY after Chrome verification passes." --max-iterations 4 --completion-promise "SUBMIT_FIXED"
```

### Medium Feature (6 iterations)

User prompt: "Add dark mode to the app"

Output:
```
PROMPT_TYPE: substantial
ORIGINAL_PROMPT: Add dark mode to the app
COMPLEXITY: medium
ITERATIONS: 6
TAG: DARK_MODE_DONE

EXECUTE THIS RALPH LOOP COMMAND:

/ralph-loop:ralph-loop "ultrathink FEATURE: Add dark mode support to the application. There should be a toggle that allows users to switch between light and dark themes. The theme preference should persist so when users refresh or return later their choice is remembered. The default should respect the system preference if no choice has been saved. All pages and components should properly support both themes. CREATE A PLAN BEFORE IMPLEMENTATION. MANDATORY VERIFICATION WITH CHROME EXTENSION: First check .env file for UI_PORT value. Navigate to the application on the correct port for this worktree. Verify the theme toggle is visible and accessible. Click it and verify the theme changes immediately across all visible elements. Refresh the page and verify the preference persisted. Output <promise>DARK_MODE_DONE</promise> ONLY after Chrome verification passes." --max-iterations 6 --completion-promise "DARK_MODE_DONE"
```

### Complex Refactor (8 iterations)

User prompt: "The API returns IDs sometimes as numbers and sometimes as objects, need to handle both"

Output:
```
PROMPT_TYPE: substantial
ORIGINAL_PROMPT: The API returns IDs sometimes as numbers and sometimes as objects, need to handle both
COMPLEXITY: complex
ITERATIONS: 8
TAG: FORMAT_HANDLED

EXECUTE THIS RALPH LOOP COMMAND:

/ralph-loop:ralph-loop "ultrathink DATA HANDLING: The API response format is inconsistent for ID fields. Sometimes the API returns IDs as plain numbers and sometimes as objects containing an id property with the number inside. All code that processes these responses needs to handle BOTH formats gracefully for backward compatibility. This affects all places where ID fields are read from API responses. CREATE A PLAN BEFORE IMPLEMENTATION. MANDATORY VERIFICATION WITH CHROME EXTENSION: First check .env file for UI_PORT value. Navigate to pages that display data from these API endpoints on the correct port for this worktree. Verify all data loads and displays correctly regardless of which format the API returns. Output <promise>FORMAT_HANDLED</promise> ONLY after Chrome verification passes." --max-iterations 8 --completion-promise "FORMAT_HANDLED"
```

---

## PROMPTS.md Logging

### Location Priority

1. docs/PROMPTS.md (if docs folder exists in project)
2. PROMPTS.md (project root)

Create the file if it does not exist.

### Entry Format

```markdown
## [YYYY-MM-DD HH:MM] - [quick|substantial]

**Original Prompt:**
> [The user original prompt]

**Classification:** [quick|substantial]

[For substantial only:]
**Complexity:** [simple|medium|complex|major]
**Iterations:** [number]
**Tag:** [COMPLETION_TAG]
**Ralph Loop Command:**
[the full command]

---
```

---

## Checklist Before Returning Ralph Loop Command

- Command is on ONE LINE (no line breaks)
- Starts with ultrathink
- NO forbidden characters (single quotes, curly braces, backticks, dollar signs, backslashes)
- Problem described thoroughly in plain language
- NO code examples or implementation suggestions
- Includes CREATE A PLAN BEFORE IMPLEMENTATION
- Includes MANDATORY VERIFICATION WITH CHROME EXTENSION
- Includes .env port check instruction
- Verification steps are specific to the task
- Ends with Output <promise>TAG</promise> ONLY after Chrome verification passes.
- --max-iterations set based on complexity
- --completion-promise "TAG" matches the tag in the prompt exactly

---

## Important Rules

1. **Never skip analysis** - Every prompt must be classified
2. **Preserve user intent** - The Ralph Loop command must achieve what the user asked
3. **Be thorough but concise** - Include all necessary context without bloat
4. **Sanitize forbidden characters** - Replace any forbidden characters in user input
5. **Always verify on correct port** - Never hardcode ports, always read .env
6. **Tie completion to verification** - Promise only outputs after Chrome tests pass
7. **No plan confirmation** - Plan mode proceeds automatically
