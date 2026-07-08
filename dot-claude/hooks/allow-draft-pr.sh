#!/bin/bash
# PreToolUse hook for Bash. Auto-approves a command that opens DRAFT
# `gh pr create` PRs, every one targeting a repo owned by franky47 or 47ng.
# Anything it is unsure about gets no decision, so the `ask` rule in
# settings.json prompts as usual — this hook never denies.
#
# Design — parse, don't validate. permissionDecision=allow re-runs the WHOLE
# string, but this shell already runs under `defaultMode: bypassPermissions`,
# so the surrounding commands (git push, cat, a body heredoc) run regardless of
# this hook, and the `deny` rules (sudo, curl|sh, …) still block regardless of
# it. So the hook does not police the preamble — a losing race against shell
# syntax. It only answers one question: is every `gh pr create` in this command
# a draft to a repo I own? It PARSES each such command out and reads its
# structural flags; everything else is ignored.
#
# What "parse" means here:
#   - Split into top-level command segments on ; && || | & and newlines,
#     honouring quotes, so a `gh pr create` inside a --title/--body value (the
#     quote groups it) is never mistaken for a command.
#   - A segment whose first word is `gh pr create` is a PR command. Read its
#     flags left to right, stopping at --title/--body/--body-file — --draft and
#     --repo always precede the free-text region, which may hold heredocs and
#     substitutions we deliberately never parse.
#   - Require at least one PR command, and every one draft + owned. A second,
#     non-draft or foreign `gh pr create` bundled in the chain makes the whole
#     thing abstain.
#
# Owner comes from `--repo owner/repo`/`--repo=…`; else it is resolved LOCALLY
# from `git remote get-url origin` in the effective cwd (the last `cd` in the
# chain, or the session cwd) — no network call, so it does not flake. A `-R`
# short repo flag we do not parse forces an abstain rather than a cwd fallback
# that would vouch for the wrong repo. Threat model is an inattentive agent,
# not an adversary (same stance as block-dangerous-git.sh).

set -uo pipefail

ALLOWED='franky47|47ng'

emit_allow() {
  jq -nc --arg r "$1" \
    '{ hookSpecificOutput: { hookEventName: "PreToolUse", permissionDecision: "allow", permissionDecisionReason: $r } }'
}

# Split $1 into top-level command segments (SEG[]) so each `gh pr create`
# surfaces as its own segment. Honours single/double quotes (a separator inside
# a quoted value does not split), backslash escapes (`\'`/`\"` are literal, not
# quotes), and treats subshell `( … )` boundaries as separators so a `cd` or a
# `$(gh …)` inside them is not hidden from the scan.
split_top() {
  SEG=()
  local s=$1
  local n=${#s} i=0 c q='' cur=''
  while [ "$i" -lt "$n" ]; do
    c=${s:i:1}
    if [ -n "$q" ]; then
      if [ "$q" = '"' ] && [ "$c" = '\' ]; then cur+=$c${s:$((i + 1)):1}; i=$((i + 2)); continue; fi
      cur+=$c
      [ "$c" = "$q" ] && q=''
      i=$((i + 1)); continue
    fi
    case "$c" in
      '\') cur+=$c${s:$((i + 1)):1}; i=$((i + 2)) ;;
      "'"|'"') q=$c; cur+=$c; i=$((i + 1)) ;;
      ';'|$'\n'|'('|')') SEG+=("$cur"); cur=''; i=$((i + 1)) ;;
      '&'|'|')
        [ "${s:$((i + 1)):1}" = "$c" ] && i=$((i + 2)) || i=$((i + 1))
        SEG+=("$cur"); cur='' ;;
      *) cur+=$c; i=$((i + 1)) ;;
    esac
  done
  SEG+=("$cur")
}

