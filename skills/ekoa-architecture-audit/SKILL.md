---
name: ekoa-architecture-audit
description: Deliberate architecture and invariant audit of Ekoa codebases (ekoa-mono, agent-garrison). Produces ARCHITECTURE_AUDIT.md with file-cited findings, checking Ekoa platform invariants (Cortex-mediated Git, Data Service API boundary, composition isolation, multi-tenancy) plus structural debt in agent-written code. Audit only, never fixes. Use when asked for an architecture audit, invariant check, weakness/inconsistency review, or codebase health check. Does not auto-invoke.
disable-model-invocation: true
---

# Ekoa Architecture Audit

Invoked via `/ekoa-architecture-audit`. Conducts a deliberate audit of the current repo and writes `ARCHITECTURE_AUDIT.md` with cited findings. This is an audit, not a fix run: never modify code during the audit. Findings are executed later, one per session or worktree, after approval.

Context that shapes everything below: all code in these repos is written by Claude Code. Human readability is not a goal. The audience for the code is future agent sessions. What matters: invariants hold, one canonical way to do each thing, typed contracts at boundaries, no dead or misleading content, no speculative abstraction.

## Operating principles

Find what's actually wrong. Not diplomatic, not surface-only. No "overall the codebase is well-structured" filler. Don't pattern-match to generic best practices without grounding in this repo.

Cite `file:line` for every concrete finding. Vague claims ("the code generally...") don't count. Read code before judging it: a pattern that looks wrong in isolation may be load-bearing.

Every finding must name a concrete cost: a violated invariant, wrong behavior, a blocked or half-finished migration, a security or tenant-isolation exposure, or confusion cost for future agent sessions (the next agent picks the wrong pattern, extends dead code, trusts a stale doc). "Cleaner", "more idiomatic", or "best practice" is not a finding.

## Phase 1: Orient

Do not skip this. Forming opinions before understanding the system produces bad audits.

1. Identify which repo you are in:
   - **ekoa-mono** (`ekoa-core/`, `ekoa-platform/`, `ekoa-data/`): the platform. Apply Phase 2A and 2B.
   - **agent-garrison**: agnostic agent infrastructure. Apply Phase 2B plus invariant G in 2A.
   - Anything else: apply Phase 2B and whatever invariants from 2A the code touches.
2. Read `CLAUDE.md`, the README, package manifests, and any architecture docs or ADRs. Treat them as claimed invariants to verify, not as truth.
3. Map the directory structure and identify the major modules and layers.
4. Run `git log --oneline -200` and `git log --stat --since="6 months ago"` to see where churn concentrates.
5. List the top 20 largest files by line count and the 20 most frequently modified files. The intersection is where debt usually hides.
6. Use `TodoWrite` to publish a plan so progress through the phases is visible.

Write a 1–2 paragraph mental model of the architecture before proceeding. If your model contradicts CLAUDE.md or the docs, flag it: that itself is a finding (see dimension 9).

## Phase 2A: Ekoa invariants (highest priority)

These are the platform's structural rules. Violations start at **High** severity; cross-tenant exposure or silent breaking changes are **Critical**. Run these checks in the main agent with a cross-package view, since boundary violations are cross-package by nature. The grep seeds below are starting points: adapt them to the actual identifiers you found in Phase 1.

**A. Git mediation.** Every Git/GitHub operation flows through Cortex via the GitHub App. Findings: direct GitHub API calls or raw `git` invocations outside the sanctioned Cortex path; GitHub URLs reaching any user-facing surface; remnants of the removed bespoke version/download/fork/backup code. Seeds: `octokit`, `api.github.com`, `github.com/` in frontend code, `simple-git`, `child_process` + `git`.

**B. Data boundary.** All entity reads and writes go through the Data Service API using logical entity names. Findings: direct Firestore (or legacy JsonStore) collection access from app or feature code; collections not following `comp_{compositionId}__{entity}` namespacing; entity definitions not living as versioned content in Git; schema changes that violate additive-is-silent / breaking-asks (a breaking change applied without an ask gate is Critical). Seeds: `collection(`, `firestore`, `JsonStore`, hardcoded collection name strings.

**C. Composition isolation (Vision Discipline Rule).** Customer-specific logic hardcoded anywhere in core is a finding. Customer bends must live inside their composition as skills, recipes, instructions, or artifacts. Any core feature that can only be justified by one customer is **Critical**. Seeds: customer names (`bsm`, `brasil`, `salomao`), client-specific IDs or business rules in `ekoa-core`.

**D. Multi-tenancy.** Authorization must be expressed through the three-role hierarchy (Super Admin / Admin / Builder) and four-level visibility (private, team, company, public). Findings: ad-hoc role checks bypassing the canonical authz path; queries not scoped by company/tenant; `EKOA_TOKEN` appearing in any user-facing surface.

**E. Migration completeness (build-to-final-form).** Half-migrated parallel implementations (JsonStore beside Firestore, old bespoke Git code beside Cortex paths), temporary scaffolding, bridges marked "for now", feature flags that became permanent. A migration that is 90% done is debt at the 10%, not progress at the 90%.

