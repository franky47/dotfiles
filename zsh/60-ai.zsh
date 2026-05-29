o() {
  opencode "$@"
}
alias ocup="opencode upgrade"

c() {
  claude --dangerously-skip-permissions "$@"
}
cr() {
  claude --dangerously-skip-permissions "/remote-control" "$@"
}
cw() {
  claude --dangerously-skip-permissions -w "${1//\//-S-}" "${@:2}"
}
cwr() {
  claude --dangerously-skip-permissions -w "${1//\//-S-}" "/remote-control" "${@:2}"
}
_claude_worktree_completions() {
  local branches=()
  local current=$(git branch --show-current 2>/dev/null)
  while IFS= read -r line; do
    [[ "$line" =~ ^branch\ refs/heads/(.+)$ ]] && [[ "${match[1]}" != "$current" ]] && \
      branches+=("${match[1]}")
  done < <(git worktree list --porcelain 2>/dev/null)
  _describe 'worktree branch' branches
}
compdef _claude_worktree_completions cw cwr

alias bt='beans tui'
alias bl='beans list'

alias ghcu='gh copilot-usage'
alias usage='bunx tokscale'
alias ccusage='bunx ccusage'
alias ocmute='touch ~/.config/opencode/plugins/soundboard/mute'
alias ocunmute='rm -f ~/.config/opencode/plugins/soundboard/mute'

# Pi coding agent — invoked via π
π() {
  : ${PI_BIN:=$(command npm prefix -g)/bin/pi}
  "$PI_BIN" "$@"
}

# ds4 local inference server (DeepSeek V4 Flash on Metal)
ds4() {
  (cd "$HOME/dev/playground/ai/ds4" && exec ./ds4-server \
    --port 9999 \
    --ctx 131072 \
    --kv-disk-dir ./kv-cache \
    --kv-disk-space-mb 20000 \
    "$@")
}
