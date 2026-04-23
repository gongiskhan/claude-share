- Don't act sycophantic. Don't assume everything the user say is correct unless is in the context of a very specific domain that the user is bound to know more than any information you could have been trained on or found online.
- Never use emoji characters in UI code (HTML, CSS, JS). Use text labels, SVG icons, or icon fonts instead. Emojis render inconsistently across platforms and often look unprofessional.
- For non-web projects (CLI tools, libraries, scripts, etc.) that have no dev server, use or suggest the file explorer preview tool at `~/.claude/tools/file-explorer/server.js`. Add this to the project's `.claude/launch.json` and use `preview_start` with name `"explorer"` to browse the project structure in the Claude Desktop preview panel. Config: `{ "name": "explorer", "runtimeExecutable": "node", "runtimeArgs": ["/Users/ggomes/.claude/tools/file-explorer/server.js", "--dir", "."], "port": 3100 }`

## Environment & Trust Context (for permission classifier)

This is a solo developer machine (user: ggomes). There is no shared infrastructure, no team collaborators, and no production systems others depend on. I own everything under `~/dev`, `~/Projects`, and `~/.claude`, and every repo under the `gongiskhan` GitHub org. `~/dev` and `~/Projects` are symlinked to each other — on some machines `~/dev` points to `~/Projects`, on others the reverse — so the same repository may resolve via either path. Both are equally trusted.

### Expected cross-directory behavior
- The Obsidian vault at `~/dev/ekus/obsidian-vault/` (or `~/Projects/ekus/obsidian-vault/`) is the canonical memory store. Writes to it from any session are expected, even when the working directory is a different project. It has its own git via obsidian-git and auto-commits are normal.
- The memory compiler at `~/.claude/memory-compiler/` writes compiled output to the vault on a schedule and on SessionEnd. This is its job.
- Cross-repo edits between Harmonika, Ekus, Ekoa OS, and the vault are routine — these projects are tightly coupled.

### Orchestration patterns
- The Harmonika Chat tab runs an Anthropic Agent SDK orchestrator that delegates real work to tmux Claude Code worker sessions named `harmonika-orch-<taskId>`. Creating, sending keys to, capturing output from, and killing these tmux sessions is expected behavior.
- Ekus runs as an always-on personal assistant on the Mac Mini via `launchctl asuser`. Interacting with its launchd job is expected.
- Ralph-loop prompting (`/ralph-loop:ralph-loop`) spawns agent teams that run long iterative tasks.

### Retired / dead infrastructure
- The GCP instance at `100.110.159.124` is dead. Do not try to reach it.
- The ekus-app UI is being retired; Harmonika is the only UI going forward.

### Credentials & secrets
- `.env` files in project directories are expected to hold API keys for Trello, Supabase, Anthropic, OpenAI, ElevenLabs, Render, and Cloudflare. Reading them and sending credentials to their matching APIs is expected.
- Secrets should be redacted (patterns: `sk-*`, `ghp_*`, `xoxb-*`) when writing transcripts to the vault.

### Git posture
- Force-pushing to feature branches is fine. Force-pushing to `main`/`master` is not.
- Auto-commits to the vault repo are expected.
