---
name: worktree
description: Parallel development with Git worktrees. Use when user says "fork", "worktree" (to create a worktree and launch Claude Code in iTerm2), "merge" (to safely merge changes back to main), "update" (to merge main into the current worktree), or "remove/delete worktree" (to discard a worktree without merging). Handles both worktree merges and regular branch merges with the same careful approach.
---

# Worktree - Parallel Development

Create isolated worktrees for parallel development with Claude Code, then safely merge back to main.

## Storage Location

Worktrees are stored in the user's home directory:
```
~/.worktrees/<project-name>/wt-<worktree-name>
```

Example: `~/.worktrees/maestric/wt-auth-fix`

This keeps worktrees out of the project directory and organized by project.

## Port Convention

- **Main repo**: Uses fixed ports (UI: 3000, API: 3232)
- **Worktrees**: Each gets random ports (3000-4000 range) assigned at creation

This ensures worktrees don't conflict with main or each other. The `.ports` file in each worktree shows its assigned ports.

## Workflow Decision Tree

```
User says "fork" or "worktree" with a name
  -> Check if worktree already exists at ~/.worktrees/<project>/wt-<name>
    -> Yes: Resume Worktree workflow (find or create pane)
    -> No: Create Worktree workflow

User says "fork" or "worktree" without a name
  -> Ask for name, then follow above

User says "merge"
  -> Check if in worktree (.git is a file pointing to main repo)
    -> Yes: Merge Worktree workflow
    -> No: Merge Branch workflow (same principles apply)

User says "update"
  -> Check if in worktree (.git is a file pointing to main repo)
    -> Yes: Update Worktree workflow (merge main into worktree)
    -> No: Error - not in a worktree

User says "remove worktree" or "delete worktree"
  -> Remove Worktree workflow (discard without merging)
```

## Create Worktree

When user says "fork" or "worktree" and the worktree does NOT exist:

1. **Get worktree name** - Ask user for a short name (e.g., "auth-fix", "new-feature")

2. **Run create script**:
   ```bash
   ~/.claude/skills/worktree/scripts/create-worktree.sh <name>
   ```
   This creates `~/.worktrees/<project>/wt-<name>`, branch `wt-<name>`, and:
   - Copies all `.env*` files (preserving paths for monorepos)
   - Assigns random ports (3000-4000) for UI and API
   - Updates env files so UI connects to its own API
   - Creates `.ports` file with assigned ports

3. **Open in split pane**:
   ```bash
   ~/.claude/skills/worktree/scripts/open-in-pane.sh <worktree-path> "wt-<name>"
   ```
   Attempts tmux -> iTerm2 -> Zed, falls back to manual instructions.

4. **Confirm** - Tell user the worktree is ready and provide the path.

## Resume Worktree

When user says "fork" or "worktree" with a name that ALREADY exists:

1. **Check worktree exists**:
   ```bash
   PROJECT_NAME=$(basename "$(git rev-parse --show-toplevel)")
   WORKTREE_PATH="$HOME/.worktrees/$PROJECT_NAME/wt-<name>"
   [ -d "$WORKTREE_PATH" ] && echo "exists"
   ```

2. **Open new pane**:
   ```bash
   ~/.claude/skills/worktree/scripts/open-in-pane.sh <worktree-path> "wt-<name>"
   ```

3. **Report result** - Tell user the pane is ready and provide the path.

## Update Worktree

When user says "update" and current directory is inside a worktree:

**Use this to pull the latest changes from main into the worktree.**

1. **Verify in worktree**:
   ```bash
   # Check if .git is a file (worktrees have .git as file pointing to main repo)
   if [ -f .git ]; then
       echo "In worktree"
   else
       echo "Not in a worktree"
       exit 1
   fi
   ```

2. **Ensure clean state**:
   ```bash
   git status --porcelain
   ```
   If dirty, ask user to commit or stash changes first.

3. **Fetch and merge main**:
   ```bash
   git fetch origin main
   git merge origin/main -m "Update from main"
   ```

