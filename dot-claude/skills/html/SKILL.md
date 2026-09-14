---
name: html
description: Render a standalone HTML file when the user explicitly asks for a durable file outside Sideshow.
---

Generate a self-contained HTML document summarising what the user asked for in this session. If the user asks for Sideshow or a live visual surface, load and use the `sideshow` skill instead; it owns publication, rendering, and comments.

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
