#!/bin/bash
# PreToolUse hook for Bash. Pre-approves a *very* small allow-list of
# read-only invocations that LLMs reach for often. Any command whose first
# token is `npm` and doesn't match emits a structured `deny` decision whose
# reason text tells the agent exactly which shapes ARE allowed, so it can
# self-correct on the next turn without bothering the user. Everything else
# (pnpm, `echo npm`, env-prefixed npm, ...) gets no decision.
#
# To allow a new command verbatim, add a line to ALLOWED below. Each entry
# is a human-readable template. Placeholders in <angle-brackets> are
# substituted with the regex fragments defined above (<pkg>, <field>, <json>);
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

# Read-only field selector for `npm view <pkg> <field>` (e.g. version,
# versions, dist-tags.latest, dependencies). Must start with an alphanumeric
# (so it can never be read as a `-flag`/`--option` to npm), then word chars,
# dots and hyphens — deliberately NO brackets, so the shell can't glob-expand
# an approved command (e.g. `versions[0]`). Agents can fetch the whole field
# instead.
FIELD='[a-zA-Z0-9][a-zA-Z0-9._-]*'

# Optional ` --json` output flag. The parens/`?` here are regex syntax that
# exists only in this fragment, never in an ALLOWED template or in a matched
# command (which contains at most the harmless literal ` --json`), so header
# rule 1 is not violated.
JSON='( --json)?'

ALLOWED=(
  'npm view <pkg><json>'
  'npm view <pkg> <field><json>'
  'npm info <pkg><json>'
  'npm info <pkg> <field><json>'
  'npm show <pkg><json>'
  'npm show <pkg> <field><json>'
  'npm --version'
  'npm -v'
)

substitute() {
  local s=$1
  s=${s//<pkg>/${PKG}}
  s=${s//<field>/${FIELD}}
  s=${s//<json>/${JSON}}
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
# static rules in settings.json / bypassPermissions decide. This hook is
# wired with `if: "Bash(*npm*)"` (substring match), so it's only invoked for
# commands that contain "npm" — not every Bash call. The substring form (not
# the old `npm *` prefix) is deliberate: it also fires for ` npm install`
# (leading space), which a prefix glob would miss and thus let auto-run under
# bypassPermissions. Env-prefixed forms (`FOO=1 npm install`) still ABSTAIN
# here — their first token is not `npm` — and are accepted as out of scope,
# unlike in block-dangerous-git.sh which strips env prefixes.
# Over-firing on harmless matches
# (pnpm, an `echo "npm"`, …) is fine — this in-script guard abstains on them.
# This guard is the real gate; do not remove it.
TRIMMED="${CMD#"${CMD%%[![:space:]]*}"}"
case "$TRIMMED" in
  npm|npm[[:space:]]*) ;;
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
where <pkg> is a lowercase package name with an optional @scope/ prefix and optional @version (containing only [a-z0-9._-] in the name and [a-zA-Z0-9._^~-] in the version), <field> is a dotted field path like version / dist-tags.latest, and <json> is an optional trailing --json flag. One package per call (npm reads only the first); for several, query each separately. No other flags, no extra args, no shell metacharacters. The match starts at the command's first character: strip any leading whitespace.

If you genuinely need a different invocation, ask the user to add it to ~/.claude/hooks/allow-readonly-npm.sh — do not try to work around this hook."
exit 0
