o() {
  opencode $1
}
alias ocup="opencode upgrade"

c() {
  claude --allow-dangerously-skip-permissions
}
cr() {
  claude --allow-dangerously-skip-permissions "/remote-control"
}
cw() {
  claude --allow-dangerously-skip-permissions -w $1
}
cwr() {
  claude --allow-dangerously-skip-permissions -w $1 "/remote-control"
}

alias bt='beans tui'
alias bl='beans list'

alias ghcu='gh copilot-usage'
alias usage='bunx tokscale'
alias ccusage='bunx ccusage'
alias ocmute='touch ~/.config/opencode/plugins/soundboard/mute'
alias ocunmute='rm -f ~/.config/opencode/plugins/soundboard/mute'
