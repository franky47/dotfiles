# Personal Preferences

- Be terse in your replies, follow the `prose` skill.
- After implementation, run code-review agent on changes. Fix all issues found, then re-run. Loop until clean.

## General coding guidelines

- Philosophy: KISS + SOLID + TDD
- Comments are brittle and leak abstractions. Write self-documenting code instead.
- If multi-line comments are needed, split lines semantically,
  don't try and maximise the line width.

## Git

- Never add a Co-Authored-By line for Claude when creating Git commits. Do not add Claude as a co-author.
- Don't commit mid-work. Commit only when asked to — group related changes into logical commits.
- Always use conventional commit titles with the outcome (`fix: memory leak`, `chore: improve build system`).
- Explain **why** something was done in a short commit message body (1-2 sentences, max 100 char per line), never _what_ was done (it's in the diff).
- Never commit generated artifacts (plans, reports, analyses, summaries) — only commit source code changes. Exclude non-code files unless explicitly asked.
- When opening PRs:
  1. Use a short body (unwrapped lines), using the prose skill, explaining **why** the changes are made.
  2. Never add "by Claude Code" attribution
  3. Always open in draft state
  4. Once opened, monitor CI
  5. When CI is green, run a flight of review sub-agents from the pr toolkit on the PR changes
- Never merge PRs yourself (nor propose to do so): that's my job.
- Never amend commits, unless asked.

## Python

- Always use `uv` for everything Python-related (e.g. `uv run`, `uv pip install`). Never use raw `python3` or `pip` directly.

## TypeScript

- Use the `typescript-advanced-types` skill for any TypeScript task.
- Never make your own type definitions for external libraries, install `@types` packages instead. If they don't exist, look for alternatives. Always prefer type-safe libraries.
