#!/bin/bash
# PreToolUse hook for Bash. Auto-approves a command chain that opens a DRAFT
# `gh pr create` targeting a repo owned by franky47 or 47ng. Everything it is
# not sure about gets no decision, so the `ask` rule in settings.json prompts
# as usual — this hook never denies.
#
# Why a chain and not a single command: agents bundle the PR with its setup —
#   cat > body <<'EOF' … EOF
#   git push -u origin branch && gh pr create --draft --body-file body …
# permissionDecision=allow approves the WHOLE string, and the harness splits a
# chain and checks each sub-command against settings.json rules; the only one
# that stops such a chain is `gh pr create` (an `ask` rule). To clear that one
# prompt the hook must vouch for the whole string, so it re-imposes a per-command
# discipline of its own:
#   - exactly one segment is a DRAFT `gh pr create` to an allowed owner, and it
#     tokenises cleanly (so it carries no substitution/redirection/globbing);
#   - every other segment is a recognised setup command (see `safe_preamble`):
#       cd, mkdir, touch, true, :, echo, printf;
#       git restricted to a safe sub-command (no `git -c …`, which runs aliases);
#       cat/tee/echo/printf writing a file — but with NO substitution ($(), ``,
#       $VAR, <()), so only a literal redirect target is written.
# Anything else (rm, npm, another `ask` command, a `gh` with substitution, an
# unlisted git sub-command) is unknown → abstain → the user is prompted. A draft
# PR riding along therefore cannot launder an unfamiliar command past review.
# The residual power granted to an approved chain is: write a literal path via a
# file-writer, and a fixed set of git/dir sub-commands — which for this repo's
# owner is already covered by settings.json (bypassPermissions + cat/git allow
# rules), and the deny rules (sudo, curl|sh, …) remain a harness-level backstop
# regardless of this hook. Threat model is an inattentive agent, not an
# adversary (same stance as block-dangerous-git.sh).
#
# Parsing, in order:
#   1. strip heredoc bodies. Detection is quote-aware and skips here-strings
#      (`<<<`): only an UNQUOTED `<<WORD` is a real heredoc, and its body is
#      data the shell never executes. A `<<` inside quotes (e.g. in a --title)
#      is not a heredoc, so its following lines stay in the command and are
#      judged like any other segment — never silently dropped.
#   2. split into segments on top-level ; && || | & and newlines, honouring
#      single/double quotes so a separator inside a --title is not a split.
#   3. tokenise each segment under a strict grammar where every character is
#        - a bare word of [A-Za-z0-9@%+,./:=_~-]
#        - a single-quoted string (the shell expands nothing inside)
#        - a double-quoted string containing none of  " $ \ ` !
#      A segment with any other metacharacter (a redirect, a substitution) does
#      not tokenise; it is trusted only via the opaque file-writer path above.
#
# The target repo comes from `--repo <value>`/`--repo=<value>`, else from
# `gh repo view` in the effective cwd — the last `cd <dir>` in the chain, or the
# session cwd. A fork's parent is where the PR lands by default, so the parent
# owner is checked; a parent whose owner cannot be resolved abstains rather than
# falling back to the fork's own owner.
#
# Only flags the scanner fully models are accepted; anything else abstains.
# Short flags: pflag accepts spellings this scanner does not model (-Rx, -R=x,
# combined -fR clusters), and a misparsed target repo must never fall back to
# cwd resolution while gh sends the PR elsewhere. Same for --repo with a
# missing/empty value. Unknown long flags: a future gh value-taking flag would
# swallow the next word, so `--newflag --draft` would read as draft here while
# gh creates a non-draft PR — vocabulary drift must fail toward prompting. Ditto
# `--draft=false` after `--draft` (pflag is last-wins). --web and --editor are
# deliberately not allow-listed: --web hands draft-ness to the browser, --editor
# hangs in a headless shell. The flag lists mirror `gh pr create --help` and
# must be kept in sync.

