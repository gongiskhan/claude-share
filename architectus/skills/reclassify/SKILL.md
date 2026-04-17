---
name: reclassify
description: Manually override the current tier classification. Use when the deterministic UserPromptSubmit classifier under- or over-estimated the task. Invoke with /architectus:reclassify T5 optional-reason, or /architectus:reclassify down to T2 etc.
allowed-tools: Bash(mkdir -p*), Bash(sh -c*), Bash(printf*), Bash(cat*), Bash(echo*)
effort: low
argument-hint: "<T1-T7> [reason]"
disable-model-invocation: true
---

# Reclassify

Override the current tier. The classifier's `<architectus-tier>` block from the last turn is **not** authoritative once you run this skill — the new tier is.

## Arguments

- `$0` — target tier, `T1` through `T7` (with or without the leading T)
- `$ARGUMENTS` after the first token — free-text reason, logged

## Steps

1. **Validate target.** Strip any leading `T` from `$0`. The remainder must be an integer 1–7. If not, abort with a one-line error and stop.
2. **Emit the override block.** Output exactly this, with the right tier filled in:

   ```
   <architectus-tier source="manual" tier="T<n>" effort="<effort>" retry="false">
   ROUTING: <hint for this tier — see table below>
   <ultrathink line, only if tier >= 4>
   </architectus-tier>
   ```

   | Tier | Effort | Hint | ultrathink? |
   |------|--------|------|-------------|
   | T1 | low | trivial — answer directly | no |
   | T2 | low | mechanical — implement directly; /simplify before done | no |
   | T3 | medium | brief plan, implement, /simplify before done | no |
   | T4 | high | /architectus:plan-with-testing; Argus validates; /architectus:quality-gate before done | yes |
   | T5 | high | /architectus:plan-with-testing with ultrathink; Argus mandatory | yes |
   | T6 | max | /architectus:plan-with-testing; engage Explorator first; Argus mandatory | yes |
   | T7 | max | fresh architectural planning; Explorator first | yes |

3. **Log the override.** Append a JSONL line to `.claude/architectus/tier-log.jsonl` (create the directory if missing):

   ```bash
   mkdir -p .claude/architectus
   printf '{"ts":"%s","tier":"T%s","reason":"%s"}\n' "$(date -u +%FT%TZ)" "<n>" "<reason, default empty>" >> .claude/architectus/tier-log.jsonl
   ```

4. **Confirm** in one line: `Tier set to T<n>.`

## Behavior note

Treat the new tier as authoritative for the remainder of the task. The next user turn will get a fresh classification from the hook — if the user keeps typing prompts that would classify lower, your responsibility is to keep operating at the manually-set tier until the task completes, then let the hook resume control.
