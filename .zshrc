DOTFILES=$(cat ~/.dotfiles-path 2>/dev/null) || DOTFILES=${0:A:h}
MACHINE_NAME=${$(cat ${DOTFILES}/.machine-name 2>/dev/null):-$(hostname -s)}

for f in ${DOTFILES}/zsh/*.zsh(N); do source "$f"; done
for f in ${DOTFILES}/local/${MACHINE_NAME}/zsh/*.zsh(N); do source "$f"; done
