---
name: html
description: Render a document, a diagram, or a report as HTML for human visualisation.
---

Generate a self-contained HTML document summarising what the user asked for in this session.

## Contents

Read the `prose` skill for guidelines on content (syntax, grammar, tone, verbosity): @../prose/SKILL.md

Include:

- Diagrams (sequence, ERD, flowcharts, pick which is relevant)
- Code samples (syntax highlighted)
- Links to the code (opening in VScode) in context

If you can represent a concept visually, prefer a diagram to a wall of text.
User attention is scarce, optimise for visual understanding.

## Style

Dark mode, mobile-friendly responsive design. Use this design system:

```!
curl https://vercel.com/design.dark.md
```

## Output

Save the generated file in my Obsidian vault: `~/dev/obsidian/Projects/<projectName>/<fileName>.html`,
check for vault layout first.