set -uo pipefail

ALLOWED_OWNERS='franky47|47ng'

BARE='[A-Za-z0-9@%+,./:=_~-]+'
SQ="'[^']*'"
DQ='"[^"$\`!]*"'

emit_allow() {
  jq -nc --arg r "$1" \
    '{ hookSpecificOutput: { hookEventName: "PreToolUse", permissionDecision: "allow", permissionDecisionReason: $r } }'
}

# Find heredoc openers on one line, quote-aware and carrying quote state in via
# $2 / out via QOUT. Fills HD_DELIMS/HD_DASHES with the delimiters an UNQUOTED
# `<<WORD` (not `<<<`) introduces. Only these are real heredocs, so dropping
# their bodies always matches the shell — a quoted `<<`, or a `<<` past an
# unquoted `#` comment, is left in place so its lines are still judged.
scan_heredocs() {
  local line=$1 q=$2 L=${#1} i=0 c j dash qc word pc
  HD_DELIMS=() HD_DASHES=()
  while [ "$i" -lt "$L" ]; do
    c=${line:i:1}
    if [ "$q" = "'" ]; then
      [ "$c" = "'" ] && q=''
      i=$((i + 1)); continue
    fi
    if [ "$q" = '"' ]; then
      [ "$c" = '\' ] && { i=$((i + 2)); continue; }
      [ "$c" = '"' ] && q=''
      i=$((i + 1)); continue
    fi
    case "$c" in
      "'") q="'"; i=$((i + 1)) ;;
      '"') q='"'; i=$((i + 1)) ;;
      '\') i=$((i + 2)) ;;
      '#')
        [ "$i" = 0 ] && break
        pc=${line:$((i - 1)):1}
        { [ "$pc" = ' ' ] || [ "$pc" = $'\t' ]; } && break
        i=$((i + 1)) ;;
      '<')
        if [ "${line:i+1:1}" != '<' ]; then i=$((i + 1)); continue; fi
        if [ "${line:i+2:1}" = '<' ]; then i=$((i + 3)); continue; fi
        j=$((i + 2)) dash=0
        [ "${line:j:1}" = '-' ] && { dash=1; j=$((j + 1)); }
        while [ "${line:j:1}" = ' ' ] || [ "${line:j:1}" = $'\t' ]; do j=$((j + 1)); done
        qc=${line:j:1}
        { [ "$qc" = "'" ] || [ "$qc" = '"' ]; } && j=$((j + 1))
        word=''
        while [[ ${line:j:1} =~ [A-Za-z0-9_] ]]; do word+=${line:j:1}; j=$((j + 1)); done
        if [ -n "$word" ]; then
          HD_DELIMS[${#HD_DELIMS[@]}]=$word
          HD_DASHES[${#HD_DASHES[@]}]=$dash
        fi
        i=$j ;;
      *) i=$((i + 1)) ;;
    esac
  done
  QOUT=$q
}

# Drop heredoc bodies and their closing delimiter lines, keeping the command
# lines. Delimiters close FIFO; leading blanks are stripped before comparison,
# which can only close earlier than the shell (keeping more lines → abstain).
strip_heredocs() {
  local input=$1 out='' line d dash cmp k
  local pend_delim=() pend_dash=() pi=0 qcarry=''
  while IFS= read -r line || [ -n "$line" ]; do
    if [ "$pi" -lt "${#pend_delim[@]}" ]; then
      d=${pend_delim[$pi]} dash=${pend_dash[$pi]}
      cmp=${line#"${line%%[![:blank:]]*}"}
      [ "$dash" = 0 ] && [ "$line" != "$d" ] && cmp=$line
      [ "$cmp" = "$d" ] && pi=$((pi + 1))
      continue
    fi
    scan_heredocs "$line" "$qcarry"
    qcarry=$QOUT
    k=0
    while [ "$k" -lt "${#HD_DELIMS[@]}" ]; do
      pend_delim[${#pend_delim[@]}]=${HD_DELIMS[$k]}
      pend_dash[${#pend_dash[@]}]=${HD_DASHES[$k]}
      k=$((k + 1))
    done
    out+="$line"$'\n'
  done <<<"$input"
  printf '%s' "$out"
}

# Split into top-level command segments (result in SEGMENTS), honouring quotes.
split_segments() {
  SEGMENTS=()
  local s=$1
  local len=${#s} i=0 c seg='' q=''
  while [ "$i" -lt "$len" ]; do
    c=${s:i:1}
    if [ -n "$q" ]; then
      seg+=$c
      [ "$c" = "$q" ] && q=''
      i=$((i + 1))
      continue
    fi
    case "$c" in
      "'"|'"') q=$c; seg+=$c; i=$((i + 1)) ;;
      ';'|$'\n') SEGMENTS+=("$seg"); seg=''; i=$((i + 1)) ;;
      '&') if [ "${s:$((i + 1)):1}" = '&' ]; then i=$((i + 2)); else i=$((i + 1)); fi
           SEGMENTS+=("$seg"); seg='' ;;
      '|') if [ "${s:$((i + 1)):1}" = '|' ]; then i=$((i + 2)); else i=$((i + 1)); fi
           SEGMENTS+=("$seg"); seg='' ;;
      *) seg+=$c; i=$((i + 1)) ;;
    esac
  done
  SEGMENTS+=("$seg")
}

# Tokenise $1 into TOKENS under the strict grammar; return 1 if any character
# falls outside it (a metacharacter, an unterminated quote).
tokenize() {
  TOKENS=()
  local rest=$1 word seg matched
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
    [ "$matched" = 1 ] || return 1
    TOKENS+=("$word")
  done
  return 0
}

# A tokenised `git …` segment is safe only for a fixed set of sub-commands, and
# never with a leading global flag (`git -c alias.x=!cmd …` runs arbitrary code,
# `git -C` redirects the repo — both land as TOKENS[1] and fail the case). The
# only remaining ways a listed sub-command runs a command are the transport
# overrides `--upload-pack`/`--receive-pack` (push/pull/fetch; `--exec` is
# push's documented synonym for `--receive-pack`); those are long-only, and git
# accepts any unambiguous PREFIX of a long option, so the
# test is prefix containment, not equality (`--upload-pac=…` reaches the same
# code as the full spelling). A stray literal value starting with `--` may
# abstain — the safe direction. `rebase` is deliberately NOT listed: its `-x`
# short option attaches (`-xCMD`) and bundles (`-fx CMD`), spellings a deny-list
# cannot reliably catch; dropping the sub-command removes the vector outright.
# clone/init are likewise omitted (not pre-PR steps; clone's `-u` is a short
# --upload-pack). TOKENS is set by the caller's tokenize().
git_safe() {
  case "${TOKENS[1]:-}" in
    push|pull|fetch|switch|checkout|branch|add|commit|status|stash|\
    restore|tag|merge|reset|rm|mv|remote|worktree) ;;
    *) return 1 ;;
  esac
  local w flag
  for w in "${TOKENS[@]}"; do
    flag=${w%%=*}
    case "$flag" in
      --?*)
        if [[ --upload-pack == "$flag"* ]] || [[ --receive-pack == "$flag"* ]] \
          || [[ --exec == "$flag"* ]]; then
          return 1
        fi ;;
    esac
  done
  return 0
}

