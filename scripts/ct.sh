#!/usr/bin/env bash
# ct — Multi-session Claude Code workspace launcher
#
# Usage: ct [project_path]   (defaults to $PWD)
#
# Source in ~/.zshrc:  source ~/.claude/scripts/ct.sh

ct() {
  local _path="${1:-$PWD}"
  _path="$(cd "$_path" 2>/dev/null && pwd)" || { echo "ct: invalid path: ${1}" >&2; return 1; }

  # Derive slug: lowercase alphanumeric with hyphens, no leading/trailing hyphens
  local _slug
  _slug=$(basename "$_path" | tr -cs '[:alnum:]' '-' | tr '[:upper:]' '[:lower:]' | sed 's/^-*//; s/-*$//')
  [[ -z "$_slug" ]] && _slug="project"

  local _session="ct-$_slug"

  # Idempotent: attach to existing session without re-launching anything
  if tmux has-session -t "$_session" 2>/dev/null; then
    exec tmux attach-session -t "$_session"
    return
  fi

  # Directories
  local _state_dir="$HOME/.claude/workspaces/$_slug"
  local _state_file="$_state_dir/state.json"
  local _bus_dir="$HOME/.claude/bus/$_slug"
  mkdir -p "$_state_dir" "$_bus_dir"

  # Port allocation: reuse recorded block or find first free 4-port block
  local _base=""
  if [[ -f "$_state_file" ]]; then
    _base=$(python3 -c "import json; d=json.load(open('$_state_file')); print(d.get('portBase',''))" 2>/dev/null || true)
  fi

  if [[ -z "$_base" ]]; then
    _base=8788
    while true; do
      local _free=true
      for _off in 0 1 2 3; do
        if lsof -i "tcp:$((_base + _off))" -sTCP:LISTEN &>/dev/null 2>&1; then
          _free=false; break
        fi
      done
      $_free && break
      _base=$((_base + 4))
    done
  fi

  local _peers="{\"pericles\":${_base},\"spartacus\":$((_base+1)),\"maximus\":$((_base+2)),\"argus\":$((_base+3))}"
  local _task_list_id="ct-$_slug"
  local _mcp_config="$HOME/.claude/templates/mcp-ct.json"
  local _prompts_dir="$HOME/.claude/prompts"

  # Session counter (for classifier refresh)
  local _count=0
  if [[ -f "$_state_file" ]]; then
    _count=$(python3 -c "import json; d=json.load(open('$_state_file')); print(d.get('sessionCount',0))" 2>/dev/null || echo 0)
  fi
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
    "taskListId": "$_task_list_id",
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

  # Check whether bootstrap is needed
  local _needs_bootstrap=0
  [[ ! -f "$_path/.claude/project-classifier.md" ]] && _needs_bootstrap=1

  # Write per-pane startup scripts to /tmp (avoids quoting issues in send-keys)
  _ct_write_pane_script() {
    local _ag="$1" _pt="$2" _mod="$3" _eff="$4"
    local _script="/tmp/ct-${_slug}-${_ag}.sh"
    printf '#!/usr/bin/env bash\n' > "$_script"
    printf "export CT_AGENT='%s'\n" "$_ag" >> "$_script"
    printf "export CT_PROJECT='%s'\n" "$_slug" >> "$_script"
    printf "export CT_CHANNEL_PORT=%s\n" "$_pt" >> "$_script"
    printf "export CT_PEERS='%s'\n" "$_peers" >> "$_script"
    printf "export CLAUDE_CODE_TASK_LIST_ID='%s'\n" "$_task_list_id" >> "$_script"
    printf "export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1\n" >> "$_script"
    printf "exec claude --model '%s' --effort '%s' --append-system-prompt-file '%s/%s.md' --dangerously-skip-permissions --dangerously-load-development-channels 'server:ct-channel' --mcp-config '%s'\n" \
      "$_mod" "$_eff" "$_prompts_dir" "$_ag" "$_mcp_config" >> "$_script"
    chmod +x "$_script"
  }

  _ct_write_pane_script "pericles"  "$_base"        "sonnet"    "medium"
  _ct_write_pane_script "spartacus" "$((_base+1))"  "opusplan"  "medium"
  _ct_write_pane_script "maximus"   "$((_base+2))"  "opus"      "max"
  _ct_write_pane_script "argus"     "$((_base+3))"  "sonnet"    "medium"

  # Build tmux session: 2x2 grid
  tmux new-session -d -s "$_session" -c "$_path" -x 240 -y 70
  tmux split-window -h  -t "${_session}:0"   -c "$_path"   # creates pane 0.1 (right)
  tmux split-window -v  -t "${_session}:0.0" -c "$_path"   # creates pane 0.2 (bottom-left)
  tmux split-window -v  -t "${_session}:0.1" -c "$_path"   # creates pane 0.3 (bottom-right)
  tmux select-layout    -t "${_session}:0" tiled
  tmux set-option       -t "$_session" remain-on-exit on
  tmux set-option       -t "$_session" pane-border-status top
  tmux select-pane      -t "${_session}:0.0" -T "Pericles"
  tmux select-pane      -t "${_session}:0.1" -T "Spartacus"
  tmux select-pane      -t "${_session}:0.2" -T "Maximus"
  tmux select-pane      -t "${_session}:0.3" -T "Argus"

  # Launch each pane via startup script
  tmux send-keys -t "${_session}:0.0" "source /tmp/ct-${_slug}-pericles.sh"  Enter
  tmux send-keys -t "${_session}:0.1" "source /tmp/ct-${_slug}-spartacus.sh" Enter
  tmux send-keys -t "${_session}:0.2" "source /tmp/ct-${_slug}-maximus.sh"   Enter
  tmux send-keys -t "${_session}:0.3" "source /tmp/ct-${_slug}-argus.sh"     Enter

  # Auto-dismiss the interactive --dangerously-load-development-channels prompt
  # (Claude v2.1.80+ prompts once per session before attaching a channel server)
  (sleep 4
   for _pane in 0.0 0.1 0.2 0.3; do
     tmux send-keys -t "${_session}:${_pane}" "" Enter 2>/dev/null || true
   done) &

  # Send bootstrap instruction after Claude has started (if classifier missing)
  if [[ $_needs_bootstrap -eq 1 ]]; then
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

  exec tmux attach-session -t "$_session"
}
