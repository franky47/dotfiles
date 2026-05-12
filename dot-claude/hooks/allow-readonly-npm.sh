#!/bin/bash
# PreToolUse hook for Bash. Pre-approves a *very* small allow-list of
# read-only invocations that LLMs reach for often. Anything that doesn't
# match emits a structured `deny` decision whose reason text tells the agent
# exactly which shapes ARE allowed, so it can self-correct on the next turn
# without bothering the user.
#
# To allow a new command verbatim, add a line to ALLOWED below. Each entry
# is a human-readable template. Placeholders in <angle-brackets> are
# substituted with the regex fragments defined above (currently only <pkg>);
# the rest is matched literally as part of an anchored regex.
#
# Rules for any line you add to ALLOWED:
#   1. Use only safe characters and placeholders. NEVER bake in & ; | < > ( )
#      $ ` \ * ? or quote chars, since the shell would re-interpret them
#      AFTER this hook approves the command.
#   2. A bare ` ` matches exactly one ASCII space.
#   3. The entry must describe the ENTIRE command (^…$ is added for you).
#
# To add a new placeholder, define it as a bash variable above ALLOWED and
# extend `substitute` below to swap it in.

set -uo pipefail

# Package spec: optional @scope/, name, optional @version. SemVer chars only
# — no <, >, =, *, or whitespace, all of which need shell quoting and would
# create an injection surface.
PKG='(@[a-z0-9][a-z0-9._-]*/)?[a-z0-9][a-z0-9._-]*(@[a-zA-Z0-9._^~-]+)?'

ALLOWED=(
  'npm view <pkg>'
  'npm info <pkg>'
  'npm show <pkg>'
)

substitute() {
  local s=$1
  s=${s//<pkg>/${PKG}}
  printf '%s' "$s"
}

emit() {
  local decision=$1 reason=$2
  jq -nc --arg d "$decision" --arg r "$reason" \
    '{ hookSpecificOutput: { hookEventName: "PreToolUse", permissionDecision: $d, permissionDecisionReason: $r } }'
}

INPUT=$(cat) || exit 0
TOOL=$(jq -r '.tool_name // empty' <<<"$INPUT" 2>/dev/null) || exit 0
[ "$TOOL" = "Bash" ] || exit 0

CMD=$(jq -r '.tool_input.command // empty' <<<"$INPUT" 2>/dev/null) || exit 0
[ -z "$CMD" ] && exit 0

# Only act on commands whose first token is literally `npm`. Anything else
# (pnpm, yarn, bun, npx, anything containing $0/$@/$!, …) gets no decision so
# static rules in settings.json decide. Empirically (tested 2026-05-12) the
# `if: "Bash(npm *)"` clause on this hook is unreliable — it fires the hook
# for many commands that contain no `npm` substring at all (e.g. `echo $0`,
# `echo $@`, multi-line backgrounded commands with `$!`). This in-script
# guard is the real gate; do not remove it.
TRIMMED="${CMD#"${CMD%%[![:space:]]*}"}"
case "$TRIMMED" in
  npm|npm\ *) ;;
  *) exit 0 ;;
esac

for human in "${ALLOWED[@]}"; do
  pattern="^$(substitute "$human")\$"
  if [[ "$CMD" =~ $pattern ]]; then
    emit allow "allowlisted: $CMD"
    exit 0
  fi
done

LIST=$(printf '  • %s\n' "${ALLOWED[@]}")
emit deny "This npm invocation is not in the allow-list. Allowed shapes (must match the entire command):
${LIST}
where <pkg> is a lowercase package name with an optional @scope/ prefix and optional @version, containing only [a-z0-9._-] in the name and [a-zA-Z0-9._^~-] in the version. No flags, no extra args, no shell metacharacters.

If you genuinely need a different invocation, ask the user to add it to ~/.claude/hooks/allow-readonly-npm.sh — do not try to work around this hook."
exit 0
