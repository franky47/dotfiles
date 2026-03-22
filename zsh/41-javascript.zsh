# FNM - https://github.com/Schniz/fnm
eval "$(fnm env --shell zsh)"

# Bun
export BUN_INSTALL=~/.bun
export PATH=$BUN_INSTALL/bin:$PATH
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

alias b='bun'
alias bi='bun install'
alias ba='bun add'
alias br='bun remove'
alias bad='bun add -D'
alias bur='bunx taze -r'
alias bx='bunx'

# PNPM
export PNPM_HOME="$HOME/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac

alias p='pnpm'
alias pi='pnpm install'
alias pa='pnpm add'
alias pr='pnpm remove'
alias pad='pnpm add -D'
alias pur='pnpm dlx taze -r'
alias px='pnpm dlx'
