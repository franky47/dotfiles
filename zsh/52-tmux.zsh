alias tn='tmux new -s'
alias tls='tmux ls'
alias tk='tmux kill-session -t'
alias ts='tmux switch-client -t'
alias trs='tmux rename-session'

ta() {
  tmux new-session -A -s "${1:-$(basename "$PWD")}"
}

# Auto-attach SSH sessions to a shared tmux session so disconnects don't kill work.
if [[ $- == *i* ]] && [[ -n "$SSH_CONNECTION" ]] && [[ -z "$TMUX" ]]; then
    tmux new-session -A -s ssh
fi
