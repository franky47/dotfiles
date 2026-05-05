alias tn='tmux new -s'
alias tls='tmux ls'
alias tk='tmux kill-session -t'
alias ts='tmux switch-client -t'
alias trs='tmux rename-session'

ta() {
  tmux new-session -A -s "${1:-$(basename "$PWD")}"
}
