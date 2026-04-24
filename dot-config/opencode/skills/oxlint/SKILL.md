---
name: oxlint
description: High-performance linter for JavaScript/TypeScript built on Oxc. 50-100x faster than ESLint with built-in React, TypeScript, Next.js, and accessibility rules. Use when setting up linting, migrating from ESLint, or configuring lint rules.
---

# Oxlint

Blazingly fast linter (50-100x faster than ESLint) with zero-config defaults and built-in plugins.

## Quick Start

```bash
# Install
bun add -D oxlint

# Run
oxlint

# Auto-fix
oxlint --fix
```

## Configuration

Create `.oxlintrc.json`:

```json
{
  "$schema": "./node_modules/oxlint/configuration_schema.json",
  "plugins": ["react", "jsx-a11y", "nextjs"],
  "rules": {
    "react/rules-of-hooks": "error",
    "react/exhaustive-deps": "error",
    "jsx-a11y/alt-text": "warn",
    "nextjs/no-img-element": "warn"
  },
  "ignorePatterns": [".next/**", "node_modules/**"]
}
```

## Critical: Rule Namespaces

**Oxlint uses different namespaces than ESLint:**

| ESLint | Oxlint | Example |
|--------|--------|---------|
| `@typescript-eslint/*` | `typescript/*` | `typescript/no-explicit-any` |
| `eslint-plugin-react-hooks/*` | `react/*` | `react/exhaustive-deps` |
| `@next/eslint-plugin-next/*` | `nextjs/*` | `nextjs/no-img-element` |

**Common mistakes:**
- ❌ `react-hooks/exhaustive-deps` → ✅ `react/exhaustive-deps`
- ❌ `@typescript-eslint/no-unused-vars` → ✅ `typescript/no-unused-vars`

## Available Plugins

Enable in config `"plugins"` array:
- `react` - React + Hooks
- `react-perf` - Performance
- `jsx-a11y` - Accessibility
- `nextjs` - Next.js rules
- `typescript` - TypeScript (default on)
- `unicorn` - Best practices (default on)
- `import` - Import validation
- `jest` / `vitest` - Testing

## Migration from ESLint

```bash
# 1. Install/remove
bun add -D oxlint
bun remove eslint eslint-config-next

# 2. Update package.json
"lint": "oxlint"

# 3. Create .oxlintrc.json (see config above)

# 4. Delete old configs
rm eslint.config.mjs .eslintrc.* .eslintignore
```

## Common Patterns

### Next.js + TypeScript + a11y
```json
{
  "plugins": ["react", "jsx-a11y", "nextjs"],
  "rules": {
    "react/rules-of-hooks": "error",
    "react/exhaustive-deps": "error",
    "react/jsx-key": "error",
    "jsx-a11y/alt-text": "warn",
    "jsx-a11y/click-events-have-key-events": "warn",
    "nextjs/no-img-element": "warn"
  }
}
```

### CLI Flags
```bash
# Enable plugins
oxlint --react-plugin --jsx-a11y-plugin --nextjs-plugin

# Control categories
oxlint -D correctness -A no-debugger  # Deny correctness, allow debugger

# CI/CD
oxlint --deny-warnings --max-warnings 0
```

## Accessibility Fix Pattern

For `jsx-a11y/click-events-have-key-events`:

```tsx
// Add tabIndex + onKeyDown
<div
  tabIndex={0}
  onClick={handleClick}
  onKeyDown={(e) => {
    if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault()
      handleClick(e)
    }
  }}
>
```

Or use semantic HTML: `<button onClick={handleClick}>`

## References

See `references/` for detailed guides:
- `eslint-migration.md` - Complete migration guide
- `a11y-patterns.md` - Accessibility fixes
- `react-rules.md` - React/Hooks rules
- `cli-reference.md` - All CLI options

**Docs:**
- [Oxlint Documentation](https://oxc.rs/docs/guide/usage/linter)
- [Rules Reference](https://oxc.rs/docs/guide/usage/linter/rules)
