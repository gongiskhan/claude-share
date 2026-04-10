#!/usr/bin/env node
/**
 * Prompt Router -- UserPromptSubmit hook
 *
 * Classifies every user prompt and routes it to a tmux session
 * with the optimal Claude model and effort level.
 *
 * Session naming: <project-folder>-cc  (e.g. ekoa-dev-cc)
 * One session per project, persistent. iTerm tab opened once.
 * On subsequent prompts: interrupt running Claude, resume same session ID.
 *
 * Input:  JSON on stdin { prompt, session_id, cwd, ... }
 * Output: JSON on stdout { decision, reason } | {} (allow)
 */

import { writeFileSync } from 'node:fs';
import { basename } from 'node:path';
import { randomUUID } from 'node:crypto';
import { hostname as osHostname } from 'node:os';

// --- Bootstrap: read stdin before anything else ---
const inputRaw = await new Promise(resolve => {
  let data = '';
  process.stdin.on('data', chunk => { data += chunk; });
  process.stdin.on('end', () => resolve(data));
});

// --- Loop guard: routed sessions must not re-route ---
if (process.env.PROMPT_ROUTER_SKIP === '1') {
  process.stdout.write('{}');
  process.exit(0);
}

let input;
try {
  input = JSON.parse(inputRaw);
} catch {
  process.stdout.write('{}');
  process.exit(0);
}

const rawPrompt = input.prompt ?? input.user_prompt ?? '';
const cwd = input.cwd ?? process.cwd();

if (!rawPrompt.trim()) {
  process.stdout.write('{}');
  process.exit(0);
}

// --- Imports (after loop guard to keep startup fast for routed sessions) ---
const { classify } = await import('./router-lib/classify.mjs');
const { readState, writeState, generateSessionId, needsClassifierRefresh, markClassifierRefresh } = await import('./router-lib/session.mjs');
const { sessionExists, createSession, openTerminalTab, sendKeys, respawnPane } = await import('./router-lib/tmux.mjs');
const { getWorkflowInstructions, TIERS } = await import('./router-lib/config.mjs');
const { spawnProjectAnalysis, classifierExists } = await import('./router-lib/project-analyzer.mjs');

// --- Startup cleanup: kill stale analyzer sessions ---
try { killSessionsMatching(/^cc-analyze-/); } catch {}

// --- Classify prompt ---
const classification = await classify(rawPrompt, cwd);

// --- Handle classification error ---
if (classification?.error) {
  process.stdout.write(JSON.stringify({
    decision: 'block',
    reason: `ROUTER CLASSIFICATION FAILED\n\n${classification.message}\n\nFix the issue above, then retry your prompt.`,
  }));
  process.exit(0);
}

// --- Handle bypass (! prefix) ---
if (classification?.bypass) {
  process.stdout.write(JSON.stringify({
    hookSpecificOutput: {
      hookEventName: 'UserPromptSubmit',
      additionalContext: 'User used "!" bypass prefix. Process this prompt directly in this session. Ignore the "!" character at the start.',
    }
  }));
  process.exit(0);
}

// --- Read per-project state ---
const state = readState(cwd);

// Session name: <folder>-cc
const tmuxName = `${basename(cwd)}-cc`;

// --- Trigger background project analysis if needed ---
const hasClassifier = classifierExists(cwd);
if (!hasClassifier && state.sessionCount === 0) {
  spawnProjectAnalysis(cwd).catch(() => {});
} else if (hasClassifier && needsClassifierRefresh(state)) {
  spawnProjectAnalysis(cwd).catch(() => {});
}

// --- Determine clean prompt and tier ---
const cleanPrompt = classification.cleanPrompt ?? rawPrompt;
const tier = classification.tier ?? 3;

// --- Build workflow instructions ---
const workflowInstructions = getWorkflowInstructions(tier);
const fullPrompt = workflowInstructions
  ? `${workflowInstructions}\n\n${cleanPrompt}`
  : cleanPrompt;

// --- Write prompt to temp file (avoids all shell escaping issues) ---
const promptFile = `/tmp/cc-router-${randomUUID()}.txt`;
writeFileSync(promptFile, fullPrompt, 'utf8');

// --- Session and terminal management ---
const isNewSession = !sessionExists(tmuxName);

if (isNewSession) {
  createSession(tmuxName, cwd);
  // Open terminal tab once per session lifetime
  openTerminalTab(tmuxName, cwd);
  state.terminalOpened = true;
} else {
  // Existing session. A previous Claude may still be running inside the pane.
  // If we just sent the new `claude ...` command via send-keys, it would be
  // typed into the running Claude's input box (treated as a chat message)
  // instead of being executed by the shell. And `/exit` isn't reliable because
  // Claude ignores slash commands mid-stream, while permission dialogs, etc.
  // So: always nuke the pane with respawn-pane -k. This sends SIGKILL to the
  // running command, gives us a fresh shell, and is reliable regardless of
  // whatever state Claude was in.
  respawnPane(tmuxName, cwd);
  // Give the fresh shell a beat to initialize before sending keystrokes.
  await new Promise(resolve => setTimeout(resolve, 500));
}

// --- Build claude command ---
const tierConfig = TIERS[tier] ?? TIERS[3];
const modelFlag = `--model ${tierConfig.model}`;
const effortFlag = tierConfig.effort ? `--effort ${tierConfig.effort}` : '';

// Unset TMUX/TMUX_PANE so the Agent SDK can't capture and later kill this session
const envPrefix = 'PROMPT_ROUTER_SKIP=1 TMUX= TMUX_PANE=';

let claudeCmd;
if (state.lastSessionId) {
  claudeCmd = [
    envPrefix,
    'claude',
    '--resume', state.lastSessionId,
    modelFlag,
    effortFlag,
    '--dangerously-skip-permissions',
    `< "${promptFile}"`,
  ].filter(Boolean).join(' ');
} else {
  const newSessionId = generateSessionId();
  state.lastSessionId = newSessionId;
  claudeCmd = [
    envPrefix,
    'claude',
    '--session-id', newSessionId,
    modelFlag,
    effortFlag,
    `--name "routed-${tier}"`,
    '--dangerously-skip-permissions',
    `< "${promptFile}"`,
  ].filter(Boolean).join(' ');
}

// Send command (literal=false so < redirection works)
sendKeys(tmuxName, claudeCmd, { literal: false, enter: true });

// --- Update state ---
state.lastTier = tier;
state.lastModel = tierConfig.model;
state.sessionCount = (state.sessionCount || 0) + 1;
state.tmuxSession = tmuxName;
if (hasClassifier && needsClassifierRefresh(state)) {
  Object.assign(state, markClassifierRefresh(state));
}
writeState(cwd, state);

// --- Block prompt in main session ---
const tierName = tierConfig.name ?? 'MODERATE';
const effortDisplay = tierConfig.effort ?? 'default';
const host = osHostname();

const viewName = `view-${tmuxName}`;
const reason = [
  `Routed to ${tierConfig.model} (${effortDisplay}) -- Tier ${tier}: ${tierName}`,
  `Reason: ${classification.reasoning ?? 'classification'}`,
  ``,
  `--- SESSION: ${tmuxName} ---`,
  `Local:   tmux new-session -t ${tmuxName} -s ${viewName} || tmux attach-session -t ${viewName}`,
  `Remote:  ssh ${host} -t tmux attach-session -t ${tmuxName}`,
  `Claude session: ${state.lastSessionId}`,
  ``,
  `Tips: ! to bypass routing | @opus/@sonnet/@haiku to force model`,
].join('\n');

process.stdout.write(JSON.stringify({ decision: 'block', reason }));
