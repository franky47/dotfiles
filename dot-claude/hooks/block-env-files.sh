#!/bin/bash
# PreToolUse hook for file-reading/-editing tools.
# Permission rules can't express "deny .env* except .env.example" because
# deny precedence overrides allow. This hook closes that gap by allowing
# .env.example verbatim and denying every other .env-like filename.
#
# Matches basenames:
#   - .env                  (exact)        -> deny
#   - .env.<anything>       (variants)     -> deny  (e.g. .env.local, .env.example.bak)
#   - <anything>.env        (suffix)       -> deny  (e.g. secrets.env)
#   - .env.example          (exact)        -> allow (pass through, no decision)
#   - .envrc and others                    -> pass through

set -uo pipefail

emit_deny() {
  jq -nc --arg r "$1" \
    '{ hookSpecificOutput: { hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r } }'
  exit 0
}

INPUT=$(cat) || exit 0
TOOL=$(echo "$INPUT" | jq -r '.tool_name' 2>/dev/null) || exit 0

case "$TOOL" in
  Read | Edit | Write | MultiEdit | NotebookEdit) ;;
  *) exit 0 ;;
esac

# NotebookEdit uses notebook_path; the rest use file_path.
TARGET=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' 2>/dev/null) || exit 0
[ -z "$TARGET" ] && exit 0

BASE=$(basename "$TARGET")

# Allowlist exactly .env.example
[ "$BASE" = ".env.example" ] && exit 0

# Deny .env, .env.<anything>, and <anything>.env
if [[ "$BASE" =~ ^\.env(\..*)?$ ]] || [[ "$BASE" =~ \.env$ ]]; then
  emit_deny "Access to env file '$BASE' is blocked. Only .env.example is permitted."
fi

exit 0
