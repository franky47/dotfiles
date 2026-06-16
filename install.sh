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

  if ! command -v hunk &>/dev/null; then
    echo "${YELLOW}WARN:${RESET} hunk not found — git diff will fall back to built-in diff."
    echo "  brew install modem-dev/tap/hunk"
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
    echo "  curl -fsSL https://claude.ai/install.sh | bash"
    warn=1
  fi

  if [[ "${MACHINE_NAME}" == "m4x" || "${MACHINE_NAME}" == "echo" ]]; then
    if ! command -v llama-swap &>/dev/null; then
      echo "${YELLOW}WARN:${RESET} llama-swap not found — model swap daemon unavailable."
      echo "  brew install llama-swap"
      warn=1
    fi
  fi

  if [[ "${MACHINE_NAME}" == "m4x" ]]; then
    if ! command -v llama-server &>/dev/null; then
      echo "${YELLOW}WARN:${RESET} llama-server not found — llama.cpp unavailable."
      echo "  brew install llama.cpp"
      warn=1
    fi
  fi

  if [[ "${MACHINE_NAME}" == "echo" ]]; then
    if [[ ! -x /Volumes/Storage/dev/franky47/llama.cpp/build/bin/llama-server ]]; then
      echo "${YELLOW}WARN:${RESET} echo llama.cpp build missing — llama-server unavailable."
      echo "  ${DOTFILES}/local/echo/setup-llama-cpp.sh"
      warn=1
    fi
  fi

  [[ $warn -ne 0 ]] && echo "" || true
}

check_prereqs

# Bootstrap sfw — zsh aliases route npm/pnpm/cargo/pip/etc. through it.
# Runs in bash, so aliases aren't active here; `npm` is unaliased.
ensure_sfw() {
  if command -v sfw &>/dev/null; then
    return
  fi
  if ! command -v npm &>/dev/null; then
    echo "${YELLOW}WARN:${RESET} sfw not installed and npm unavailable." >&2
    echo "  Install Node first (brew install fnm && fnm install --lts), then re-run." >&2
    return
  fi
  echo "Installing sfw (Socket Firewall) globally via npm..."
  npm install -g sfw
}

ensure_sfw

# Ensure target dirs exist so stow unfolds (per-file symlinks) instead of folding (one dir symlink)
mkdir -p ~/.claude/{skills,agents,hooks} ~/.agents/skills ~/Library/Application\ Support/lazygit ~/.pi/agent/extensions

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

# OBS scene collections live under ~/.config/obs (stow-folded with the rest of
# dot-config). OBS demands its scenes at basic/scenes, so re-point that dir at the
# managed one. A whole-dir symlink (not per-file) survives OBS's atomic save —
# OBS writes a temp file and renames it *inside* the dir, which would clobber a
# per-file link but leaves the dir link intact. macOS-only; the guard skips hosts
# without OBS. profiles/ (stream keys) is deliberately left unmanaged.
OBS_BASIC="${HOME}/Library/Application Support/obs-studio/basic"
if [[ -d "$OBS_BASIC" && ! -L "$OBS_BASIC/scenes" ]]; then
  [[ -e "$OBS_BASIC/scenes" ]] && mv "$OBS_BASIC/scenes" "$OBS_BASIC/scenes.pre-dotfiles.$(date +%s).bak"
  ln -sfn "${HOME}/.config/obs/scenes" "$OBS_BASIC/scenes"
  echo "Linked OBS scenes → ~/.config/obs/scenes"
fi

# ln -sfn replaces existing symlinks but creates a link *inside* a real dir,
# which nests-too-deep and masks stale copies. Skip and warn instead.
link_skill() {
  local src="$1" target="$2"
  if [[ -d "$target" && ! -L "$target" ]]; then
    echo "${YELLOW}WARN:${RESET} skipping symlink ${src} → ${target} (target is a non-symlink dir — move its contents into dotfiles or local/<machine>/claude/skills/ if intended as managed)" >&2
    return
  fi
  ln -sfn "$src" "$target"
}

