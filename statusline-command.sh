#!/bin/sh
# Claude Code status line command
# Format: folder | branch | context% | model@effort | Changes: N files / N lines

input=$(cat)

# --- directory & branch ---
cwd=$(echo "$input" | jq -r '.workspace.current_dir')
dir=$(basename "$cwd")
branch=$(cd "$cwd" 2>/dev/null && git --no-optional-locks -c core.useBuiltinFSMonitor=false rev-parse --abbrev-ref HEAD 2>/dev/null || true)

# --- context window ---
usage=$(echo "$input" | jq '.context_window.current_usage')
if [ "$usage" != "null" ] && [ -n "$usage" ]; then
  current=$(echo "$usage" | jq '.input_tokens + .cache_creation_input_tokens + .cache_read_input_tokens')
  size=$(echo "$input" | jq '.context_window.context_window_size')
  ctx="$((current * 100 / size))%"
else
  ctx="0%"
fi

# --- model @ effort ---
model=$(echo "$input" | jq -r '.model.display_name')
effort=$(echo "$input" | jq -r '.effort.level // empty')
if [ -n "$effort" ]; then
  model_str="${model}@${effort}"
else
  model_str="${model}"
fi

# --- git changes (files + added/updated/deleted lines) ---
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
RESET='\033[0m'

changes_str=""
if [ -n "$branch" ]; then
  # Count changed files (staged + unstaged, excludes untracked)
  file_count=$(cd "$cwd" 2>/dev/null && git --no-optional-locks -c core.useBuiltinFSMonitor=false diff --name-only HEAD 2>/dev/null | wc -l | tr -d ' ')
  file_count=${file_count:-0}

  # Per-hunk classify lines as added (pure +), updated (overlap of + and -), deleted (pure -)
  counts=$(cd "$cwd" 2>/dev/null && git --no-optional-locks -c core.useBuiltinFSMonitor=false diff HEAD 2>/dev/null | awk '
    function flush() {
      if (ins > 0 || del > 0) {
        m = (ins < del) ? ins : del
        upd_t += m
        add_t += ins - m
        del_t += del - m
      }
      ins = 0; del = 0
    }
    /^diff /  { flush(); in_hdr = 1; next }
    in_hdr && /^@@/ { in_hdr = 0 }
    in_hdr { next }
    /^@@/    { flush(); next }
    /^\+/    { ins++ }
    /^-/     { del++ }
    END      { flush(); printf "%d %d %d", add_t, upd_t, del_t }
  ')
  add_count=${counts%% *}
  rest=${counts#* }
  upd_count=${rest%% *}
  del_count=${rest##* }
  add_count=${add_count:-0}
  upd_count=${upd_count:-0}
  del_count=${del_count:-0}

  # Color files (green ≤5, yellow ≤15, red >15)
  if [ "$file_count" -le 5 ]; then
    fc="${GREEN}${file_count}${RESET}"
  elif [ "$file_count" -le 15 ]; then
    fc="${YELLOW}${file_count}${RESET}"
  else
    fc="${RED}${file_count}${RESET}"
  fi

  changes_str=" | ${fc} f / ${GREEN}${add_count}${RESET} ${YELLOW}${upd_count}${RESET} ${RED}${del_count}${RESET} l"
fi

# --- assemble ---
if [ -n "$branch" ]; then
  printf '%b' "${dir} | ${branch} | ${ctx} | ${model_str}${changes_str}"
else
  printf '%b' "${dir} | ${ctx} | ${model_str}${changes_str}"
fi
