---
name: autothing-walkthrough
description: Record self-verified video evidence that the current change works by invoking the walkthrough skill with the change's diff and acceptance context, then surface the scrubbable link. In an autothing build a walkthrough STUCK/ask-user return becomes failed-but-unblocking and the run continues; standalone it records the walkthrough and reports (including a STUCK). Use for "record a walkthrough/demo of this", "capture proof it works", or as the evidence step of a build. Delegates to the walkthrough skill (never rebuilds it).
---

# autothing-walkthrough

Records self-verified evidence that the current change works, by invoking the **`walkthrough`** skill (never rebuilding it) with the change's context, and surfacing the scrubbable link. The evidence step of an autothing build, and a standalone "show it working" recorder.

## What it does
Invoke **`walkthrough`** on the change, passing the **diff + task context + acceptance** so its flow selection is accurate. walkthrough owns recording, captions, frame extraction, vision self-verification, its own retry ceiling, honest failure rendering, its notes file, and publishing the Tailscale link + gallery.
- For a **terminal/CLI** deliverable, evidence is an asciinema/PTY capture of the real flow (asciinema + agg ship in walkthrough's preflight) — a browser walkthrough does not fit one.
- For an **event-streamed / dynamic** flow (escalation, an agent run, a live status/progress stream), the capture MUST be a LIVED end-to-end run of that exact flow, not a mechanism proxy or a partial stand-in.
After it returns, **confirm the gallery URL actually resolves** (the serve must be running); (re)start it if down, so the recorded link is live.

## Loop role + output
- **In an autothing build:** a walkthrough **STUCK/ask-user return becomes `video.status: failed-but-unblocking`** — record the STUCK.md path + link (if any), append a blocker to `docs/decisions.md`, and **CONTINUE**; never wait for input. A genuine feature failure that walkthrough renders honestly (`flagged: true`) is recorded, not faked green. Record `video` in the slice gate-status.
- **Standalone:** record the walkthrough and report the link (rendering a STUCK honestly, not as success).

Print the evidence status in the lead context; a build's terminal verdict counts it in `videos:<verified>/<total>`.