# Mirror shared skills into ~/.agents/skills/ (stow only targets ~/.claude/)
for d in "${DOTFILES}/dot-claude/skills/"*/; do
  [[ -d "$d" ]] || continue
  name="$(basename "$d")"
  link_skill "$d" ~/.agents/skills/"$name"
done
echo "Mirrored shared skills to ~/.agents/skills/"

# Wire hunk's bundled review skill into both skill dirs. `hunk skill path`
# returns a versioned Cellar path (stale on upgrade), so rebase it onto
# `brew --prefix hunk` — a stable symlink brew re-points to the current version
# on every `brew upgrade`. The link then never goes stale and tracks whatever
# hunk version is installed. brew-only; skipped where hunk isn't installed.
if command -v hunk &>/dev/null && hunk_prefix="$(brew --prefix hunk 2>/dev/null)"; then
  hunk_skill_dir="$(dirname "$(hunk skill path)")"
  hunk_rel="${hunk_skill_dir#"$(cd "$hunk_prefix" && pwd -P)"/}"
  hunk_skill="${hunk_prefix}/${hunk_rel}"
  hunk_name="$(basename "$hunk_skill_dir")"
  if [[ -d "$hunk_skill" ]]; then
    link_skill "$hunk_skill" ~/.claude/skills/"$hunk_name"
    link_skill "$hunk_skill" ~/.agents/skills/"$hunk_name"
    echo "Linked hunk skill: $hunk_name (via ${hunk_prefix})"
  fi
fi

# Symlink machine-local skills
if [[ -d "${LOCAL_CLAUDE}/skills" ]]; then
  for d in "${LOCAL_CLAUDE}/skills/"*/; do
    [[ -d "$d" ]] || continue
    name="$(basename "$d")"
    link_skill "$d" ~/.claude/skills/"$name"
    link_skill "$d" ~/.agents/skills/"$name"
    echo "Linked local skill: $name"
  done
fi

# Symlink machine-local pi extensions
LOCAL_PI="${DOTFILES}/local/${MACHINE_NAME}/pi"
if [[ -d "${LOCAL_PI}/extensions" ]]; then
  for f in "${LOCAL_PI}/extensions/"*.ts; do
    [[ -f "$f" ]] || continue
    name="$(basename "$f")"
    link_skill "$f" ~/.pi/agent/extensions/"$name"
    echo "Linked local pi extension: $name"
  done
fi

# llama-swap active config: pick the per-host variant. The symlink is created
# inside the stow-managed dir (~/.config is folded), so the link literally lives
# next to its target in the repo — gitignored to keep host selection local.
if [[ -e "${DOTFILES}/dot-config/llama-swap/config.${MACHINE_NAME}.yml" ]]; then
  ln -snf "config.${MACHINE_NAME}.yml" ~/.config/llama-swap/config.yml
  echo "Selected llama-swap config: config.${MACHINE_NAME}.yml"
fi

