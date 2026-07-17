# dotfiles

Cross-machine dotfile management with shared configs and per-machine overrides.

## Skills

Agent skills live in `dot-claude/skills/` (shared) and `local/<machine>/claude/skills/` (per-machine), and are symlinked to .agents for cross-agent use.

Original sources attributed, but skills have been adapted for my usage.

| Skill | What it does | Original Source |
| --- | --- | --- |
| [`audit-github-actions`](dot-claude/skills/audit-github-actions/) | Audit GitHub Actions for supply-chain / CI-CD vulns (Shai-Hulud-class worms, expression injection, token exfil) | ✏️ |
| [`prose`](dot-claude/skills/prose/SKILL.md) | Write human-readable prose: PRs, docs, emails, memos | ✏️ |
| [`html`](dot-claude/skills/html/SKILL.md) | Render a document, diagram, or report as HTML for humans | ✏️ |
| [`issue`](dot-claude/skills/issue/SKILL.md) | Research and word a good GitHub issue (never posts it) | ✏️ |
| [`github-stars-lists`](dot-claude/skills/github-stars-lists/SKILL.md) | Scrape repos from your GitHub Stars lists (no API for them) | ✏️ |
| [`research`](dot-claude/skills/research/SKILL.md) | Run a deep-research session and save it to Obsidian | ✏️ |
| [`taildrop`](dot-claude/skills/taildrop/SKILL.md) | Send files to Tailscale devices via Taildrop | ✏️ |
| [`work`](dot-claude/skills/work/SKILL.md) | Pick one open beans task and implement it end-to-end | ✏️ |
| [`premortem`](dot-claude/skills/premortem/SKILL.md) | Assume the plan already failed, work backward to find why (Gary Klein) | Ohle Lehmann |
| [`brainstorm`](dot-claude/skills/brainstorm/SKILL.md) | Interview you relentlessly to stress-test a plan or design | Matt Pocock |
| [`frontend-design`](dot-claude/skills/frontend-design/) | Build distinctive, production-grade UIs that dodge generic AI aesthetics | Anthropic |
| [`handoff`](dot-claude/skills/handoff/SKILL.md) | Compact the conversation into a handoff doc for a fresh agent | Matt Pocock |
| [`improve`](dot-claude/skills/improve/) | Survey a codebase read-only and produce prioritized handoff plans for other agents | shadcn |
| [`improve-codebase-architecture`](dot-claude/skills/improve-codebase-architecture/) | Surface deep-module refactors (Ousterhout) for testability | Matt Pocock |
| [`prd-to-issues`](dot-claude/skills/prd-to-issues/SKILL.md) | Split a PRD into independently-grabbable beans issues (tracer bullets) | Matt Pocock |
| [`repro`](dot-claude/skills/repro/SKILL.md) | Build a minimal, self-contained bug reproduction | Matt Pocock |
| [`tdd`](dot-claude/skills/tdd/) | Red-green-refactor with behavior-focused integration tests | Matt Pocock |
| [`typescript-advanced-types`](dot-claude/skills/typescript-advanced-types/SKILL.md) | Generics, conditional/mapped/template-literal types, utility types | Matt Pocock |
| [`ubiquitous-language`](dot-claude/skills/ubiquitous-language/SKILL.md) | Extract a DDD glossary from the conversation | Matt Pocock |
| [`write-a-prd`](dot-claude/skills/write-a-prd/SKILL.md) | Create a PRD via interview, codebase exploration, module design | Matt Pocock |
| [`write-a-skill`](dot-claude/skills/write-a-skill/SKILL.md) | Author new skills with progressive disclosure and bundled resources | Matt Pocock |

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

## Pi extensions

User-level Pi extensions are stored in `dot-pi/agent/extensions/`. The `private-session/` extension adds user-only `/private` and `/delete-session` commands. `/private` stops future local transcript persistence without removing existing history; `/delete-session` first makes the process private, then explicitly removes the current transcript (trash first, unlink fallback). A persistent 🕵️ footer indicator marks non-persisted sessions, including Pi's built-in ephemeral mode.

Third-party packages are declared in `dot-pi/agent/settings.json`: `pi-subagents`, `pi-web-access`, `pi-add-dir`, `@tintinweb/pi-tasks`, `pi-btw`, and `pi-web-access`.

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
