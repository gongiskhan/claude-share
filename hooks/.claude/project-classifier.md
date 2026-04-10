# Project Classifier

## Summary
A Claude Code hook system that intercepts every user prompt via a `UserPromptSubmit` hook, classifies it into one of 6 complexity tiers using a two-stage classifier (regex heuristics -> Haiku AI fallback), then routes it to a dedicated tmux session with the appropriate Claude model and effort level. A `Stop` hook enforces that tier 4+ tasks complete browser automation and test execution before closing. Secondary hooks handle macOS notifications. Pure Node.js ESM, no package.json/dependencies, no test framework.

## Default Minimum Tier
2 - Small, focused codebase (~8 files, no external deps). Most changes are mechanical edits to a single module, but each file is architecturally load-bearing so even small changes can have wide effect.

## Classification Overrides
- tier, tiers, model mapping, TIERS, effort level -> minimum tier 3: Tier definitions in config.mjs cascade through every module; a change here affects routing, enforcement, and workflow instructions simultaneously
- routing, route, classify, classification, heuristic, regex pattern -> minimum tier 3: classify.mjs heuristics interact with haiku fallback and project-classifier context; changes are easy to get subtly wrong
- tmux, session, sendKeys, createSession -> minimum tier 3: tmux.mjs uses a non-standard two-step send-keys pattern; changes require understanding shell-quoting and literal vs. non-literal mode
- enforcement, stop hook, test-enforcement, browser automation -> minimum tier 4: test-enforcement.mjs reads router-state.json and transcript JSONL; changes affect when tasks can complete and must be validated end-to-end
- workflow instructions, WORKFLOW_INSTRUCTIONS, tier 4+, TIER_4_ENFORCEMENT -> minimum tier 4: modifying these strings changes the injected prompt text that governs how Claude behaves in routed sessions
- project-analyzer, spawnProjectAnalysis, classifier refresh -> minimum tier 3: background async analysis interacts with session state and tmux lifecycle

## Testing Setup
No test framework is present. Manual testing only:
- Trigger `UserPromptSubmit`: `echo '{"prompt":"your prompt","cwd":"/path/to/project"}' | node prompt-router.mjs`
- Trigger `Stop` hook: `echo '{"transcript_path":"/path","session_id":"id","cwd":"/path"}' | node test-enforcement.mjs`
- Observe tmux session creation: `tmux list-sessions`
- Full integration test requires a live Claude Code session with hooks wired in `~/.claude/settings.json`.
- No automated tests exist; consider this when modifying enforcement logic.

## Key Files and Modules
- `prompt-router.mjs` - Entry point for `UserPromptSubmit` hook; orchestrates classify -> tmux -> block flow
- `router-lib/classify.mjs` - Two-stage classifier: regex heuristics first, then Haiku `claude -p` fallback with project context
- `router-lib/config.mjs` - Single source of truth for tier definitions, model/effort mappings, and all workflow instruction strings injected into routed prompts
- `router-lib/session.mjs` - Per-project state (`router-state.json`): tracks last session ID, tier, session count, and classifier refresh threshold
- `router-lib/tmux.mjs` - tmux abstraction: create/check/send-keys to sessions; uses two-step send to avoid shell escaping issues
- `router-lib/project-analyzer.mjs` - Spawns background `claude -p sonnet` analysis to generate `.claude/project-classifier.md` for the active project
- `test-enforcement.mjs` - `Stop` hook that blocks task completion for tier 4+ sessions unless browser automation and test execution are found in the transcript
- `default-classifier-prompt.md` - Template prompt fed to Haiku for AI-based classification; contains tier table and `{{PROJECT_CONTEXT}}` / `{{PROMPT}}` placeholders
- `notification-hook.sh` - `Notification` hook; wraps macOS `osascript` to display system alerts from Claude Code events

## Common Task Patterns
- **Adjusting tier thresholds or model assignments** (e.g., "make tier 3 use opus"): single edit to `config.mjs:TIERS` but must verify downstream effects in `prompt-router.mjs` and `test-enforcement.mjs` — treat as tier 3
- **Adding a new heuristic pattern** (e.g., "also match 'refactor' as tier 4"): edit `classify.mjs` TIER*_PATTERNS arrays; test with sample prompts via stdin — tier 2-3
- **Changing enforcement rules** (e.g., "require pytest specifically" or "add a third enforcement check"): edits `test-enforcement.mjs` logic and should be validated with a live routed session — tier 4
- **Modifying workflow instructions** (e.g., "add a step 8 to tier 5"): edit the `WORKFLOW_INSTRUCTIONS` object in `config.mjs`; changes are injected verbatim into routed prompts so wording matters — tier 3
- **Debugging routing behavior** (reading state, checking why a prompt went to wrong tier): read `router-state.json`, run classify manually via stdin — tier 1-2
