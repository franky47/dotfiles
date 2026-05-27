---
name: scheduler
description: Schedule a prompt to fire back at yourself at a future time or on a recurring cron pattern. Use when the user says "remind me", "every N minutes/hours/days", "at HH:MM tomorrow", "check X periodically", or otherwise asks for any time-based action. Triggered by the `schedule` tool plus the `/schedule` command for listing and deletion.
---

# Scheduler

The `schedule` tool lets you enqueue a prompt that fires back as a user message when a cron pattern matches. The fired prompt triggers a fresh agent turn, so write the prompt as a complete, standalone instruction — past you won't be in context.

## ⚠ ALWAYS check the current time first

You have **no built-in clock**. Your training data is months or years stale. If you guess the year, you will pick the wrong one.

**Before computing any cron expression involving a relative offset** ("in N minutes", "tomorrow", "next Friday", "in 2 hours", "at 3pm" — anything that depends on "now"), run:

```bash
date "+%Y-%m-%d %H:%M %A"
```

Use the output as the basis for every date/time field in the cron. After the tool returns, read the `next fire` and `current time` lines back — if they don't match the user's intent, delete and reschedule.

Exception: if the user gives a fully absolute time with year ("on 2026-12-25 at 09:00"), you can construct the cron directly without consulting `date`.

## When to use it

Trigger the tool, don't try to remember manually:

- "remind me in 10 minutes" → one-shot, ~10 min from now (check `date` first!)
- "remind me at 3pm" → one-shot, today at 15:00 (or tomorrow if past — check `date`!)
- "every Monday at 9am send me my open PRs" → recurring weekday cron (no `date` needed)
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

| Request             | Steps                                       | Cron              | Recurring |
| ------------------- | ------------------------------------------- | ----------------- | --------- |
| in 10 minutes       | `date` → compute now+10min → pin all fields | `42 14 27 5 *`    | false     |
| every 5 minutes     | (no `date` needed)                          | `*/5 * * * *`     | true      |
| tomorrow at 8am     | `date` → tomorrow's date → pin              | `0 8 <DD> <MM> *` | false     |
| daily at 9am        | (no `date` needed)                          | `0 9 * * *`       | true      |
| weekdays at 9am     | (no `date` needed)                          | `0 9 * * MON-FRI` | true      |
| every Friday at 5pm | (no `date` needed)                          | `0 17 * * FRI`    | true      |

For one-shot reminders, pin minute + hour + day + month exactly and set `recurring: false`. The task auto-deletes after firing.

## The prompt argument

The `prompt` is what gets sent back when the task fires. Make it self-contained — the agent that picks it up may not have prior context. Bad: "do the thing". Good: "Check the open PRs on owner/repo and summarize any with failing CI."

## Listing and deleting

- `/schedule` — lists active tasks (id, schedule, next fire, prompt preview)
- `/schedule delete <id>` — removes a task

## Firing model

- Tasks fire via a single in-process timer for the soonest due task. They also drain on `turn_end` as a fallback. Sub-second jitter on the wall clock is expected.
- One message per fired task. If 3 tasks fire at once, you get 3 sequential turns.
- Tasks persist across reloads (stored in session JSONL). On session start, overdue tasks fire immediately.
- Tasks are scoped to the session JSONL. Resuming the same session restores them; `/new` (a fresh session) starts with no tasks.
