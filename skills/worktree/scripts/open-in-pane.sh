#!/bin/bash
# Opens a directory in a new terminal pane and runs Claude Code
# Supports: tmux (split or new session), iTerm2, Zed, fallback instructions
# Usage: open-in-pane.sh <directory> [session-name]

set -e

DIR="$1"
SESSION_NAME="${2:-worktree}"

if [ -z "$DIR" ]; then
    echo "Error: Directory path required"
    exit 1
fi

if [ ! -d "$DIR" ]; then
    echo "Error: Directory does not exist: $DIR"
    exit 1
fi

# Export display/X11 environment variables for GUI support
ENV_EXPORTS=""
[ -n "$DISPLAY" ] && ENV_EXPORTS="export DISPLAY='$DISPLAY'; "
[ -n "$XAUTHORITY" ] && ENV_EXPORTS="${ENV_EXPORTS}export XAUTHORITY='$XAUTHORITY'; "
[ -n "$DBUS_SESSION_BUS_ADDRESS" ] && ENV_EXPORTS="${ENV_EXPORTS}export DBUS_SESSION_BUS_ADDRESS='$DBUS_SESSION_BUS_ADDRESS'; "

CLAUDE_CMD="${ENV_EXPORTS}cd '$DIR' && claude --dangerously-skip-permissions --chrome"
CLAUDE_CMD_SIMPLE="claude --dangerously-skip-permissions --chrome"

# Open VS Code and run Claude Code in integrated terminal
# Tasks in .vscode/tasks.json auto-run on folder open
try_vscode() {
    if [[ "$OSTYPE" != "darwin"* ]]; then
        return 1
    fi

    if ! command -v code &> /dev/null; then
        return 1
    fi

    echo "Opening VS Code at $DIR..."
    code --new-window "$DIR"

    # Wait for VS Code to open
    sleep 2

    # Maximize window
    echo "Maximizing VS Code window..."
    osascript <<EOF
tell application "Visual Studio Code"
    activate
end tell

delay 0.3

tell application "System Events"
    tell process "Code"
        try
            click menu item "Zoom" of menu "Window" of menu bar 1
        end try
    end tell
end tell
EOF

    echo "VS Code opened - tasks will auto-run (Claude Code + npm run dev)"
    echo "Note: First time may require clicking 'Allow' for workspace trust"
    return 0
}

# Create new tmux pane (if already in tmux session)
# Smart splitting: odd pane count → horizontal, even → vertical
try_tmux() {
    if [ -z "$TMUX" ]; then
        return 1
    fi

    local pane_count
    pane_count=$(tmux list-panes | wc -l | tr -d ' ')

    local split_flag
    if (( pane_count % 2 == 1 )); then
        split_flag="-h"
        echo "Splitting horizontally (pane #$((pane_count + 1)))..."
    else
        split_flag="-v"
        echo "Splitting vertically (pane #$((pane_count + 1)))..."
    fi

    local new_pane
    new_pane=$(tmux split-window $split_flag -P -F "#{pane_id}" "$CLAUDE_CMD")
    tmux select-pane -t "$new_pane" -T "$SESSION_NAME"

    return 0
}

# Launch tmux when not already in tmux
try_launch_tmux() {
    if [ -n "$TMUX" ]; then
        return 1
    fi

    if ! command -v tmux &> /dev/null; then
        return 1
    fi

    local TMUX_INNER="${ENV_EXPORTS}cd '$DIR' && tmux new-session -s '$SESSION_NAME' '${ENV_EXPORTS}claude --dangerously-skip-permissions --chrome'"

    if [[ "$OSTYPE" == "darwin"* ]]; then
        if osascript -e 'application "iTerm" is running' 2>/dev/null | grep -q "true"; then
            echo "Opening iTerm2 with tmux session: $SESSION_NAME..."
            osascript <<EOF
tell application "iTerm"
    activate
    create window with default profile
    tell current session of current window
        write text "$TMUX_INNER"
    end tell
end tell
EOF
            return 0
        fi

        echo "Opening Terminal.app with tmux session: $SESSION_NAME..."
        osascript -e "tell app \"Terminal\" to do script \"$TMUX_INNER\""
        osascript -e 'tell app "Terminal" to activate'
        return 0
    fi

    echo ""
    echo "To start Claude Code in tmux:"
    echo "  $TMUX_INNER"
    return 0
}

# Create new Zed terminal
try_zed() {
    if [[ "$OSTYPE" != "darwin"* ]]; then
        return 1
    fi

    if ! pgrep -x "Zed" > /dev/null; then
        return 1
    fi

    if command -v zed &> /dev/null; then
        zed "$DIR"
        echo "Opened $DIR in Zed."
        echo "Session name: $SESSION_NAME"
        echo ""
        echo "To start Claude Code:"
        echo "  1. Open terminal (Ctrl+\`)"
        echo "  2. Run: claude --dangerously-skip-permissions --chrome"
        return 0
    fi

    return 1
}

# Create new iTerm2 session
try_iterm() {
    if [[ "$OSTYPE" != "darwin"* ]]; then
        return 1
    fi

    if ! osascript -e 'application "iTerm" is running' 2>/dev/null | grep -q "true"; then
        return 1
    fi

    echo "Detected iTerm2, creating split pane..."
    osascript <<EOF 2>/dev/null
tell application "iTerm"
    tell current session of current window
        set newSession to (split horizontally with default profile)
        tell newSession
            set name to "$SESSION_NAME"
            write text "$CLAUDE_CMD"
        end tell
    end tell
end tell
EOF
    if [ $? -eq 0 ]; then
        echo "iTerm2 session named: $SESSION_NAME"
        return 0
    fi
    return 1
}

# Main logic - iTerm2 first, then tmux, then VS Code, then Zed
if try_iterm; then
    echo "Claude Code launched in iTerm2 split pane"
    exit 0
fi

if try_tmux; then
    echo "Pane title: $SESSION_NAME"
    exit 0
fi

if try_launch_tmux; then
    echo "Claude Code launched in new tmux session: $SESSION_NAME"
    exit 0
fi

if try_vscode; then
    exit 0
fi

if try_zed; then
    exit 0
fi

# Fallback
echo ""
echo "Could not automatically open VS Code or split pane."
echo ""
echo "Session name: $SESSION_NAME"
echo ""
echo "To launch Claude Code in the worktree:"
echo "  cd $DIR"
echo "  claude --dangerously-skip-permissions --chrome"
