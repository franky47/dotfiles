#!/usr/bin/env bash
set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
MACHINE_NAME="$(cat "${DOTFILES}/.machine-name" 2>/dev/null || hostname -s)"
LOCAL_CLAUDE="${DOTFILES}/local/${MACHINE_NAME}/claude"

echo "Installing dotfiles from ${DOTFILES}"
echo "Machine: ${MACHINE_NAME}"

# Check stow version >= 2.4 (--dotfiles bug in 2.3.x)
stow_version="$(stow --version 2>&1 | grep -oE '[0-9]+\.[0-9]+' | head -1)"
if [[ "$(printf '%s\n' "2.4" "$stow_version" | sort -V | head -1)" != "2.4" ]]; then
  echo "ERROR: stow >= 2.4 required (found ${stow_version}). Install with: brew install stow" >&2
  exit 1
fi

# Ensure target dirs exist so stow unfolds (per-file symlinks) instead of folding (one dir symlink)
mkdir -p ~/.claude/{skills,agents,hooks} ~/.agents/skills

# Stow: symlinks .zshrc, .zshenv, and dot-claude/ contents into ~
stow --dotfiles --restow -t ~ -d "${DOTFILES}" .
echo "Stow complete"

# Mirror shared skills into ~/.agents/skills/ (stow only targets ~/.claude/)
for d in "${DOTFILES}/dot-claude/skills/"*/; do
  [[ -d "$d" ]] || continue
  name="$(basename "$d")"
  ln -sfn "$d" ~/.agents/skills/"$name"
done
echo "Mirrored shared skills to ~/.agents/skills/"

# Symlink machine-local skills
if [[ -d "${LOCAL_CLAUDE}/skills" ]]; then
  for d in "${LOCAL_CLAUDE}/skills/"*/; do
    [[ -d "$d" ]] || continue
    name="$(basename "$d")"
    ln -sfn "$d" ~/.claude/skills/"$name"
    ln -sfn "$d" ~/.agents/skills/"$name"
    echo "Linked local skill: $name"
  done
fi

echo "Done"
