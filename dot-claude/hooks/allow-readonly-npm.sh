#!/bin/bash
# PreToolUse hook for Bash. Pre-approves read-only `npm` subcommands so they
# bypass the broad `Bash(npm *)` deny rule. Anything not matched here falls
# through to static permission rules (where the deny still blocks).
#
# Pre-approved (read-only, network-or-local lookups, no install/publish):
#   npm view | info | show | v       -> registry metadata
#   npm ls | list                     -> installed tree
#   npm search | s | se | find        -> registry search
#   npm docs | home | repo            -> open URL (gated by browser anyway)
#   npm explain | why                 -> dependency reasoning
#   npm outdated                      -> compare local vs registry
#   npm ping                          -> registry reachability
#   npm config get ...                -> read config (not set/delete)
#   npm --version | -v | version      -> version print
#   npm help | -h                     -> help text

set -uo pipefail

emit_allow() {
  jq -nc --arg r "$1" \
    '{ hookSpecificOutput: { hookEventName: "PreToolUse", permissionDecision: "allow", permissionDecisionReason: $r } }'
  exit 0
}

INPUT=$(cat) || exit 0
TOOL=$(echo "$INPUT" | jq -r '.tool_name' 2>/dev/null) || exit 0
[ "$TOOL" = "Bash" ] || exit 0

CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0
[ -z "$CMD" ] && exit 0

# Only consider commands that start with `npm ` (after optional leading whitespace).
# Reject pipelines/chains by requiring the first token to be `npm` and bailing
# on shell metacharacters that could smuggle a second command.
TRIMMED="${CMD#"${CMD%%[![:space:]]*}"}"
case "$TRIMMED" in
  npm\ *|npm) ;;
  *) exit 0 ;;
esac

# Disallow chaining (&&, ||, ;, |, backticks, $()) — keep this hook strictly
# scoped to a single npm invocation.
case "$CMD" in
  *'&&'*|*'||'*|*';'*|*'|'*|*'`'*|*'$('*) exit 0 ;;
esac

# Extract subcommand (first token after `npm`, skipping flags like -s/--silent).
SUB=""
read -ra TOKENS <<<"$TRIMMED"
for tok in "${TOKENS[@]:1}"; do
  case "$tok" in
    -*) continue ;;
    *) SUB="$tok"; break ;;
  esac
done

# Flag-only invocations: `npm --version`, `npm -v`, `npm -h`.
if [ -z "$SUB" ]; then
  case "$TRIMMED" in
    *' --version'*|*' -v'*|*' --help'*|*' -h'*) emit_allow "npm version/help — read-only" ;;
  esac
  exit 0
fi

case "$SUB" in
  view|info|show|v)             emit_allow "npm $SUB — registry metadata, read-only" ;;
  ls|list|ll|la)                emit_allow "npm $SUB — installed tree, read-only" ;;
  search|s|se|find)             emit_allow "npm $SUB — registry search, read-only" ;;
  docs|home|repo|bugs)          emit_allow "npm $SUB — opens URL, no mutation" ;;
  explain|why)                  emit_allow "npm $SUB — dependency reasoning, read-only" ;;
  outdated)                     emit_allow "npm outdated — compare versions, read-only" ;;
  ping)                         emit_allow "npm ping — registry reachability" ;;
  version)                      emit_allow "npm version — print versions" ;;
  help)                         emit_allow "npm help — help text" ;;
  config)
    # Allow `npm config get ...` and `npm config list/ls`; everything else falls through.
    for tok in "${TOKENS[@]:2}"; do
      case "$tok" in
        -*) continue ;;
        get|list|ls) emit_allow "npm config $tok — read-only" ;;
        *) exit 0 ;;
      esac
    done
    ;;
esac

exit 0
