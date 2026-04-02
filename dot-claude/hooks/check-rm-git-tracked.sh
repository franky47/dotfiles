#!/bin/bash
# PreToolUse hook for rm commands.
# Allows deletion of git-tracked files without prompting.
# Falls back to asking the user for untracked files.

set -euo pipefail

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')

decide() {
  jq -n --arg d "$1" \
    '{ hookSpecificOutput: { hookEventName: "PreToolUse", permissionDecision: $d } }'
  exit 0
}

# Strip "rm" and any flags (-r, -rf, -f, etc.) to get just the paths
ARGS=$(echo "$COMMAND" | sed -E 's/^rm[[:space:]]+//' | sed -E 's/(^|[[:space:]])-[a-zA-Z]+//g' | xargs)

# If no paths remain, or args contain shell globs, fall back to asking
if [ -z "$ARGS" ] || echo "$ARGS" | grep -qE '[*?]'; then
  decide ask
fi

# Not in a git repo → ask
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
  decide ask
fi

# Check each path
for path in $ARGS; do
  # Strip surrounding quotes
  path=$(echo "$path" | sed "s/^['\"]//;s/['\"]$//")
  path="${path%/}"

  if [ -d "$path" ]; then
    # Directory: check if git tracks any files inside
    if [ -z "$(git ls-files "$path")" ]; then
      decide ask
    fi
  else
    # File: check if git tracks it
    if ! git ls-files --error-unmatch "$path" &>/dev/null; then
      decide ask
    fi
  fi
done

# All targets are under version control — safe to delete
decide allow
