/**
 * Background project analysis for generating project-classifier.md.
 * Runs asynchronously in a throwaway tmux session -- does NOT block the current prompt.
 */

import { existsSync, writeFileSync } from 'node:fs';
import { join, basename } from 'node:path';
import { createSession, sendKeys, sessionExists } from './tmux.mjs';
import { CLAUDE_BIN } from './config.mjs';

const ANALYZER_PROMPT = `Analyze this project and generate a project classifier document.

Read the codebase structure: package.json, main source directories, test setup, key patterns.

Output a markdown document with this EXACT structure (no deviations):

# Project Classifier

## Summary
Brief description of the project, tech stack, and architecture complexity.

## Default Minimum Tier
[tier number 1-6] - Reason why (e.g., "3 - Complex codebase, most tasks need context")

## Classification Overrides
List specific rules that override the default tier mapping for this project.
Format: "- Keyword/pattern X -> minimum tier Y: reason"
Examples:
- auth, authentication, middleware -> minimum tier 4: Auth spans 12 files across 3 layers
- database, migration, schema -> minimum tier 4: ORM setup requires understanding migrations
- tests, playwright, e2e -> minimum tier 4: Test infrastructure is complex

## Testing Setup
How to run tests in this project. Command(s), expected duration, timeout notes.

## Key Files and Modules
List the 5-10 most architecturally important files with brief descriptions.

## Common Task Patterns
3-5 patterns specific to this codebase that should influence tier selection.

---
Output ONLY the markdown document above. No preamble, no explanation, no code blocks around the document.`;

export async function spawnProjectAnalysis(cwd) {
  const sessionName = `cc-analyze-${basename(cwd)}`;
  const outputPath = join(cwd, '.claude', 'project-classifier.md');

  // Don't spawn if already running
  if (sessionExists(sessionName)) return;

  try {
    createSession(sessionName, cwd);

    // Write the analysis command - uses stdin to avoid escaping issues
    const promptFile = `/tmp/cc-analyzer-${Date.now()}.txt`;
    writeFileSync(promptFile, ANALYZER_PROMPT, 'utf8');

    const cmd = `PROMPT_ROUTER_SKIP=1 ${CLAUDE_BIN} -p --model sonnet --effort high < "${promptFile}" > "${outputPath}" 2>/dev/null && rm -f "${promptFile}" && /opt/homebrew/bin/tmux kill-session -t "${sessionName}" || true`;
    sendKeys(sessionName, cmd, { literal: false, enter: true });
  } catch {
    // Analysis failure is non-fatal - heuristic classification continues
  }
}

export function classifierExists(cwd) {
  return existsSync(join(cwd, '.claude', 'project-classifier.md'));
}
