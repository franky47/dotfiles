# CLI Reference

Complete reference for oxlint command-line interface.

## Basic Usage

```bash
oxlint [OPTIONS] [PATH]...
```

## Common Commands

```bash
# Lint current directory
oxlint

# Lint specific files/directories
oxlint src/ app/ lib/

# Auto-fix issues
oxlint --fix

# Apply dangerous fixes (may change behavior)
oxlint --fix-dangerously

# Check only, don't write fixes
oxlint --fix --check
```

## Configuration

```bash
# Use specific config file
oxlint -c .oxlintrc.json

# Specify tsconfig location
oxlint --tsconfig ./tsconfig.json

# Initialize new config
oxlint --init
```

## Rule Control

```bash
# Allow/suppress rules (-A)
oxlint -A no-debugger
oxlint -A suspicious  # Allow entire category

# Warn on rules (-W)
oxlint -W no-console

# Deny/error on rules (-D)
oxlint -D correctness
oxlint -D no-unused-vars

# Combine multiple
oxlint -D correctness -A no-debugger -W no-console
```

### Rule Categories

- `correctness` - Wrong or useless code (default)
- `suspicious` - Likely wrong code
- `pedantic` - Strict rules
- `perf` - Performance issues
- `style` - Code style
- `restriction` - Language feature restrictions
- `nursery` - New experimental rules
- `all` - All categories except nursery

## Plugin Control

```bash
# Enable plugins
oxlint --react-plugin
oxlint --nextjs-plugin
oxlint --jsx-a11y-plugin
oxlint --import-plugin
oxlint --jsdoc-plugin
oxlint --jest-plugin
oxlint --vitest-plugin
oxlint --react-perf-plugin
oxlint --promise-plugin
oxlint --node-plugin
oxlint --vue-plugin

# Disable default plugins
oxlint --disable-unicorn-plugin
oxlint --disable-oxc-plugin
oxlint --disable-typescript-plugin

# Combine multiple
oxlint --react-plugin --jsx-a11y-plugin --nextjs-plugin
```

## Ignore Patterns

```bash
# Ignore specific patterns
oxlint --ignore-pattern "**/*.test.ts"
oxlint --ignore-pattern "dist/**" --ignore-pattern "build/**"

# Use custom ignore file
oxlint --ignore-path .gitignore

# Disable all ignore files
oxlint --no-ignore
```

## Output Control

```bash
# Suppress all output except errors
oxlint --silent

# Only show errors, hide warnings
oxlint --quiet

# Fail on any warnings
oxlint --deny-warnings

# Allow up to N warnings
oxlint --max-warnings 5
```

## Output Formats

```bash
# Default stylish format
oxlint --format default
oxlint --format stylish

# GitHub Actions annotations
oxlint --format github

# GitLab Code Quality
oxlint --format gitlab

# JSON for parsing
oxlint --format json

# JUnit XML
oxlint --format junit

# Checkstyle XML
oxlint --format checkstyle

# Unix format
oxlint --format unix
```

## Type-Aware Linting

```bash
# Enable type-aware rules
oxlint --type-aware

# With custom tsconfig
oxlint --type-aware --tsconfig ./tsconfig.json

# Enable experimental type checking
oxlint --type-check
```

## Multi-File Analysis

```bash
# Enable import plugin for cross-file checks
oxlint --import-plugin --tsconfig ./tsconfig.json
```

## Performance Options

```bash
# Control thread count
oxlint --threads 4

# Single-threaded (for debugging)
oxlint --threads 1
```

## Configuration Display

```bash
# Print effective configuration
oxlint --print-config

# List all available rules
oxlint --rules

# Filter rules list
oxlint --rules | grep react
```

## Inline Comment Control

```bash
# Check for unused disable comments
oxlint --report-unused-disable-directives

# Set severity for unused directives
oxlint --report-unused-disable-directives-severity error
oxlint --report-unused-disable-directives-severity warn
```

## Advanced Options

```bash
# Disable nested config loading
oxlint --disable-nested-config

# Start language server
oxlint --lsp
```

## Version and Help

```bash
# Show version
oxlint --version
oxlint -V

# Show help
oxlint --help
oxlint -h
```

## Exit Codes

- `0` - No errors (warnings OK unless `--deny-warnings`)
- `1` - Errors found
- `2` - Invalid configuration

## Examples

### CI/CD Strict Mode

```bash
# Fail on any issues
oxlint --deny-warnings --max-warnings 0
```

### React + Next.js Project

```bash
oxlint \
  --react-plugin \
  --nextjs-plugin \
  --jsx-a11y-plugin \
  --import-plugin \
  --tsconfig ./tsconfig.json \
  src/ app/
```

### Fix All Auto-Fixable Issues

```bash
# Safe fixes only
oxlint --fix

# Including dangerous fixes
oxlint --fix-dangerously
```

### Monorepo Linting

```bash
# Lint multiple packages
oxlint packages/*/src

# With custom config per package
cd packages/app && oxlint src/
cd packages/lib && oxlint src/
```

### GitHub Actions Integration

```yaml
- name: Lint
  run: oxlint --format github --deny-warnings
```

### Save Results to File

```bash
# JSON output
oxlint --format json > lint-results.json

# JUnit XML
oxlint --format junit > lint-results.xml
```

## Combining Options

Most options can be combined:

```bash
oxlint \
  -c .oxlintrc.json \
  --react-plugin \
  --jsx-a11y-plugin \
  --fix \
  --deny-warnings \
  --format stylish \
  --ignore-pattern "**/*.test.ts" \
  src/ app/
```

## Performance Tips

1. **Specify paths** - Don't lint everything
   ```bash
   oxlint src/ app/  # Not: oxlint .
   ```

2. **Use ignore patterns** - Exclude node_modules, build dirs
   ```bash
   oxlint --ignore-pattern "node_modules/**"
   ```

3. **Disable expensive features** if not needed
   ```bash
   oxlint --disable-unicorn-plugin  # If you don't use it
   ```

4. **Profile with single thread** - Find slow files
   ```bash
   oxlint --threads 1
   ```
