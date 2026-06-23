#!/bin/bash

set -uo pipefail

TEST_DIR=$(dirname "$0")
HOOK="$TEST_DIR/../block-dangerous-git.sh"

# This hook is a hard-blocker: exit 2 => blocked, exit 0 => allowed (no opinion).
# It emits no JSON permission decision (unlike the sibling permission hooks),
# because exit 2 pre-empts permission-rule evaluation and is the only mechanism
# that cannot be overridden by an `allow` rule under bypassPermissions.

hook_rc() {
  local command=$1 rc=0
  jq -nc --arg c "$command" '{tool_name:"Bash",tool_input:{command:$c}}' \
    | bash "$HOOK" >/dev/null 2>&1 || rc=$?
  printf '%s' "$rc"
}

assert_blocks() {
  local command=$1 rc
  rc=$(hook_rc "$command")
  if [ "$rc" != "2" ]; then
    printf 'FAIL: expected BLOCK (exit 2) for: %q\nactual exit: %s\n' "$command" "$rc" >&2
    exit 1
  fi
}

assert_allows() {
  local command=$1 rc
  rc=$(hook_rc "$command")
  if [ "$rc" != "0" ]; then
    printf 'FAIL: expected ALLOW (exit 0) for: %q\nactual exit: %s\n' "$command" "$rc" >&2
    exit 1
  fi
}

# ===========================================================================
# git push is ALLOWED (policy: the agent may push; user keeps `! git push`
# only as a fallback, not a restriction). Force variants included.
# ===========================================================================
assert_allows 'git push'
assert_allows 'git push origin main'
assert_allows 'git push --force'
assert_allows 'git push --force-with-lease'
assert_allows 'git push -f'
assert_allows 'git push --all'
assert_allows 'git -C /some/repo push'
assert_allows 'git -c http.sslVerify=false push origin main'
assert_allows 'GIT_DIR=/x/.git git push origin main'

# ===========================================================================
# git reset --hard is BLOCKED — including every argument-bypass form.
# This is the recurring class the hook must defeat: global options, env
# prefixes, wrappers, and compound/substitution placement that split `git`
# from its subcommand.
# ===========================================================================
assert_blocks 'git reset --hard'
assert_blocks 'git reset --hard HEAD~1'
assert_blocks 'git reset --hard origin/main'
assert_blocks 'git -C /some/repo reset --hard'
assert_blocks 'git -c rerere.enabled=false reset --hard'
assert_blocks 'git --git-dir=/x/.git --work-tree=/x reset --hard'
assert_blocks 'git --git-dir /x/.git reset --hard'
assert_blocks 'git -p reset --hard'
assert_blocks 'GIT_DIR=/x git reset --hard'
assert_blocks 'cd /repo && git reset --hard'
assert_blocks 'echo before; git reset --hard'
assert_blocks 'git fetch origin && git reset --hard origin/main'
assert_blocks 'true || git reset --hard'
assert_blocks '$(git reset --hard)'
assert_blocks 'echo $(git -C /r reset --hard)'
assert_blocks $'ls\ngit reset --hard'
assert_blocks 'env git reset --hard'
assert_blocks 'command git reset --hard'
# line-continuation (backslash-newline) must not smuggle the subcommand past:
assert_blocks $'git \\\n  reset --hard'
assert_blocks $'git \\\nreset --hard'
assert_blocks $'git reset \\\n--hard'

# ===========================================================================
# git clean -f / -fd / clusters / --force are BLOCKED.
# ===========================================================================
assert_blocks 'git clean -f'
assert_blocks 'git clean -fd'
assert_blocks 'git clean -ffd'
assert_blocks 'git clean -xdf'
assert_blocks 'git clean -df'
assert_blocks 'git clean --force'
assert_blocks 'git -C /repo clean -fd'
assert_blocks 'cd x && git clean -fd'

