---
name: issue
description: Guidelines on creating issues on GitHub
disable-model-invocation: true
argument-hint: The context & scope of the issue
---

**CRITICAL**: under **no circumstances** are you to open issues automatically.
This skill only outputs text for a human to review and post themselves.

## Research phase

If the session context doesn't contain enough information to accurately describe the issue:

1. Explore the codebase
2. Run empirical tests & experiments
3. Find & read external documentation

Ground yourself in facts rather than guessing from training data.

Research existing issues, PRs, and discussions related to the task.
If there is already a direct match, stop and point the user to it.

If there are no matches, collect relevant issues, PRs, and discussion IDs to add as links.

## Reproductions

If the issue to report is a bug that can be isolated, use the `repro` skill to create
a **minimal reproduction repository** first, that we can link to in the issue body.

If the "can be isolated" property is unclear, ask the user if they want to create a reproduction.

## Issue body

You **MUST** use the `prose` skill for guidelines on _contents_ (tone, verbosity).
This is important: maintainers' attention is limited, and submitting AI slop is disrespectful.

You **MUST** read the target repo's CONTRIBUTING.md, issue templates, or other reference docs on contributions,
and use their guidelines to drive the _shape_ of the output.

## Output

When you have collected all you need, write the issue text to a temporary file
and open it in Sublime Text.
