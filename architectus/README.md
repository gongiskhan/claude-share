# Architectus

Single-session autonomous development plugin. One Claude session drives planning and implementation; three context-isolated subagents (Argus, Mercurius, Explorator) handle testing, image analysis, and codebase exploration. Successor to [Vitruvius](../vitruvius/) — same T1–T7 tier discipline, no tmux, no MCP channel server. Works in CLI and Claude Desktop.

## Install

Architectus ships as a plugin delivered by a local marketplace wrapper at `/Users/ggomes/.claude/architectus-marketplace/`. The plugin itself lives at `/Users/ggomes/.claude/architectus/` (the marketplace holds a `./architectus` symlink into that directory).

### One-time user-level install

From Claude Code (interactive):

```
/plugin marketplace add /Users/ggomes/.claude/architectus-marketplace
/plugin install architectus@architectus-local
```

Or from the shell:

```bash
claude plugin marketplace add /Users/ggomes/.claude/architectus-marketplace
claude plugin install architectus@architectus-local
```

Verify: `claude plugin list | grep architectus` should show `Status: ✔ enabled`.

### Per-project bootstrap

Once the plugin is installed, run the bootstrap in each project you want to use it in:

```bash
cd /path/to/your/project
bash /Users/ggomes/.claude/architectus/scripts/bootstrap.sh
```

Idempotent. Does:

- **Global (once):** registers the `architectus-local` marketplace and installs the plugin if either is missing (`claude plugin marketplace add` + `claude plugin install`).
- **Global (once):** installs `coleam00/claude-memory-compiler` into `~/.claude/memory-compiler/` via `git clone` + `uv sync`. Requires `git` and `uv` on `PATH`.
- **Per-project:** creates `.claude/architectus/`, `.claude/plans/`, `.claudeignore`, `.claude/tasks.md`, `.claude/architectus/strikes.json`. Warns if `.claude/project-classifier.md` is missing.

### Generate the project classifier

From inside Claude Code in the project:

```
/architectus:plan-with-testing
```

On first invocation in a project without a classifier, this skill generates one using the template at `templates/project-classifier.md`.

## Architecture

```
hooks/
  UserPromptSubmit  →  classify-prompt.sh  →  <architectus-tier> block
  SessionStart      →  session-start.sh    →  briefing + first-turn directives
    (startup, resume, clear matchers)
  SessionStart      →  post-compact.sh     →  heartbeat re-injection
    (compact matcher)
  Stop              →  stop-notify.sh      →  macOS notification

agents/
  argus             →  tester, sonnet, medium effort, never edits source
  mercurius         →  image analyst, sonnet, medium effort
  explorator        →  codebase cartographer, haiku, read-only

skills/
  /architectus:heartbeat          40-minute pulse; reads tasks, git, strikes
  /architectus:reclassify         manual tier override
  /architectus:rootcause          forked deep investigation for 3+ strike issues
  /architectus:plan-with-testing  plan with mandatory Testing Plan section
  /architectus:quality-gate       mandatory completion sequence for T4+

scripts/
  bootstrap.sh                per-project setup
  install-memory-compiler.sh  one-time global install of memory-compiler
  strikes-util.sh             manage per-project strikes.json
  notify.sh                   shared macOS notification helper

prompts/main-session.md       operating brief injected at SessionStart
templates/                    project-classifier, testing-plan, .claudeignore, tasks.md
state-schema/                 JSON Schema for strikes.json
```

## How it behaves

### Every prompt is classified

The `UserPromptSubmit` hook injects a `<architectus-tier>` block before Claude sees the prompt. Tier is derived from keyword rules plus floor rules (frustration keywords, compound asks, `!!!`, literal uppercase `NEVER`/`ALWAYS`/`WRONG`, project-classifier floor). T4+ adds the literal keyword `ultrathink` for extended thinking.

**Bypass:** prefix your prompt with `!` — the classifier exits silently and injects nothing. Use this for casual messages where you don't want a tier tag.

### Three-strike escalation

