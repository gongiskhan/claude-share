#!/bin/bash
# Creates a git worktree in ~/.worktrees/<project>/ directory
# Usage: create-worktree.sh <name> [base-branch]
# Example: create-worktree.sh feature-auth main

set -e

NAME="$1"
BASE_BRANCH="${2:-HEAD}"

if [ -z "$NAME" ]; then
    echo "Error: Worktree name required"
    echo "Usage: create-worktree.sh <name> [base-branch]"
    exit 1
fi

# Get repo root and project name
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -z "$REPO_ROOT" ]; then
    echo "Error: Not in a git repository"
    exit 1
fi

PROJECT_NAME=$(basename "$REPO_ROOT")

# Worktrees stored in ~/.worktrees/<project>/wt-<name>
WORKTREES_BASE="$HOME/.worktrees"
PROJECT_WORKTREES="$WORKTREES_BASE/$PROJECT_NAME"
WORKTREE_PATH="$PROJECT_WORKTREES/wt-$NAME"
BRANCH_NAME="wt-$NAME"

# Create directories if needed
mkdir -p "$PROJECT_WORKTREES"

# Check if worktree already exists
if [ -d "$WORKTREE_PATH" ]; then
    echo "Error: Worktree already exists at $WORKTREE_PATH"
    exit 1
fi

# Check if branch already exists
if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; then
    echo "Branch $BRANCH_NAME already exists, using it"
    git worktree add "$WORKTREE_PATH" "$BRANCH_NAME"
else
    echo "Creating new branch $BRANCH_NAME from $BASE_BRANCH"
    git worktree add -b "$BRANCH_NAME" "$WORKTREE_PATH" "$BASE_BRANCH"
fi

# Copy all .env files from main repo to worktree (preserving paths)
ENV_FILES_COPIED=0
while IFS= read -r env_file; do
    if [ -f "$env_file" ]; then
        # Get relative path from repo root
        rel_path="${env_file#$REPO_ROOT/}"
        target_dir="$WORKTREE_PATH/$(dirname "$rel_path")"
        mkdir -p "$target_dir"
        cp "$env_file" "$WORKTREE_PATH/$rel_path"
        ENV_FILES_COPIED=$((ENV_FILES_COPIED + 1))
    fi
done < <(find "$REPO_ROOT" -name ".env*" -type f -not -path "*/node_modules/*" -not -path "*/.git/*" 2>/dev/null)

# Generate random ports for this worktree (3000-4000 range)
UI_PORT=$((3000 + RANDOM % 1000))
API_PORT=$((3000 + RANDOM % 1000))
# Ensure they're different
while [ "$API_PORT" -eq "$UI_PORT" ]; do
    API_PORT=$((3000 + RANDOM % 1000))
done

# Detect IP address - prefer Tailscale, fall back to local network IP
if command -v tailscale &> /dev/null && tailscale status &> /dev/null; then
    # Tailscale is available and running
    IP_ADDRESS=$(tailscale ip -4 2>/dev/null | head -1)
    if [ -z "$IP_ADDRESS" ]; then
        # Fallback if tailscale ip fails
        IP_ADDRESS=$(ifconfig | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | head -1)
    fi
else
    # Tailscale not available, use local network IP
    IP_ADDRESS=$(ifconfig | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | head -1)
fi

# Default to localhost if no IP found
if [ -z "$IP_ADDRESS" ]; then
    IP_ADDRESS="127.0.0.1"
fi

# Update port configuration in copied .env files
# Function to update or add a variable in an env file
update_env_var() {
    local file="$1"
    local var="$2"
    local value="$3"

    if [ ! -f "$file" ]; then
        return 1
    fi

    # Check if variable exists (with or without value, allowing spaces)
    if grep -q "^[[:space:]]*${var}[[:space:]]*=" "$file"; then
        # Update existing variable
        sed -i '' "s|^[[:space:]]*${var}[[:space:]]*=.*|${var}=${value}|" "$file" 2>/dev/null || \
        sed -i "s|^[[:space:]]*${var}[[:space:]]*=.*|${var}=${value}|" "$file"
    else
        # Add variable if it doesn't exist
        echo "${var}=${value}" >> "$file"
    fi
}

# API port - check common API directory patterns
for api_env in "$WORKTREE_PATH/agent-api/.env" "$WORKTREE_PATH/api/.env" "$WORKTREE_PATH/server/.env" "$WORKTREE_PATH/backend/.env"; do
    if [ -f "$api_env" ]; then
        update_env_var "$api_env" "PORT" "$API_PORT"
        echo "Updated PORT=$API_PORT in $api_env"
    fi
done

# UI config - update API URL to point to the Next.js app (which has API routes)
for ui_env in "$WORKTREE_PATH/app/.env.local" "$WORKTREE_PATH/app/.env" "$WORKTREE_PATH/frontend/.env.local" "$WORKTREE_PATH/frontend/.env" "$WORKTREE_PATH/web/.env.local" "$WORKTREE_PATH/web/.env"; do
    if [ -f "$ui_env" ]; then
        update_env_var "$ui_env" "NEXT_PUBLIC_API_URL" "http://$IP_ADDRESS:$UI_PORT"
        echo "Updated NEXT_PUBLIC_API_URL=http://$IP_ADDRESS:$UI_PORT in $ui_env"
    fi
done

# Create .env file with ports and IP address
cat > "$WORKTREE_PATH/.env" << EOF
UI_PORT=$UI_PORT
API_PORT=$API_PORT
IP_ADDRESS=$IP_ADDRESS
EOF

# Create .vscode directory with settings and tasks
mkdir -p "$WORKTREE_PATH/.vscode"

# Settings to disable welcome screen and allow automatic tasks
cat > "$WORKTREE_PATH/.vscode/settings.json" << 'SETTINGS'
{
  "workbench.startupEditor": "none",
  "task.allowAutomaticTasks": "on"
}
SETTINGS

# Tasks to auto-run Claude Code and dev server on folder open
cat > "$WORKTREE_PATH/.vscode/tasks.json" << 'TASKS'
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Claude Code",
      "type": "shell",
      "command": "claude --dangerously-skip-permissions --chrome",
      "presentation": {
        "reveal": "always",
        "panel": "dedicated",
        "group": "dev"
      },
      "runOptions": {
        "runOn": "folderOpen"
      }
    },
    {
      "label": "Dev Server",
      "type": "shell",
      "command": "npm install && npm run build && npm run dev",
      "presentation": {
        "reveal": "always",
        "panel": "dedicated",
        "group": "dev"
      },
      "runOptions": {
        "runOn": "folderOpen"
      }
    }
  ]
}
TASKS

echo ""
echo "Worktree created successfully:"
echo "  Path: $WORKTREE_PATH"
echo "  Branch: $BRANCH_NAME"
echo "  UI Port: $UI_PORT"
echo "  API Port: $API_PORT"
echo "  IP Address: $IP_ADDRESS"
if [ "$ENV_FILES_COPIED" -gt 0 ]; then
    echo "  Env files: $ENV_FILES_COPIED copied and configured"
fi
echo ""

# Output path for scripts to use
echo "$WORKTREE_PATH"
