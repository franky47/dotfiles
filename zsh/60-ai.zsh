o() {
  opencode $1
}
alias ocup="opencode upgrade"

c() {
  claude --dangerously-skip-permissions
}
cr() {
  claude --dangerously-skip-permissions "/remote-control"
}
cw() {
  claude --dangerously-skip-permissions -w "${1//\//-S-}"
}
cwr() {
  claude --dangerously-skip-permissions -w "${1//\//-S-}" "/remote-control"
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
