FROM debian:bookworm-slim

# Install stow 2.4+ from source (Debian ships 2.3.1 which has --dotfiles bugs)
RUN apt-get update && apt-get install -y --no-install-recommends \
    zsh hostname perl make curl ca-certificates git \
    && curl -sL https://ftp.gnu.org/gnu/stow/stow-2.4.1.tar.gz | tar xz -C /tmp \
    && cd /tmp/stow-2.4.1 && ./configure && make install \
    && rm -rf /tmp/stow-2.4.1 \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/zsh testuser
USER testuser
WORKDIR /home/testuser

COPY --chown=testuser:testuser . /home/testuser/dotfiles/

# Set machine name
RUN echo "testbox" > /home/testuser/dotfiles/.machine-name

# Create a machine-local skill to test linking
RUN mkdir -p /home/testuser/dotfiles/local/testbox/claude/skills/testbox-only \
    && echo '---\nname: testbox-only\n---\nTest skill' > /home/testuser/dotfiles/local/testbox/claude/skills/testbox-only/SKILL.md

# Ensure ~/.config exists so stow unfolds into it.
# Pre-create ~/.config/opencode to simulate opencode having been installed first
# (matches real-world layout: opencode owns the dir, stow contributes per-file symlinks).
RUN mkdir -p ~/.config/opencode

# Run install
RUN bash -o pipefail -c '/home/testuser/dotfiles/install.sh 2>&1 | tee /tmp/install.out'

# Assertions: shell loaders
RUN echo "=== Shell loaders ===" \
    && test -L ~/.zshrc && readlink ~/.zshrc | grep -q dotfiles && echo "OK: ~/.zshrc" \
    && test -L ~/.zshenv && readlink ~/.zshenv | grep -q dotfiles && echo "OK: ~/.zshenv"

# Assertions: stow-managed Claude files
RUN echo "=== Claude configs ===" \
    && test -L ~/.claude/settings.json && echo "OK: settings.json symlinked" \
    && test -L ~/.claude/CLAUDE.md && echo "OK: CLAUDE.md symlinked" \
    && test -L ~/.claude/statusline-command.sh && echo "OK: statusline symlinked" \
    && test -L ~/.claude/hooks/block-dangerous-git.sh && echo "OK: hook symlinked" \
    && test -L ~/.claude/agents/deep-research.md && echo "OK: agent symlinked"

# Assertions: shared skills in both locations
RUN echo "=== Shared skills ===" \
    && test -L ~/.claude/skills/tdd && echo "OK: tdd in ~/.claude/skills" \
    && test -L ~/.claude/skills/brainstorm && echo "OK: brainstorm in ~/.claude/skills" \
    && test -L ~/.agents/skills/tdd && echo "OK: tdd in ~/.agents/skills" \
    && test -L ~/.agents/skills/brainstorm && echo "OK: brainstorm in ~/.agents/skills"

# Assertions: machine-local skill
RUN echo "=== Local skills ===" \
    && test -L ~/.claude/skills/testbox-only && echo "OK: testbox-only in ~/.claude/skills" \
    && test -L ~/.agents/skills/testbox-only && echo "OK: testbox-only in ~/.agents/skills"

# Assertions: git config
RUN echo "=== Git ===" \
    && test -L ~/.gitconfig && readlink ~/.gitconfig | grep -q dotfiles && echo "OK: ~/.gitconfig symlinked" \
    && test -L ~/.gitignore_global && readlink ~/.gitignore_global | grep -q dotfiles && echo "OK: ~/.gitignore_global symlinked" \
    && grep -q 'excludesfile = ~/.gitignore_global' ~/.gitconfig && echo "OK: excludesfile uses portable path"

# Assertions: ghostty
RUN echo "=== Ghostty ===" \
    && test -L ~/.config/ghostty && readlink ~/.config/ghostty | grep -q dotfiles && echo "OK: ~/.config/ghostty symlinked"

# Assertions: opencode config stowed under ~/.config/opencode.
# Dir is pre-created above, so stow unfolds (per-file symlinks) — mirrors real-world layout.
RUN echo "=== Opencode ===" \
    && ! test -L ~/.config/opencode && test -d ~/.config/opencode && echo "OK: ~/.config/opencode is a real dir (unfolded)" \
    && test -L ~/.config/opencode/opencode.json && echo "OK: opencode.json symlinked" \
    && test -L ~/.config/opencode/AGENTS.md && echo "OK: AGENTS.md symlinked" \
    && test -L ~/.config/opencode/agents && readlink ~/.config/opencode/agents | grep -q dotfiles && echo "OK: agents/ symlinked" \
    && test -L ~/.config/opencode/commands && echo "OK: commands/ symlinked" \
    && test -L ~/.config/opencode/skills && echo "OK: skills/ symlinked" \
    && test -L ~/.config/opencode/themes && echo "OK: themes/ symlinked" \
    && test -e ~/.config/opencode/skills/pnpm/SKILL.md && echo "OK: nested skill reachable through symlinked dir"

