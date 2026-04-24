# Agent Creation Guide

Step-by-step guide for creating custom OpenCode agents.

## Step 1: Determine Agent Purpose

Ask yourself:

- What specific task should this agent perform?
- Should it be a primary agent (switchable) or subagent (@mention)?
- What tools does it need?
- Should it be able to modify files or just analyze?

**Decision Matrix:**

| Use Case             | Mode     | Tools       | Example             |
| -------------------- | -------- | ----------- | ------------------- |
| Alternative to Build | Primary  | All enabled | Custom dev workflow |
| Planning/analysis    | Primary  | Read-only   | Pre-code review     |
| Code review          | Subagent | Read-only   | @review             |
| Research             | Subagent | Web + read  | @research           |
| Specialized task     | Subagent | Specific    | @test-writer        |

## Step 2: Choose File Location

**Global agent** (available in all projects):

```bash
~/.config/opencode/agents/my-agent.md
```

**Project-specific agent** (only in this project):

```bash
./.opencode/agents/my-agent.md
```

**JSON config** (opencode.json):

```json
{
  "agent": {
    "my-agent": { ... }
  }
}
```

## Step 3: Write Agent Configuration

### Basic Subagent Example

Create `~/.config/opencode/agents/reviewer.md`:

```markdown
---
description: Reviews code for quality and best practices
mode: subagent
tools:
  write: false
  edit: false
  bash: false
---

You are a code reviewer. Focus on:

- Code quality and maintainability
- Potential bugs and edge cases
- Security considerations
- Performance implications

Provide constructive feedback without making changes.
```

### Primary Agent Example

Create `~/.config/opencode/agents/planner.md`:

```markdown
---
description: Planning and analysis without code changes
mode: primary
tools:
  write: false
  edit: false
  bash: false
---

You are a planning assistant. Help users:

- Break down complex tasks
- Analyze codebases before changes
- Design system architecture
- Create implementation strategies

Never modify files - only analyze and suggest.
```

## Step 4: Configure Tools

### Available Tools

- `read` - Read files and directories
- `write` - Create new files
- `edit` - Modify existing files
- `bash` - Execute shell commands
- `grep` - Search file contents
- `glob` - Find files by pattern
- `webfetch` - Fetch web content
- `websearch` - Search the internet
- `task` - Invoke subagents

### Tool Patterns

**Read-only agent:**

```yaml
tools:
  write: false
  edit: false
  bash: false
```

**Full access agent:**

```yaml
tools:
  write: true
  edit: true
  bash: true
```

**Research agent:**

```yaml
tools:
  write: false
  edit: false
  webfetch: true
  websearch: true
```

## Step 5: Set Permissions

Control approval requirements:

```yaml
permission:
  edit: ask # Prompt before editing
  bash:
    '*': ask # Ask for all bash commands
    'git status*': allow # Except git status
    'git log*': allow # And git log
```

## Step 6: Write System Prompt

Effective prompts include:

1. **Role definition**

   ```
   You are a [specific role] specializing in [domain].
   ```

2. **Core responsibilities**

   ```
   Your main tasks are:
   - Task 1
   - Task 2
   - Task 3
   ```

3. **Constraints**

   ```
   You MUST NOT:
   - Modify files without explicit permission
   - Execute destructive commands
   - Share sensitive information
   ```

4. **Output format**

   ```
   Structure your responses as:
   1. Analysis
   2. Recommendations
   3. Next steps
   ```

5. **Examples (if helpful)**
   ```
   Example interaction:
   User: "Review this function"
   You: "I'll analyze this for potential issues..."
   ```

## Step 7: Test the Agent

1. **Switch to the agent** (if primary) or **@mention it** (if subagent)
2. **Test tool access**: Ask it to perform actions it should/shouldn't do
3. **Verify permissions**: Try restricted operations
4. **Refine prompt**: Adjust based on behavior

## Step 8: Iterate

Common refinements:

- **Too verbose?** Add "Be concise" to prompt
- **Wrong tool usage?** Adjust tool permissions
- **Not invoked correctly?** Improve description
- **Wrong tone?** Adjust temperature (0.1-0.3 for serious, 0.5-0.7 for creative)

## Example: Complete Research Agent

```markdown
---
description: Research assistant that searches the web and summarizes findings
mode: subagent
temperature: 0.2
tools:
  write: false
  edit: false
  bash: false
  webfetch: true
  websearch: true
---

You are a research assistant. Your job is to:

1. Search for accurate, up-to-date information
2. Summarize findings clearly and concisely
3. Cite sources when possible
4. Ask clarifying questions if the topic is ambiguous

Guidelines:

- Use websearch to find current information
- Use webfetch to read specific pages
- Synthesize information from multiple sources
- Highlight conflicting information if found
- Keep summaries under 3 paragraphs when possible

You cannot modify files or execute commands - focus purely on research.
```

## Troubleshooting

**Agent not showing up?**

- Check file is in correct location
- Verify YAML frontmatter is valid
- Restart OpenCode

**Tools not working?**

- Check tool names match exactly
- Verify parent config doesn't override
- Check permission settings

**Model not using agent correctly?**

- Improve description to be more specific
- Add examples to prompt
- Consider making it primary agent instead

## References

- [OpenCode Agents Documentation](https://opencode.ai/docs/agents.md)
- [Tool Reference](https://opencode.ai/docs/tools.md)
- [Permission System](https://opencode.ai/docs/permissions.md)
