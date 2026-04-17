---
name: status
description: Print current Architectus plugin state — version, subagents, skills, project classifier presence, memory-compiler state, active strike counts. Invoke with /architectus:status. Use when you want visible proof the plugin is active or to get a quick project snapshot.
allowed-tools: Read, Bash(cat*), Bash(ls*), Bash(jq*), Bash(test*), Bash(/Users/ggomes/.claude/architectus/scripts/strikes-util.sh*)
effort: low
disable-model-invocation: true
---

# Architectus Status

Print a compact status block describing the plugin's current state in this session. This is the canonical "am I working?" check — it runs as a normal assistant response, so its output is visible in the transcript.

## Steps

1. **Version.** Read `/Users/ggomes/.claude/architectus/.claude-plugin/plugin.json` and extract `version` via jq.
2. **Subagents.** List argus, mercurius, explorator — read each `/Users/ggomes/.claude/architectus/agents/<name>.md` frontmatter to confirm the file exists and report its `model` and `effort`.
3. **Skills.** List the names under `/Users/ggomes/.claude/architectus/skills/` (one directory per skill).
4. **Project classifier.** Check `.claude/project-classifier.md` in the current project. Report present / missing and the Default Minimum Tier line if present.
5. **Strikes.** Run `bash /Users/ggomes/.claude/architectus/scripts/strikes-util.sh list`. Report the count of active issues plus any with strikes ≥ 3.
6. **Memory compiler.** Check `~/.claude/memory-compiler/pyproject.toml` — report populated vs. empty.
7. **Classifier hook liveness.** Note that every user prompt carries a `<architectus-tier>` block via the UserPromptSubmit hook; mention the current session tier if you can see it from the most recent injection.

## Output format

Emit exactly this structure (no emoji, no decoration):

```
architectus v<version>  [enabled]

subagents:
  argus       <model> <effort>
  mercurius   <model> <effort>
  explorator  <model> <effort>

skills (plugin-scoped, namespace /architectus:):
  heartbeat, reclassify, rootcause, plan-with-testing, quality-gate, status

project:
  cwd:           <PWD>
  classifier:    <present — T<n> floor | missing>
  strikes:       <active count> (<escalate count> at >= 3)
  memory-comp:   <populated | empty>

hooks fire: UserPromptSubmit (every prompt), SessionStart (startup/resume/clear/compact), Stop
```

If any check fails (file missing, script errors), show `ERROR` in that line with a one-sentence reason. Do not silently drop a section.

Keep the whole output under 20 lines. This is a status snapshot, not a dashboard.
