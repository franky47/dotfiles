#!/bin/bash

set -euo pipefail

TEST_DIR=$(cd "$(dirname "$0")" && pwd)
HOOK="$TEST_DIR/../allow-draft-pr.sh"

# Real git repos so owner resolution runs the actual `git remote get-url origin`
# (no network). Each dir's origin owner drives the implicit-repo decision.
mkrepo() {
  local dir url=$2
  dir=$(mktemp -d)
  git -C "$dir" init -q
  git -C "$dir" remote add origin "$url"
  printf '%s' "$dir"
}
OWNED=$(mkrepo _ 'git@github.com:47ng/lib.git')           # 47ng → allowed
MINE=$(mkrepo _ 'https://github.com/franky47/app.git')    # franky47 → allowed
FOREIGN=$(mkrepo _ 'git@github.com:acme/tool.git')        # acme → not mine
NOREMOTE=$(mktemp -d) && git -C "$NOREMOTE" init -q       # no origin
trap 'rm -rf "$OWNED" "$MINE" "$FOREIGN" "$NOREMOTE"' EXIT

run_hook() {
  local command=$1 cwd=${2:-$OWNED}
  jq -nc --arg command "$command" --arg cwd "$cwd" \
    '{tool_name:"Bash",tool_input:{command:$command},cwd:$cwd}' | bash "$HOOK"
}

assert_allows() {
  local out
  out=$(run_hook "$1" "${2:-$OWNED}")
  if [ "$(jq -r '.hookSpecificOutput.permissionDecision // empty' <<<"$out" 2>/dev/null || true)" != allow ]; then
    printf 'FAIL: expected allow for: %s\nactual: %s\n' "$1" "$out" >&2
    exit 1
  fi
}

assert_asks() {
  local out
  out=$(run_hook "$1" "${2:-$OWNED}")
  if [ "$(jq -r '.hookSpecificOutput.permissionDecision // empty' <<<"$out" 2>/dev/null || true)" != ask ]; then
    printf 'FAIL: expected ask for: %s\nactual: %s\n' "$1" "$out" >&2
    exit 1
  fi
}

assert_no_decision() {
  local out
  out=$(run_hook "$1" "${2:-$OWNED}")
  if [ -n "$out" ]; then
    printf 'FAIL: expected no decision for: %s\nactual: %s\n' "$1" "$out" >&2
    exit 1
  fi
}

# --- explicit --repo, draft, owned → allow ----------------------------------
assert_allows 'gh pr create --draft --repo franky47/app --title "feat: x" --body-file /tmp/b.md'
assert_allows 'gh pr create --repo=47ng/lib --draft --title "fix: y" --body "hello world"'
assert_allows 'gh pr create --draft --repo franky47/app --base main --head feat/x --fill'

# --- shapes seen in real transcripts: draft to an owned repo → allow --------
# implicit repo resolved locally from the cwd's git remote (47ng)
assert_allows "gh pr create --draft --base next --head chore/branch --title 'perf: a thing' --body-file /tmp/pr-body.md --label 'a label'"
assert_allows 'gh pr create --draft --base next --title "doc: a note" --body-file /tmp/pr-body.md --label internal --label documentation --milestone "Q3 Backlog"'
# --body "$(cat <<EOF … )" idiom — the quote groups the whole body, incl. its heredoc
assert_allows 'gh pr create --draft --base next --title "fix: a bug" --body "$(cat <<'"'"'EOF'"'"'
Some body text with a && b; c and even the words gh pr create inside it.
EOF
)"'
assert_allows 'gh pr create --repo 47ng/lib --draft --base next --head fix/x --label "area/one" --label "bug" --title "chore: a task" --body "$(cat <<'"'"'EOF'"'"'
body
EOF
)"'
# trailers agents append
assert_allows 'gh pr create --draft --base main --title "feat: x" --body-file /tmp/b.md 2>&1 | tail -5'
assert_allows 'gh pr create --draft --repo franky47/app --head fix/x --base main --title "fix: y" --body-file /tmp/b.md 2>&1 || gh api repos/franky47/app/pulls'
assert_allows 'gh pr create --draft --repo franky47/app --head fix/x --base main --title "x" --body-file /tmp/b.md && git worktree remove /tmp/wt'
# two draft PRs, both owned → allow
assert_allows 'gh pr create --draft --repo franky47/app --head a --base main --title x --body-file /tmp/a.md && gh pr create --draft --repo 47ng/lib --head b --base next --title y --body-file /tmp/b.md'
# bundled setup: heredoc body file, push, then the draft PR
assert_allows "cat > /tmp/prbody.txt <<'EOF'
Release notes.
EOF
git push -u origin release/x && gh pr create --draft --title 'chore: a release' --body-file /tmp/prbody.txt --base main --head release/x"
# cd into another owned repo, then create the PR there
assert_allows "cd $MINE && gh pr create --draft --base main --head feat/x --title x --body-file /tmp/b.md"

