/**
 * tmux operations for the prompt router.
 * Ported from ~/dev/ekus/mac-mini/drive/modules/tmux.py patterns.
 */

import { execSync } from 'node:child_process';
import { writeFileSync, unlinkSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { TMUX_BIN } from './config.mjs';
import { platform } from 'node:os';

function run(args, { check = true } = {}) {
  const cmd = [TMUX_BIN, ...args].map(a => `'${String(a).replace(/'/g, "'\\''")}'`).join(' ');
  try {
    const result = execSync(cmd, { encoding: 'utf8', timeout: 10000, stdio: ['pipe', 'pipe', 'pipe'] });
    return { stdout: result, returncode: 0 };
  } catch (err) {
    if (!check) return { stdout: '', returncode: err.status ?? 1 };
    throw new Error(`tmux ${args[0]} failed: ${err.stderr ?? err.message}`);
  }
}

export function sessionExists(name) {
  const result = run(['has-session', '-t', name], { check: false });
  return result.returncode === 0;
}

export function createSession(name, cwd, { headed = false } = {}) {
  if (!sessionExists(name)) {
    run(['new-session', '-d', '-s', name, '-c', cwd]);
    // Keep pane visible even if the shell exits unexpectedly (survive Claude exits)
    run(['set-option', '-t', name, 'remain-on-exit', 'on']);
    // Diagnostic trap: log every shell exit with signal info to /tmp/cc-session-exit.log
    const logFile = `/tmp/cc-exit-${name}.log`;
    const trapCmd = [
      `trap 'echo "$(date): EXIT code=$? ppid=$PPID shell=$$" >> ${logFile}' EXIT`,
      `trap 'echo "$(date): SIGTERM ppid=$PPID shell=$$" >> ${logFile}' TERM`,
      `trap 'echo "$(date): SIGHUP ppid=$PPID shell=$$" >> ${logFile}' HUP`,
      `echo "$(date): Shell started ppid=$PPID shell=$$" >> ${logFile}`,
    ].join(' && ');
    run(['send-keys', '-t', `${name}:`, trapCmd, 'Enter']);
    if (headed) {
      openTerminalTab(name, cwd);
    }
  }
}

/** Returns true if the first pane of the session has exited (dead pane). */
export function isPaneDead(session) {
  const result = run(
    ['list-panes', '-t', `${session}:`, '-F', '#{pane_dead}'],
    { check: false }
  );
  return result.stdout.trim().split('\n')[0] === '1';
}

/** Respawn a dead pane in the session, resetting to cwd. */
export function respawnPane(session, cwd) {
  run(['respawn-pane', '-t', `${session}:`, '-k', '-c', cwd]);
}

/**
 * Open iTerm2 tab (or Terminal.app fallback) attached to the session.
 * Called ONCE per session lifetime when the session is first created.
 */
export function openTerminalTab(sessionName, cwd) {
  if (platform() !== 'darwin') return;
  if (!tryOpenInIterm(sessionName, cwd)) {
    openInTerminalApp(sessionName, cwd);
  }
}

function tryOpenInIterm(sessionName, cwd) {
  // Use a grouped session (new-session -t) instead of attach-session.
  // A grouped session mirrors the main session but is an independent tmux object —
  // closing the iTerm tab kills the view session only, NOT the main session.
  const viewName = `view-${sessionName}`;
  const attachCmd = `${TMUX_BIN} new-session -t '${sessionName.replace(/'/g, "'\\''")}'` +
    ` -s '${viewName.replace(/'/g, "'\\''")}'` +
    ` || ${TMUX_BIN} attach-session -t '${viewName.replace(/'/g, "'\\''")}'`;
  const cdCmd = `cd '${cwd.replace(/'/g, "'\\''")}'`;
  const script = `tell application "iTerm"
  activate
  if (count of windows) = 0 then
    create window with default profile
  end if
  tell current window
    create tab with default profile
    tell current session
      write text "${cdCmd} && ${attachCmd}"
    end tell
  end tell
end tell`;

  const scriptFile = join(tmpdir(), `cc-iterm-${Date.now()}.scpt`);
  try {
    writeFileSync(scriptFile, script, 'utf8');
    execSync(`osascript '${scriptFile}'`, { timeout: 5000, stdio: 'ignore' });
    return true;
  } catch {
    return false;
  } finally {
    try { unlinkSync(scriptFile); } catch {}
  }
}

function openInTerminalApp(sessionName, cwd) {
  const viewName = `view-${sessionName}`;
  const cmd = `cd '${cwd.replace(/'/g, "'\\''")}' && (${TMUX_BIN} new-session -t '${sessionName}' -s '${viewName}' || ${TMUX_BIN} attach-session -t '${viewName}')`;
  const escaped = cmd.replace(/\\/g, '\\\\').replace(/"/g, '\\"');
  try {
    execSync(`osascript -e 'tell application "Terminal" to do script "${escaped}"'`, {
      timeout: 5000,
      stdio: 'ignore',
    });
  } catch {
    // Silently fail
  }
}

/**
 * Create a new window in the session for the next prompt.
 * The already-attached iTerm terminal automatically switches to the new window —
 * no new tab opens. Each prompt gets a fresh shell with no conflict.
 */
export function createFreshWindow(sessionName, cwd) {
  run(['new-window', '-t', `${sessionName}:`, '-c', cwd]);
}

/**
 * Kill all tmux sessions whose names match the given regex pattern.
 */
export function killSessionsMatching(pattern) {
  for (const s of listSessions()) {
    if (pattern.test(s.name)) {
      killSession(s.name);
    }
  }
}

/**
 * Send keystrokes to a tmux pane.
 * target: "session" or "session:window"
 */
export function sendKeys(target, keys, { literal = true, enter = true } = {}) {
  if (!target.includes(':')) target = `${target}:`;

  const prefix = [TMUX_BIN, 'send-keys', '-t', target, ...(literal ? ['-l'] : [])];
  const prefixStr = prefix.map(a => `'${String(a).replace(/'/g, "'\\''")}'`).join(' ');
  const keysEscaped = `'${keys.replace(/'/g, "'\\''")}'`;

  execSync(`${prefixStr} ${keysEscaped}`, { encoding: 'utf8', timeout: 10000, stdio: ['pipe', 'pipe', 'pipe'] });

  if (enter) {
    run(['send-keys', '-t', target, 'C-m']);
  }
}

export function capturePane(session, { startLine = -500 } = {}) {
  const target = `${session}:`;
  const result = run(['capture-pane', '-p', '-t', target, '-S', String(startLine)]);
  return result.stdout;
}

export function killSession(name) {
  if (sessionExists(name)) {
    run(['kill-session', '-t', name]);
  }
}

export function listSessions() {
  const result = run(
    ['list-sessions', '-F', '#{session_name}\t#{session_windows}\t#{session_attached}'],
    { check: false }
  );
  if (result.returncode !== 0) return [];
  return result.stdout.trim().split('\n').filter(Boolean).map(line => {
    const [name, windows, attached] = line.split('\t');
    return { name, windows: parseInt(windows, 10), attached: attached !== '0' };
  });
}