**G. Garrison rule (agent-garrison only).** Apply the Garrison Honesty Test: any component justifiable only on Ekoa grounds fails the test and is a finding. It belongs in Ekoa, not Garrison.

## Phase 2B: Structural dimensions

Use `rg`, `ast-grep`, and the tooling below to find concrete examples. Cite `path/to/file.ext:LINE` for every finding.

1. **Architectural decay**: circular deps, layering violations, god files (>500 LOC) and god functions, duplicated logic across 3+ sites where an abstraction should exist, abstractions nobody uses, dead code (unused exports, unreachable branches, stale commented-out blocks). Dead code is worse here than in a human codebase: future agent sessions will read it and extend the wrong path.

2. **Consistency rot**: in an agent-written codebase this is the top confusion source. Multiple ways of doing the same thing (HTTP clients, error handling, logging, config loading, validation, date handling) means the next session picks one at random and entrenches the split. For each split pattern, identify the canonical form and flag deviations from it.

3. **Over-engineering and speculative generality**: abstractions with a single implementation, options and parameters never passed, plugin points with no second plugin, indirection layers with one caller, config surface nobody sets. LLM-written code over-engineers by default; hunt for it deliberately. The recommendation is usually deletion or inlining, not completion.

4. **Type and contract debt**: `any` / `as any` / `unknown` escape hatches, untyped boundaries, missing schema validation at trust boundaries (Cortex endpoints, the Data Service API, the MCP surface, webhook handlers).

5. **Error handling and observability**: swallowed exceptions, blanket catches, errors logged but not handled, inconsistent error shapes across modules, missing structured logs on critical paths.

6. **Security and tenant hygiene**: hardcoded secrets, missing input validation at trust boundaries, permissive auth or CORS, anything that could leak data across tenants or compositions.

7. **Dependency and config debt**: CVEs, unused deps, duplicate deps doing the same job, env var sprawl (referenced but undocumented, defaults inconsistent across environments).

8. **Test debt on critical paths only**: high-churn modules with no behavior tests, tests that assert implementation rather than behavior, skipped tests. No coverage worship; only flag gaps where a regression would matter.

9. **Misleading content**: CLAUDE.md claims, comments, or ADRs that contradict the adjacent code. In an agent-built repo these actively poison future sessions, so treat them as debt, not paperwork. Also: performance hygiene where it bites (N+1 Firestore reads, sync work in async hot paths, unbounded listeners).

## Phase 3: Deliverable

Write to `ARCHITECTURE_AUDIT.md` in the repo root:

- **Executive summary**: max 10 bullets, ranked by impact.
- **Architectural mental model**: the system as it actually is.
- **Findings table**: `ID | Category | File:Line | Severity (Critical/High/Medium/Low) | Effort (S/M/L) | Description | Recommendation`. Aim for 30–80 findings; padding past that is noise.
- **Top 5 "if you fix nothing else, fix these"**: with concrete diff sketches or refactor outlines, not vague advice.
- **Quick wins**: Low effort × Medium+ severity, as a checklist.
- **Things that look bad but are actually fine**: calls you considered flagging and chose not to, with reasoning. **This section is required.** If it's empty, you didn't look hard enough.
- **Open questions for the maintainer**: things you couldn't tell were debt vs. intentional.

## Rules

- Audit only. Do not modify code. Each approved finding is fixed later in its own session or worktree.
- Cite `file:line` for every concrete finding.
- If unsure whether something is debt or intentional, put it in open questions; don't assert.
- Don't recommend rewrites. Recommend specific, scoped changes.
- Don't pad. If a category has nothing material, write "Nothing material" and move on.
- Every finding names its concrete cost (see operating principles).

## Tooling (TS/JS stack)

Run per package, in parallel where possible: `npm audit`, `npx knip` (dead exports), `npx madge --circular` (circular deps), `npx depcheck` (unused deps), `tsc --noEmit` (type drift). Fold results into findings; tool output without interpretation is not a finding. If a tool isn't installed, note it and move on. Don't install dev tools globally without permission.

## Large repo: subagents

If the repo is >50k LOC or has 3+ top-level packages (ekoa-mono qualifies), dispatch subagents in parallel, one per package (`ekoa-core`, `ekoa-platform`, `ekoa-data`), each scoped to Phase 2B with the citation requirement and a 200-finding cap. Keep Phase 2A in the main agent: invariants live at the boundaries between packages and need the cross-package view. The main agent merges, dedupes, and ranks.

## Repeat-run mode

If `ARCHITECTURE_AUDIT.md` already exists, read it first. Mark resolved findings `RESOLVED`, update stale ones, and tag new findings `NEW`. The audit is a living ledger: successive runs diff against it instead of relitigating.

---

Adapted from [ksimback/tech-debt-skill](https://github.com/ksimback/tech-debt-skill) (MIT). Ekoa invariants, over-engineering dimension, and agent-codebase reframing added; human-readability dimensions and non-TS tooling removed.