# --- not a draft → ask ------------------------------------------------------
assert_asks 'gh pr create --base next --title "doc: a note" --body "" --label documentation --label sponsors'
assert_asks 'gh pr create --repo franky47/app --title "x" --body-file /tmp/b.md'
# --draft as the VALUE of --title is not a draft flag
assert_asks 'gh pr create --title --draft --repo franky47/app --fill'
# --draft after the free-text region is not parsed (agents put it first)
assert_asks 'gh pr create --repo franky47/app --title x --draft'

# --- foreign repo → ask -----------------------------------------------------
assert_asks 'gh pr create --repo acme/tool --base main --head franky47:feat/x --title x --body-file /tmp/b.md'
assert_asks 'gh pr create --draft --repo acme/tool --title x --fill'
# implicit repo resolves to a repo I do not own → ask
assert_asks 'gh pr create --draft --base main --title "feat: x" --body-file /tmp/b.md 2>&1 | tail -5' "$FOREIGN"
# no origin remote → cannot resolve → ask
assert_asks 'gh pr create --draft --title x --fill' "$NOREMOTE"
# nonexistent cwd → ask
assert_asks 'gh pr create --draft --title x --fill' /nonexistent-dir

# --- owner-spoofing shapes → ask --------------------------------------------
assert_asks 'gh pr create --draft --repo franky47-evil/x --fill'
assert_asks 'gh pr create --draft --repo 47ngx/x --fill'
assert_asks 'gh pr create --draft --repo franky47 --fill'
assert_asks 'gh pr create --draft --repo evilfranky47/x --fill'
# short -R repo flag we do not parse must not fall back to cwd resolution
assert_asks 'gh pr create --draft -Racme/tool --fill'
assert_asks 'gh pr create --draft -R acme/tool --fill'
assert_asks 'gh pr create --draft -R=acme/tool --fill'
# empty --repo value must not fall back to cwd
assert_asks 'gh pr create --draft --repo --fill'
assert_asks "gh pr create --draft --repo='' --fill"

# --- multiple PRs: any non-draft or foreign one poisons the whole chain -----
assert_asks 'gh pr create --draft --repo franky47/app --fill && gh pr create --repo acme/tool --title x --body y'
assert_asks 'gh pr create --draft --repo franky47/app --fill && gh pr create --repo franky47/app --title x --body y'

# --- hook-vs-shell parse gaps that would false-allow → ask ------------------
# a short value-flag can swallow --draft (gh makes a NON-draft PR) → ask on any short flag
assert_asks 'gh pr create --repo franky47/app -t --draft --body y'
assert_asks 'gh pr create --draft -d --repo franky47/app --fill'
# subshell cd into a foreign repo runs gh there → resolve that repo, not the outer cwd
assert_asks "( cd $FOREIGN ; gh pr create --draft --title x --body y )" "$OWNED"
assert_asks "cd $OWNED && ( cd $FOREIGN ; gh pr create --draft --title x --body y )" "$OWNED"
# an unquoted \$(gh …) inner command is surfaced and checked
assert_asks 'gh pr create --draft --repo franky47/app --title $(gh pr create --repo acme/tool)'
# backslash-escaped quote must not swallow the ; that separates a foreign second PR
assert_asks "gh pr create --repo franky47/app --draft --title x\\' ; gh pr create --repo acme/tool --title z\\'"

# --- no real gh pr create (only mentioned in a body) → defer, no prompt ------
# no command-position gh pr create to gate; let the normal flow (bypass) handle it
assert_no_decision 'echo "run gh pr create --draft --repo franky47/x later"'

echo "All allow-draft-pr tests passed"
