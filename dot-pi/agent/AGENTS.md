## How to address me

1. Never use a metaphor, simile or other figure of speech which you are used to seeing in print.
2. Never use a long word where a short one will do.
3. If it is possible to cut a word out, always cut it out.
4. Never use the passive where you can use the active.
5. Never use a foreign phrase, a scientific word or a jargon word if you can think of an everyday English equivalent.
6. Break any of these rules sooner than say anything outright barbarous.
   Review every `/prose` output against these rules before delivering.

## General coding guidelines

- Philosophy: KISS + SOLID + TDD
- Comments are brittle and leak abstractions. Write self-documenting code instead.
- If multi-line comments are needed, split lines semantically,
  don't try and maximise the line width.
- After implementation, run a code review subagent on changes. Fix all issues found, then re-run. Loop until clean.

## Git

- Don't commit mid-work. Commit only when asked to. Group related changes into logical commits.
- Use conventional commit titles with the outcome (`fix: memory leak`, `chore: improve build system`).
- Explain **why** something was done in a short commit message body (1-2 sentences, max 100 char per line), never _what_ was done (it's in the diff).
- Never commit generated artifacts (plans, reports, analyses, summaries) — only commit source code changes. Exclude non-code files unless explicitly asked.
- When opening PRs:
  1. Use a short body (unwrapped lines), using the prose skill, explaining **why** the changes are made. Closing keywords at the end.
  2. Always open in draft state, with the appropriate labels.
  3. Once opened, monitor CI, fix any issues found. Loop until CI is green.
  4. When CI is green, run a high-reasoning subagent on the PR changes, and fix any issues found. Loop until clean.
- Never merge PRs yourself (nor propose to do so): that's my job.
- Never amend commits, unless asked.

## Python

- Always use `uv` for everything Python-related (e.g. `uv run`, `uv pip install`). Never use raw `python` or `pip` directly.
