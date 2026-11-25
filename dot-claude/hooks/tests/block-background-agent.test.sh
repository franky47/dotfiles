#!/bin/bash

set -euo pipefail

TEST_DIR=$(cd "$(dirname "$0")" && pwd)
HOOK="$TEST_DIR/../block-background-agent.sh"

IN_T3=t3-thread
MAIN_SESSION='{}'

run_raw() {
  local raw=$1
  shift
  local out code=0
  out=$(printf '%s' "$raw" | env "$@" "$HOOK") || code=$?
  if [ "$code" != 0 ]; then
    printf 'FAIL: hook exited %s for input: %s\n' "$code" "$raw" >&2
    exit 1
  fi
  printf '%s' "$out"
}

in_t3() {
  local tool=$1 input=$2 caller=${3:-$MAIN_SESSION}
  run_raw "$(jq -nc --arg tool "$tool" --argjson input "$input" --argjson caller "$caller" '{tool_name:$tool,tool_input:$input} + $caller')" \
    T3CODE_THREAD_ID="$IN_T3"
}

decision() {
  jq -r 'select(.hookSpecificOutput.hookEventName == "PreToolUse") | .hookSpecificOutput.permissionDecision // empty' <<<"$1" 2>/dev/null || true
}

assert_denies() {
  local out
  out=$(in_t3 "$1" "$2" "${3:-$MAIN_SESSION}")
  if [ "$(decision "$out")" != deny ]; then
    printf 'FAIL: expected deny for: %s %s %s\nactual: %s\n' "$1" "$2" "${3:-}" "$out" >&2
    exit 1
  fi
}

assert_no_decision() {
  local out
  out=$(in_t3 "$1" "$2" "${3:-$MAIN_SESSION}")
  if [ -n "$out" ]; then
    printf 'FAIL: expected no decision for: %s %s %s\nactual: %s\n' "$1" "$2" "${3:-}" "$out" >&2
    exit 1
  fi
}

# --- in T3, background agents → deny ----------------------------------------
assert_denies Agent '{"prompt":"x","run_in_background":true}'
assert_denies Agent '{"prompt":"x"}'
assert_denies Agent '{"prompt":"x","run_in_background":"false"}'
assert_denies Agent '{"prompt":"x","run_in_background":null}'
assert_denies Task '{"prompt":"x","run_in_background":true}'
assert_denies Task '{"prompt":"x"}'

# --- in T3, remote agents run outside this session → no decision ------------
assert_no_decision Agent '{"prompt":"x","isolation":"remote"}'
assert_no_decision Agent '{"prompt":"x","subagent_type":"fork","isolation":"remote"}'
assert_no_decision Agent '{"prompt":"x","isolation":"remote"}' '{"agent_id":"a1"}'
assert_no_decision Agent '{"prompt":"x","subagent_type":"fork","isolation":"remote"}' '{"agent_id":"a1"}'

# --- in T3, forks from the main session are allowed; from a subagent, denied -
SUBAGENT='{"agent_id":"a1","agent_type":"general-purpose"}'
assert_no_decision Agent '{"prompt":"x","subagent_type":"fork"}'
assert_no_decision Agent '{"prompt":"x","subagent_type":"fork","run_in_background":true}'
assert_no_decision Task '{"prompt":"x","subagent_type":"fork"}'
assert_no_decision Agent '{"prompt":"x","subagent_type":"fork"}' '{"agent_id":null}'
assert_no_decision Agent '{"prompt":"x","subagent_type":"fork"}' '{"agent_id":""}'
assert_no_decision Agent '{"prompt":"x","subagent_type":"fork"}' '{"agent_type":"reviewer"}'
assert_denies Agent '{"prompt":"x","subagent_type":"fork"}' "$SUBAGENT"
assert_denies Agent '{"prompt":"x","subagent_type":"fork","run_in_background":false}' "$SUBAGENT"
assert_denies Agent '{"prompt":"x"}' "$SUBAGENT"
assert_no_decision Agent '{"prompt":"x","run_in_background":false}' "$SUBAGENT"

# --- in T3, a malformed Agent call → deny -----------------------------------
out=$(run_raw '{"tool_name":"Agent"}' T3CODE_THREAD_ID="$IN_T3")
[ "$(decision "$out")" = deny ] || { printf 'FAIL: expected deny with no tool_input\nactual: %s\n' "$out" >&2; exit 1; }
out=$(run_raw '{"tool_name":"Agent","tool_input":"x"}' T3CODE_THREAD_ID="$IN_T3")
[ "$(decision "$out")" = deny ] || { printf 'FAIL: expected deny with a string tool_input\nactual: %s\n' "$out" >&2; exit 1; }

# --- the deny reason points at the tool to use instead ----------------------
reason=$(in_t3 Agent '{"prompt":"x"}' | jq -r '.hookSpecificOutput.permissionDecisionReason')
case "$reason" in
  *mcp__t3-code__delegate_task*) ;;
  *) printf 'FAIL: deny reason does not name mcp__t3-code__delegate_task: %s\n' "$reason" >&2; exit 1 ;;
esac

# --- in T3, foreground agents → no decision ---------------------------------
assert_no_decision Agent '{"prompt":"x","run_in_background":false}'
assert_no_decision Agent '{"prompt":"x","subagent_type":"Explore","isolation":"worktree","run_in_background":false}'
assert_no_decision Task '{"prompt":"x","run_in_background":false}'

# --- other tools → no decision ----------------------------------------------
assert_no_decision Bash '{"command":"ls","run_in_background":true}'
assert_no_decision TaskStop '{"task_id":"x"}'
assert_no_decision TaskOutput '{"task_id":"x"}'
assert_no_decision mcp__t3-code__delegate_task '{"task":"x"}'

# --- outside T3, no delegate_task to fall back on → no decision -------------
background='{"tool_name":"Agent","tool_input":{"prompt":"x"}}'
for env_args in "T3CODE_THREAD_ID=" "-u T3CODE_THREAD_ID"; do
  # shellcheck disable=SC2086
  out=$(run_raw "$background" $env_args)
  [ -z "$out" ] || { printf 'FAIL: expected no decision outside T3 (env %s)\nactual: %s\n' "$env_args" "$out" >&2; exit 1; }
done

# --- without jq: blocks in T3, stays silent outside ------------------------
NO_JQ_BIN=$(mktemp -d)
trap 'rm -rf "$NO_JQ_BIN"' EXIT
ln -s "$(command -v cat)" "$NO_JQ_BIN/cat"
for t3 in "$IN_T3" ''; do
  code=0
  err=$(printf '%s' "$background" | env PATH="$NO_JQ_BIN" T3CODE_THREAD_ID="$t3" /bin/bash "$HOOK" 2>&1 >/dev/null) || code=$?
  if [ -n "$t3" ]; then want_code=2; else want_code=0; fi
  if [ "$code" != "$want_code" ] || { [ -n "$t3" ] && [[ "$err" != *jq* ]]; } || { [ -z "$t3" ] && [ -n "$err" ]; }; then
    printf 'FAIL: without jq (T3CODE_THREAD_ID=%s) expected exit %s\nexit: %s\nstderr: %s\n' "$t3" "$want_code" "$code" "$err" >&2
    exit 1
  fi
done

# --- empty or unparseable input fails open ---------------------------------
for raw in '' 'not json' '{}'; do
  out=$(run_raw "$raw" T3CODE_THREAD_ID="$IN_T3")
  [ -z "$out" ] || { printf 'FAIL: expected no decision for raw input: %s\nactual: %s\n' "$raw" "$out" >&2; exit 1; }
done

echo "All block-background-agent tests passed"