# A non-gh chain segment is safe iff it is a recognised setup command. A
# tokenised segment is judged by its verb (git further restricted); an opaque
# one (a redirect/heredoc, e.g. `cat > body <<'EOF'`) only if its verb is a file
# writer AND it has no substitution, so a literal redirect target is its only
# extra effect.
safe_preamble() {
  local seg=$1
  if tokenize "$seg"; then
    case "${TOKENS[0]:-}" in
      cd|mkdir|touch|echo|printf|true|:) return 0 ;;
      git) git_safe; return ;;
      *) return 1 ;;
    esac
  fi
  case "$seg" in
    *'$'*|*'`'*|*'<('*|*'>('*) return 1 ;;
  esac
  [[ $seg =~ ^[[:blank:]]*(cat|tee|echo|printf)([[:blank:]]|$) ]]
}

# Scan a tokenised `gh pr create …` (in "$@") for draft-ness and target repo.
# Sets gh_draft/gh_repo; returns 1 on any flag the scanner does not fully model.
scan_gh() {
  gh_draft=0 gh_repo=''
  local a=("$@") n=$# i=3 w
  while [ "$i" -lt "$n" ]; do
    w=${a[$i]}
    case "$w" in
      --draft) gh_draft=1 ;;
      --repo) i=$((i + 1)); gh_repo=${a[$i]:-}; [ -n "$gh_repo" ] || return 1 ;;
      --repo=*) gh_repo=${w#--repo=}; [ -n "$gh_repo" ] || return 1 ;;
      --assignee|--base|--body|--body-file|--head|--label|\
      --milestone|--project|--reviewer|--template|--title|--recover)
        i=$((i + 1)); [ "$i" -lt "$n" ] || return 1 ;;
      --fill|--fill-first|--fill-verbose|--dry-run|--no-maintainer-edit) ;;
      -*) return 1 ;;
    esac
    i=$((i + 1))
  done
  return 0
}

