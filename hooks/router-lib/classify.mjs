/**
 * Prompt classification engine.
 * Uses direct Anthropic API call (HAIKU_API_KEY) for classification.
 * No heuristic patterns. Only bypass (!) and model override prefixes are local.
 *
 * Set HAIKU_API_KEY in ~/.claude/settings.json "env" block or shell profile.
 * Classification FAILS LOUDLY if the API key is missing or the API call fails.
 */

import { readFileSync, existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { TIERS } from './config.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const HOOKS_DIR = join(__dirname, '..');
const CLASSIFIER_TEMPLATE_PATH = join(HOOKS_DIR, 'default-classifier-prompt.md');

const ANTHROPIC_API_URL = 'https://api.anthropic.com/v1/messages';

// Model override prefixes
const MODEL_OVERRIDES = {
  '@haiku':  1,
  '@sonnet': 3,
  '@opus':   5,
};

// ─── Programmatic tier enforcement ───────────────────────────────────────────
// Haiku is unreliable about following prompt-level classification rules
// (it will often discount explicit "minimum tier" instructions when it
// thinks it knows better). These helpers apply hard floors that can't be
// argued away.

/**
 * Parse "## Default Minimum Tier\n<number> - ..." from a project-classifier.md.
 * Returns the number, or 0 if not found.
 */
function parseProjectMinTier(projectContext) {
  if (!projectContext) return 0;
  const match = projectContext.match(/##\s*Default Minimum Tier\s*\n\s*(\d)/i);
  if (!match) return 0;
  const n = parseInt(match[1], 10);
  return Number.isFinite(n) ? n : 0;
}

/**
 * Detect escalation / repeated-failure signals in the user prompt.
 * These indicate the user is correcting a previous attempt that failed,
 * which strongly implies hidden complexity → should always be ≥ tier 4.
 */
function detectEscalationSignals(prompt) {
  if (!prompt) return { tier: 0, matched: null };
  const p = prompt.toLowerCase();
  const signals = [
    { re: /\blike i (asked|said|told|requested)\b/, label: '"like I asked"' },
    { re: /\bi (told|asked|said) you\b/, label: '"I told you"' },
    { re: /\bi already (told|said|asked|explained)\b/, label: '"I already told you"' },
    { re: /\byou (missed|forgot|ignored|didn't|didnt|did not)\b/, label: '"you missed/forgot/ignored"' },
    { re: /\bshould have (chosen|picked|used|done|been|known|fixed)\b/, label: '"should have ..."' },
    { re: /\bstill (not|doesn'?t|isn'?t|broken|wrong|failing|missing)\b/, label: '"still not/broken/wrong"' },
    { re: /\bnot (working|fixed|done) (yet|still)\b/, label: '"not working yet"' },
    { re: /\babsolutely (wrong|not|incorrect)\b/, label: '"absolutely wrong"' },
    { re: /\bthat'?s wrong\b/, label: '"that\'s wrong"' },
    { re: /\bwhy (is|are|did|does|didn'?t|wasn'?t)\b.*\?/, label: '"why ...?" question about failure' },
    { re: /\bagain\b.*\b(wrong|broken|failing|not)\b/, label: '"again ... wrong"' },
    { re: /!!!/, label: 'triple exclamation' },
  ];
  // Uppercase-emphasis words are signals when used as whole-word shouts
  const upperSignals = [
    { re: /\bNEVER\b/, label: 'uppercase NEVER' },
    { re: /\bALWAYS\b/, label: 'uppercase ALWAYS' },
    { re: /\bWRONG\b/, label: 'uppercase WRONG' },
  ];

  for (const { re, label } of signals) {
    if (re.test(p)) return { tier: 4, matched: label };
  }
  for (const { re, label } of upperSignals) {
    if (re.test(prompt)) return { tier: 4, matched: label }; // case-sensitive match
  }
  return { tier: 0, matched: null };
}

/**
 * Detect compound tasks: prompt contains both a fix/correct verb AND an
 * add/create/build verb. These are tier 4 minimum because they combine
 * two distinct operations.
 */
function detectCompoundTaskSignals(prompt) {
  if (!prompt) return { tier: 0, matched: null };
  const p = prompt.toLowerCase();
  const fixVerbs = /\b(fix|correct|repair|resolve|debug|broken|bug|not working|doesn'?t work|isn'?t working|failing)\b/;
  const addVerbs = /\b(add|create|build|implement|introduce|new (feature|button|field|section|box|component|endpoint|page))\b/;
  if (fixVerbs.test(p) && addVerbs.test(p)) {
    return { tier: 4, matched: 'fix + new feature compound task' };
  }
  return { tier: 0, matched: null };
}

// ─── API classification ──────────────────────────────────────────────────────

/**
 * Classifies prompt via Anthropic API.
 * Returns classification result or throws with a descriptive error message.
 */
async function apiClassify(prompt, cwd) {
  const apiKey = process.env.HAIKU_API_KEY;
  if (!apiKey) {
    throw new Error(
      'HAIKU_API_KEY is not set.\n' +
      'Add it to ~/.claude/settings.json under "env": { "HAIKU_API_KEY": "sk-ant-..." }\n' +
      'or export it in your shell profile.'
    );
  }

  if (!existsSync(CLASSIFIER_TEMPLATE_PATH)) {
    throw new Error(`Classifier template not found: ${CLASSIFIER_TEMPLATE_PATH}`);
  }

  const template = readFileSync(CLASSIFIER_TEMPLATE_PATH, 'utf8');

  let projectContext = '(no project context available)';
  const classifierPath = join(cwd, '.claude', 'project-classifier.md');
  if (existsSync(classifierPath)) {
    try { projectContext = readFileSync(classifierPath, 'utf8').slice(0, 6000); } catch {}
  }

  // Strip [Image #N] tags — these are Claude Code image placeholders, not text
  const cleanedPrompt = prompt.replace(/\[Image #\d+\]/g, '').trim();

  const classificationPrompt = template
    .replace('{{PROJECT_CONTEXT}}', projectContext)
    .replace('{{PROMPT}}', cleanedPrompt.slice(0, 1500));

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 8000);

  let resp;
  try {
    resp = await fetch(ANTHROPIC_API_URL, {
      method: 'POST',
      signal: controller.signal,
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify({
        model: 'claude-haiku-4-5-20251001',
        max_tokens: 256,
        messages: [{ role: 'user', content: classificationPrompt }],
      }),
    });
  } catch (err) {
    clearTimeout(timeout);
    throw new Error(`Anthropic API request failed: ${err.message}`);
  }

  clearTimeout(timeout);

  if (!resp.ok) {
    const body = await resp.text().catch(() => '');
    throw new Error(`Anthropic API error ${resp.status}: ${body.slice(0, 200)}`);
  }

  const data = await resp.json();
  const text = data.content?.[0]?.text ?? '';
  const jsonMatch = text.match(/\{[^{}]*"tier"[^{}]*\}/);
  if (!jsonMatch) {
    throw new Error(`Classifier returned unparseable response: ${text.slice(0, 200)}`);
  }

  const parsed = JSON.parse(jsonMatch[0]);
  const haikuTier = Math.max(1, Math.min(6, parseInt(parsed.tier, 10)));

  // ── Apply programmatic floors ──
  const projectMin = parseProjectMinTier(projectContext);
  const escalation = detectEscalationSignals(prompt);
  const compound = detectCompoundTaskSignals(prompt);

  const maxFloor = Math.max(haikuTier, projectMin, escalation.tier, compound.tier);
  const tier = Math.max(1, Math.min(6, maxFloor));

  // Build reasoning that surfaces any programmatic bumps
  let reasoning = parsed.reasoning || 'Haiku API classification';
  const bumps = [];
  if (projectMin > haikuTier) bumps.push(`project minimum tier ${projectMin}`);
  if (escalation.tier > haikuTier) bumps.push(`escalation signal (${escalation.matched})`);
  if (compound.tier > haikuTier) bumps.push(`${compound.matched}`);
  if (bumps.length > 0) {
    reasoning = `${reasoning} [tier raised from ${haikuTier} by: ${bumps.join(', ')}]`;
  }

  return { tier, ...TIERS[tier], reasoning };
}

// ─── Public API ──────────────────────────────────────────────────────────────

/**
 * Classify a prompt.
 * Returns { tier, model, effort, reasoning, cleanPrompt?, bypass?, isOverride? }
 * or { error: true, message: string } if classification fails.
 */
export async function classify(prompt, cwd) {
  const p = prompt.trimStart();

  // Bypass prefix
  if (p.startsWith('!')) {
    return { tier: null, bypass: true, cleanPrompt: p.slice(1).trimStart() };
  }

  // Model override prefixes
  for (const [prefix, tier] of Object.entries(MODEL_OVERRIDES)) {
    if (p.toLowerCase().startsWith(prefix)) {
      return {
        tier,
        ...TIERS[tier],
        reasoning: `Forced by ${prefix} prefix`,
        cleanPrompt: p.slice(prefix.length).trimStart(),
        isOverride: true,
      };
    }
  }

  // Direct API classification (requires HAIKU_API_KEY)
  try {
    return await apiClassify(prompt, cwd);
  } catch (err) {
    return { error: true, message: err.message };
  }
}
