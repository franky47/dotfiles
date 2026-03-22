# dotfiles

Cross-machine dotfile management with shared configs and per-machine overrides.

## Conventions

1. **Shared vs local**: Top-level directories hold configs shared across all machines. `local/<machine>/` mirrors the same structure for machine-specific overrides.
2. **Numbered files, glob-sourced**: Sourceable configs (zsh) are loaded alphabetically. Numeric prefixes (00-, 10-, 20-, ...) control load order with gaps of 10 for future insertions.
3. **Stow for symlinking**: `dot-` prefixed directories are symlinked into `~/` by stow's `--dotfiles` flag (e.g., `dot-claude/` becomes `~/.claude/`). Tools with their own layering (like Claude Code's user/project/local scopes) are stowed directly.

```
<tool>/                         # Shared sourceable configs (all machines)
dot-<tool>/                     # Shared configs, stow-managed (symlinked into ~/.<tool>/)
local/<machine>/<tool>/         # Machine-specific overrides
```

## Structure

```
.zshrc                          # Loader: zsh/ then local/<machine>/zsh/
.zshenv                         # Loader: zshenv/ then local/<machine>/zshenv/
.stow-local-ignore              # Excludes internal dirs from stow
.machine-name                   # Machine identifier (gitignored, per-clone)
install.sh                      # Install script: stow + link

zsh/                            # Shared interactive shell modules
  00-environment.zsh            # PATH, EDITOR
  10-options.zsh                # Shell options, autoloads
  20-completion.zsh             # Completion system
  30-history.zsh                # History config, search keybindings
  40-aliases.zsh                # General system aliases
  41-javascript.zsh             # fnm, bun, pnpm (env + aliases)
  42-git.zsh                    # Git aliases
  50-functions.zsh              # Utility functions, crypto, network
  51-docker.zsh                 # Docker functions and aliases
  60-ai.zsh                     # AI tool functions and aliases
  90-prompt.zsh                 # Prompt configuration
zshenv/                         # Shared all-shell modules
  00-cargo.zsh                  # Rust/Cargo environment

dot-claude/                     # Stow-managed → ~/.claude/
  CLAUDE.md                     # Global instructions
  settings.json                 # Permissions, hooks, plugins, preferences
  statusline-command.sh
  hooks/
    block-dangerous-git.sh
  agents/
    deep-research.md
  skills/                       # Shared skills
    brainstorm/
    tdd/
    ...

local/<machine>/zsh/            # Machine-specific shell overrides
local/<machine>/zshenv/         # Machine-specific env overrides
local/<machine>/claude/skills/  # Machine-specific Claude skills
```

## Install

If this is ran by a coding agent like Claude code, first ask the user what the name of this machine should be.

Prerequisites: `stow` >= 2.4, `zsh`.

```sh
brew install stow       # macOS
# or build stow 2.4+ from source on Linux (Debian ships 2.3.x which has --dotfiles bugs)

git clone <repo-url> ~/dotfiles
echo "<machine>" > ~/dotfiles/.machine-name
~/dotfiles/install.sh
```

The install script:

1. Runs `stow --dotfiles --restow` to symlink `.zshrc`, `.zshenv`, and `dot-claude/` contents into `~`
2. Mirrors shared skills into `~/.agents/skills/`
3. Symlinks machine-local skills into `~/.claude/skills/` and `~/.agents/skills/`

Re-run `install.sh` after any changes. Stow's `--restow` handles re-runs cleanly.

## Claude Code settings

Claude Code has a built-in scope system (user → project → local). Stow symlinks `dot-claude/` into `~/.claude/` as the **user** scope. Per-project overrides use Claude's native `.claude/settings.json` (shared) and `.claude/settings.local.json` (personal, gitignored) — no custom merge needed.

## How the zsh loader works

Both `.zshrc` and `.zshenv` resolve their own real path (following symlinks), then glob-source shared files first and machine-local files second:

```zsh
DOTFILES=${0:A:h}
MACHINE_NAME=${$(cat ${DOTFILES}/.machine-name 2>/dev/null):-$(hostname -s)}

for f in ${DOTFILES}/zsh/*.zsh(N); do source "$f"; done
for f in ${DOTFILES}/local/${MACHINE_NAME}/zsh/*.zsh(N); do source "$f"; done
```

- **`${0:A:h}`** resolves the directory of the script, following symlinks. The repo can be checked out anywhere.
- **`(N)`** is the zsh nullglob qualifier — no error if the directory or files don't exist.

### .zshrc vs .zshenv

- **`.zshenv`** is sourced by every zsh invocation (interactive, non-interactive, login, non-login). Use `zshenv/` for environment variables that non-interactive scripts may need.
- **`.zshrc`** is sourced only by interactive shells. Use `zsh/` for everything else.

## Machine identification

Read from `.machine-name` in the repo root, falling back to `hostname -s`.

```sh
echo "<machine>" > /path/to/dotfiles/.machine-name
```

This file is gitignored (per-clone). The hostname fallback usually works, but can change due to network adapter conflicts — the file provides a stable override.

Current machines: `echo` (macOS), `m4x` (macOS), `pi3` (Linux).

## Machine-local overrides

- **zsh**: local `.zsh` files load after shared, overriding aliases, functions, exports
- **Claude skills**: local skills appear alongside shared skills in `~/.claude/skills/`

## Secrets

Files matching `**/secrets.*` are gitignored. Store API keys and credentials in machine-local files:

```
local/m4x/zsh/secrets.zsh    # export SUPER_SECRET_API_KEY="..."
```

## Adding a new tool

1. For stow-managed configs: create `dot-<tool>/` with files mirroring `~/.<tool>/`
2. For sourceable configs: create `<tool>/` with numbered files
3. For machine-specific overrides: add files under `local/<machine>/<tool>/`
4. Update `.stow-local-ignore` if adding internal-only directories
