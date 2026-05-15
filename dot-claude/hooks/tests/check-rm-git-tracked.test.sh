#!/bin/bash

set -euo pipefail

TEST_DIR=$(dirname "$0")
HOOK="$TEST_DIR/../check-rm-git-tracked.sh"

# A path that is git-tracked in this repo (the hook itself).
TRACKED="dot-claude/hooks/check-rm-git-tracked.sh"

run_hook() {
  local command=$1
  jq -nc --arg command "$command" '{tool_name:"Bash",tool_input:{command:$command}}' | bash "$HOOK"
}

assert_decision() {
  local expected=$1 command=$2
  local output decision
  output=$(run_hook "$command")
  decision=$(jq -r '.hookSpecificOutput.permissionDecision // empty' <<<"$output" 2>/dev/null || true)
  if [ "$decision" != "$expected" ]; then
    printf 'FAIL: expected %s for: %q\nactual: %s\n' "$expected" "$command" "$output" >&2
    exit 1
  fi
}

assert_allows() { assert_decision allow "$1"; }
assert_asks()   { assert_decision ask   "$1"; }

# --- single rm: /tmp shortcut ----------------------------------------------
assert_allows 'rm /tmp/foo.txt'
assert_allows 'rm /tmp/some-dir/file.log'
assert_allows 'rm /private/tmp/foo.txt'
assert_allows 'rm -rf /tmp/scratch'
assert_allows 'rm -f /tmp/foo'

# --- single rm: macOS $TMPDIR (mktemp -d default lands in T/) -------------
# Only the T/ subtree is the "throwaway temp" — C/ (Darwin user cache) and
# 0/ (legacy user-temp) hold app state worth a confirmation prompt.
assert_allows 'rm /var/folders/90/abcdef1234567890/T/tmp.AbCdEf'
assert_allows 'rm -rf /var/folders/zz/0123456789abcdef/T/gha-audit.XYZ'
assert_allows 'rm /private/var/folders/90/abcdef1234567890/T/tmp.AbCdEf'

# --- sibling subtrees of the hash dir -> ask -------------------------------
assert_asks 'rm /var/folders/90/abcdef1234567890/C/some-cache-file'
assert_asks 'rm /var/folders/90/abcdef1234567890/0/something'

# --- single rm: tracked file -----------------------------------------------
assert_allows "rm $TRACKED"
assert_allows "rm -f $TRACKED"

# --- single rm: untracked / nonexistent path -> ask -------------------------
assert_asks 'rm /Users/franky/some-untracked-file-that-does-not-exist'
assert_asks 'rm ./totally-untracked.tmp'

# --- single rm: globs -> ask (cannot statically verify what they match) -----
assert_asks 'rm /tmp/*.txt'
assert_asks 'rm ./?.log'

# --- compound: rm at the START of a chain -> ask ----------------------------
assert_asks 'rm /tmp/foo.txt; ls'
assert_asks 'rm /tmp/foo.txt && echo done'
assert_asks 'rm /tmp/foo.txt || true'
assert_asks 'rm /tmp/foo.txt | tee /tmp/log'
assert_asks 'rm /tmp/foo.txt &'

# --- compound: rm in the MIDDLE of a chain -> ask --------------------------
assert_asks 'echo before; rm /tmp/foo.txt; echo after'
assert_asks 'ls /tmp && rm /tmp/foo.txt && ls /tmp'

# --- compound: rm at the END of a chain -> ask -----------------------------
assert_asks 'ls; rm /tmp/foo.txt'
assert_asks 'echo cleanup && rm -rf /tmp/scratch'
assert_asks 'true || rm /tmp/foo.txt'
assert_asks 'cat /tmp/foo | rm /tmp/foo.txt'

# --- compound: newline separator -> ask ------------------------------------
assert_asks $'rm /tmp/foo.txt\nls'
assert_asks $'ls\nrm /tmp/foo.txt'

# --- command substitution: $(...) -> ask (expansion unknown at hook time) --
assert_asks 'rm $(cat /tmp/list)'
assert_asks 'rm /tmp/$(whoami).log'

# --- command substitution: backticks -> ask --------------------------------
assert_asks 'rm `cat /tmp/list`'
assert_asks 'rm /tmp/`whoami`.log'

# --- compound: even when every rm target would individually allow -> ask ---
# Compound auto-allow would also auto-allow the non-rm segments, so we must ask.
assert_asks "rm /tmp/foo.txt; rm $TRACKED"
assert_asks "rm /tmp/a && rm /tmp/b"

# --- no rm anywhere -> allow regardless of shape ---------------------------
# The `if: "Bash(rm *)"` matcher in settings.json fail-opens on commands
# containing shell metacharacters, so this hook fires on plenty of non-rm
# bash. The self-gate at the top of the hook is what actually prevents
# prompts. These shapes (compound, expansion, for-loops, pipelines,
# multi-line, command-substitution) used to return `ask` and defeat AFK.
assert_allows 'which actionlint zizmor 2>&1; echo "---"'
assert_allows 'for f in foo/*.yml; do echo "=== $f ==="; wc -l "$f"; done'
assert_allows 'gh api repos/x/y/git/refs/tags/v3 2>/dev/null | jq -r .object.sha'
assert_allows 'git -C /some/path grep -lE pattern $(git -C /some/path for-each-ref --format=%(refname) refs/heads)'
assert_allows 'CLONE=/some/path; git -C "$CLONE" log --oneline -5'
assert_allows 'cd /tmp && VAR=foo; ls "$VAR"'
assert_allows $'line1\nline2\nls -la'
assert_allows 'echo `whoami` && id'
assert_allows 'for owner in a b c; do printf "%s: " "$owner"; curl -sI "https://github.com/$owner"; done'
assert_allows 'HEAD_BLOB=$(git ls-tree HEAD -- file); echo "$HEAD_BLOB"'

# --- subcommands containing the literal "rm" are NOT standalone rm ---------
# `git rm`, `npm rm`, etc. are subcommands of other tools with their own
# semantics — not this hook's concern. They must allow without triggering
# path validation.
assert_allows "git rm $TRACKED"
assert_allows "git -C . rm $TRACKED"
assert_allows 'npm rm some-package'
assert_allows 'echo "--remove-tag"'
assert_allows 'echo "the form is broken"'

# --- rm inside $(...) is still rm and must still be validated -------------
# Command substitution executes its contents; we cannot let an rm hide in
# `$(...)` or `` `...` ``. The fast-path must NOT short-circuit these.
assert_asks 'echo $(rm /tmp/foo)'
assert_asks 'X=$(rm /tmp/foo)'
assert_asks 'echo `rm /tmp/foo`'

printf 'check-rm-git-tracked tests passed (%d cases)\n' \
  "$(grep -cE '^assert_(allows|asks) ' "$0")"
