#!/bin/bash
INPUT=$(cat)
RAW=$(echo "$INPUT" | jq -r '.name')

# Decode -S- back to / for the branch name (encoded by cw/cwr shell functions)
NAME=$(echo "$RAW" | sed 's/-S-/\//g')
# Slugify for the directory
SLUG=$(echo "$NAME" | sed 's/[^a-zA-Z0-9._-]/-/g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//')
WORKTREE_DIR="$CLAUDE_PROJECT_DIR/.worktrees/$SLUG"

mkdir -p "$CLAUDE_PROJECT_DIR/.worktrees"

# Ensure .worktrees has a .gitignore that ignores everything except itself.
# Skip if the repo already ignores .worktrees (e.g. a top-level .gitignore entry):
# the local one would be redundant. Use `git check-ignore` rather than grepping so
# broken patterns (e.g. a non-functional `./.worktrees`) don't fool us into skipping.
GITIGNORE="$CLAUDE_PROJECT_DIR/.worktrees/.gitignore"
if [ ! -f "$GITIGNORE" ] && ! git -C "$CLAUDE_PROJECT_DIR" check-ignore -q .worktrees/x; then
  printf '*\n!.gitignore\n' > "$GITIGNORE"
fi

if git -C "$CLAUDE_PROJECT_DIR" show-ref --verify --quiet "refs/heads/$NAME"; then
  git -C "$CLAUDE_PROJECT_DIR" worktree add "$WORKTREE_DIR" "$NAME" >&2
else
  git -C "$CLAUDE_PROJECT_DIR" worktree add -b "$NAME" "$WORKTREE_DIR" >&2
fi

echo "$WORKTREE_DIR"
