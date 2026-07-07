#!/bin/bash
# PreToolUse hook for Bash. Auto-approves `gh pr create` when the PR is a
# DRAFT targeting a repo owned by franky47 or 47ng. Everything else gets no
# decision, so the `ask` rule in settings.json prompts as usual — this hook
# never denies.
#
# Safety: permissionDecision=allow approves the WHOLE command string, which
# the shell then re-interprets. So before any semantic check, the command
# must tokenize under a strict grammar where every character belongs to
#   - a bare word of [A-Za-z0-9@%+,./:=_~-]
#   - a single-quoted string (the shell expands nothing inside)
#   - a double-quoted string containing none of  " $ \ ` !
# separated by blanks (never unquoted newlines — those separate commands in
# the shell). No metacharacter can appear outside quotes, so an
# approved command is a single simple command — no chaining, substitution,
# redirection or globbing. Commands that don't fit (notably the
# --body "$(cat <<'EOF'…)" idiom) abstain; agents should use --body-file.
#
# The target repo comes from `--repo <value>` or `--repo=<value>` when
# present, otherwise from `gh repo view` in the session cwd. A fork's parent
# is where the PR lands by default, so the parent owner is what gets checked;
# a parent whose owner cannot be resolved abstains rather than falling back
# to the fork's own owner.
#
# Only flags the scanner fully models are accepted; anything else abstains.
# Short flags: pflag accepts spellings this scanner does not model (-Rx,
# -R=x, combined -fR clusters), and a misparsed target repo must never fall
# back to cwd resolution while gh sends the PR elsewhere. Same reasoning for
# --repo with a missing/empty value. Unknown long flags: a future gh
# value-taking flag would swallow the next word, so `--newflag --draft`
# would read as draft here while gh creates a non-draft PR — vocabulary
# drift must fail toward prompting. Ditto `--draft=false` after `--draft`
# (pflag is last-wins). --web and --editor are deliberately not allow-listed:
# --web hands draft-ness to the browser, --editor hangs in a headless shell.
#
# Flag scan skips the value after each value-taking flag, so `--title
# --draft` (a NON-draft PR titled "--draft") is not mistaken for a draft.
# Both flag lists mirror `gh pr create --help` and must be kept in sync.
# Threat model is an inattentive agent, not an adversary (same stance as
# block-dangerous-git.sh).

set -uo pipefail

ALLOWED_OWNERS='franky47|47ng'

emit_allow() {
  jq -nc --arg r "$1" \
    '{ hookSpecificOutput: { hookEventName: "PreToolUse", permissionDecision: "allow", permissionDecisionReason: $r } }'
}

INPUT=$(cat) || exit 0
TOOL=$(jq -r '.tool_name // empty' <<<"$INPUT" 2>/dev/null) || exit 0
[ "$TOOL" = "Bash" ] || exit 0
CMD=$(jq -r '.tool_input.command // empty' <<<"$INPUT" 2>/dev/null) || exit 0
[ -z "$CMD" ] && exit 0

BARE='[A-Za-z0-9@%+,./:=_~-]+'
SQ="'[^']*'"
DQ='"[^"$\`!]*"'

# Tokenize into words, concatenating adjacent segments (--repo='x' is one
# word) and stripping quotes so semantic checks see unquoted values.
words=()
rest=$CMD
while [ -n "$rest" ]; do
  if [[ $rest =~ ^[[:blank:]]+ ]]; then
    rest=${rest:${#BASH_REMATCH[0]}}
    continue
  fi
  word='' matched=0
  while :; do
    if [[ $rest =~ ^$BARE ]]; then
      seg=${BASH_REMATCH[0]}
      word+=$seg
    elif [[ $rest =~ ^$SQ ]] || [[ $rest =~ ^$DQ ]]; then
      seg=${BASH_REMATCH[0]}
      word+=${seg:1:$((${#seg} - 2))}
    else
      break
    fi
    rest=${rest:${#seg}}
    matched=1
  done
  [ "$matched" = 1 ] || exit 0
  words+=("$word")
done

[ "${words[0]:-}" = gh ] || exit 0
[ "${words[1]:-}" = pr ] || exit 0
[ "${words[2]:-}" = create ] || exit 0

draft=0
repo=''
i=3
n=${#words[@]}
while [ "$i" -lt "$n" ]; do
  w=${words[$i]}
  case "$w" in
    --draft) draft=1 ;;
    --repo) i=$((i + 1)); repo=${words[$i]:-}; [ -n "$repo" ] || exit 0 ;;
    --repo=*) repo=${w#--repo=}; [ -n "$repo" ] || exit 0 ;;
    --assignee|--base|--body|--body-file|--head|--label|\
    --milestone|--project|--reviewer|--template|--title|--recover)
      i=$((i + 1)); [ "$i" -lt "$n" ] || exit 0 ;;
    --fill|--fill-first|--fill-verbose|--dry-run|--no-maintainer-edit) ;;
    -*) exit 0 ;;
  esac
  i=$((i + 1))
done
[ "$draft" = 1 ] || exit 0

if [ -n "$repo" ]; then
  [[ $repo =~ ^(${ALLOWED_OWNERS})/[A-Za-z0-9._-]+$ ]] || exit 0
  emit_allow "draft PR to $repo auto-allowed"
  exit 0
fi

CWD=$(jq -r '.cwd // empty' <<<"$INPUT" 2>/dev/null) || exit 0
[ -d "$CWD" ] || exit 0
info=$(cd "$CWD" 2>/dev/null && gh repo view --json owner,parent 2>/dev/null) || exit 0
owner=$(jq -r 'if .parent == null then .owner.login // empty else .parent.owner.login // empty end' <<<"$info" 2>/dev/null) || exit 0
[[ $owner =~ ^(${ALLOWED_OWNERS})$ ]] || exit 0
emit_allow "draft PR to $owner repo (resolved from git remote) auto-allowed"
exit 0
