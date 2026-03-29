#!/usr/bin/env bash
set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
MACHINE_NAME="$(cat "${DOTFILES}/.machine-name" 2>/dev/null || hostname -s)"
LOCAL_CLAUDE="${DOTFILES}/local/${MACHINE_NAME}/claude"

echo "${DOTFILES}" > ~/.dotfiles-path

echo "Installing dotfiles from ${DOTFILES}"
echo "Machine: ${MACHINE_NAME}"

# ---------------------------------------------------------------------------
# Prerequisites
# ---------------------------------------------------------------------------

check_prereqs() {
  local missing=0

  # Required — install fails without these
  if ! command -v stow &>/dev/null; then
    echo "ERROR: stow is required but not installed." >&2
    echo "  brew install stow" >&2
    missing=1
  else
    local stow_version
    stow_version="$(stow --version 2>&1 | grep -oE '[0-9]+\.[0-9]+' | head -1)"
    if [[ "$(printf '%s\n' "2.4" "$stow_version" | sort -V | head -1)" != "2.4" ]]; then
      echo "ERROR: stow >= 2.4 required (found ${stow_version})." >&2
      echo "  brew install stow" >&2
      missing=1
    fi
  fi

  if ! command -v git &>/dev/null; then
    echo "ERROR: git is required but not installed." >&2
    echo "  brew install git" >&2
    missing=1
  fi

  [[ $missing -ne 0 ]] && exit 1

  # Optional — dotfiles install fine but the configs won't be useful without these
  local warn=0

  if ! command -v difft &>/dev/null; then
    echo "WARN: difftastic (difft) not found — git diff will fall back to built-in diff."
    echo "  brew install difftastic"
    warn=1
  fi

  if ! command -v lazygit &>/dev/null; then
    echo "WARN: lazygit not found."
    echo "  brew install lazygit"
    warn=1
  fi

  if ! command -v git-lfs &>/dev/null; then
    echo "WARN: git-lfs not found — LFS filters in gitconfig won't work."
    echo "  brew install git-lfs"
    warn=1
  fi

  if ! command -v ghostty &>/dev/null; then
    echo "WARN: ghostty not found."
    echo "  https://ghostty.org/download"
    warn=1
  fi

  if ! command -v bat &>/dev/null; then
    echo "WARN: bat not found — 'cat' alias won't work."
    echo "  brew install bat"
    warn=1
  fi

  if ! command -v htop &>/dev/null; then
    echo "WARN: htop not found — 'top' alias won't work."
    echo "  brew install htop"
    warn=1
  fi

  if ! command -v fnm &>/dev/null; then
    echo "WARN: fnm not found — Node version management unavailable."
    echo "  brew install fnm"
    warn=1
  fi

  if ! command -v claude &>/dev/null; then
    echo "WARN: claude not found — Claude Code config won't be used."
    echo "  npm install -g @anthropic-ai/claude-code"
    warn=1
  fi

  [[ $warn -ne 0 ]] && echo ""
}

check_prereqs

# Ensure target dirs exist so stow unfolds (per-file symlinks) instead of folding (one dir symlink)
mkdir -p ~/.claude/{skills,agents,hooks} ~/.agents/skills ~/.config/jesseduffield/lazygit

# Stow: first run uses --adopt to pull existing files into the repo, then --restow for re-runs.
# --adopt moves conflicting files into the package dir so stow can create symlinks.
# After first install, review `git diff` to decide what to keep, move to local/, or revert.
if stow --dotfiles --restow -t ~ -d "${DOTFILES}" . 2>/dev/null; then
  echo "Stow complete"
else
  echo "Conflicts detected — adopting existing files into the repo"
  stow --dotfiles --adopt -t ~ -d "${DOTFILES}" .
  echo "Stow complete (adopted). Run 'git diff' to review adopted changes."
fi

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

echo "Done — to reload your shell, run:"
echo "source ~/.zshrc"
