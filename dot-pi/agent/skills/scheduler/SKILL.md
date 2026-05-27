---
name: scheduler
description: Schedule a prompt to fire back at yourself at a future time or on a recurring cron pattern. Use when the user says "remind me", "every N minutes/hours/days", "at HH:MM tomorrow", "check X periodically", or otherwise asks for any time-based action. Triggered by the `schedule` tool plus the `/schedule` command for listing and deletion.
---

# Scheduler

The `schedule` tool lets you enqueue a prompt that fires back as a user message when a cron pattern matches. The fired prompt triggers a fresh agent turn, so write the prompt as a complete, standalone instruction — past you won't be in context.

## When to use it

Trigger the tool, don't try to remember manually:

- "remind me in 10 minutes" → one-shot, ~10 min from now
- "remind me at 3pm" → one-shot, today at 15:00 (or tomorrow if past)
- "every Monday at 9am send me my open PRs" → recurring weekday cron
- "check the build status every 30 minutes" → recurring `*/30 * * * *`
- "wake me up daily with the news" → recurring `0 8 * * *`

If the user's request has a time component and an action component, schedule it.

## Cron format (5 fields)

```
minute hour day-of-month month day-of-week
0-59   0-23 1-31         1-12  0-7   (0 and 7 both = Sunday)
```

Supported syntax:

- `*` — any value
- `*/N` — every N (e.g. `*/15` in minute field = every 15 min)
- `A-B` — range (e.g. `9-17` in hour field)
- `A-B/N` — stepped range (e.g. `1-10/2`)
- `A,B,C` — list (e.g. `MON,WED,FRI` or `1,15,30`)
- Month aliases: `JAN`-`DEC`
- Day-of-week aliases: `SUN`-`SAT`

When both day-of-month and day-of-week are restricted, the task fires when **either** matches (standard cron behavior).

## Constructing a cron from natural language

You generate the cron expression. The tool validates it and rejects anything bogus.

| Request | Cron | Recurring |
|---|---|---|
| in 10 minutes (from 14:32) | `42 14 27 5 *` | false |
| every 5 minutes | `*/5 * * * *` | true |
| daily at 9am | `0 9 * * *` | true |
| weekdays at 9am | `0 9 * * MON-FRI` | true |
| first of every month at midnight | `0 0 1 * *` | true |
| every Friday at 5pm | `0 17 * * FRI` | true |
| tomorrow at 8am (one-shot) | `0 8 <DD> <MM> *` | false |

For one-shot reminders that are not naturally a recurring pattern, pin minute + hour + day + month exactly and set `recurring: false`. The task auto-deletes after firing.

## The prompt argument

The `prompt` is what gets sent back when the task fires. Make it self-contained — the agent that picks it up may not have prior context. Bad: "do the thing". Good: "Check the open PRs on owner/repo and summarize any with failing CI."

## Listing and deleting

- `/schedule` — lists active tasks (id, schedule, next fire, prompt preview)
- `/schedule delete <id>` — removes a task

You can also call the schedule tool to create new tasks; deletion goes through the slash command (no `unschedule` tool — keeps the tool surface small).

## Firing model

- Tasks fire on `turn_end` (when you become idle). Sub-minute lag while you're mid-turn is expected.
- One message per fired task. If 3 tasks fire at once, you get 3 sequential turns.
- Tasks persist across reloads (stored in session JSONL). On session start, overdue tasks are flagged and fire on the next turn.
- Tasks are scoped to the session. They do not carry across `/new` or `/resume`.
