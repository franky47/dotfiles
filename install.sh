#!/usr/bin/env bash
set -euo pipefail

YELLOW=$'\033[33m'
RESET=$'\033[0m'

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
    echo "${YELLOW}WARN:${RESET} difftastic (difft) not found — git diff will fall back to built-in diff."
    echo "  brew install difftastic"
    warn=1
  fi

  if ! command -v lazygit &>/dev/null; then
    echo "${YELLOW}WARN:${RESET} lazygit not found."
    echo "  brew install lazygit"
    warn=1
  fi

  if ! command -v ghostty &>/dev/null; then
    echo "${YELLOW}WARN:${RESET} ghostty not found."
    echo "  https://ghostty.org/download"
    warn=1
  fi

  if ! command -v bat &>/dev/null; then
    echo "${YELLOW}WARN:${RESET} bat not found — 'cat' alias won't work."
    echo "  brew install bat"
    warn=1
  fi

  if ! command -v htop &>/dev/null; then
    echo "${YELLOW}WARN:${RESET} htop not found — 'top' alias won't work."
    echo "  brew install htop"
    warn=1
  fi

  if ! command -v fnm &>/dev/null; then
    echo "${YELLOW}WARN:${RESET} fnm not found — Node version management unavailable."
    echo "  brew install fnm"
    warn=1
  fi

  if ! command -v claude &>/dev/null; then
    echo "${YELLOW}WARN:${RESET} claude not found — Claude Code config won't be used."
    echo "  npm install -g @anthropic-ai/claude-code"
    warn=1
  fi

  if [[ "${MACHINE_NAME}" == "m4x" ]]; then
    if ! command -v llama-swap &>/dev/null; then
      echo "${YELLOW}WARN:${RESET} llama-swap not found — model swap daemon unavailable."
      echo "  brew install llama-swap"
      warn=1
    fi

    if ! command -v llama-server &>/dev/null; then
      echo "${YELLOW}WARN:${RESET} llama-server not found — llama.cpp unavailable."
      echo "  brew install llama.cpp"
      warn=1
    fi
  fi

  [[ $warn -ne 0 ]] && echo "" || true
}

check_prereqs

# Ensure target dirs exist so stow unfolds (per-file symlinks) instead of folding (one dir symlink)
mkdir -p ~/.claude/{skills,agents,hooks} ~/.agents/skills ~/Library/Application\ Support/lazygit

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

# Lazygit config (macOS path with spaces — can't use stow)
ln -sfn "${DOTFILES}/lazygit/config.yml" ~/Library/Application\ Support/lazygit/config.yml
echo "Linked lazygit config"

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

# llama-swap LaunchAgent (m4x only — other hosts still get the config via stow)
if [[ "${MACHINE_NAME}" == "m4x" ]]; then
  LLAMA_SWAP="$(which llama-swap 2>/dev/null || echo /opt/homebrew/bin/llama-swap)"
  HOME_DIR="$HOME"
  sed -e "s|__LLAMA_SWAP_BIN__|${LLAMA_SWAP}|g" \
      -e "s|__LLAMA_SWAP_CONFIG__|${HOME_DIR}/.config/llama-swap/config.yml|g" \
      -e "s|__LLAMA_SWAP_LOG_OUT__|${HOME_DIR}/.config/llama-swap/logs/stdout.txt|g" \
      -e "s|__LLAMA_SWAP_LOG_ERR__|${HOME_DIR}/.config/llama-swap/logs/stderr.txt|g" \
      "${DOTFILES}/templates/com.47ng.llama-swap.plist" \
    > ~/Library/LaunchAgents/com.47ng.llama-swap.plist
  if launchctl list gui/"$(id -u)" 2>/dev/null | grep -q com.47ng.llama-swap; then
    launchctl bootout gui/"$(id -u)"/com.47ng.llama-swap 2>/dev/null || true
    launchctl bootstrap gui/"$(id -u)" ~/Library/LaunchAgents/com.47ng.llama-swap.plist 2>/dev/null || true
    echo "Restarted llama-swap LaunchAgent"
  else
    echo "llama-swap LaunchAgent already loaded"
  fi
fi

echo "Done — to reload your shell, run:"
echo "source ~/.zshrc"