4. **Handle conflicts** (if any):
   - For each conflicted file, analyze both versions
   - **Worktree changes are priority** - this is an update, not a merge to main
   - Preserve worktree's new functionality while incorporating main's updates
   - Resolution strategy:
     - Read both versions completely
     - Identify what main changed that should be incorporated
     - Identify what worktree has that must be preserved
     - Write merged version that does both
     - If truly incompatible, prefer worktree's behavior and note what was skipped from main

5. **Rebuild if needed**:
   ```bash
   npm install && npm run build
   ```

6. **Report results** - Summarize what was updated from main.

## List Worktrees

To show existing worktrees:
```bash
git worktree list
```

Or check the project's worktrees directory:
```bash
PROJECT_NAME=$(basename "$(git rev-parse --show-toplevel)")
ls -la "$HOME/.worktrees/$PROJECT_NAME/"
```

## Remove Worktree (Delete/Discard)

When user says "remove worktree", "delete worktree", or "discard worktree":

**Use this when abandoning work without merging.**

1. **Identify worktree**:
   ```bash
   # If in worktree, get its name
   WORKTREE_NAME=$(basename "$(git rev-parse --show-toplevel)")

   # Or user specifies: "remove worktree auth-fix"
   ```

2. **Stop running instance**:
   ```bash
   ~/.claude/skills/run-project/scripts/stop-project.sh <worktree-path>
   ```

3. **Confirm with user** (if uncommitted changes):
   ```bash
   cd <worktree-path>
   git status --porcelain
   ```
   If dirty, warn: "This worktree has uncommitted changes. Are you sure you want to delete it?"

4. **Remove the worktree**:
   ```bash
   # Get main repo root first
   MAIN_REPO=$(git worktree list --porcelain | head -1 | sed 's/worktree //')

   # Remove worktree (force if dirty)
   cd "$MAIN_REPO"
   git worktree remove ~/.worktrees/<project>/wt-<name> --force
   ```

5. **Delete the branch**:
   ```bash
   git branch -D wt-<name>  # Force delete even if not merged
   ```

6. **Report result**:
   ```
   Removed worktree: wt-<name>
   - Stopped running instance
   - Deleted worktree folder
   - Deleted branch wt-<name>
   ```

## Merge Worktree

When user says "merge" and current directory is inside a worktree:

### Pre-merge Checks

1. **Stop running instance**:
   ```bash
   ~/.claude/skills/run-project/scripts/stop-project.sh <worktree-path>
   ```
   This stops any dev servers running for this worktree and updates the tracking file.

2. **Identify context**:
   ```bash
   # Check if in worktree
   git rev-parse --git-dir  # Returns path like ../.git/worktrees/wt-name

   # Get worktree branch name
   git branch --show-current

   # Get main repo root
   git worktree list --porcelain | grep -A1 "^worktree " | head -2
   ```

3. **Ensure clean state**:
   ```bash
   git status --porcelain
   ```
   If dirty, ask user to commit or stash changes first.

4. **Run e2e tests in worktree**:
   ```bash
   npm run test:e2e  # or project-specific test command
   ```
   If tests fail, stop and report. Don't merge broken code.

### Merge Process

5. **Switch to main repo and update**:
   ```bash
   cd <main-repo-root>
   git checkout main
   git pull origin main
   ```

6. **Squash merge the worktree branch**:
   ```bash
   git merge --squash wt-<name>
   ```

7. **Handle conflicts** (if any):
   - For each conflicted file, analyze both versions
   - **Main is source of truth** - preserve all working functionality from main
   - **Preserve worktree intent** - incorporate new functionality without breaking main
   - Resolution strategy:
     - Read both versions completely
     - Identify what main does that must keep working
     - Identify what worktree adds/changes
     - Write merged version that does both
     - If truly incompatible, prefer main's behavior and note what was lost

8. **Commit the merge**:
   ```bash
   git commit -m "Merge wt-<name>: <brief description>"
   ```

