# Docker Desktop CLI tools.
export PATH="$PATH:$HOME/.docker/bin"

if command -v brew >/dev/null 2>&1; then
  eval "$(brew shellenv)"
fi

# Select the nearest repository's Node version in login shells, including agents.
if command -v fnm >/dev/null 2>&1; then
  eval "$(fnm env --shell zsh --use-on-cd --version-file-strategy recursive)"
fi
