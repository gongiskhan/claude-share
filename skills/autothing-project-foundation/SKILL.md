---
name: autothing-project-foundation
description: Idempotently audit and scaffold a project's Claude-Code foundation — a lean root CLAUDE.md with a routing index, living /docs (product-overview, architecture, conventions, governance, decisions), per-area skills under .claude/skills/, and git init. Read-only DETECT pass produces a gap list; GENERATE creates only the missing/partial pieces and NEVER rewrites an existing canonical file. Use to set up a new or existing repo for agent-driven work, or to audit what foundation a repo is missing — without running a full build. autothing calls this as its Phase 0/1; usable directly. Do NOT use to plan build slices (that is the planning/FLOW_PLAN step) or to implement features.
---

# autothing-project-foundation

Sets up (or audits) the per-project foundation that lets agents work a repo coherently: a lean root `CLAUDE.md` that routes to area skills, a small set of living `/docs`, the warranted area skills inside the project's `.claude/skills/`, and a git repo. **USER-scope skill; everything it writes is PROJECT-scope** (inside the target repo).

`autothing` invokes this as its Phase 0 (detect) + Phase 1 (generate) before building. Use it directly any time you want to bootstrap or audit a repo's foundation without launching a build.

## Two steps

### 1. Detect (read-only — never edits)
Run the manifest detection in `references/manifest.md`. Produce a **gap list** — `present | missing | partial` per manifest element — plus a role map for any existing docs and any refresh recommendations. Detection only reads; it proposes, it does not change files.

### 2. Generate the gaps ONLY
Per `references/generation.md`, create **only** what detection marked missing/partial. Delegate; do not reinvent.
- **Git first:** if the repo is not a git work tree, `git init` + an initial commit before anything else — flow-selection diffs (`walkthrough`), workflow `isolation: 'worktree'`, and rollback all depend on it.
- New/empty repo: seed via `deep-research` (product brief) → `frontend-design`/`huashu-design` (prototype + design tokens). Skip for an existing codebase.
- Generate missing `/docs` from `assets/docs/`, the lean `CLAUDE.md` from `assets/CLAUDE.md.template` (routing index filled with the REAL generated skill names), and author the area skills into `<project>/.claude/skills/<proj>-<area>/` from the exemplar `assets/area-skills/testing.SKILL.md`. Area skills are NOT optional when the project will be built by parallel teammates/workers — they load these, not the lead's context.

## The area-skill set
Author into the **target project** (`<proj>-<area>`), each from the project's real commands/paths — never a generic copy. Include the first five always; add the last two when the stack warrants. Full table + authoring rules in `references/generation.md`:

`<proj>-planning` · `<proj>-architecture` · `<proj>-testing` · `<proj>-design-audit` · `<proj>-governance` — and `<proj>-mobile` / `<proj>-data-api` when relevant.

**Verbs in the skill, nouns in the doc.** Each SKILL.md references its backing doc by path and never duplicates it; each description states when to trigger AND an explicit "do NOT use for … (that is `<other skill>`)" clause to prevent collisions.

## Non-negotiables — idempotent + non-clobbering
- **Missing element → create it** from the template/exemplar.
- **Existing canonical file → NEVER rewrite or refactor it.** Not CLAUDE.md, not any /doc the user already wrote. The only permitted edits to existing files are **additive and clearly-owned**: append a `## Routing index` to CLAUDE.md *if absent*, append to `docs/decisions.md`, or add a **new** area-skill / nested CLAUDE.md (creating files ≠ editing existing ones).
- **Staleness is REPORTED, never acted on.** Long CLAUDE.md, stale doc, overlapping skill descriptions → write to `docs/REFRESH-RECOMMENDATIONS.md` and continue. Slimming/reorganising an existing file is a recommendation, not an action — never do it unattended.
- For an existing repo, a role already covered by a differently-named file gets a **pointer** in CLAUDE.md's reference list, not a duplicate.

## Files
- `references/manifest.md` — the 6-element manifest, the /docs role map, idempotency rules, staleness reporting, and what the gap list contains.
- `references/generation.md` — generating /docs + the lean CLAUDE.md, new-project bootstrap, and authoring the area-skill set (with the full table).
- `assets/CLAUDE.md.template` — the lean root CLAUDE.md skeleton (summary, critical rules, design source of truth, definition of done, canonical @imports, routing index, path-scoped guidance).
- `assets/docs/` — skeletons for product-overview, architecture, conventions, governance, decisions.
- `assets/area-skills/testing.SKILL.md` — the worked area-skill exemplar to adapt (vision-first explore → write+run tests → report exit codes).
