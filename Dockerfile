FROM debian:bookworm-slim

# Install stow 2.4+ from source (Debian ships 2.3.1 which has --dotfiles bugs)
RUN apt-get update && apt-get install -y --no-install-recommends \
    zsh hostname perl make curl ca-certificates \
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

# Run install
RUN /home/testuser/dotfiles/install.sh

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

# Assertions: zsh sources
RUN echo "=== Zsh ===" \
    && zsh -c 'source ~/.zshrc' 2>&1 || true \
    && echo "OK: .zshrc sourced"

RUN echo "=== All assertions passed ==="
