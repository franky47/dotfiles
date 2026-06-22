# SHELL= points lazygit's `:` prompt / customCommands at an interactive zsh
# wrapper so they load ~/.zshrc (aliases + functions), just like a terminal.
alias g='SHELL=$HOME/.local/bin/lazygit-shell lazygit'
alias gl='git log --graph --oneline -n 10'
alias gll='git log --graph -n 5'
alias gls='git log --oneline -n 20'
alias grpo='git remote prune origin'
alias gpfl='git push --force-with-lease'
alias d='hunk diff'
alias hd='~/.bun/bin/bun run ~/dev/floss/hunk/src/main.tsx --'
