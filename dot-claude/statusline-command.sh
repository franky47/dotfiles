#!/usr/bin/env bash
# Claude Code status line
input=$(cat)

DIM='\033[2m'
CYAN='\033[36m'
RED='\033[31m'
YELLOW='\033[33m'
GREEN='\033[32m'
RESET='\033[0m'

eval "$(echo "$input" | jq -r '
  @sh "model=\(.model.display_name // "Claude")",
  @sh "cwd=\(.workspace.current_dir // .cwd // "")",
  @sh "used=\(.context_window.used_percentage // "")",
  @sh "session_id=\(.session_id // "")",
  @sh "added=\(.cost.total_lines_added // "")",
  @sh "removed=\(.cost.total_lines_removed // "")"
')"

# Context usage
if [ -n "$used" ]; then
  used_int=$(printf "%.0f" "$used")
  if [ "$used_int" -ge 75 ]; then
    ctx_color="$RED"
  elif [ "$used_int" -ge 50 ]; then
    ctx_color="$YELLOW"
  else
    ctx_color=""
  fi
  ctx_str="ctx: ${ctx_color}${used_int}%${RESET}"
else
  ctx_str="ctx: ${DIM}--${RESET}"
fi

# Shorten cwd
short_cwd="${cwd/#$HOME/~}"

# Git branch (if in a repo)
git_branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)
if [ -n "$git_branch" ]; then
  location="${short_cwd}${DIM}:${RESET}${CYAN}${git_branch}${RESET}"
else
  location="${short_cwd}"
fi

separator=" ${DIM}|${RESET} "

diff=""
if [ -n "$added" ] && [ -n "$removed" ]; then
  if [ "$added" -gt 0 ]; then
    diff+="${GREEN}+${added}${RESET} "
  fi
  if [ "$removed" -gt 0 ]; then
    diff+="${RED}-${removed}${RESET}"
  fi
  # Prepend separator if we have any diff info
  if [ -n "$diff" ]; then
    diff="$separator$diff"
  fi
fi

echo -e "$model""$separator""$ctx_str""$separator""$location"
echo -e "${DIM}${session_id}${RESET}""$diff"
