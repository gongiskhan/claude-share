#!/usr/bin/env node
/**
 * Test Enforcement -- Stop hook
 *
 * For tier 4+ tasks routed by the prompt router, blocks stopping unless:
 * 1. Browser automation tool was used
 * 2. Tests were executed
 *
 * High-tier detection: reads .claude/router-state.json and checks that
 * input.session_id matches the router's lastSessionId with lastTier >= 4.
 * This avoids false positives from transcript text-matching.
 *
 * Input:  JSON on stdin { transcript_path, reason, cwd, session_id, stop_hook_active }
 * Output: JSON on stdout { decision, reason } | {}
 */

import { openSync, readSync, fstatSync, closeSync, readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';

const inputRaw = await new Promise(resolve => {
  let data = '';
  process.stdin.on('data', chunk => { data += chunk; });
  process.stdin.on('end', () => resolve(data));
});

let input;
try {
  input = JSON.parse(inputRaw);
} catch {
  process.stdout.write('{}');
  process.exit(0);
}

// Prevent infinite loops
if (input.stop_hook_active) {
  process.stdout.write('{}');
  process.exit(0);
}

const transcriptPath = input.transcript_path;
const sessionId = input.session_id;
const cwd = input.cwd ?? process.cwd();

if (!transcriptPath || !sessionId) {
  process.stdout.write('{}');
  process.exit(0);
}

// --- Check router-state.json to determine if this is a high-tier routed session ---
function readRouterState(cwd) {
  const statePath = join(cwd, '.claude', 'router-state.json');
  if (!existsSync(statePath)) return null;
  try {
    return JSON.parse(readFileSync(statePath, 'utf8'));
  } catch {
    return null;
  }
}

const routerState = readRouterState(cwd);

// Only enforce if: router has a record for this exact session AND tier >= 4
const isHighTierRoutedSession =
  routerState !== null &&
  routerState.lastSessionId === sessionId &&
  (routerState.lastTier ?? 0) >= 4;

if (!isHighTierRoutedSession) {
  process.stdout.write('{}');
  process.exit(0);
}

// --- Efficiently read last N lines of the transcript JSONL file ---
function readLastLines(filePath, n) {
  let fd;
  try {
    fd = openSync(filePath, 'r');
    const { size } = fstatSync(fd);
    if (size === 0) return [];
    const readSize = Math.min(size, n * 2048);
    const buf = Buffer.alloc(readSize);
    readSync(fd, buf, 0, readSize, size - readSize);
    return buf.toString('utf8').split('\n').filter(Boolean).slice(-n);
  } catch {
    return [];
  } finally {
    if (fd !== undefined) closeSync(fd);
  }
}

const lines = readLastLines(transcriptPath, 200);
const entries = lines
  .map(l => { try { return JSON.parse(l); } catch { return null; } })
  .filter(Boolean);

// --- Extract tool_use calls from assistant messages ---
const toolUses = entries
  .filter(e => e.type === 'assistant')
  .flatMap(e => {
    const content = e.message?.content ?? e.content ?? [];
    return Array.isArray(content) ? content.filter(c => c.type === 'tool_use') : [];
  });

// --- Skip enforcement if only config/script files were touched ---
// Rationale: tier 4+ enforcement is meant for real feature/bug work that
// needs browser validation and test runs. Editing markdown prompts, JSON/YAML
// config, shell scripts, or hook .mjs files has nothing meaningful to validate
// with a browser and usually no test suite in scope. Detect by file extension
// rather than cwd — because cwd sometimes drifts during a session.
const CONFIG_EXTS = new Set([
  'md', 'markdown', 'mdx',
  'json', 'jsonl', 'jsonc',
  'xml',
  'yaml', 'yml',
  'toml',
  'ini', 'conf', 'cfg',
  'env',
  'sh', 'bash', 'zsh', 'fish',
  'mjs', 'cjs',
  'txt',
  'applescript', 'scpt',
]);

function extOf(filePath) {
  if (!filePath) return '';
  const base = filePath.split('/').pop() ?? '';
  const dot = base.lastIndexOf('.');
  return dot === -1 ? '' : base.slice(dot + 1).toLowerCase();
}

const editedFiles = toolUses
  .filter(t => ['Edit', 'Write', 'MultiEdit', 'NotebookEdit'].includes(t.name))
  .map(t => t.input?.file_path ?? t.input?.filePath ?? t.input?.notebook_path ?? '')
  .filter(Boolean);

const onlyConfigTouched =
  editedFiles.length === 0 || editedFiles.every(f => CONFIG_EXTS.has(extOf(f)));

if (onlyConfigTouched) {
  process.stdout.write('{}');
  process.exit(0);
}

// --- Check for browser automation ---
const hasBrowserTest = toolUses.some(t =>
  t.name?.startsWith('mcp__claude-in-chrome__') ||
  t.name?.startsWith('mcp__playwright') ||
  (t.name === 'Bash' && /playwright|cypress|puppeteer/.test(t.input?.command ?? ''))
);

// --- Check for test execution ---
const hasTestRun = toolUses.some(t =>
  t.name === 'Bash' &&
  /\b(npm\s+(run\s+)?test|yarn\s+test|pnpm\s+test|jest|vitest|pytest|cargo\s+test|go\s+test|mocha|jasmine|rspec)\b/.test(t.input?.command ?? '')
);

if (!hasBrowserTest || !hasTestRun) {
  const missing = [];
  if (!hasBrowserTest) missing.push('browser automation validation');
  if (!hasTestRun) missing.push('test execution');

  process.stdout.write(JSON.stringify({
    decision: 'block',
    reason: [
      `Testing incomplete. Missing: ${missing.join(', ')}.`,
      ``,
      `Required for tier 4+ tasks:`,
      `  1. Browser automation validation (mcp__claude-in-chrome__ tools or Playwright)`,
      `  2. Automated test execution (jest/vitest/pytest/etc.)`,
      ``,
      `Complete both before stopping.`,
    ].join('\n'),
  }));
} else {
  process.stdout.write('{}');
}
