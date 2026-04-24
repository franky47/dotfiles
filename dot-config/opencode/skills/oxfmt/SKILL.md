---
name: oxfmt
description: Fast JavaScript/TypeScript formatter compatible with Prettier. Use when formatting JS/TS files, setting up code formatting, or migrating from Prettier.
---

# Oxfmt

High-performance formatter (~30x faster than Prettier) for JavaScript/TypeScript/JSON/CSS and more.

## Installation

```bash
pnpm add -D oxfmt
```

## Usage

```bash
# Format all files
pnpm oxfmt --write .

# Check formatting without writing
pnpm oxfmt --check .

# Initialize config
pnpm oxfmt --init
```

## Configuration

Create `.oxfmtrc.json`:

```json
{
  "$schema": "./node_modules/oxfmt/configuration_schema.json",
  "semi": false,
  "singleQuote": true,
  "trailingComma": "all",
  "printWidth": 80
}
```

**Prettier-compatible options:**
- `semi` - Add semicolons (default: true)
- `singleQuote` - Use single quotes (default: false)
- `trailingComma` - "all" | "es5" | "none"
- `printWidth` - Line width limit (default: 100)
- `tabWidth` - Spaces per indent (default: 2)
- `useTabs` - Use tabs (default: false)

**Oxfmt-specific:**
- `experimentalSortImports` - Sort imports
- `experimentalTailwindcss` - Sort Tailwind classes
- `insertFinalNewline` - Add final newline (default: true)

## Migration from Prettier

Oxfmt automatically reads `.prettierrc`. To migrate:

1. Install oxfmt: `pnpm add -D oxfmt`
2. Rename `.prettierrc` to `.oxfmtrc.json`
3. Add `"$schema": "./node_modules/oxfmt/configuration_schema.json"`
4. Remove `prettier` from devDependencies
5. Update scripts: `"format": "oxfmt --write"`

## Package.json Scripts

```json
{
  "scripts": {
    "format": "oxfmt --write .",
    "format:check": "oxfmt --check ."
  }
}
```

## References

- [Oxfmt docs](https://oxc.rs/docs/guide/usage/formatter)
- [Config reference](https://oxc.rs/docs/guide/usage/formatter/config-file-reference)