- Argus records a strike via `strikes-util.sh record-failure <slug> <reason>` on each `overall: fail`.
- `/architectus:quality-gate` checks the count. If ≥ 3 on the same slug, it stops patching and escalates to `/architectus:rootcause <slug>` in a forked context.
- `/architectus:rootcause` runs at max effort with `ultrathink`, reads the full failure history, calls `advisor()`, and returns a structured diagnosis with a proposed architectural fix.
- A `pass` from Argus clears the strike counter for the slug.

### Heartbeat

The SessionStart hook reminds the main session to run `/loop 40m /architectus:heartbeat` as its first action. Every 40 minutes thereafter, `/architectus:heartbeat` reviews `.claude/tasks.md`, `git status`, and the strike counter. It takes no corrective action — it surfaces state.

**Survives `/compact` at the scheduler level.** The post-compact hook re-injects a reminder. **Does not survive `/clear`** — the SessionStart `clear` matcher re-injects the directive and the model re-issues `/loop 40m /architectus:heartbeat`.

### Memory

Two layers, both required:

1. **Claude Code native auto-memory** — `autoMemoryEnabled: true` globally. Per-project `~/.claude/projects/<slug>/memory/MEMORY.md` indexes.
2. **Memory compiler** — `~/.claude/memory-compiler/` captures transcripts on Stop/PreCompact and maintains structured knowledge articles. The global `~/.claude/settings.json` hooks for SessionStart/SessionEnd/PreCompact fire into it. Installed by `bootstrap.sh`.

Disable the compiler layer by `rm -rf ~/.claude/memory-compiler/`. The guarded hooks in global settings will then no-op safely.

## Remote control

Architectus does not ship a `/remote-control` skill. For phone-driven re-entry into a session, use the built-in `RemoteTrigger` tool plus your existing phone-push setup.

## Files to know

| Path | Purpose |
|------|---------|
| `.claude-plugin/plugin.json` | Plugin manifest |
| `hooks/hooks.json` | Hook declarations |
| `hooks/scripts/classify-prompt.sh` | Tier classifier |
| `hooks/scripts/session-start.sh` | SessionStart briefing |
| `hooks/scripts/post-compact.sh` | Post-compaction re-injection |
| `hooks/scripts/stop-notify.sh` | macOS completion notification |
| `agents/argus.md` | Tester subagent |
| `agents/mercurius.md` | Image analyst subagent |
| `agents/explorator.md` | Codebase cartographer subagent |
| `skills/<name>/SKILL.md` | Five bundled skills |
| `prompts/main-session.md` | Operating brief injected at SessionStart |
| `scripts/bootstrap.sh` | Per-project setup |
| `scripts/strikes-util.sh` | Manage strikes.json |

## Troubleshooting

**`/hooks` doesn't list Architectus entries.** Plugin probably isn't installed or enabled. Check with `claude plugin list | grep architectus`. If missing, run the install commands under `## Install` above. If present but disabled, run `/plugin enable architectus@architectus-local` inside Claude Code.

**Every prompt shows a tier tag, including "hello".** Working as designed. Prefix with `!` to bypass.

**`ultrathink` keyword appears in the tier block but extended thinking doesn't kick in.** Confirm the session model supports extended thinking (Opus 4.x family does). Lower-tier models will ignore the keyword.

**Argus refuses with "No Testing Plan provided".** The prompt to `Agent(subagent_type="argus", ...)` must include the `## Testing Plan` section verbatim. `/architectus:quality-gate` handles this automatically.

**`bootstrap.sh` fails on memory-compiler install.** Check `uv` is on `PATH` (`command -v uv`). Install from https://docs.astral.sh/uv/. The rest of Architectus still works without memory-compiler; the bundled hooks in `~/.claude/settings.json` are guarded and will no-op until the compiler directory is populated.

## Caveats

- Plugin paths are hardcoded to `/Users/ggomes/.claude/architectus/`. Moving the plugin requires search-and-replace in hook scripts, skills, and agents.
- Argus's model is `sonnet`; Mercurius is `sonnet`; Explorator is `haiku`. Plugin scope supports `model` and `effort` frontmatter per the Claude Code docs.
- Plugin-scope subagents silently ignore `hooks`, `mcpServers`, and `permissionMode`. None of the three subagents use those.
- `/architectus:rootcause` uses `context: fork` + `agent: general-purpose` at `effort: max`. It does not share history with the parent session — the skill body carries everything it needs to investigate.
