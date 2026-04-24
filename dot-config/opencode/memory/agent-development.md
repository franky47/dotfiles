# Agent Development & OpenCode System Patterns

## OpenCode Permissions System (v1.1.1+)

**Date:** 2026-02-17  
**Context:** Migration from deprecated `tools: true/false` to `permission: allow/ask/deny` format

### Permission Structure

- **Values:** `allow`, `ask`, or `deny` (replaces deprecated boolean `true/false`)
- **Available permissions:** `read`, `edit`, `bash`, `webfetch`, `websearch`, `task`, `skill`, `external_directory`
- **Granular control:** Path patterns with wildcards, command-specific bash permissions
- **Note:** `write` is NOT a valid permission key — see dedicated section below

### Pattern Matching Rules

- `*` matches zero or more characters (within a single path segment)
- `?` matches exactly one character
- `**` matches recursively through directories
- `~` expands to user's home directory
- **Last matching rule wins** - put `"*": deny` first, then specific allows after

### Common Permission Patterns

```yaml
permission:
  # Read-only agent
  read: allow
  grep: allow
  glob: allow
  edit: deny   # covers edit, write, patch, multiedit — do NOT use write: here
  bash: deny

  # With bash access for specific commands
  bash:
    "*": ask
    "git status": allow
    "git diff": allow
    "rm *": deny

  # With external directory access
  external_directory:
    "~/.config/opencode/**": allow
```

### Migration Gotchas Found

1. **Review agent without read/grep/glob** → Completely non-functional
2. **Learn agent missing `question` permission** → Can't use interactive prompts despite instructions referencing it
3. **Inconsistent model declarations** → Some agents missing explicit model
4. **Backwards compatibility trap** → Old `tools: true/false` works but blocks granular features

**Reference:** [OpenCode Agent Permissions](https://opencode.ai/docs/agents)

---

## Memory System Structure

**Date:** 2026-02-16  
**Context:** Implementing persistent memory storage

### Directory Layout

```
~/.config/opencode/memory/
├── user-preferences.md      # User-specific constraints and preferences
├── tech-stack-patterns.md   # Framework and tool patterns
├── common-issues.md         # Problems and solutions
├── project-context.md       # Project-specific knowledge
└── [emergent-categories].md # Any category that emerges organically
```

### File Format Guidelines

- Date-stamped entries
- Clear topic headings
- Context about when/why information matters
- Links to relevant files or documentation
- Append-only updates (don't overwrite, add new entries)

---

## When to Invoke @memory Agent

**Date:** 2026-02-16  
**Context:** Defining the memory agent's role in workflow

### Who Can Invoke

**Only `@plan` and `@build` agents** invoke `@memory`:

- Use strict allow-list: only these primary agents trigger memory capture
- Conversational agents (eg: `@ask`, `@brainstorm`, `@learn`) never invoke `@memory`

### Invocation Points

- End of planning sessions (by `@plan` agent)
- End of building sessions (by `@build` agent)
- At any point in a plan/build session when significant learnings occurred

### What to Capture

1. **User Clarifications** - Preferences, constraints, context provided
2. **Problem Solutions** - Issues encountered and resolutions
3. **Documentation Discoveries** - Key findings from context7/websearch/webfetch
4. **Patterns** - Reusable solutions that could become skills/agents
5. **Gotchas** - Common pitfalls and avoidance strategies

---

## Agent File Structure

**Date:** 2026-02-16  
**Context:** Creating agent definitions

### Required Frontmatter

```yaml
---
description: Clear description of agent purpose
mode: primary | subagent
temperature: 0.1-1.0 # lower = more deterministic
permission:
  # permission rules here
---
```

### File Organization

- **Global agents:** `~/.config/opencode/agents/*.md`
- **Subagents:** `~/.config/opencode/agents/sub/*.md`
- **Naming:** Descriptive names (e.g., `memory.md`, `review.md`)
- **Format:** Markdown with YAML frontmatter + instructions body

### Best Practices

- Start restrictive - deny by default, allow explicitly
- Include `read`, `grep`, `glob` for any agent that explores code
- Add `question` permission if agent uses interactive prompts
- Declare explicit model for consistency
- Give agents access to creation skills only when needed

### Agent Memory Access Patterns

**Only `@plan` and `@build` agents should invoke `@memory`**:

- Use an allow-list approach: only these agents invoke the memory sub-agent
- Conversational agents (`@ask`, `@brainstorm`, `@learn`) do NOT invoke `@memory`
- Do not mention `@memory` in conversational agent instructions

**Why restrict invocation?**

- Memory capture is a deliberate end-of-session activity
- Conversational agents are for back-and-forth dialogue, not session wrap-up
- Prevents redundant or premature memory writes
- Keeps memory content high-quality and session-complete

**Memory agent** (`@memory`):

- Only agent that writes to `~/.config/opencode/memory/`
- Invoked at end of planning/building sessions to capture learnings
- Has granular write permissions restricted to memory directory only

---

## `write:` is NOT a Valid Permission Key — Use `edit:` Instead

**Date:** 2026-02-23  
**Context:** Memory agent had a broken permission config — the `write:` key was silently ignored, leaving the agent with unrestricted write access

The `edit` permission key covers **all** file modification tools: `edit`, `write`, `patch`, and `multiedit`. There is no separate `write:` permission key — using it as a top-level key is **silently ignored**.

### Broken config

```yaml
permission:
  edit:
    '*': deny
    '~/.config/opencode/memory/*.md': allow
  write: # INVALID — silently ignored, grants no restrictions
    '*': deny
    '~/.config/opencode/memory/*.md': allow
```

### Correct config

```yaml
permission:
  edit:
    '*': deny
    '~/.config/opencode/memory/*.md': allow
```

### Rule Evaluation Order

**Last matching rule wins.** Put the `"*"` catch-all first, specific overrides after:

```yaml
permission:
  edit:
    '*': deny # catch-all first
    '~/safe/**': allow # specific override last — this wins for matching paths
```

This also applies to `bash` command matching: `"*": ask` first, then `"git status": allow` overrides after.
