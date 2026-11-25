#!/bin/bash
# T3 only: outside T3 there is no delegate_task to send background work to.

set -uo pipefail

INPUT=$(cat) || exit 0

[ -n "${T3CODE_THREAD_ID:-}" ] || exit 0

command -v jq >/dev/null || { echo "block-background-agent: jq not found. Install jq to start agents in T3." >&2; exit 2; }

case "$(jq -r '.tool_name // empty' <<<"$INPUT" 2>/dev/null)" in
  Agent | Task) ;;
  *) exit 0 ;;
esac

jq -e '(.agent_id // "") as $caller
  | .tool_input
  | if .isolation == "remote" then true
    elif .subagent_type == "fork" then $caller == ""
    else .run_in_background == false end' <<<"$INPUT" >/dev/null 2>&1 && exit 0

jq -nc --arg r "In T3, background Agent calls are blocked: they die when the session compacts or exits. A subagent also never gets the result of a background agent it starts. Use mcp__t3-code__delegate_task (load it with ToolSearch if deferred). Or set run_in_background to the boolean false (a fork from a subagent has no such option)." \
  '{ hookSpecificOutput: { hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r } }'
exit 0
