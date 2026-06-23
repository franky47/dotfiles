# Shared formulae for all machines.
# Install: `brew bundle` (from this repo root)
# On m4x also run: `brew bundle --file=local/m4x/Brewfile`
# Note: HOMEBREW_BUNDLE_NO_UPGRADE=1 is set in zshenv/03-homebrew.zsh —
# pass `--upgrade` explicitly to refresh existing formulae.

tap "anomalyco/tap"
tap "modem-dev/tap"
tap "mostlygeek/llama-swap"

# Core
brew "git"
brew "stow"                         # >= 2.4 (install.sh prereq)
brew "gh"
brew "curl"
brew "wget"

# Shell utilities
brew "bat"                          # cat replacement (zsh alias cat=bat)
brew "htop"                         # top replacement (zsh alias top=htop)
brew "tmux"
brew "reattach-to-user-namespace"   # share host Keychain (Claude Code auth) + pbcopy/pbpaste into tmux
brew "mosh"                         # roaming SSH replacement — survives sleep/network changes
brew "jq"
brew "ripgrep"
brew "tree"
brew "nano"                         # macOS ships ancient pico-as-nano with no syntax highlighting
brew "fresh-editor"                 # text editor & IDE - https://getfresh.dev/

# Git
brew "lazygit"
brew "modem-dev/tap/hunk"           # terminal diff viewer — lazygit pager, git dlog/dshow, zsh alias d="hunk diff"
brew "sem-cli"                       # semantic (entity-level) diffs — lazygit quick-check pager via sem-pager

# GitHub Actions
brew "pinact"                       # pin actions to commit SHAs

# Languages and runtimes
brew "elixir"
brew "fnm"                          # Node version manager (pnpm via `corepack enable pnpm`)
brew "uv"                           # Python tooling

# AI / agents
brew "anomalyco/tap/opencode"
brew "rtk"                          # Token savings (setup in OpenCode)
brew "llama-swap"                   # Local LLM router with auto-load/unload (LaunchAgent: m4x, echo)

# Yazi (terminal file manager) + preview/extraction deps — https://yazi-rs.github.io
# Reuses jq + ripgrep from Shell utilities above. ffmpeg-full/imagemagick-full are
# keg-only; `link: :overwrite` makes `brew bundle` run `brew link --force --overwrite`
# so their binaries win in PATH (wider codec/format support than the stock formulae).
brew "yazi"                         # the file manager
brew "ffmpeg-full", link: :overwrite      # video thumbnails (keg-only)
brew "imagemagick-full", link: :overwrite # image previews / format support (keg-only)
brew "sevenzip"                     # archive extraction & preview
brew "poppler"                      # PDF previews
brew "fd"                           # file-search backend
brew "fzf"                          # fuzzy finder integration
brew "zoxide"                       # directory jumping
brew "resvg"                        # SVG previews
cask "font-symbols-only-nerd-font"  # glyphs/icons (first cask here — drop if fonts managed elsewhere)
