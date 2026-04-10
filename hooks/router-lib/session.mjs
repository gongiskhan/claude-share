/**
 * Session state management for the prompt router.
 * Per-project state stored in .claude/router-state.json
 */

import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { randomUUID } from 'node:crypto';
import { REFRESH_THRESHOLD } from './config.mjs';

const DEFAULT_STATE = {
  lastSessionId: null,
  sessionCount: 0,
  lastClassifierRefresh: null,
  lastTier: null,
  lastModel: null,
  tmuxSession: null,
  terminalOpened: false,
};

function statePath(cwd) {
  return join(cwd, '.claude', 'router-state.json');
}

export function readState(cwd) {
  const path = statePath(cwd);
  if (!existsSync(path)) return { ...DEFAULT_STATE };
  try {
    return { ...DEFAULT_STATE, ...JSON.parse(readFileSync(path, 'utf8')) };
  } catch {
    return { ...DEFAULT_STATE };
  }
}

export function writeState(cwd, state) {
  const dotClaudeDir = join(cwd, '.claude');
  if (!existsSync(dotClaudeDir)) {
    mkdirSync(dotClaudeDir, { recursive: true });
  }
  writeFileSync(statePath(cwd), JSON.stringify(state, null, 2), 'utf8');
}

export function generateSessionId() {
  return randomUUID();
}

export function needsClassifierRefresh(state) {
  if (!state.lastClassifierRefresh) return false; // No refresh if never analyzed
  return state.sessionCount > 0 && state.sessionCount % REFRESH_THRESHOLD === 0;
}

export function markClassifierRefresh(state) {
  return { ...state, lastClassifierRefresh: new Date().toISOString() };
}