INPUT=$(cat) || exit 0
TOOL=$(jq -r '.tool_name // empty' <<<"$INPUT" 2>/dev/null) || exit 0
[ "$TOOL" = "Bash" ] || exit 0
CMD=$(jq -r '.tool_input.command // empty' <<<"$INPUT" 2>/dev/null) || exit 0
[ -z "$CMD" ] && exit 0

split_segments "$(strip_heredocs "$CMD")"

gh_seen=0
draft=0
repo=''
cd_dir=''
for seg in "${SEGMENTS[@]}"; do
  seg=${seg#"${seg%%[![:blank:]]*}"}
  seg=${seg%"${seg##*[![:blank:]]}"}
  [ -n "$seg" ] || continue
  if tokenize "$seg" \
    && [ "${TOKENS[0]:-}" = gh ] && [ "${TOKENS[1]:-}" = pr ] && [ "${TOKENS[2]:-}" = create ]; then
    gh_seen=$((gh_seen + 1))
    [ "$gh_seen" -gt 1 ] && exit 0
    scan_gh "${TOKENS[@]}" || exit 0
    draft=$gh_draft
    repo=$gh_repo
    continue
  fi
  safe_preamble "$seg" || exit 0
  if tokenize "$seg" && [ "${TOKENS[0]:-}" = cd ]; then
    cd_dir=${TOKENS[1]:-}
  fi
done

[ "$gh_seen" -eq 1 ] || exit 0
[ "$draft" = 1 ] || exit 0

if [ -n "$repo" ]; then
  [[ $repo =~ ^(${ALLOWED_OWNERS})/[A-Za-z0-9._-]+$ ]] || exit 0
  emit_allow "draft PR to $repo auto-allowed"
  exit 0
fi

CWD=${cd_dir:-$(jq -r '.cwd // empty' <<<"$INPUT" 2>/dev/null)} || exit 0
case "$CWD" in
  '~') CWD=$HOME ;;
  '~/'*) CWD=$HOME/${CWD#'~/'} ;;
esac
[ -d "$CWD" ] || exit 0
info=$(cd "$CWD" 2>/dev/null && gh repo view --json owner,parent 2>/dev/null) || exit 0
owner=$(jq -r 'if .parent == null then .owner.login // empty else .parent.owner.login // empty end' <<<"$info" 2>/dev/null) || exit 0
[[ $owner =~ ^(${ALLOWED_OWNERS})$ ]] || exit 0
emit_allow "draft PR to $owner repo (resolved from git remote) auto-allowed"
exit 0