# ===========================================================================
# git branch -D (force-delete) is BLOCKED. Lowercase -d is allowed below.
# ===========================================================================
assert_blocks 'git branch -D feature'
assert_blocks 'git -C /r branch -D old'
assert_blocks 'git branch --delete --force feature'
assert_blocks 'git branch -rD origin/feature'
assert_blocks 'git branch -df feature'
assert_blocks 'git branch -fd feature'

# ===========================================================================
# git checkout . / restore . (discard worktree) are BLOCKED.
# ===========================================================================
assert_blocks 'git checkout .'
assert_blocks 'git checkout -- .'
assert_blocks 'git -C /r checkout .'
assert_blocks 'git checkout HEAD -- .'
assert_blocks 'git checkout ./'
assert_blocks 'git checkout -- ./'
assert_blocks 'git restore .'
assert_blocks 'git restore -- .'
assert_blocks 'git restore ./'
assert_blocks 'git restore --worktree .'
assert_blocks 'git restore --staged --worktree .'

# ===========================================================================
# FALSE-POSITIVE GUARDS — these merely *mention* dangerous text or use a
# safe variant; they must NOT block.
# ===========================================================================
# Dangerous text inside quoted strings / grep patterns / commit messages:
assert_allows 'git log --grep="reset --hard"'
assert_allows 'git log --grep "git clean -fd"'
assert_allows 'git commit -m "git reset --hard"'
assert_allows 'git commit -m "wip && git reset --hard later"'
assert_allows "git commit -m 'git clean -fd'"
assert_allows 'echo "git reset --hard"'
assert_allows 'echo git reset --hard'

# Safe git operations:
assert_allows 'git status'
assert_allows 'git diff'
assert_allows 'git fetch --all'
assert_allows 'git pull'
assert_allows 'git add .'
assert_allows 'git add . && git commit -m wip'
assert_allows 'git branch -d merged'
assert_allows 'git branch -rd origin/feature'
assert_allows 'git branch -m oldname newname'
assert_allows 'git clean -n'
assert_allows 'git clean --dry-run'
assert_allows 'git clean -nd'
assert_allows 'git reset --soft HEAD~1'
assert_allows 'git reset --mixed'
assert_allows 'git reset HEAD file.txt'
assert_allows 'git checkout main'
assert_allows 'git checkout -b feature'
assert_allows 'git checkout feature.branch'
assert_allows 'git checkout reset--hard'
assert_allows 'git switch main'
assert_allows 'git rebase main'

# restore --staged . (unstage only — worktree is preserved) is SAFE:
assert_allows 'git restore --staged .'
assert_allows 'git restore --staged ./'
assert_allows 'git restore --staged file.txt'
assert_allows 'git restore file.txt'

# Non-git commands are never this hook's concern:
assert_allows 'rm -rf build'
assert_allows 'find . -name "*.log"'

# ===========================================================================
# Tool-name + empty-input guards (raw JSON, bypassing the helpers).
# ===========================================================================
# Non-Bash tool call must not block, even with a dangerous payload:
rc=0
jq -nc '{tool_name:"Read",tool_input:{command:"git reset --hard"}}' \
  | bash "$HOOK" >/dev/null 2>&1 || rc=$?
if [ "$rc" != "0" ]; then
  printf 'FAIL: expected ALLOW for non-Bash tool, got exit %s\n' "$rc" >&2
  exit 1
fi

# Empty / missing command must not block:
rc=0
jq -nc '{tool_name:"Bash",tool_input:{command:""}}' \
  | bash "$HOOK" >/dev/null 2>&1 || rc=$?
if [ "$rc" != "0" ]; then
  printf 'FAIL: expected ALLOW for empty command, got exit %s\n' "$rc" >&2
  exit 1
fi

rc=0
jq -nc '{tool_name:"Bash",tool_input:{}}' \
  | bash "$HOOK" >/dev/null 2>&1 || rc=$?
if [ "$rc" != "0" ]; then
  printf 'FAIL: expected ALLOW for missing command, got exit %s\n' "$rc" >&2
  exit 1
fi

printf 'block-dangerous-git tests passed (%d cases)\n' \
  "$(grep -cE '^assert_(blocks|allows) ' "$0")"
