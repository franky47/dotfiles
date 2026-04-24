---
description: Refactor AGENTS.md using progressive disclosure
agent: general
subtask: true
---

Refactor the existing AGENTS.md file to follow progressive disclosure principles.

## Step 1: Read Current AGENTS.md

Load the @AGENTS.md file content and analyze its current structure.

If AGENTS.md does not exist, inform the user and suggest running `/init` first to create it.

## Step 2: Find Contradictions

Identify ALL instructions that conflict with each other. Examples of contradictions:

- Different formatting rules for the same thing
- Conflicting preferences (e.g., "use async/await" vs "use promises")
- Different naming conventions specified in different sections
- Contradictory import styles or patterns

Collect all contradictions first, then present them to the user in a single question asking which version to keep for each contradiction.

IMPORTANT: Do not proceed until the user has resolved all contradictions.

## Step 3: Identify the Essentials

Extract ONLY what belongs in the root AGENTS.md:

- One-sentence project description
- Package manager (if not npm)
- Non-standard build/typecheck commands (only if they differ from standard conventions)
- Anything truly relevant to EVERY single task

Everything else should be moved to separate files.

## Step 4: Group the Rest

Organize remaining instructions into logical categories. Common categories include:

- TypeScript conventions
- Testing patterns and strategies
- API design guidelines
- Git workflow and commit standards
- Code review standards
- Documentation standards
- Performance guidelines
- Security practices
- Error handling patterns
- Component architecture (for frontend projects)
- Database conventions (for backend projects)
- Build and deployment processes
- Monorepo conventions (if applicable)

Create appropriate categories based on the actual content found. Don't force categories if content doesn't naturally fit.

## Step 5: Infer Target Directory

Determine the best location for the split files by checking for existing agentic config directories:

1. Check if `.opencode/` directory exists → use `.opencode/docs/`
2. Check if `.claude/` directory exists → use `.claude/docs/`
3. Check if `.cursor/` directory exists → use `.cursor/docs/`
4. If none exist, create `agents/` directory in the project root

Use the Read or Glob tools to check for these directories. Pick the first one that exists.

## Step 6: Create the File Structure

Output the following:

### 1. Minimal Root AGENTS.md

Create a concise root AGENTS.md file with:

- Project one-liner
- Essential configuration (package manager, build commands if non-standard)
- Markdown links to the separate files (use relative paths)

Example structure:

```markdown
# Project Name

Brief one-sentence description of what this project does.

## Configuration

- Package manager: pnpm
- Build: `pnpm build`
- Typecheck: `pnpm typecheck`

## Development Guidelines

For detailed development guidelines, see:

- [TypeScript Conventions](docs/typescript.md)
- [Testing Patterns](docs/testing.md)
- [API Design](docs/api-design.md)
- [Git Workflow](docs/git-workflow.md)
```

### 2. Separate Category Files

Create each category file with:

- Clear heading with category name
- Relevant instructions from original AGENTS.md
- Well-organized sections with subheadings
- Specific, actionable guidelines

Ensure each file is self-contained and can be understood independently.

## Step 7: Flag for Deletion

Identify any instructions that are:

- **Redundant**: The agent already knows this from its base instructions (e.g., "use TypeScript", "follow best practices")
- **Too vague**: Cannot be acted upon without more specifics (e.g., "write clean code", "be careful")
- **Overly obvious**: States the obvious without adding value (e.g., "functions should work correctly")
- **Contradictory**: Instructions that weren't resolved in Step 2 but still conflict

For each flagged item, provide:

- The instruction text
- Why it should be removed
- Whether it needs replacement with something more specific

Present these to the user in the final report but DO NOT delete them automatically.

## Step 8: Final Report

Provide a comprehensive summary including:

- Location of the refined AGENTS.md
- List of created category files with their paths
- List of flagged items recommended for deletion with explanations

IMPORTANT:

- Do NOT create backups - Git will handle version control
- Do NOT commit any changes to git - The user will review and commit themselves
- Do show the user what was changed and where files were created
