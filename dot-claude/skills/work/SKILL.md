---
name: work
description: Pick one open task and implement it end-to-end as a unit of work. Use when the user asks to pick a task.
user-invocable: true
---

Task management is done with beans. Familiarise yourself with the beans CLI if you haven't already (calling `beans prime`).

When the user asks you to pick a task, do the following, in this specific order:

1. Pick one and only one open bean task.
2. Implement it with your TDD skills.
3. Do a code review.
4. Address the code review feedback.
5. Update the bean as done when the acceptance criteria are met.
6. Commit **both** the code and the bean.
7. You are done.

## Important

- Only pick one task at a time. This is the "work loop" pattern: pick one task, do it, then say you are done.
- Always commit the bean along with the code. The bean is the source of truth for task management, so it must be updated to reflect the work done.

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
