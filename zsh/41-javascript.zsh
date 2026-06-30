# FNM - https://github.com/Schniz/fnm
eval "$(fnm env --shell zsh)"

# fnm (above) prepends the active Node version's bin, which ships a bundled npm.
# Keep our globally-installed npm/npx (~/.npm-packages) ahead of it so the npm
# CLI is pinned independent of the Node version. node still resolves to fnm.
export PATH="$HOME/.npm-packages/bin:${PATH//$HOME\/.npm-packages\/bin:/}"

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

# PNPM — global package bins live in $PNPM_HOME/bin (pnpm >= 8)
export PNPM_HOME="$HOME/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME/bin:"*) ;;
  *) export PATH="$PNPM_HOME/bin:$PATH" ;;
esac

alias p='pnpm'
alias pi='pnpm install'
alias pa='pnpm add'
alias pr='pnpm remove'
alias pad='pnpm add -D'
alias pur='pnpm dlx taze -r'
alias px='pnpm dlx'
