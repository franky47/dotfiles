---
name: turborepo
description: |
  Turborepo monorepo build system guidance. Triggers on: turbo.json, task pipelines,
  dependsOn, caching, remote cache, the "turbo" CLI, --filter, --affected, CI optimization, environment
  variables, internal packages, monorepo structure/best practices, and boundaries.

  Use when user: configures tasks/workflows/pipelines, creates packages, sets up
  monorepo, shares code between apps, runs changed/affected packages, debugs cache,
  or has apps/packages directories.
metadata:
  version: 2.7.6
---

# Turborepo Skill

Build system for JavaScript/TypeScript monorepos. Turborepo caches task outputs and runs tasks in parallel based on dependency graph.

## IMPORTANT: Package Tasks, Not Root Tasks

**DO NOT create Root Tasks. ALWAYS create package tasks.**

When creating tasks/scripts/pipelines, you MUST:

1. Add the script to each relevant package's `package.json`
2. Register the task in root `turbo.json`
3. Root `package.json` only delegates via `turbo run <task>`

**DO NOT** put task logic in root `package.json`. This defeats Turborepo's parallelization.

```json
// DO THIS: Scripts in each package
// apps/web/package.json
{ "scripts": { "build": "next build", "lint": "eslint .", "test": "vitest" } }

// apps/api/package.json
{ "scripts": { "build": "tsc", "lint": "eslint .", "test": "vitest" } }

// packages/ui/package.json
{ "scripts": { "build": "tsc", "lint": "eslint .", "test": "vitest" } }
```

```json
// turbo.json - register tasks
{
  "tasks": {
    "build": { "dependsOn": ["^build"], "outputs": ["dist/**"] },
    "lint": {},
    "test": { "dependsOn": ["build"] }
  }
}
```

```json
// Root package.json - ONLY delegates, no task logic
{
  "scripts": {
    "build": "turbo run build",
    "lint": "turbo run lint",
    "test": "turbo run test"
  }
}
```

Root Tasks (`//#taskname`) are ONLY for tasks that truly cannot exist in packages (rare).

## Secondary Rule: `turbo run` vs `turbo`

**Always use `turbo run` when the command is written into code:**

```json
// package.json - ALWAYS "turbo run"
{
  "scripts": {
    "build": "turbo run build"
  }
}
```

The shorthand `turbo <tasks>` is **ONLY for one-off terminal commands** typed directly by humans or agents. Never write `turbo build` into package.json, CI, or scripts.

## Quick Decision Trees

| Question | Solution |
|----------|----------|
| Configure task dependencies | [configuration/tasks.md](./references/configuration/tasks.md) |
| Lint/type-check in parallel | Use Transit Nodes ([task-configurations.md](./references/task-configurations.md)) |
| Missing cache outputs | Add `outputs` key to task |
| Cache debug | Use `--summarize` or `--dry` flags |
| Run only changed packages | `turbo run build --affected` |
| Custom base branch | `--affected --affected-base=origin/develop` |
| Env vars not available | Add to `env` or `globalEnv` |
| .env not invalidating cache | Add `.env` to `inputs` |
| Set up CI | [ci/github-actions.md](./references/ci/github-actions.md) |
| Watch for changes | `turbo watch dev` |
| Create internal package | [best-practices/packages.md](./references/best-practices/packages.md) |
| Enforce boundaries | `turbo boundaries` → [boundaries/README.md](./references/boundaries/README.md) |

## Critical Anti-Patterns

See [references/anti-patterns.md](./references/anti-patterns.md) for: using `turbo` shorthand, root scripts bypassing turbo, `prebuild` scripts, missing `outputs`, env vars not hashed, root `.env` files, and more.

## Common Task Configurations

Ready-to-use patterns at [references/task-configurations.md](./references/task-configurations.md): standard build pipeline, dev task with `^dev` pattern, transit nodes, lint/type-check setup, test pipeline with coverage.

## Reference Index

| Category | Files |
|----------|-------|
| **Configuration** | [tasks](./references/configuration/tasks.md) · [global-options](./references/configuration/global-options.md) · [gotchas](./references/configuration/gotchas.md) |
| **Caching** | [remote-cache](./references/caching/remote-cache.md) · [gotchas](./references/caching/gotchas.md) |
| **Environment** | [gotchas](./references/environment/gotchas.md) |
| **Filtering** | [patterns](./references/filtering/patterns.md) |
| **CI/CD** | [github-actions](./references/ci/github-actions.md) · [vercel](./references/ci/vercel.md) |
| **Best Practices** | [packages](./references/best-practices/packages.md) · [structure](./references/best-practices/structure.md) · [dependencies](./references/best-practices/dependencies.md) · [boundaries](./references/boundaries/README.md) |

## Source Documentation

- Source: `docs/site/content/docs/` in the Turborepo repository
- Live: https://turborepo.dev/docs
