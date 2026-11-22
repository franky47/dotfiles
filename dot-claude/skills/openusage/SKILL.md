---
name: openusage
description: Read AI subscription limits and pacing (Claude, Codex, Copilot and more) from the local OpenUsage menu bar app. Use when the user asks how much of a plan or model limit is left, or wants a long task or loop to run until usage catches up with the pace line or the limit resets.
---

# OpenUsage

!`~/.claude/skills/openusage/scripts/usage.sh || true`

## Read limits

```sh
~/.claude/skills/openusage/scripts/usage.sh [target]
```

```
claude/fable: 38% used, pace 53% (15 pts under), resets in 3d 6h at 2026-11-24T04:00:00Z
```

The pace line is the share of the window that has passed.
Under the line means spare quota to spend before the reset.

A target is a provider (`claude`), a model, an account (`codex@ab12cd34`) or one limit (`claude/weekly`).
Fable has its own limit (`claude/fable`); other Claude models use the shared Claude limit;
`gpt-*` and `o3`-style models use Codex.

## Run until caught up or reset

Pick the one limit to pace against, for example `claude/fable` for Fable work.
After each unit of work, run `usage.sh check <limit>`:

- exit 0: still under the pace line, continue.
- exit 1: caught up with the pace line, spent, stale or reset. Stop and report the line.
  Under 5% used counts as a reset, so a limit already under 5% stops at once.
- exit 2: error (app not running, bad target). Stop and report.

The app refreshes about every 5 minutes, so check after each unit of work, not in a tight loop.

## Gate a scripted run

`usage.sh gate <target>` exits 0 when every limit of the target is more than 5 pts under the pace line,
or its pace line is still under 10% (start of a window).
It exits 1 when a limit is within 5 pts of the line or over it,
or when a limit is spent, stale or reset due. It exits 2 on errors.
Use it in cron jobs or hooks to start an agent only when there is quota to spend:

```sh
~/.claude/skills/openusage/scripts/usage.sh gate fable >/dev/null && claude -p "..."
```