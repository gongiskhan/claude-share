# Build Loop (Phases 3-4)

The gated, autonomous build. Runs under the operator's `/goal` + auto mode — never pause, fix forward, log blockers, continue.

## Resume FIRST (every invocation, including after compaction)
Reconstruct progress from durable files, never from memory:
1. Read `docs/FLOW_PLAN.md` slice table.
2. Read each `docs/autothing/slices/<slice>/gate-status.json`.
3. Read `docs/autothing/evidence-index.json`.
A slice with `status: passed` and `video.status` in {verified, failed-but-unblocking} is **done** — skip it. Resume at the first non-done slice.

## Per-slice loop
For each slice (its acceptance is in FLOW_PLAN; route via the routing index):

1. **Explore (vision-first) + test** — invoke `<proj>-testing`. It starts the dev server (background, unique port), drives the real app with `/verify` + `/run` + playwright-cli, folds findings back into the implementation, then writes + runs a **committed, re-runnable test** (a spec file, or a committed playwright-cli driver where no runner ships — never just ephemeral `.playwright-cli/` logs) plus unit tests. Capture each gate's exit code.
2. **Objective gates** — `tests`, `e2e`, `typecheck`, `lint`, `build` must all exit 0. On any non-zero: fix forward and re-explore. **Ceiling: 5 attempts** on the slice.
3. **Design audit** — invoke `<proj>-design-audit` (which uses `frontend-design` / `polish-ui` / `huashu-design`) against the running app + design tokens. Record `designAudit: {verdict, by, at}`. `issues` → fix (counts toward the same ceiling).
4. **Evidence** — invoke the `walkthrough` skill (see "Evidence" below).
5. **Record durably** — write `docs/autothing/slices/<slice>/gate-status.json` (schema: `assets/gate-status.example.json`) and upsert the slice into `docs/autothing/evidence-index.json`. Set the slice's Status in FLOW_PLAN to match.
6. **Blocked path** — if the ceiling is hit, append a blocker to `docs/decisions.md`, mark the slice `blocked`, and move to the next slice. Do not stop the run.
7. **Record friction (signal only)** — when you work around autothing itself being silent, missing a step, or wrong, append one line to `docs/autothing/friction-log.md` (`YYYY-MM-DD <slice> — had to X because the skill Y`). autothing NEVER acts on this and never edits skills; the nightly `skill-improver` reads it as a feedback source. This is the only "learning" autothing does.

