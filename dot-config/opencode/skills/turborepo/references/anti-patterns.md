# Critical Anti-Patterns

Common mistakes when working with Turborepo and how to avoid them.

## Using `turbo` Shorthand in Code

**`turbo run` is recommended in package.json scripts and CI pipelines.** The shorthand `turbo <task>` is intended for interactive terminal use.

```json
// WRONG - using shorthand in package.json
{
  "scripts": {
    "build": "turbo build",
    "dev": "turbo dev"
  }
}

// CORRECT
{
  "scripts": {
    "build": "turbo run build",
    "dev": "turbo run dev"
  }
}
```

```yaml
# WRONG - using shorthand in CI
- run: turbo build --affected

# CORRECT
- run: turbo run build --affected
```

## Root Scripts Bypassing Turbo

Root `package.json` scripts MUST delegate to `turbo run`, not run tasks directly.

```json
// WRONG - bypasses turbo entirely
{
  "scripts": {
    "build": "bun build",
    "dev": "bun dev"
  }
}

// CORRECT - delegates to turbo
{
  "scripts": {
    "build": "turbo run build",
    "dev": "turbo run dev"
  }
}
```

## Using `&&` to Chain Turbo Tasks

Don't chain turbo tasks with `&&`. Let turbo orchestrate.

```json
// WRONG - turbo task not using turbo run
{
  "scripts": {
    "changeset:publish": "bun build && changeset publish"
  }
}

// CORRECT
{
  "scripts": {
    "changeset:publish": "turbo run build && changeset publish"
  }
}
```

## `prebuild` Scripts That Manually Build Dependencies

Scripts like `prebuild` that manually build other packages bypass Turborepo's dependency graph.

```json
// WRONG - manually building dependencies
{
  "scripts": {
    "prebuild": "cd ../../packages/types && bun run build && cd ../utils && bun run build",
    "build": "next build"
  }
}
```

**However, the fix depends on whether workspace dependencies are declared:**

1. **If dependencies ARE declared** (e.g., `"@repo/types": "workspace:*"` in package.json), remove the `prebuild` script. Turbo's `dependsOn: ["^build"]` handles this automatically.

2. **If dependencies are NOT declared**, the `prebuild` exists because `^build` won't trigger without a dependency relationship. The fix is to:
   - Add the dependency to package.json: `"@repo/types": "workspace:*"`
   - Then remove the `prebuild` script

```json
// CORRECT - declare dependency, let turbo handle build order
// package.json
{
  "dependencies": {
    "@repo/types": "workspace:*",
    "@repo/utils": "workspace:*"
  },
  "scripts": {
    "build": "next build"
  }
}

// turbo.json
{
  "tasks": {
    "build": {
      "dependsOn": ["^build"]
    }
  }
}
```

**Key insight:** `^build` only runs build in packages listed as dependencies. No dependency declaration = no automatic build ordering.

## Overly Broad `globalDependencies`

`globalDependencies` affects ALL tasks in ALL packages. Be specific.

```json
// WRONG - heavy hammer, affects all hashes
{
  "globalDependencies": ["**/.env.*local"]
}

// BETTER - move to task-level inputs
{
  "globalDependencies": [".env"],
  "tasks": {
    "build": {
      "inputs": ["$TURBO_DEFAULT$", ".env*"],
      "outputs": ["dist/**"]
    }
  }
}
```

## Repetitive Task Configuration

Look for repeated configuration across tasks that can be collapsed. Turborepo supports shared configuration patterns.

```json
// WRONG - repetitive env and inputs across tasks
{
  "tasks": {
    "build": {
      "env": ["API_URL", "DATABASE_URL"],
      "inputs": ["$TURBO_DEFAULT$", ".env*"]
    },
    "test": {
      "env": ["API_URL", "DATABASE_URL"],
      "inputs": ["$TURBO_DEFAULT$", ".env*"]
    },
    "dev": {
      "env": ["API_URL", "DATABASE_URL"],
      "inputs": ["$TURBO_DEFAULT$", ".env*"],
      "cache": false,
      "persistent": true
    }
  }
}

// BETTER - use globalEnv and globalDependencies for shared config
{
  "globalEnv": ["API_URL", "DATABASE_URL"],
  "globalDependencies": [".env*"],
  "tasks": {
    "build": {},
    "test": {},
    "dev": {
      "cache": false,
      "persistent": true
    }
  }
}
```

