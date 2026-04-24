---
name: create-agent
description: Guide for creating custom OpenCode agents using markdown files with YAML frontmatter
---

# Create Agent

Create custom OpenCode agents using **markdown files with YAML frontmatter** - the preferred method for readability and version control.

## Markdown Format (Recommended)

Create `~/.config/opencode/agents/my-agent.md`:

```markdown
---
description: What this agent does
mode: subagent | primary
temperature: 0.3
permission:
  edit: deny
---

System prompt here...
```

**File locations:**

- Global: `~/.config/opencode/agents/*.md`
- Project: `.opencode/agents/*.md`

## Key Configuration

| Option        | Description                                         | Example           |
| ------------- | --------------------------------------------------- | ----------------- |
| `description` | When to use this agent (required)                   | `"Code reviewer"` |
| `mode`        | `primary` (Tab-switchable) or `subagent` (@mention) | `subagent`        |
| `permission`  | Tool access control: `allow`, `ask`, or `deny`      | `edit: deny`      |
| `temperature` | 0.0-1.0 (lower=focused)                             | `0.3`             |

## Common Patterns

### Read-Only Research Agent

```markdown
---
description: Research assistant with web access
mode: subagent
permission:
  read: allow
  webfetch: allow
  websearch: allow
  edit: deny
  bash: deny
---
```

### Restricted Primary Agent

```markdown
---
description: Planning mode without file changes
mode: primary
permission:
  read: allow
  edit: deny
  bash: deny
---
```

### Code Review Subagent

```markdown
---
description: Reviews code for quality and best practices
mode: subagent
permission:
  read: allow
  grep: allow
  glob: allow
  edit: deny
  bash:
    '*': ask
    'git *': allow
---
```

## Prompt Design

Effective prompts include:

1. **Clear role**: "You are a..."
2. **Responsibilities**: "Your tasks are..."
3. **Constraints**: "You MUST NOT..."
4. **Output format**: "Structure responses as..."
5. **Examples**: 1-2 sample interactions
6. **Tone guidelines**: "Be concise and professional."

## Tool Reference

Common permissions to configure:

- `read` / `grep` / `glob` - Code exploration
- `edit` / `bash` - File operations (deny for safety)
- `webfetch` / `websearch` - Internet access
- `task` - Invoking other subagents
- `question` - Interactive user prompts

Use `allow`, `ask`, or `deny` values. Use object syntax for granular control:

```yaml
permission:
  bash:
    '*': ask
    'git status': allow
    'rm *': deny
```

## Permissions

Control approvals in YAML:

```yaml
permission:
  edit: ask # Prompt before edit
  bash:
    '*': ask # Ask all commands
    'git status': allow # Except git status
```

### Permission Key for File Writes

> **Important:** The `edit` key controls ALL file modification tools: `edit`, `write`, `patch`, and `multiedit`.
> There is **no separate `write:` key** — it is silently ignored if present. Always use `edit:` to restrict file writes.

### Wildcard Path Patterns

> **Gotcha:** `**` is NOT a true globstar — it requires a literal `/` separator to work. Use `*.md` for files
> directly inside a directory; use `**/*.md` only when files are guaranteed to be in subdirectories.

```yaml
permission:
  edit:
    "*": deny
    "~/.config/opencode/memory/*.md": allow    # correct — files directly in memory/
    # "~/.config/opencode/memory/**/*.md": allow  # WRONG — never matches flat files
```

### Rule Evaluation Order

**Last matching rule wins.** Always put the `"*"` catch-all first, specific overrides after:

```yaml
permission:
  edit:
    "*": deny            # catch-all first
    "~/safe/subdir/*.md": allow   # specific override last — this wins for matching paths
  bash:
    "*": ask             # catch-all first
    "git status": allow  # specific override last
```

### `external_directory` and `edit:` Are Independent

> **Gotcha:** `external_directory` only gates access to out-of-project paths. The `edit:` permission rules
> still run independently on top. You must configure **both** for agents that write to paths outside the project.

```yaml
permission:
  external_directory:
    "~/.config/opencode": allow      # gates out-of-project access
  edit:
    "*": deny
    "~/.config/opencode/memory/*.md": allow  # still required — edit rules apply independently
```

## Best Practices

- **Start restrictive**: Read-only by default
- **Use `edit: deny`** to block all file writes (not `write: deny` — that key doesn't exist)
- **Use `*.md` not `**/*.md`** for files directly inside a directory
- **Configure both `external_directory` and `edit:`** when writing outside the project root
- **Specific descriptions**: Help model know when to invoke
- **Test incrementally**: Verify tool access works
- **Iterate**: Refine prompts based on usage

## Full Example

```markdown
---
description: Security auditor that identifies vulnerabilities
mode: subagent
temperature: 0.2
permission:
  read: allow
  grep: allow
  glob: allow
  edit: deny
  bash: deny
---

You are a security auditor. Focus on:

- Input validation vulnerabilities
- Authentication flaws
- Data exposure risks
- Dependency vulnerabilities

Provide specific recommendations with code examples.
Never modify files - only report findings.
```

## References

- [Step-by-step guide](references/agent-creation-guide.md)
- [OpenCode docs](https://opencode.ai/docs/agents.md)
