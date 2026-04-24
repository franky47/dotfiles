## Preferred tech stack

- Language: TypeScript, Bun, Node.js 24+, ESM only
- Frontend: React, Next.js app router, Tailwind, nuqs, shadcn
- Backend: Elysia, Fastify, Prisma, Drizzle, PostgreSQL, Redis
- Testing: vitest, playwright
- Tooling: pnpm, turborepo, tsdown, vite, knip, sherif

## Scripting

- Bash for very simple standalone scripts, Bun as complexity grows
- macOS first

## Code Style

- Prioritise simplicity over abstraction (Follow Occam's razor religiously)
- Avoid YAGNI at all costs
- Use explicit variable names, avoid comments
- Keep functions short
- Keep files short

## Code Conventions

- Prefer `function` keyword for definitions, arrow functions for inline callbacks only
- Name variables with camelCase, types with PascalCase, constants with SCREAMING_SNAKE_CASE
- Name files with kebab-case.extension

Type-safety in TypeScript is paramount:

- Never use `as` or `any`.
- Never specify generics type arguments (`dontDoThis<string>('bad')`), infer instead (`doThis('good')`)
- Always parse untrusted inputs (network, filesystem), use zod and infer types from schemas
- Prefer types to interfaces
- Don't make properties optional if they are needed
- As a last resort, prefer // @ts-expect-error, never @ts-ignore

## Testing

- Always cover your changes with relevant tests
- Never delete or modify existing tests
- Don't test implementation, test behaviors
- Tests must pass

## Interaction

- Keep your responses concise: 1-3 paragraphs
- Make your plans as detailed as possible
- Make focused edits to files, in small increments

## Docs

Use `context7` tools to search docs.
When stuck on some issue, look into your memory files: `~/.config/opencode/memory/*.md`.

## Phases

Code review: After implementing code changes, always ask the `@review` agent to do a pass of code review, and follow its guidelines. Skip that for prose-only changes (Markdown, docs).

Memory & Learning: At the end of planning and building sessions, invoke the `@memory` agent to capture:

- Lessons learned from problems encountered and solutions found
- User clarifications and preferences revealed during the session
- Important discoveries from documentation research that solved issues
- Patterns that could become reusable skills or sub-agents

Workflow for code implementations:

1. When you start implementing code changes, create a todo item: "Call @review agent for code review"
2. Set this todo with high priority and pending status at the end of the task list
3. After all code changes are complete, mark this todo as in_progress and invoke the @review agent
4. Follow the @review agent's feedback and make any necessary changes
5. Only mark the review todo as completed after addressing all review feedback

Workflow for memory capture:

1. When implementing significant changes, create a todo item: "Call @memory agent to capture learnings"
2. Set this todo with medium priority and pending status (after review)
3. After code review is completed, mark this todo as in_progress and invoke the @memory agent
4. Mark completed once memory has been captured
