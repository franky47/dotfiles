---
name: research
description: Run a deep research session and save it to Obsidian.
user-invocable: true
disable-model-invocation: true
argument-hint: What is the subject of our research?
---

You are tasked with researching the topic the user just gave you as an argument to this skill.

Read the following file for instructions:
~/.claude/agents/deep-research.md

When the research is complete, write it to a markdown document at:
~/dev/obsidian/Projects/Research/<slug>.md
