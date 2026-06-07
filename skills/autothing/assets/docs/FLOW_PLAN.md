# Flow Plan

<!-- The build plan. autothing writes/updates this in Phase 2 and updates each slice's Status as it builds (durable resume — on re-invocation, progress is re-read from here + gate-status files, never from memory). Keep the table current. -->

## Slices
<!-- A slice = one user-facing flow or one automation, small enough for a 60-90s walkthrough. Order by dependency; mark which can run in parallel. -->

| # | Slice ID | Title | Kind | Routes to (area skill / doc) | Parallel group | Status |
|---|----------|-------|------|------------------------------|----------------|--------|
| 1 | {{slug}} | {{title}} | ui | testing + {{area}} | A | pending |
| 2 | {{slug}} | {{title}} | automation | testing + {{area}} | A | pending |
| 3 | {{slug}} | {{title}} | mixed | testing + {{area}} | B (after A) | pending |

<!-- Status: pending | in_progress | passed | blocked. Mirror of each slice's gate-status.json status. -->

## Acceptance per slice
<!-- Concrete, testable outcome each slice must reach. Seeds the Playwright assertions AND the walkthrough expectedScreen beats. -->
- **{{slug}}**: {{e.g. "Logged-in user lands on /dashboard; SSO session persists across reload; no console errors."}}

## Parallelism
- Group A slices are independent → build concurrently (one worker each, area skill + acceptance pasted into the worker prompt).
- Group B depends on A → starts after A's slices reach `passed`.

## Global acceptance
See `governance.md`. Tracked in `docs/autothing/evidence-index.json → globalGate`.