# Tokenise a segment into words (WORDS[]), quote-aware and permissive: quotes
# are stripped, every other character is literal. Enough to read a command's
# leading verb and its structural flags.
toks() {
  WORDS=()
  local s=$1
  local n=${#s} i=0 c q='' w='' inw=0
  while [ "$i" -lt "$n" ]; do
    c=${s:i:1}
    if [ -n "$q" ]; then
      if [ "$q" = '"' ] && [ "$c" = '\' ]; then w+=${s:$((i + 1)):1}; inw=1; i=$((i + 2)); continue; fi
      [ "$c" = "$q" ] && q='' || w+=$c
      inw=1; i=$((i + 1)); continue
    fi
    case "$c" in
      '\') w+=${s:$((i + 1)):1}; inw=1; i=$((i + 2)) ;;
      ' '|$'\t'|$'\n') [ "$inw" = 1 ] && { WORDS+=("$w"); w=''; inw=0; }; i=$((i + 1)) ;;
      "'"|'"') q=$c; inw=1; i=$((i + 1)) ;;
      *) w+=$c; inw=1; i=$((i + 1)) ;;
    esac
  done
  [ "$inw" = 1 ] && WORDS+=("$w")
}

# Parse a `gh pr create` segment (WORDS already set). Returns 1 if it is not
# one. Otherwise sets PR_DRAFT, PR_REPO, and PR_BAD=1 when the command carries a
# short flag — gh may consume the next word as that flag's value (`-t --draft`
# makes a NON-draft PR titled "--draft"), which this long-flag-only scanner
# cannot model, so the caller must abstain. Reading stops at --title/--body:
# --draft/--repo always precede the free-text region, and stopping can only miss
# a real --draft (abstain), never invent one.
parse_pr() {
  [ "${WORDS[0]:-}" = gh ] && [ "${WORDS[1]:-}" = pr ] && [ "${WORDS[2]:-}" = create ] || return 1
  PR_DRAFT=0 PR_REPO='' PR_BAD=0
  local i=3 n=${#WORDS[@]} w
  while [ "$i" -lt "$n" ]; do
    w=${WORDS[$i]}
    case "$w" in
      --draft) PR_DRAFT=1 ;;
      --repo) i=$((i + 1)); PR_REPO=${WORDS[$i]:-}; [ -n "$PR_REPO" ] || PR_REPO='-' ;;
      --repo=*) PR_REPO=${w#--repo=}; [ -n "$PR_REPO" ] || PR_REPO='-' ;;
      --title|--body|--body-file) break ;;
      --base|--head|--label|--milestone|--assignee|--reviewer|--project|--template|--recover)
        i=$((i + 1)) ;;
      --*) ;;
      -?*) PR_BAD=1 ;;
    esac
    i=$((i + 1))
  done
  return 0
}

# Is $1 (owner/repo, or empty to resolve from the git remote) owned by me?
owner_ok() {
  local repo=$1 dir url owner
  if [ -n "$repo" ]; then
    [[ $repo =~ ^(${ALLOWED})/[A-Za-z0-9._-]+$ ]]
    return
  fi
  dir=${CD_DIR:-$CWD}
  case "$dir" in '~') dir=$HOME ;; '~/'*) dir=$HOME/${dir#'~/'} ;; esac
  [ -d "$dir" ] || return 1
  url=$(git -C "$dir" remote get-url origin 2>/dev/null) || return 1
  [[ $url =~ github\.com[:/]([^/]+)/ ]] || return 1
  owner=${BASH_REMATCH[1]}
  [[ $owner =~ ^(${ALLOWED})$ ]]
}

INPUT=$(cat) || exit 0
[ "$(jq -r '.tool_name // empty' <<<"$INPUT" 2>/dev/null)" = Bash ] || exit 0
CMD=$(jq -r '.tool_input.command // empty' <<<"$INPUT" 2>/dev/null) || exit 0
[ -n "$CMD" ] || exit 0
CWD=$(jq -r '.cwd // empty' <<<"$INPUT" 2>/dev/null) || exit 0

split_top "$CMD"

CD_DIR=''
found=0
for seg in "${SEG[@]}"; do
  toks "$seg"
  [ "${WORDS[0]:-}" = cd ] && [ -n "${WORDS[1]:-}" ] && CD_DIR=${WORDS[1]}
  parse_pr || continue
  found=$((found + 1))
  [ "$PR_BAD" = 0 ] || exit 0
  [ "$PR_DRAFT" = 1 ] || exit 0
  owner_ok "$PR_REPO" || exit 0
done

[ "$found" -ge 1 ] || exit 0
emit_allow "draft PR(s) to an owned repo auto-allowed"
exit 0
