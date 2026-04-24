# ESLint to Oxlint Migration Guide

Complete step-by-step guide for migrating from ESLint to oxlint.

## Pre-Migration Checklist

1. **Review current ESLint config** - Document which rules you actually need
2. **Check oxlint compatibility** - Not all ESLint rules exist in oxlint
3. **Backup your config** - Keep `.eslintrc.*` files until migration is complete
4. **Test on a branch** - Don't migrate directly on main

## Step-by-Step Migration

### 1. Install oxlint

```bash
# Using your package manager
pnpm add -D oxlint
bun add -D oxlint
npm install -D oxlint
```

### 2. Map ESLint Config to Oxlint

#### From eslint-config-next

ESLint config (before):
```js
// eslint.config.mjs
import nextVitals from 'eslint-config-next/core-web-vitals'
import nextTs from 'eslint-config-next/typescript'

export default [
  ...nextVitals,
  ...nextTs,
]
```

Oxlint config (after):
```json
{
  "$schema": "./node_modules/oxlint/configuration_schema.json",
  "plugins": ["react", "jsx-a11y", "nextjs"],
  "rules": {
    "react/rules-of-hooks": "error",
    "react/exhaustive-deps": "error",
    "react/jsx-key": "error",
    "jsx-a11y/alt-text": "warn",
    "jsx-a11y/click-events-have-key-events": "warn",
    "nextjs/no-img-element": "warn",
    "nextjs/no-html-link-for-pages": "warn",
    "nextjs/no-sync-scripts": "error"
  },
  "ignorePatterns": [".next/**", "node_modules/**"]
}
```

#### From TypeScript ESLint

ESLint config (before):
```js
import tseslint from '@typescript-eslint/eslint-plugin'

export default [
  {
    plugins: { '@typescript-eslint': tseslint },
    rules: {
      '@typescript-eslint/no-explicit-any': 'error',
      '@typescript-eslint/no-unused-vars': 'warn',
    }
  }
]
```

Oxlint config (after):
```json
{
  "rules": {
    "typescript/no-explicit-any": "error",
    "typescript/no-unused-vars": "warn"
  }
}
```

### 3. Update package.json Scripts

Before:
```json
{
  "scripts": {
    "lint": "eslint .",
    "lint:fix": "eslint . --fix"
  }
}
```

After:
```json
{
  "scripts": {
    "lint": "oxlint",
    "lint:fix": "oxlint --fix"
  }
}
```

### 4. Remove ESLint Dependencies

```bash
# Remove all ESLint packages
pnpm remove eslint \
  eslint-config-next \
  @typescript-eslint/eslint-plugin \
  @typescript-eslint/parser \
  eslint-plugin-react \
  eslint-plugin-react-hooks \
  eslint-plugin-jsx-a11y

# Check no ESLint packages remain
pnpm why eslint
```

### 5. Delete Old Config Files

```bash
rm eslint.config.mjs
rm eslint.config.js
rm .eslintrc.json
rm .eslintrc.js
rm .eslintrc.yml
rm .eslintignore
```

### 6. Test the Migration

```bash
# Run on your codebase
pnpm lint

# Compare with old ESLint results (if you saved them)
diff eslint-output.txt oxlint-output.txt

# Fix auto-fixable issues
pnpm lint:fix
```

## Automated Migration

Use the official migration tool:

```bash
npx @oxlint/migrate
```

This will:
1. Analyze your ESLint config
2. Generate `.oxlintrc.json`
3. Show which rules couldn't be migrated

## Common Rule Mappings

| ESLint | Oxlint | Notes |
|--------|--------|-------|
| `@typescript-eslint/*` | `typescript/*` | All TS rules |
| `react-hooks/rules-of-hooks` | `react/rules-of-hooks` | Namespace change |
| `react-hooks/exhaustive-deps` | `react/exhaustive-deps` | Namespace change |
| `@next/next/no-img-element` | `nextjs/no-img-element` | Plugin name |
| `jsx-a11y/*` | `jsx-a11y/*` | Same namespace |

## Rules That Don't Exist

Some ESLint rules don't have oxlint equivalents. Document these:

```bash
# Check available rules
oxlint --rules | grep "rule-name"
```

Common missing rules:
- `import/order` - Use `oxfmt` with `experimentalSortImports` instead
- Many style-related rules - Use `oxfmt` for formatting
- Some custom ESLint plugins - Check oxlint plugin ecosystem

## Incremental Migration (Large Codebases)

For large repos, run both linters during transition:

```json
{
  "scripts": {
    "lint": "pnpm lint:oxlint && pnpm lint:eslint",
    "lint:oxlint": "oxlint",
    "lint:eslint": "eslint . --config .eslintrc.legacy.json"
  }
}
```

Use `eslint-plugin-oxlint` to disable overlapping rules:

```bash
pnpm add -D eslint-plugin-oxlint
```

```js
// eslint.config.mjs
import oxlintPlugin from 'eslint-plugin-oxlint'

export default [
  oxlintPlugin.configs.recommended, // Disables overlapping rules
  // ... your other configs
]
```

## Post-Migration

1. **Update CI/CD** - Change lint commands in workflows
2. **Update pre-commit hooks** - If using husky/lint-staged
3. **Update IDE settings** - Remove ESLint extensions, add oxlint
4. **Document changes** - Update CONTRIBUTING.md or similar
5. **Train team** - Share the new oxlint commands

## Troubleshooting

### "Rule not found" errors

Check the namespace mapping table above. Most issues are namespace mismatches.

### More/fewer errors than ESLint

This is expected. Oxlint has different defaults and some rules behave differently. Review each error and adjust rules as needed.

### Performance issues

Make sure you're not linting `node_modules`:

```json
{
  "ignorePatterns": ["node_modules/**", ".next/**"]
}
```

## Rollback Plan

If migration fails, rollback is simple:

```bash
# Reinstall ESLint
pnpm add -D eslint eslint-config-next

# Restore config from git
git checkout HEAD -- eslint.config.mjs package.json

# Remove oxlint
pnpm remove oxlint
rm .oxlintrc.json
```
