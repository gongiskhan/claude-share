# Vitruvius

A Claude Code plugin that packages a multi-session autonomous development workspace. Named after the Roman architect who wrote *De Architectura* -- the original treatise on how to build things properly.

Vitruvius launches four Claude Code sessions in a tmux 2x2 grid, each with a specialized role, coordinated via MCP channel messaging. One command (`ct`) gives you an orchestrated team that classifies tasks, plans, implements, and validates autonomously.

## Architecture

### The Four Sessions

| Pane | Agent | Role | Model | Effort |
|------|-------|------|-------|--------|
| Top-left | **Pericles** | Orchestrator | sonnet | medium |
| Top-right | **Spartacus** | Planner & Implementer | opusplan | high |
| Bottom-left | **Maximus** | T6-T7 Powerhouse | opus[1m] | max |
| Bottom-right | **Argus** | Validator | sonnet | medium |

**Pericles** (Orchestrator) receives every task from the user. He classifies it into a tier (T1-T7), synthesizes a structured brief, and routes it to the appropriate agent. He never writes code -- read-only operations only.

**Spartacus** (Worker) handles T2-T5 tasks. He writes a structured plan before implementing (T3+), runs `/simplify` after implementation, and reports back to Pericles. Runs on `opusplan` -- Opus for planning, Sonnet for execution.

**Maximus** (Powerhouse) handles T6-T7 tasks only: critical architectural changes and new projects/rewrites. Runs on Opus at max effort with 1M context. Does both planning and implementation. For T7, always plans from scratch.

**Argus** (Validator) is the final quality gate. He executes Testing Plans step-by-step, captures evidence for every assertion, and reports pass/fail per step. He never edits production code.

### Tier System (T1-T7)

| Tier | Name | Description | Agent |
|------|------|-------------|-------|
| T1 | TRIVIAL | Questions, lookups, status checks | Pericles (direct) |
| T2 | SIMPLE | Single-line mechanical changes | Spartacus |
| T3 | MODERATE | Single-component bug fix or small feature | Spartacus (plan first) |
| T4 | SIGNIFICANT | Multi-file, compound tasks, retries | Spartacus + optional Argus |
| T5 | MAJOR | New module, 10+ files, architectural touch | Spartacus + Argus |
| T6 | CRITICAL | Architectural change, high risk | Maximus + Argus |
| T7 | NEW PROJECT | Entire new project or full rewrite | Maximus + Argus |

Automatic escalation triggers bump the tier when frustration signals, compound tasks, or retry patterns are detected.

### Channel Protocol

Sessions communicate via MCP channel messaging. Each session runs a channel server (`channel/server.mjs`) that bridges HTTP and MCP notifications. Agents use the `send_to` tool to message peers:

```
mcp__ct-channel__send_to({ target: "spartacus", text: "<structured brief>" })
```

All coordination flows through Pericles -- agents never message each other directly (except to report back to Pericles).

### Project Classifier

Each project gets a `.claude/project-classifier.md` file (auto-generated on first launch) that tells Pericles the project's tech stack, size, minimum tier floor, dev environment commands, and testing setup. This calibrates routing decisions per project.

## Installation

### Prerequisites

- macOS (notification hooks use macOS-specific tools)
- Node.js >= 18
- tmux
- jq
- Claude Code CLI (`claude`)
- `terminal-notifier` (optional, for notifications): `brew install terminal-notifier`

### Install

```bash
# Clone or place the vitruvius directory
git clone <repo-url> ~/.claude/vitruvius

# Run the installer
bash ~/.claude/vitruvius/scripts/install.sh

# Reload your shell
source ~/.zshrc
```

The installer:
1. Detects your node binary
2. Writes `~/.claude/vitruvius.env` with paths
3. Installs channel server npm dependencies
4. Creates runtime directories (`~/.claude/bus/`, `~/.claude/workspaces/`)
5. Adds `ct` function loader to your `.zshrc`

### After Plugin Updates

Re-run the installer to update paths:

```bash
bash ~/.claude/vitruvius/scripts/install.sh
```

## Usage

### Launch a Workspace

```bash
# New workspace for current directory
ct

# New workspace for a specific project
ct ~/dev/my-project

# Continue previous sessions
ct -c ~/dev/my-project
ctc ~/dev/my-project    # shorthand
```

This creates a tmux session named `ct-<project-slug>` with four panes. Talk to Pericles (top-left pane) -- he routes everything.

### Tmux Navigation

- `Ctrl-b + arrow keys` -- move between panes
- `Ctrl-b + z` -- zoom/unzoom current pane
- `Ctrl-b + d` -- detach (sessions keep running)
- `ct -c <path>` -- reattach to existing session

### The Workflow

1. Type your task in the Pericles pane (top-left)
2. Pericles classifies and routes to the appropriate agent
3. Spartacus/Maximus plans, implements, runs `/simplify`
4. Argus validates with the Testing Plan
5. Pericles reports the final result

For quick tasks, prefix with `!` to bypass classification and have Pericles handle directly.

### Skills (In-Session Reference)

Within any Claude Code session, invoke these skills for quick reference:

- `/orchestrator` -- Pericles routing rules and tier table
- `/worker` -- Spartacus plan contract and quality gate
- `/powerhouse` -- Maximus T6-T7 protocols
- `/investigator` -- Argus testing protocol and report format
- `/classify` -- Full tier system with escalation triggers

## Directory Structure

```
vitruvius/
  .claude-plugin/plugin.json    Plugin manifest
  hooks/                        Stop notification hook
  skills/                       In-session reference cards
  channel/                      MCP channel server (inter-session messaging)
  templates/                    Project classifier + testing plan templates
  prompts/                      System prompts (loaded via --append-system-prompt-file)
  scripts/                      ct launcher, installer, notify utility
```

**Runtime directories** (outside the plugin, in `~/.claude/`):
- `workspaces/<slug>/state.json` -- port allocation, session count
- `bus/<slug>/channel.log` -- inter-agent message log
- `bus/<slug>/evidence/` -- Argus test evidence artifacts

## Customization

### Editing System Prompts

Modify files in `vitruvius/prompts/` to change agent behavior. These are loaded at session launch -- changes take effect on the next `ct` invocation.

### Adding Tier Overrides

Edit a project's `.claude/project-classifier.md` to add classification overrides:

```markdown
## Classification Overrides

- database migrations -> minimum tier 5: schema changes are high risk
- auth -> minimum tier 4: security-sensitive code
```

### Notification Sound

Edit `scripts/notify.sh` to change the alert sound or volume. The `-v 4` flag controls volume multiplier for `afplay`.
