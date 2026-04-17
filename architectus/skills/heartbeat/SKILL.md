---
name: heartbeat
description: Self-check during long autonomous work. Runs every 40 minutes via /loop. Reviews .claude/tasks.md, git status, strike counter. Flags unresolved issues. Invoke with /architectus:heartbeat or the scheduled loop. Pass --deep to also call advisor().
allowed-tools: Read, Bash(git status*), Bash(git log*), Bash(/Users/ggomes/.claude/architectus/scripts/strikes-util.sh*), Bash(ls*), Bash(cat*)
effort: low
argument-hint: "[--deep]"
---

# Heartbeat

Pulse check. Do NOT perform corrective action — just surface state.

## Steps

1. **Tasks** — if `.claude/tasks.md` exists, read it. List unchecked top-level items under `## Active`. If 0 unchecked, say so.
2. **Git** — run `git status --short` and `git log --oneline -5`. Note any uncommitted drift or unusual state (merge in progress, detached HEAD).
3. **Strikes** — run `bash /Users/ggomes/.claude/architectus/scripts/strikes-util.sh list`. For each active issue with strikes ≥ 3, recommend `/architectus:rootcause <slug>` to the user.
4. **Classifier** — check whether `.claude/project-classifier.md` exists. If not, flag it and recommend generating via `/architectus:plan-with-testing`.
5. **Memory compiler** — check `~/.claude/memory-compiler/pyproject.toml`. Report populated vs. empty in one word.
6. **Deep mode** — if `$ARGUMENTS` is `--deep`, call `advisor()` with a prompt asking "given the above state, is there anything I'm missing about this session's direction?"
7. **Report** — one paragraph of status plus a bulleted list of concerns. If everything is clean, emit exactly:
   ```
   Heartbeat ok
   ```
   on a single line so the loop stays low-noise.

## Output format

```
Heartbeat @ <ISO timestamp>
Tasks: <count active> / <summary>
Git: <branch> / <uncommitted files count> / <head commit>
Strikes: <count active issues with strikes ≥ 3>
Classifier: <present | missing>
Memory-compiler: <populated | empty>

Concerns:
- <item>
- <item>

Recommended next action: <one concrete step or "none">
```

If clean:

```
Heartbeat ok
```

ultrathink — only if `$ARGUMENTS` is `--deep`; otherwise this is a low-effort check.