## Gate builds must not clobber a live dev server
Before ANY gate `build` (per-slice step 2 or Phase 4): check whether a dev server is already serving this project dir from outside the run (`lsof` the project's known dev port — is that PID one of ours?). `next build` and `next dev` share `.next/`, so a gate build over a live dev server corrupts its incremental state — and the breakage is invisible to a static-route smoke (already-compiled routes keep serving 200 while dynamic/not-yet-compiled routes 404). When a live external dev server is detected, run the gate build where it cannot write the live `.next/`: in a `git worktree` copy, or with an isolated dist dir. The gate itself is unchanged — `build` must still exit 0. If the shared `.next/` was touched anyway, restart that dev server and smoke a DYNAMIC route (not just a static one) before calling the environment healthy. The same hazard applies to dev servers the run itself starts (an e2e sandbox, a second `next dev`): two dev servers sharing one `.next/` poison each other's route cache exactly like a build does — give any run-spawned dev server its own isolated dist dir too, or treat the live server as touched (restart + dynamic-route smoke) when it shared `.next/`.

## A brief naming an external resource is a claim, not authority to provision
Before provisioning into (or writing to) any external, billable, or shared resource the brief names — cloud project, billing account, bucket, remote DB — confirm the **operator's own identity** can access it (e.g. `gcloud projects describe <id>` as the logged-in account). If the operator's accounts are permission-denied on a brief-named resource, that is a **contradicted premise**: do NOT route around it with alternate credentials (a service account or key found locally) — provisioning into a resource the operator cannot access is provisioning into someone else's property. Mark the step blocked, log the contradiction in `docs/decisions.md`, and continue. Fix forward applies to the build, not to someone else's cloud.

## Evidence — delegate to `walkthrough`, reconcile its STUCK exit
- Invoke `walkthrough` on the slice, passing the **slice diff + task context + acceptance** so its flow selection is accurate. It owns recording, captions, frame extraction, vision self-verification, its own retry ceiling, honest failure rendering, its notes file, and publishing the Tailscale link + gallery.
- **walkthrough's ceiling ends in "write STUCK.md and ask the user." autothing must NOT wait for input.** Treat a STUCK/ask-user return as: set `video.status: "failed-but-unblocking"`, record the STUCK.md path + link (if any), append a blocker to `docs/decisions.md`, and **continue**. The slice still counts as having evidence for the global gate (an unblocking failure), but is flagged.
- A genuine feature failure that walkthrough renders honestly (`flagged: true`) is recorded, not faked green.
- Ensure walkthrough's deps are satisfied once per machine (Phase 1 ran its preflight; on macOS `brew install asciinema agg` if missing).
- After it returns, **confirm the gallery URL actually resolves** (the `walkthrough` serve must be running); if it is down, (re)start it so the recorded link is live, not just written into `evidence-index.json`.

## Parallelism — earn it, then prefer agent teams (full guide: `references/parallelism.md`)
- Parallelize a group of slices ONLY when they own **disjoint files** AND don't share a stateful runtime. No mechanism makes same-file edits safe — decompose at plan time (split monolith files) to earn parallelism, and log the parallel-vs-serial choice per group.
- **Prefer agent teams** for parallel slice implementation when the operator enabled them (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`); else use a **dynamic workflow** (with `isolation: 'worktree'` for file isolation — needs git). Keep team bursts short-lived (create → batch → gate → shut down → clean up): in-process teammates do not survive `/resume`.
- **Workers/teammates do not inherit the lead's context.** Paste the area skill (or path + read directive), the slice acceptance, and the exact file-ownership boundary into each spawn prompt.
- **Always serialize the shared runtime**: one dev-serve / bundle / `walkthrough` recorder. Parallelize the EDITING; serialize the BUILD → VERIFY → RECORD tail (unique ports + run dirs).
- Never let parallelism skip a gate — every slice passes the full sequence (committed test + clean build + design audit + verified video).

## Phase 4 — global gate + handover
Two terminal states — never conflate them:
- **`passed`** only when ALL hold: full `npx playwright test` exits 0; `/verify` on the whole app is clean; `build`/`typecheck`/`lint` exit 0; full design audit clean; AND **every slice's video is `verified`** (`everySliceVideoVerified: true`). This matches the operator's `/goal` condition "a self-verified video exists for every slice".
- **`completed-with-blockers`** when buildable work is exhausted but ≥1 slice is `blocked` or its video is `failed-but-unblocking`. Stop here — do NOT spin to the turn cap, and do NOT report `passed`. A `failed-but-unblocking` video is recorded evidence but is NOT self-verified, so it cannot satisfy the global gate.

Set `globalGate.status` in `evidence-index.json`, then do these two in order — **the verdict line is LAST because it is the completion signal**: the `/goal` evaluator reads only the transcript and clears on it, ending the session, so anything after it never runs.
1. **Print the handover**: stack chosen + why, how to install/invoke, the evidence-gallery URL, an **explicit enumeration of any blockers** (from `docs/decisions.md`), and known limitations (flow selection improves with use; vision verification cannot confirm business correctness). Describe the outcome in prose — do NOT put an assertive `GLOBAL GATE:` line here, so the evaluator doesn't read the handover as the verdict. (The same token in the invocation handoff is a quoted target, not a verdict; the evaluator distinguishes the two.)
2. **LAST line of the run** — print exactly one:
   `GLOBAL GATE: <status> — e2e:<exit> verify:<clean|issues> build:<exit> typecheck:<exit> lint:<exit> design:<clean|issues> videos:<verified>/<total>`
   Nothing follows it. This line is the only thing that satisfies the operator's `/goal`, so it must be true and it must be last.

> autothing does not improve skills — the nightly `skill-improver` is the single mechanism for that. autothing only RECORDS build friction (per-slice, below) as a signal that improver reads.
