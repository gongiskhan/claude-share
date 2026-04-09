## WORKTREE SAFETY (CRITICAL)
- **When working inside a git worktree (`.claude/worktrees/*/`):** NEVER checkout, commit to, push, rebase, merge into, or otherwise modify the `main` branch or the branch currently checked out in the parent repository (the project root holding the `.claude/` folder). Worktrees have their own isolated branch -- all work MUST stay on that worktree branch. Before any git operation, confirm you are on the worktree's own branch. If in doubt, run `git branch --show-current` and verify it starts with `worktree-`. Violating this guardrail risks corrupting the parent repo's working state.

---

- ALWAYS check /Users/ggomes/.claude/skills to look for skills that may be be aplicable to the user prompt before responding
- When making significant changes make sure to document it in CLAUDE.md and make sure it is kept always up to date. This includes adding/updating/removing significant parts of code (but keep the file clean so remove what's not there anymore). If CLAUDE.md does not exist on a project always create it.
- whenever I mention sshot I mean you should go to the ~/sshot folder and use the latest image file there (the most recent one added) as reference
- Don't act sycophantic. Don't assume everything the user say is correct unless is in the context of a very specific domain that the user is bound to know more than any information you could have been trained on or found online.
- Never use emoji characters in UI code (HTML, CSS, JS). Use text labels, SVG icons, or icon
  fonts instead. Emojis render inconsistently across platforms and often look unprofessional.

## Obsidian

- **Vault location:** `/Users/ggomes/Documents/Obsidian Vault`
- **Account:** goncalo.p.gomes@gmail.com
- **Obsidian CLI:** Not available (requires Catalyst license). Write files directly to the vault folder instead.
- **Note structure:** Uses `Projects/<ProjectName>/` folder hierarchy with sub-folders for Architecture, Services, Frontend, Deployment.
- **Conventions:**
  - YAML frontmatter with `tags`, `parent` (wikilink back to hub note), `status`, `created`
  - Hub note per project (e.g., `Ekoa.md`) with table linking to all sub-notes
  - Wikilinks (`[[Note Name]]`) for cross-referencing between notes
  - Tables for structured data (routes, files, stores)
  - Code blocks for commands and examples
  - No emoji in notes
- **Current content:** Ekoa project fully documented in `Projects/Ekoa/` (17 notes covering architecture, routes, services, agents, frontend, stores, hooks, translations, standalone mode, electron, GCE deployment, scripts, testing, guardrails, tech stack, shared types)
- **When asked to document in Obsidian:** Write markdown files directly to the vault folder. Obsidian picks up changes instantly. Use the Obsidian CLI skill if CLI is available, otherwise write files directly.

## Knowledge Base

- **Location:** `~/.claude/memory-compiler/knowledge/`
- **Symlinked into Obsidian vault** at `Knowledge Base/` for graph view browsing
- **Auto-compiled** from conversation transcripts via Claude Code hooks (SessionStart, SessionEnd, PreCompact)
- **Manual compile:** `cd ~/.claude/memory-compiler && uv run python scripts/compile.py`
- **Query:** `cd ~/.claude/memory-compiler && uv run python scripts/query.py "question"`
