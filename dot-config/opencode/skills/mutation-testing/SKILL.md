---
name: mutation-testing
description: Evaluate test suite quality by introducing code mutations and verifying tests catch them. Use for mutation testing, test quality, mutant detection, and test effectiveness analysis.
---

# Mutation Testing

## Overview

Mutation testing assesses test suite quality by introducing small changes (mutations) to source code and verifying that tests fail. If tests don't catch a mutation, it indicates gaps in test coverage or test quality. This technique helps identify weak or ineffective tests.

## When to Use

- Evaluating test suite effectiveness
- Finding untested code paths
- Improving test quality metrics
- Validating critical business logic is well-tested
- Identifying redundant or weak tests
- Measuring real test coverage beyond line coverage
- Ensuring tests actually verify behavior

## Key Concepts

- **Mutant**: Modified version of code with small change
- **Killed**: Test fails when mutation is introduced (good)
- **Survived**: Test passes despite mutation (test gap)
- **Equivalent**: Mutation that doesn't change behavior
- **Mutation Score**: Percentage of mutants killed
- **Mutation Operators**: Types of changes (arithmetic, conditional, etc.)

## Instructions

1. Introduce a random mutation in the source code, under the scope defined by the user.
2. Run the tests for the project
3. Keep track of the mutations you introduced in a MUTATIONS.md log file at the root of the repository.

If the test passed (mutant survived): it indicates a gap in coverage or test quality. Write a test update suggestion in your mutation log notes.

If the test failed (mutant was killed): good outcome. Revert the change, keep a note of it in the log, and start the loop again.

### Mutation Log

Follow this log format for the `MUTATIONS.md` file:

```markdown
## File being tested: path/to/file.ts

### Mutation 1

- Mutation: <description> (`<before>` -> `<after>`)
- Result: passed | failed
- Notes: <context>
```

## Common Mutation Operators

### Arithmetic Mutations

- `+` → `-`, `*`, `/`
- `-` → `+`, `*`, `/`
- `*` → `+`, `-`, `/`
- `/` → `+`, `-`, `*`

### Conditional Mutations

- `>` → `>=`, `<`, `==`
- `<` → `<=`, `>`, `==`
- `==` → `!=`
- `&&` → `||`
- `||` → `&&`

### Return Value Mutations

- `return true` → `return false`
- `return x` → `return x + 1`
- `return` → Remove return statement

### Statement Mutations

- Remove method calls
- Remove conditional blocks
- Remove increments/decrements

## Best Practices

### ✅ DO

- Focus on the scope defined by the user
- Target critical business logic for mutation testing
- Review survived mutants to improve tests
- Mark equivalent mutants to exclude them
- Test boundary conditions thoroughly
- Verify actual behavior, not just code execution

### ❌ DON'T

- Run mutation testing on all code (too slow)
- Ignore equivalent mutants
- Run mutations on generated code
- Skip mutation testing on complex logic
- Focus only on line coverage
