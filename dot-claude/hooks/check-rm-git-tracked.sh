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

# Compound or expansion-bearing commands can't be safely scoped by an
# rm-only allowlist — the hook decides for the entire Bash invocation, so
# allowing the rm would also allow whatever follows or whatever the shell
# substitutes in. Bail to ask if we see any of:
#   ; && || |    — command chaining
#   \n           — multi-line scripts
#   $            — $(...) or $VAR (could expand outside our allowlisted dirs)
#   `            — legacy backtick command substitution
if [[ "$COMMAND" == *[$';&|$`\n']* ]]; then
  decide ask
fi

# Strip "rm" and any flags (-r, -rf, -f, etc.) to get just the paths
ARGS=$(echo "$COMMAND" | sed -E 's/^rm[[:space:]]+//' | sed -E 's/(^|[[:space:]])-[a-zA-Z]+//g' | xargs)

# If no paths remain, or args contain shell globs, fall back to asking
if [ -z "$ARGS" ] || echo "$ARGS" | grep -qE '[*?]'; then
  decide ask
fi

IN_GIT_REPO=true
git rev-parse --is-inside-work-tree &>/dev/null || IN_GIT_REPO=false

# Check each path
for path in $ARGS; do
  # Strip surrounding quotes
  path=$(echo "$path" | sed "s/^['\"]//;s/['\"]$//")
  path="${path%/}"

  # Per-user temp dirs are always safe to delete:
  #   /tmp/*                              — classic Unix tmp (Linux + macOS shortcut)
  #   /private/tmp/*                      — macOS canonical form of /tmp
  #   /var/folders/<x>/<hash>/T/*         — macOS $TMPDIR (mktemp -d default)
  #   /private/var/folders/<x>/<hash>/T/* — same path, symlink-resolved form
  # The sibling subtrees C/ (Darwin user cache) and 0/ (legacy user-temp) hold
  # app state worth preserving — leave those to fall through to ask.
  case "$path" in
    /tmp/*|/private/tmp/*) continue ;;
    /var/folders/*/*/T/*|/private/var/folders/*/*/T/*) continue ;;
  esac

  # Outside a git repo we can't verify tracking → ask
  if [ "$IN_GIT_REPO" = false ]; then
    decide ask
  fi

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