# llama-swap LaunchAgent (m4x + echo). PATH differs by host because the brew
# prefix differs (Apple Silicon vs Intel). The child llama-server is resolved
# via absolute path in config.echo.yml — m4x leaves it on PATH.
if [[ "${MACHINE_NAME}" == "m4x" || "${MACHINE_NAME}" == "echo" ]]; then
  case "${MACHINE_NAME}" in
    m4x)
      LAUNCH_PATH="/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
      LLAMA_SWAP_LOG_DIR="${HOME}/.config/llama-swap/logs"
      ;;
    echo)
      LAUNCH_PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
      # ~/Library/Logs is the Apple-blessed location for user-scope log files;
      # ~/.config/.../logs trips TCC under launchd on macOS 12 (EX_CONFIG).
      LLAMA_SWAP_LOG_DIR="${HOME}/Library/Logs/llama-swap"
      ;;
  esac
  mkdir -p "${LLAMA_SWAP_LOG_DIR}"
  LLAMA_SWAP="$(which llama-swap 2>/dev/null || true)"
  if [[ -z "${LLAMA_SWAP}" ]]; then
    case "${MACHINE_NAME}" in
      m4x)  LLAMA_SWAP="/opt/homebrew/bin/llama-swap" ;;
      echo) LLAMA_SWAP="/usr/local/bin/llama-swap" ;;
    esac
  fi
  HOME_DIR="$HOME"
  sed -e "s|__LLAMA_SWAP_BIN__|${LLAMA_SWAP}|g" \
      -e "s|__LLAMA_SWAP_CONFIG__|${HOME_DIR}/.config/llama-swap/config.yml|g" \
      -e "s|__LLAMA_SWAP_LOG_OUT__|${LLAMA_SWAP_LOG_DIR}/stdout.txt|g" \
      -e "s|__LLAMA_SWAP_LOG_ERR__|${LLAMA_SWAP_LOG_DIR}/stderr.txt|g" \
      -e "s|__LAUNCH_PATH__|${LAUNCH_PATH}|g" \
      -e "s|__HOME__|${HOME_DIR}|g" \
      "${DOTFILES}/templates/com.47ng.llama-swap.plist" \
    > ~/Library/LaunchAgents/com.47ng.llama-swap.plist
  # bootout (idempotent) + bootstrap. With RunAtLoad=true the bootstrap already
  # spawns the daemon; a plain kickstart force-spawns it if a cold load left the
  # job in `spawn scheduled`. Avoid kickstart -k: it kills the just-spawned
  # instance, which is then under launchd's 10s respawn throttle and blocks
  # bootstrap for ~10s.
  launchctl bootout gui/"$(id -u)"/com.47ng.llama-swap 2>/dev/null || true
  launchctl bootstrap gui/"$(id -u)" ~/Library/LaunchAgents/com.47ng.llama-swap.plist 2>/dev/null || true
  launchctl kickstart gui/"$(id -u)"/com.47ng.llama-swap >/dev/null 2>&1 || true
  echo "Started llama-swap LaunchAgent"
fi

# tmux-ssh-autostart LaunchAgent (echo only — keeps one tmux server
# alive in the GUI login (Aqua) context so panes forked by tmux inherit
# the user's Mach audit session. Required for Keychain access from
# SSH-attached tmux panes (e.g. Claude Code credentials), which
# otherwise fail with errSecInteractionNotAllowed.)
if [[ "${MACHINE_NAME}" == "echo" ]]; then
  # ~/Library/Logs is the Apple-blessed location for user-scope log
  # files. ~/.config/.../logs trips TCC under launchd (EX_CONFIG, no
  # log files written) so we use Library/Logs instead.
  TMUX_SSH_AUTOSTART_LOG_DIR="${HOME}/Library/Logs/tmux-ssh-autostart"
  mkdir -p "${TMUX_SSH_AUTOSTART_LOG_DIR}"
  sed -e "s|__TMUX_SSH_AUTOSTART_LOG_OUT__|${TMUX_SSH_AUTOSTART_LOG_DIR}/stdout.log|g" \
      -e "s|__TMUX_SSH_AUTOSTART_LOG_ERR__|${TMUX_SSH_AUTOSTART_LOG_DIR}/stderr.log|g" \
      "${DOTFILES}/templates/com.47ng.tmux-ssh-autostart.plist" \
    > ~/Library/LaunchAgents/com.47ng.tmux-ssh-autostart.plist
  launchctl bootout gui/"$(id -u)"/com.47ng.tmux-ssh-autostart 2>/dev/null || true
  launchctl bootstrap gui/"$(id -u)" ~/Library/LaunchAgents/com.47ng.tmux-ssh-autostart.plist
  echo "Loaded com.47ng.tmux-ssh-autostart LaunchAgent"
fi

echo "Done — to reload your shell, run:"
echo "source ~/.zshrc"