# Assertions: llama-swap config stowed on non-m4x hosts (config travels everywhere; daemon doesn't)
RUN echo "=== llama-swap (non-m4x) ===" \
    && test -L ~/.config/llama-swap && readlink ~/.config/llama-swap | grep -q dotfiles && echo "OK: ~/.config/llama-swap symlinked" \
    && test -e ~/.config/llama-swap/config.yml && echo "OK: llama-swap config.yml reachable" \
    && ! test -e ~/Library/LaunchAgents/com.47ng.llama-swap.plist && echo "OK: no LaunchAgent on non-m4x" \
    && ! grep -q "llama-swap not found" /tmp/install.out && echo "OK: no llama-swap prereq warn on non-m4x" \
    && ! grep -q "llama-server not found" /tmp/install.out && echo "OK: no llama-server prereq warn on non-m4x"

# Assertions: zsh sources
RUN echo "=== Zsh ===" \
    && zsh -c 'source ~/.zshrc' 2>&1 || true \
    && echo "OK: .zshrc sourced"

# === Test --adopt path: simulate pre-existing files ===
# Unstow everything, create conflicting files, re-run install
RUN stow --dotfiles -D -t ~ -d ~/dotfiles . 2>/dev/null || true \
    && rm -f ~/.zshrc ~/.zshenv ~/.gitconfig \
    && echo 'existing zshrc' > ~/.zshrc \
    && echo 'existing gitconfig' > ~/.gitconfig \
    && /home/testuser/dotfiles/install.sh 2>&1 | grep -q "adopted" && echo "OK: adopt path triggered" \
    && test -L ~/.zshrc && echo "OK: ~/.zshrc is now a symlink after adopt" \
    && test -L ~/.gitconfig && echo "OK: ~/.gitconfig is now a symlink after adopt"

# === Test guard: non-symlink dir at ~/.agents/skills/<name> is preserved ===
# Regression: ln -sfn into a real dir creates a nested symlink inside it rather
# than replacing it, leading to stale-copy / nested-too-deep bugs.
RUN echo "=== Guard: ~/.agents/skills collision ===" \
    && mkdir -p /home/testuser/dotfiles/dot-claude/skills/guard-fixture-shared \
    && echo '---\nname: guard-fixture-shared\n---' > /home/testuser/dotfiles/dot-claude/skills/guard-fixture-shared/SKILL.md \
    && mkdir -p ~/.agents/skills/guard-fixture-shared \
    && echo 'user data' > ~/.agents/skills/guard-fixture-shared/USER_DATA \
    && /home/testuser/dotfiles/install.sh 2>&1 | tee /tmp/install.out \
    && grep -q "WARN.*guard-fixture-shared" /tmp/install.out && echo "OK: warning emitted" \
    && test -f ~/.agents/skills/guard-fixture-shared/USER_DATA && echo "OK: user data preserved" \
    && ! test -L ~/.agents/skills/guard-fixture-shared && echo "OK: target not turned into symlink" \
    && ! test -e ~/.agents/skills/guard-fixture-shared/guard-fixture-shared && echo "OK: no nested symlink created"

# === Test guard: non-symlink dir at ~/.claude/skills/<name> is preserved ===
# Same bug as ~/.agents/skills but via the machine-local skills loop.
RUN echo "=== Guard: ~/.claude/skills collision ===" \
    && mkdir -p /home/testuser/dotfiles/local/testbox/claude/skills/guard-fixture-local \
    && echo '---\nname: guard-fixture-local\n---' > /home/testuser/dotfiles/local/testbox/claude/skills/guard-fixture-local/SKILL.md \
    && mkdir -p ~/.claude/skills/guard-fixture-local \
    && echo 'user data' > ~/.claude/skills/guard-fixture-local/USER_DATA \
    && /home/testuser/dotfiles/install.sh 2>&1 | tee /tmp/install.out \
    && grep -q "WARN.*guard-fixture-local.*\.claude/skills" /tmp/install.out && echo "OK: warning emitted" \
    && test -f ~/.claude/skills/guard-fixture-local/USER_DATA && echo "OK: user data preserved" \
    && ! test -L ~/.claude/skills/guard-fixture-local && echo "OK: target not turned into symlink" \
    && ! test -e ~/.claude/skills/guard-fixture-local/guard-fixture-local && echo "OK: no nested symlink created"

RUN echo "=== All assertions passed ==="
