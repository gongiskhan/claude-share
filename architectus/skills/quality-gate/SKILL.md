---
name: quality-gate
description: Mandatory completion sequence before declaring a T4+ task done. Runs /simplify, restarts dev env if needed, invokes Argus, handles strikes. Invoke with /architectus:quality-gate <issue-slug>.
effort: medium
argument-hint: "<issue-slug>"
disable-model-invocation: true
---

# Quality Gate

Run this sequence before declaring a T4+ task complete. Do not reorder.

## Steps

1. **/simplify** — invoke the `/simplify` skill on the set of changed files. Fix anything it flags. Rerun until clean.
2. **Restart dev env if needed.** If runtime code changed (not just docs, configs, or tests), consult `.claude/project-classifier.md` → "Dev Environment" section and follow the Restart strategy. Wait for the health check to pass before proceeding.
3. **Invoke Argus.** Spawn the Argus subagent with the Testing Plan from the current plan file and the issue slug:

   ```
   Agent(subagent_type="argus", prompt="""
   Testing Plan from .claude/plans/<slug>.md:
   <paste the ## Testing Plan section verbatim>

   issue_slug: $0

   Execute every step. Report structured results.
   """)
   ```

4. **Consume Argus's report.** It arrives as the Agent tool's return value in your context.
5. **On `overall: fail`:**
   - Record a strike: `bash /Users/ggomes/.claude/architectus/scripts/strikes-util.sh record-failure "$0" "<one-line reason taken from Argus's blocking_issues>"`
   - Read the new strike count: `bash /Users/ggomes/.claude/architectus/scripts/strikes-util.sh count "$0"`
   - If count ≥ 3: STOP. Do not attempt another patch. Escalate by running `/architectus:rootcause $0`. Report to the user that you're escalating.
   - If count < 3: plan a focused fix addressing Argus's specific failure. Do not re-read the whole codebase. Then re-run `/architectus:quality-gate $0`.
6. **On `overall: pass`:**
   - Clear strikes: `bash /Users/ggomes/.claude/architectus/scripts/strikes-util.sh clear "$0"`
   - Emit a single-paragraph completion summary to the user: what was done, where the evidence lives, which regression areas were checked.
7. **On `overall: partial`:** Treat as fail for strike purposes but note the passing steps in the user summary.

## Issue-slug discipline

- If `$0` is missing, derive one: `<current-git-branch>-<6-char-hash-of-first-60-chars-of-original-task-prompt>`
- Keep it stable across retries so strikes accumulate on the same slug
- Record the slug in the plan file's Context section so retries find the same one
