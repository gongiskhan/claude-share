#!/usr/bin/env bash
# ct — Multi-session Claude Code workspace launcher
# Usage: ct [project_path]   (defaults to $PWD)
# Source in ~/.zshrc:  source ~/.claude/scripts/ct.sh

ct() {
  local _path="${1:-$PWD}"
  _path="$(cd "$_path" 2>/dev/null && pwd)" || { echo "ct: invalid path: ${1}" >&2; return 1; }

  # Lowercase alphanumeric slug, no leading/trailing hyphens
  local _slug
  _slug=$(basename "$_path" | tr -cs '[:alnum:]' '-' | tr '[:upper:]' '[:lower:]' | sed 's/^-*//; s/-*$//')
  [[ -z "$_slug" ]] && _slug="project"

  local _session="ct-$_slug"
  local _attaching=0
  tmux has-session -t "$_session" 2>/dev/null && _attaching=1

  local _state_dir="$HOME/.claude/workspaces/$_slug"
  local _state_file="$_state_dir/state.json"
  mkdir -p "$_state_dir" "$HOME/.claude/bus/$_slug"

  # Read portBase and sessionCount in one jq call; fall back gracefully if absent
  local _base="" _count=0
  read -r _base _count < <(jq -r '[(.portBase // ""), (.sessionCount // 0)] | @tsv' "$_state_file" 2>/dev/null) || true
  [[ -z "$_count" || "$_count" == "null" ]] && _count=0

  # Find first free 4-port block (or reuse recorded block)
  if [[ -z "$_base" ]]; then
    _base=8788
    local _free
    while true; do
      _free=true
      for _off in 0 1 2 3; do
        if nc -z 127.0.0.1 $((_base + _off)) 2>/dev/null; then
          _free=false; break
        fi
      done
      $_free && break
      _base=$((_base + 4))
    done
  fi

  local _peers="{\"pericles\":${_base},\"spartacus\":$((_base+1)),\"maximus\":$((_base+2)),\"argus\":$((_base+3))}"
  local _task_list_id="ct-$_slug"
  local _node_bin="/Users/ggomes/.nvm/versions/node/v20.19.4/bin/node"
  local _server_mjs="$HOME/.claude/hooks/channel/server.mjs"
  local _prompts_dir="$HOME/.claude/prompts"
  _count=$((_count + 1))

  # Write state.json
  python3 - <<PYEOF
import json, datetime
data = {
    "slug": "$_slug",
    "projectPath": "$_path",
    "createdAt": datetime.datetime.utcnow().isoformat() + "Z",
    "sessionCount": $_count,
    "lastClassifierRefresh": datetime.datetime.utcnow().isoformat() + "Z",
    "portBase": $_base,
    "ports": {
        "pericles": $_base,
        "spartacus": $((_base+1)),
        "maximus": $((_base+2)),
        "argus": $((_base+3))
    }
}
with open("$_state_file", "w") as f:
    json.dump(data, f, indent=2)
PYEOF

  # Build tmux session: 2x2 grid (only if not attaching)
  if [[ $_attaching -eq 0 ]]; then
    tmux new-session -d -s "$_session" -c "$_path" -x 240 -y 70
    tmux split-window -h  -t "${_session}:0"   -c "$_path"   # creates pane 0.1 (right)
    tmux split-window -v  -t "${_session}:0.0" -c "$_path"   # creates pane 0.2 (bottom-left)
    tmux split-window -v  -t "${_session}:0.1" -c "$_path"   # creates pane 0.3 (bottom-right)
    tmux select-layout    -t "${_session}:0" tiled
    tmux set-option       -t "$_session" remain-on-exit on
    tmux set-option       -t "$_session" pane-border-status top
  fi

  # Write per-pane MCP config + startup script, set pane title, launch
  # MCP subprocess does NOT inherit the parent shell env — env vars must be
  # explicitly declared in the MCP config's env block (jq handles escaping).
  local _entry _ag _off _mod _eff _title _pt _script _mcp_file
  for _entry in \
    "pericles:0:sonnet:medium:Pericles" \
    "spartacus:1:opusplan:medium:Spartacus" \
    "maximus:2:opus:max:Maximus" \
    "argus:3:sonnet:medium:Argus"; do
    IFS=: read -r _ag _off _mod _eff _title <<< "$_entry"
    _pt="$((_base + _off))"
    _script="/tmp/ct-${_slug}-${_ag}.sh"
    _mcp_file="/tmp/ct-${_slug}-${_ag}.mcp.json"

    jq -n \
      --arg node    "$_node_bin" \
      --arg server  "$_server_mjs" \
      --arg ag      "$_ag" \
      --arg project "$_slug" \
      --arg port    "$_pt" \
      --arg peers   "$_peers" \
      '{mcpServers: {"ct-channel": {command: $node, args: [$server],
        env: {CT_AGENT: $ag, CT_PROJECT: $project, CT_CHANNEL_PORT: $port, CT_PEERS: $peers}}}}' \
      > "$_mcp_file"

    {
      printf '#!/usr/bin/env bash\n'
      printf "export CLAUDE_CODE_TASK_LIST_ID='%s'\n" "$_task_list_id"
      printf "exec claude --mcp-config '%s' --strict-mcp-config --dangerously-load-development-channels 'server:ct-channel' --model '%s' --effort '%s' --append-system-prompt-file '%s/%s.md' --dangerously-skip-permissions\n" \
        "$_mcp_file" "$_mod" "$_eff" "$_prompts_dir" "$_ag"
    } > "$_script"
    chmod +x "$_script"

    if [[ $_attaching -eq 0 ]]; then
      tmux select-pane -t "${_session}:0.${_off}" -T "$_title"
      tmux send-keys   -t "${_session}:0.${_off}" "source /tmp/ct-${_slug}-${_ag}.sh" Enter
    fi
  done

  # Fresh-launch-only post-launch actions
  if [[ $_attaching -eq 0 ]]; then
    # Auto-dismiss the --dangerously-load-development-channels confirmation prompt
    # (Claude v2.1.80+ shows it once before attaching a channel server)
    (sleep 4
     for _pane in 0.0 0.1 0.2 0.3; do
       tmux send-keys -t "${_session}:${_pane}" "" Enter 2>/dev/null || true
     done) &

    # Bootstrap if project classifier is missing
    if [[ ! -f "$_path/.claude/project-classifier.md" ]]; then
      (sleep 9 && tmux send-keys -t "${_session}:0.0" \
        "Bootstrap required: .claude/project-classifier.md is missing. Brief Spartacus to analyze this project and generate it from ~/.claude/templates/project-classifier.md. Block all other routing until complete." \
        Enter) &
    fi

    # Classifier refresh every 50 sessions
    if [[ $_count -gt 0 && $((_count % 50)) -eq 0 ]]; then
      (sleep 9 && tmux send-keys -t "${_session}:0.0" \
        "Classifier refresh due (session #${_count}): brief Spartacus to regenerate .claude/project-classifier.md from the current codebase state." \
        Enter) &
    fi
  fi

  exec tmux attach-session -t "$_session"
}