**When to use global vs task-level:**

- `globalEnv` / `globalDependencies` - affects ALL tasks, use for truly shared config
- Task-level `env` / `inputs` - use when only specific tasks need it

## NOT an Anti-Pattern: Large `env` Arrays

A large `env` array (even 50+ variables) is **not** a problem. It usually means the user was thorough about declaring their build's environment dependencies. Do not flag this as an issue.

## Using `--parallel` Flag

The `--parallel` flag bypasses Turborepo's dependency graph. If tasks need parallel execution, configure `dependsOn` correctly instead.

```bash
# WRONG - bypasses dependency graph
turbo run lint --parallel

# CORRECT - configure tasks to allow parallel execution
# In turbo.json, set dependsOn appropriately (or use transit nodes)
turbo run lint
```

## Package-Specific Task Overrides in Root turbo.json

When multiple packages need different task configurations, use **Package Configurations** (`turbo.json` in each package) instead of cluttering root `turbo.json` with `package#task` overrides.

```json
// WRONG - root turbo.json with many package-specific overrides
{
  "tasks": {
    "test": { "dependsOn": ["build"] },
    "@repo/web#test": { "outputs": ["coverage/**"] },
    "@repo/api#test": { "outputs": ["coverage/**"] },
    "@repo/utils#test": { "outputs": [] },
    "@repo/cli#test": { "outputs": [] },
    "@repo/core#test": { "outputs": [] }
  }
}

// CORRECT - use Package Configurations
// Root turbo.json - base config only
{
  "tasks": {
    "test": { "dependsOn": ["build"] }
  }
}

// packages/web/turbo.json - package-specific override
{
  "extends": ["//"],
  "tasks": {
    "test": { "outputs": ["coverage/**"] }
  }
}

// packages/api/turbo.json
{
  "extends": ["//"],
  "tasks": {
    "test": { "outputs": ["coverage/**"] }
  }
}
```

**Benefits of Package Configurations:**

- Keeps configuration close to the code it affects
- Root turbo.json stays clean and focused on base patterns
- Easier to understand what's special about each package
- Works with `$TURBO_EXTENDS$` to inherit + extend arrays

**When to use `package#task` in root:**

- Single package needs a unique dependency (e.g., `"deploy": { "dependsOn": ["web#build"] }`)
- Temporary override while migrating

## Using `../` to Traverse Out of Package in `inputs`

Don't use relative paths like `../` to reference files outside the package. Use `$TURBO_ROOT$` instead.

```json
// WRONG - traversing out of package
{
  "tasks": {
    "build": {
      "inputs": ["$TURBO_DEFAULT$", "../shared-config.json"]
    }
  }
}

// CORRECT - use $TURBO_ROOT$ for repo root
{
  "tasks": {
    "build": {
      "inputs": ["$TURBO_DEFAULT$", "$TURBO_ROOT$/shared-config.json"]
    }
  }
}
```

## Missing `outputs` for File-Producing Tasks

**Before flagging missing `outputs`, check what the task actually produces:**

1. Read the package's script (e.g., `"build": "tsc"`, `"test": "vitest"`)
2. Determine if it writes files to disk or only outputs to stdout
3. Only flag if the task produces files that should be cached

```json
// WRONG: build produces files but they're not cached
{
  "tasks": {
    "build": {
      "dependsOn": ["^build"]
    }
  }
}

// CORRECT: build outputs are cached
{
  "tasks": {
    "build": {
      "dependsOn": ["^build"],
      "outputs": ["dist/**"]
    }
  }
}
```

Common outputs by framework:

- Next.js: `[".next/**", "!.next/cache/**"]`
- Vite/Rollup: `["dist/**"]`
- tsc: `["dist/**"]` or custom `outDir`

**TypeScript `--noEmit` can still produce cache files:**

When `incremental: true` in tsconfig.json, `tsc --noEmit` writes `.tsbuildinfo` files even without emitting JS. Check the tsconfig before assuming no outputs:

