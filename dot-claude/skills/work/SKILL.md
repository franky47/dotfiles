---
name: work
description: Pick one open task and implement it end-to-end as a unit of work. Use when the user asks to pick a task.
user-invocable: true
---

Task management is done with `beans`:

!`beans prime`

---

## Workflow

Do the following, in this specific order:

0. Load project memories in order to avoid repeating previous mistakes.
1. Pick one and only one open & unblocked bean task.
2. Implement it with your TDD skills.
3. Do a code review.
4. Address the code review feedback.
5. Update the bean as done when the acceptance criteria are met.
6. Commit **both** the code and the bean.
7. Update project memories with things you've learned: steering correction from the code review or the user.
8. You are done.

## Important

- Only pick one task at a time. This is the "work loop" pattern: pick one task, do it, then say you are done.
- Always commit the bean along with the code. The bean is the source of truth for task management, so it must be updated to reflect the work done.
- Load best practices from memory, and remember

## Commit message format

Use semantic commit messages with the following format:

```<type>: <description>

<body>

Closes <bean ID>
```

The `<body>` should be short & concise (1-2 paragraphs at most), describing **why** the work was done, not what (that's in the code itself).

If the _why_ can be trivally inferred from the bean contents, omit it entirely.
Only add relevant context you encountered while doing the work, such as design decisions, tradeoffs, or implementation details that aren't obvious from the code itself.

The `Closes <bean ID>` line is important for traceability and automation.

## Memory

- Always load project memories before starting work.
- If new learnings have surfaced during work & review, add them to the project memory.

When writing memories, extract the core lesson learned, don't focus on specific implementation details that can go stale.
Use positive reinforcement phrasing: "when doing X, prefer using Y", rather than "don't do Z".
