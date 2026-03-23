#!/usr/bin/env bash
# Claude Code status line
input=$(cat)

DIM='\033[2m'
CYAN='\033[36m'
RED='\033[31m'
YELLOW='\033[33m'
GREEN='\033[32m'
MAGENTA='\033[35m'
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

# Git dirty state (matches zsh prompt style)
dirty=""
if [ -n "$cwd" ]; then
  dirty_str=$(git -C "$cwd" status --porcelain 2>/dev/null | awk \
    -v yellow="$YELLOW" -v green="$GREEN" -v red="$RED" \
    -v magenta="$MAGENTA" -v reset="$RESET" '
    {
      x = substr($0, 1, 1)
      y = substr($0, 2, 1)
      if (x == "M" || y == "M") m++
      if (x == "A")             a++
      if (x == "D" || y == "D") d++
      if (x == "?" && y == "?") u++
    }
    END {
      s = ""
      if (m) s = s sprintf("%s%d~%s ", yellow, m, reset)
      if (a) s = s sprintf("%s%d+%s ", green, a, reset)
      if (d) s = s sprintf("%s%d-%s ", red, d, reset)
      if (u) s = s sprintf("%s%d?%s ", magenta, u, reset)
      sub(/ $/, "", s)
      print s
    }
  ')
  if [ -n "$dirty_str" ]; then
    dirty="$separator$dirty_str"
  fi
fi

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

echo -e "$location""$separator""$ctx_str""$separator""$model"
echo -e "${DIM}${session_id}${RESET}""$dirty""$diff"