9. **Run e2e tests on main**:
   ```bash
   npm run test:e2e
   ```
   If tests fail, investigate and fix. The merge introduced a regression.

10. **Cleanup worktree** (after successful merge):
    ```bash
    git worktree remove ~/.worktrees/<project>/wt-<name>
    git branch -d wt-<name>
    ```

11. **Report results** - Summarize what was merged and test status.

## Merge Branch

When user says "merge" and NOT in a worktree (regular branch or remote):

Apply the same principles:

1. Identify the source branch (ask if unclear)
2. Ensure both branches have passing tests
3. Checkout main and pull latest
4. Squash merge the source branch
5. Auto-resolve conflicts (main = truth, preserve source intent)
6. Run e2e tests after merge
7. Report results

## Conflict Resolution Strategy

When auto-resolving conflicts:

```
1. Read ENTIRE files, not just conflict markers
2. Understand what main's version accomplishes
3. Understand what the branch's version adds/changes
4. Create merged version that:
   - Keeps ALL main functionality working
   - Incorporates branch changes where compatible
   - Documents any branch functionality that couldn't be preserved
5. If in doubt, test both behaviors in isolation first
```

**Never lose main's functionality** - if something works in main, it must work after merge.

## Running Instance Management

The run-project skill tracks all running instances in `~/.running-instances`.

### Check what's running:
```bash
~/.claude/skills/run-project/scripts/ports.sh
```

### Stop a worktree's instance:
```bash
~/.claude/skills/run-project/scripts/stop-project.sh <worktree-path>
```

**Always stop instances before merging or removing** - this prevents:
- Orphaned processes consuming resources
- Port conflicts when restarting
- Stale entries in the tracking file

## Environment Detection

The `open-in-pane.sh` script tries these methods in order:

| Priority | Environment | Method | Session Naming |
|----------|-------------|--------|----------------|
| 1 | iTerm2 | AppleScript split | Session name |
| 2 | tmux (in session) | Smart split (see below) | Pane title |
| 3 | tmux (launch new) | Opens iTerm2/Terminal.app with tmux | Session name |
| 4 | VS Code | Opens folder + auto-starts terminal | AppleScript automation |
| 5 | Zed | Opens folder | Manual |
| 6 | Fallback | Print instructions | Shows name |

### VS Code Automation (macOS)

When VS Code is available (`code` command), the script:
1. Opens VS Code with the worktree directory (new window)
2. Maximizes the window via AppleScript
3. VS Code tasks auto-run on folder open:
   - Terminal 1: `claude --dangerously-skip-permissions --chrome`
   - Terminal 2: `npm install && npm run build && npm run dev`

The worktree creation script generates `.vscode/settings.json` (disables welcome screen) and `.vscode/tasks.json` (defines the auto-run tasks).

**Note:** First time opening a worktree may require clicking "Allow" for workspace trust.

### Smart Tmux Splitting

When in tmux, the script creates a grid layout for monitoring multiple worktrees:

- **Odd pane count** -> split horizontally (`-h`, side by side)
- **Even pane count** -> split vertically (`-v`, top/bottom)

This creates a nice grid:
```
1 pane  -> split -h -> [1][2]
2 panes -> split -v -> [1][2]
                       [3]
3 panes -> split -h -> [1][2]
                       [3][4]
...and so on
```

Each pane gets titled with the worktree name (e.g., `wt-integrations`) for identification.

### Session Naming

All environments receive the worktree name (e.g., `wt-auth-fix`) for identification:

- **tmux**: Sets pane title via `select-pane -T`
- **iTerm2**: Sets session name directly via AppleScript
- **Zed/Fallback**: Displays session name in instructions

### Script Usage

```bash
~/.claude/skills/worktree/scripts/open-in-pane.sh <directory> [session-name]
```

| Option | Description |
|--------|-------------|
| `directory` | Path to the worktree (required) |
| `session-name` | Name for the pane title (default: "worktree") |
