/**
 * Tier definitions, model mappings, and workflow instructions for the prompt router.
 */

export const NODE_BIN = '/Users/ggomes/.nvm/versions/node/v20.19.4/bin/node';
export const TMUX_BIN = '/opt/homebrew/bin/tmux';
export const CLAUDE_BIN = 'claude'; // on PATH

export const REFRESH_THRESHOLD = 50; // Re-analyze project after this many sessions

export const TIERS = {
  1: { name: 'TRIVIAL',     model: 'haiku',  effort: null   },
  2: { name: 'SIMPLE',      model: 'sonnet', effort: 'high' },
  3: { name: 'MODERATE',    model: 'sonnet', effort: 'max'  },
  4: { name: 'SIGNIFICANT', model: 'opus',   effort: 'high' },
  5: { name: 'MAJOR',       model: 'opus',   effort: 'high' },
  6: { name: 'CRITICAL',    model: 'opus',   effort: 'max'  },
};

export const DEFAULT_TIER = 3;

// Workflow instructions injected into routed prompts per tier.
// Tiers 4+ include enforcement markers scanned by test-enforcement.mjs.
export const WORKFLOW_INSTRUCTIONS = {
  1: null, // No instructions for trivial tasks

  2: `[Keep this focused. Read only directly relevant files. No exploration beyond what's needed. No task list. Just do it and confirm.]`,

  3: `[Create a brief task list (3-5 items). Verify changes compile/work. Iterate if something fails. Task is not done until verified working.]`,

  4: `[TIER_4_ENFORCEMENT] This requires careful execution:
1. PLAN: Read all relevant files first. Understand existing patterns. State your approach.
2. TASK LIST: Create a detailed, verifiable task list.
3. IMPLEMENT: Follow the plan.
4. VALIDATE WITH BROWSER: Use browser automation (check the e2e-testing skill for current tool preference) to manually verify the implementation works. Drive the browser yourself, click through flows, confirm visual and functional correctness. This comes BEFORE writing tests.
5. WRITE TESTS: Once browser validation confirms it works, write automated tests that codify what you just verified.
6. RUN TESTS: Execute the full test suite. Wait for results no matter how long they take.
7. ITERATE: If anything fails (browser validation OR tests), fix and re-validate from step 4.
Task completion requires BOTH: browser automation validation passes AND automated tests pass.`,

  5: `[TIER_5_ENFORCEMENT] This is a complex task requiring maximum rigor:
1. PLAN: Use the planning tool. Think through architecture, edge cases, dependencies. The plan is the most important artifact. Do not rush it.
2. AGENT TEAM: Create team tasks. Delegate to specialized teammates:
   - Planner/Architect: Owns the spec
   - Implementer(s): Code following the plan
   - Tester: Validates with browser automation FIRST (check e2e-testing skill), then writes automated tests
   - Reviewer: Code quality, pattern adherence
3. TASK LIST: Comprehensive, with dependencies. Each task has acceptance criteria.
4. IMPLEMENT: Follow the plan. Deviations require plan update first.
5. VALIDATE WITH BROWSER: Before writing any tests, use browser automation to drive through all implemented flows.
6. WRITE TESTS: Codify the browser validation into automated test scripts.
7. RUN ALL TESTS: Execute full test suites. E2E. Wait for results even if 10+ minutes.
8. ITERATE UNTIL GREEN: Nothing is done until BOTH browser automation validation passes AND all automated tests pass.
9. DOCS: Update relevant documentation.
Quality over speed. Do not cut corners.`,

  6: `[TIER_5_ENFORCEMENT] This is a critical task requiring maximum rigor and depth:
1. PLAN: Use the planning tool exhaustively. This is the most important artifact.
2. AGENT TEAM: Assemble a full team with clear roles and ownership.
3. ARCHITECTURE FIRST: Design the full system before writing any code.
4. TASK LIST: Comprehensive with dependencies and acceptance criteria.
5. IMPLEMENT: Strictly follow the plan. No shortcuts.
6. VALIDATE WITH BROWSER: Full end-to-end browser automation testing of all flows.
7. WRITE TESTS: Complete test coverage.
8. RUN ALL TESTS: Full suite. Wait for everything.
9. ITERATE UNTIL GREEN: All tests pass, browser validated.
10. DOCS: Full documentation update.
Quality over speed. Maximum depth. No cutting corners.`,
};

export function getTier(tierNum) {
  return TIERS[tierNum] || TIERS[DEFAULT_TIER];
}

export function getWorkflowInstructions(tierNum) {
  return WORKFLOW_INSTRUCTIONS[tierNum] ?? WORKFLOW_INSTRUCTIONS[DEFAULT_TIER];
}
