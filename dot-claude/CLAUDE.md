# CRITICAL: Working Directory Rules

**NEVER use `cd` in compound commands. NEVER write `cd path && command`. The working directory is ALREADY set correctly when you start — just run commands directly. If you catch yourself writing `cd` before a command, STOP and remove it. This is a persistent bad habit — fight it every single time.**

# Personal Preferences

- Don't bullshit me. If there's something you don't know how to do, or a question you don't know the answer to, just say so instead of making something up. If there's an answer to a question which is commonly stated but is severely lacking in evidence or even has evidence against it don't give me that as the answer, either skip it entirely or give it with the caveat that it's dubious. Don't tell me about things you've done or experiences you've had which you don't have actual memories of. If you've exhausted everything you have to say about something don't keep repeating yourself to pad your answer length, just stop talking.
- Don't ever tell me to go search for something - that's your job. Don't ever make me tell you to go search for something or do something when you could have done it on your own.
- Only start implementing straight off if the implementation requires trivial changes, otherwise explore the codebase or the web to find answers, and brainstorm with with me if clarification is needed.
- Whenever you go in the wrong direction on a repository, propose changes to claude.md or create skills that will stop you from repeating the same mistake.
- Use skills whenever it makes sense.
- Before any task, scan available skills/plugins for relevance. Proactively invoke ones that apply (e.g. security skill when planning, debugging skill when fixing bugs) — don't wait to be told.
- On project start, check `.claude/settings.json` for pre-allowed non-destructive commands (build, test, lint, etc.). Use the repo's package manager (check lockfiles: `pnpm-lock.yaml`→pnpm, `bun.lockb`→bun, `package-lock.json`→npm). Never substitute with `npx` or a different runner.
- After implementation, run code-review agent on changes. Fix all issues found, then re-run. Loop until clean.

## Git

- Never add a Co-Authored-By line for Claude when creating Git commits. Do not add Claude as a co-author.
- Don't commit mid-work. Commit only when asked to — group related changes into logical commits.
- Always use conventional commit titles with the outcome (`fix: memory leak`, `chore: improve build system`).
- Explain **why** something was done in a short commit message body (1-2 paragraphs), never _what_ was done (it's in the diff).
- Never commit generated artifacts (plans, reports, analyses, summaries) — only commit source code changes. Exclude non-code files unless explicitly asked.

## Python

- Always use `uv` for everything Python-related (e.g. `uv run`, `uv pip install`). Never use raw `python3` or `pip` directly.

## TypeScript

- Use the `typescript-advanced-types` skill for any TypeScript task.
- Never make your own type definitions for external libraries, install `@types` packages instead. If they don't exist, look for alternatives. Always prefer type-safe libraries.
