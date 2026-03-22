# dotfiles

Cross-machine dotfile management with shared configs and per-machine overrides.

## Conventions

The repo follows two simple rules:

1. **Shared vs local**: Top-level directories (`zsh/`, `zshenv/`, and future ones like `git/`, `ssh/`, etc.) hold configs shared across all machines. `local/<machine>/` mirrors the same structure for machine-specific overrides.
2. **Numbered files, glob-sourced**: Within each directory, files are sourced alphabetically. Numeric prefixes (00-, 10-, 20-, ...) control load order with gaps of 10 for future insertions. Shared files load first, then machine-local files override.

```
<tool>/                     # Shared configs (all machines)
local/<machine>/<tool>/     # Machine-specific overrides
```

Directories are created on-demand — if a directory doesn't exist or has no matching files, it's silently skipped.

## Current structure

```
.zshrc                      # Loader: zsh/ then local/<machine>/zsh/
.zshenv                     # Loader: zshenv/ then local/<machine>/zshenv/
.machine-name               # Machine identifier (gitignored, per-clone)
zsh/                        # Shared interactive shell modules
  00-environment.zsh        # PATH, EDITOR
  10-options.zsh            # Shell options, autoloads
  20-completion.zsh         # Completion system
  30-history.zsh            # History config, search keybindings
  40-aliases.zsh            # General system aliases
  41-javascript.zsh         # fnm, bun, pnpm (env + aliases)
  42-git.zsh                # Git aliases
  50-functions.zsh          # Utility functions, crypto, network
  51-docker.zsh             # Docker functions and aliases
  60-ai.zsh                 # AI tool functions and aliases
  90-prompt.zsh             # Prompt configuration
zshenv/                     # Shared all-shell modules
  00-cargo.zsh              # Rust/Cargo environment
local/<machine>/zsh/        # Machine-specific shell overrides
local/<machine>/zshenv/     # Machine-specific env overrides
```

## How the zsh loader works

Both `.zshrc` and `.zshenv` are thin loaders that resolve their own real path (following symlinks), then glob-source shared files first and machine-local files second:

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

The machine name is read from `.machine-name` in the repo root, falling back to `hostname -s`.

Set it once per clone:

```sh
echo "m4x" > /path/to/dotfiles/.machine-name
```

This file is gitignored (per-clone). The hostname fallback usually works, but can change due to network adapter conflicts — the file provides a stable override.

Current machines: `echo` (macOS), `m4x` (macOS), `pi3` (Linux).

## Machine-local overrides

Machine-local files load after shared files, so they can override anything. For example, `pi3` is a Linux host where some macOS-specific aliases differ — create `local/pi3/zsh/overrides.zsh` to redefine them.

## Secrets

Files matching `**/secrets.*` are gitignored. Store API keys and credentials in machine-local files:

```
local/m4x/zsh/secrets.zsh    # export CONTEXT7_API_KEY="..."
```

## Adding a new tool

To add configs for a new tool (e.g., `git`):

1. Create the shared directory and add config files: `git/config`
2. Add a loader or symlink strategy for that tool (tool-dependent)
3. For machine-specific overrides, add files under `local/<machine>/git/`

## Setup

Symlink the entry points from your home directory:

```sh
ln -sf /path/to/dotfiles/.zshrc ~/.zshrc
ln -sf /path/to/dotfiles/.zshenv ~/.zshenv
```

Or use [GNU Stow](https://www.gnu.org/software/stow/):

```sh
cd /path/to/dotfiles
stow -t ~ .
```

Then set the machine name:

```sh
echo "m4x" > /path/to/dotfiles/.machine-name
```
