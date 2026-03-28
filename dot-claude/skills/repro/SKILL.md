---
name: repro
description: Create a minimal reproduction for a bug. Use when the user asks to create a repro.
user-invocable: true
argument-hint: Please provide a link or reference to the issue and any relevant context or steps to reproduce.
---

## Context

If the user hasn't given you any context, start by asking them for a link or reference to the issue and any relevant context or steps to reproduce.

From that link or reference, gather as much information as you can about the bug, such as:

- What the expected behavior is vs the actual behavior.
- Any code samples, error messages, or stack traces.
- The environment in which the bug occurs (e.g. browser vs server).
- Any relevant dependencies along with their versions.

## Minimal Reproductions

A minimal reproduction is a small, self-contained codebase that demonstrates the bug in question. It should be as simple as possible while still reproducing the issue.

Tips:

1. Use creation CLIs like `pnpm create next-app --example reproduction-template <repro-name>` to quickly scaffold a minimal app.
2. Strip out any unnecessary code, resources or dependencies that aren't relevant to the bug.
3. Create an initial commit that sets up the repro with the minimal code needed to reproduce the issue, and then incrementally add commits that flesh out the repro while ensuring it still reproduces the bug.