```json
// If tsconfig has incremental: true, tsc --noEmit produces cache files
{
  "tasks": {
    "typecheck": {
      "outputs": ["node_modules/.cache/tsbuildinfo.json"] // or wherever tsBuildInfoFile points
    }
  }
}
```

To determine correct outputs for TypeScript tasks:

1. Check if `incremental` or `composite` is enabled in tsconfig
2. Check `tsBuildInfoFile` for custom cache location (default: alongside `outDir` or in project root)
3. If no incremental mode, `tsc --noEmit` produces no files

## `^build` vs `build` Confusion

```json
{
  "tasks": {
    // ^build = run build in DEPENDENCIES first (other packages this one imports)
    "build": {
      "dependsOn": ["^build"]
    },
    // build (no ^) = run build in SAME PACKAGE first
    "test": {
      "dependsOn": ["build"]
    },
    // pkg#task = specific package's task
    "deploy": {
      "dependsOn": ["web#build"]
    }
  }
}
```

## Environment Variables Not Hashed

```json
// WRONG: API_URL changes won't cause rebuilds
{
  "tasks": {
    "build": {
      "outputs": ["dist/**"]
    }
  }
}

// CORRECT: API_URL changes invalidate cache
{
  "tasks": {
    "build": {
      "outputs": ["dist/**"],
      "env": ["API_URL", "API_KEY"]
    }
  }
}
```

## `.env` Files Not in Inputs

Turbo does NOT load `.env` files - your framework does. But Turbo needs to know about changes:

```json
// WRONG: .env changes don't invalidate cache
{
  "tasks": {
    "build": {
      "env": ["API_URL"]
    }
  }
}

// CORRECT: .env file changes invalidate cache
{
  "tasks": {
    "build": {
      "env": ["API_URL"],
      "inputs": ["$TURBO_DEFAULT$", ".env", ".env.*"]
    }
  }
}
```

## Root `.env` File in Monorepo

A `.env` file at the repo root is an anti-pattern — even for small monorepos or starter templates. It creates implicit coupling between packages and makes it unclear which packages depend on which variables.

```
// WRONG - root .env affects all packages implicitly
my-monorepo/
├── .env              # Which packages use this?
├── apps/
│   ├── web/
│   └── api/
└── packages/

// CORRECT - .env files in packages that need them
my-monorepo/
├── apps/
│   ├── web/
│   │   └── .env      # Clear: web needs DATABASE_URL
│   └── api/
│       └── .env      # Clear: api needs API_KEY
└── packages/
```

**Problems with root `.env`:**

- Unclear which packages consume which variables
- All packages get all variables (even ones they don't need)
- Cache invalidation is coarse-grained (root .env change invalidates everything)
- Security risk: packages may accidentally access sensitive vars meant for others
- Bad habits start small — starter templates should model correct patterns

**If you must share variables**, use `globalEnv` to be explicit about what's shared, and document why.

## Strict Mode Filtering CI Variables

By default, Turborepo filters environment variables to only those in `env`/`globalEnv`. CI variables may be missing:

```json
// If CI scripts need GITHUB_TOKEN but it's not in env:
{
  "globalPassThroughEnv": ["GITHUB_TOKEN", "CI"],
  "tasks": { ... }
}
```

Or use `--env-mode=loose` (not recommended for production).

## Shared Code in Apps (Should Be a Package)

```
// WRONG: Shared code inside an app
apps/
  web/
    shared/          # This breaks monorepo principles!
      utils.ts

// CORRECT: Extract to a package
packages/
  utils/
    src/utils.ts
```

## Accessing Files Across Package Boundaries

```typescript
// WRONG: Reaching into another package's internals
import { Button } from "../../packages/ui/src/button";

// CORRECT: Install and import properly
import { Button } from "@repo/ui/button";
```

## Too Many Root Dependencies

```json
// WRONG: App dependencies in root
{
  "dependencies": {
    "react": "^18",
    "next": "^14"
  }
}

// CORRECT: Only repo tools in root
{
  "devDependencies": {
    "turbo": "latest"
  }
}
```
