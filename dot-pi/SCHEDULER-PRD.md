# Scheduler Extension for Pi

## Problem Statement

Pi has no built-in mechanism for scheduling prompts to fire at future times. When a user wants the agent to "remind me in 10 minutes" or "check the build status every hour", they must manually re-prompt the agent each time. Other coding agents like Claude Code support scheduling via natural language ("remind me at 3pm", "run tests every hour") which converts the user's intent into a structured cron task, fires the prompt back into the agent's session loop, and handles missed-task catch-up.

Users of Pi lack this capability, forcing manual repetition of recurring tasks and making time-based reminders impossible without leaving the terminal or spawning external processes.

## Solution

A Pi extension that adds time-based scheduling to the agent's capabilities. The extension provides a `schedule` tool that the agent can call with a cron expression and prompt text. When a scheduled task's fire time arrives (checked when the agent becomes idle after each turn), the prompt is injected back into the session as a new user message, triggering a new turn.

The extension also provides a `/schedule` command for listing active tasks, and a skill that guides the agent on when and how to use the scheduler.

Tasks are stored as JSONL entries in the session file via `pi.appendEntry()`, making them durable across process crashes and reloads. Recurring tasks are automatically rescheduled. Missed tasks are surfaced for catch-up on session start.

## User Stories

1. As a developer, I want to schedule a reminder for a specific future time, so that I don't need to manually remember to check back
2. As a developer, I want to schedule a recurring task (e.g., "check PRs every hour"), so that I get automatic periodic updates without re-prompting
3. As a developer, I want the agent to understand natural language scheduling requests ("remind me in 10 minutes", "every weekday at 9am"), so that I don't need to learn cron syntax
4. As a developer, I want to list all my scheduled tasks at any time, so that I can review what's pending
5. As a developer, I want to cancel a scheduled task, so that I can clean up tasks I no longer need
6. As a developer, I want missed tasks to be surfaced when I return to Pi after being away, so that I can run tasks that should have fired while I was gone
7. As a developer, I want scheduled tasks to survive process crashes and reloads, so that my reminders don't disappear unexpectedly
8. As a developer, I want each scheduled task to trigger a full agent response (not just a notification), so that the agent can act on the scheduled prompt
9. As a developer, I want to know when a scheduled task will next fire, so that I can plan my workflow accordingly
10. As a developer, I want the agent to suggest using the scheduler when I make a time-based request, so that I don't have to ask for it explicitly
11. As a developer, I want one-shot tasks to auto-delete after firing, so that I don't accumulate stale task entries
12. As a developer, I want recurring tasks to be explicitly marked as recurring, so that I can schedule a one-time task that happens to match a recurring cron pattern
13. As a developer, I want to schedule tasks that include multiple instructions in the prompt, so that the agent gets complete context when the task fires
14. As a developer, I want to schedule tasks with cron expressions that use wildcards and steps (e.g., `*/5 * * * *`), so that I can express arbitrary recurrence patterns

## Implementation Decisions

### Architecture
- Extension-only: zero changes to the Pi core harness
- No polling timer: tasks are checked for firing on `turn_end` when the agent becomes idle (drain-on-idle model)
- Storage: all tasks stored as JSONL custom entries in the session file via `pi.appendEntry("scheduler-task", task)`, making them durable across crashes and reloads
- Fire delivery: fired tasks are delivered via `pi.sendUserMessage(task.prompt, {deliverAs: "followUp"})`, which triggers a new agent turn
- One message per task: each fired task becomes its own user message in the session (not batched)

### Components
1. **`schedule` tool** — Registered via `pi.registerTool()`. Parameters: `cron` (string, 5-field cron expression), `prompt` (string, the natural-language prompt to enqueue), `recurring` (boolean, default true). Returns the generated task ID and a human-readable schedule description. The agent generates cron expressions from the user's natural language request; the tool validates the expression.
2. **`/schedule` command** — Registered via `pi.registerCommand()`. Lists all active scheduled tasks with their ID, cron expression, prompt preview, next fire time, and recurring status. Supports deletion by ID.
3. **Cron parser** — A hand-rolled TypeScript module that parses standard 5-field cron expressions (minute, hour, day-of-month, month, day-of-week). Handles wildcards (`*`), numeric values, step expressions (`*/5`, `1-10/2`), comma-separated values, and validates ranges. Provides `parseCron()` for validation and `nextCronRunMs()` to compute the next matching epoch-ms time.
4. **Scheduler manager** — The core logic that stores tasks in JSONL, drains due tasks on `turn_end`, detects missed tasks on `session_start`, and handles recurring task rescheduling. Stores tasks as `{id, cron, prompt, createdAt, lastFiredAt?, recurring}`.
5. **Scheduler skill** — A `~/.pi/agent/skills/scheduler/SKILL.md` that guides the agent on when to use the scheduler (reminders, recurring checks, "set a cron" patterns) and how to construct cron expressions. The skill is auto-loaded by Pi's skill discovery.
6. **Tool `promptGuidelines`** — The schedule tool's registration includes a `promptGuidelines` entry that reminds the agent to use the schedule tool for time-based requests.

### Task lifecycle
- **Create**: Agent calls the `schedule` tool → task is validated → `pi.appendEntry()` stores it in the session JSONL
- **Fire**: On `turn_end`, the extension checks if any task's `nextFireAt <= now` → `pi.sendUserMessage()` with followUp delivery
- **One-shot**: Task is removed from storage after firing (entry is still in JSONL but filtered out by ID)
- **Recurring**: Next fire time is computed from `lastFiredAt` (or `createdAt` if never fired), stored is updated, task remains active
- **Missed**: On `session_start`, tasks whose next fire time is in the past are surfaced to the user with a catch-up prompt
- **Delete**: `/schedule` lists tasks; the model calls the delete command with a task ID; the extension removes the entry from the session

### System prompt composition
- Custom prompts in Pi completely override the default system prompt (tools list, guidelines, docs are all replaced)
- The scheduler skill survives custom prompts because skills are appended regardless of custom prompt
- The tool's `promptGuidelines` is visible in the guidelines section when using the default system prompt
- The skill provides the detailed "when" guidance that survives custom prompt overrides

### Recurring task fire-time computation
- First-sight: compute from `createdAt` (correct for pinned crons whose next match is far in the future)
- Fired tasks: compute from `lastFiredAt` (preserves schedule continuity across process restarts)
- On session start: recompute next fire time from the stored `lastFiredAt` to catch up

### Cron expression format
- Standard 5-field: `M H DoM Mon DoW` (minute, hour, day-of-month, month, day-of-week)
- Wildcards: `*` (any value)
- Steps: `*/5` (every 5th), `1-10/2` (every 2nd in range)
- Lists: `1,3,5` (specific values)
- Ranges: `1-5` (inclusive)
- Local time (no timezone conversion)
- Minute-level precision

### Error handling
- Invalid cron expression: tool returns an error message with guidance on valid formats
- Cron with no match in next year: tool rejects with a specific error
- Task storage failure: tool returns error (session file write failure)
- Missed task on startup: surfaced as a notification asking if the user wants to run them now
- Concurrent turn: if a task fires while the agent is mid-turn, it waits until `turn_end`

## Testing Decisions

### What makes a good test
- Tests should focus on external, observable behavior: given a cron expression, does `nextCronRunMs()` return the correct epoch-ms value? Given a set of scheduled tasks, does the drain function fire the correct ones? Given a task that fires, does `sendUserMessage()` get called with the right parameters?
- Tests should be deterministic and not depend on wall-clock time. Use a fixed timestamp as the reference point for all cron computations.
- Tests should cover edge cases: pinned crons (e.g., `30 14 27 2 *`), step expressions, boundary conditions (month transitions, leap years), invalid expressions.

### Modules to test
1. **Cron parser** — Primary test target. Test `parseCron()` and `nextCronRunMs()` with a comprehensive set of cron expressions and expected next-fire times. This is a pure function with no side effects, making it trivially testable in isolation.
2. **Scheduler manager** — Test the drain logic: given a set of tasks with known `nextFireAt` values and a fixed `now`, verify the correct tasks are selected for firing. Test recurring task rescheduling. Test missed-task detection.
3. **Tool integration** — Test the `schedule` tool's validation: valid cron → success, invalid cron → error, future time → scheduled, past time → rejected.

### Prior art
The existing `websearch` and `webfetch` extensions in the dot-pi directory demonstrate the pattern of registering tools with `promptGuidelines` and handling tool execution with proper error reporting. The cron parser is analogous to a utility module — a pure function tested independently of the extension lifecycle.

## Out of Scope

- Cron expression generation by the model: the tool accepts a cron string and validates it. The model generates the cron from natural language. We do not build a separate "natural language to cron" converter.
- Timezone handling: cron expressions use local time. No timezone conversion or display of the user's timezone.
- Notification UI: fired tasks are delivered as user messages, not as toast notifications or status bar messages.
- Priority levels for scheduled tasks: all tasks are delivered as follow-up user messages. No "now" vs "later" priority distinction.
- Cron expression editing: to change a scheduled task, the user must delete it and create a new one. No edit-in-place functionality.
- Bulk operations: no "delete all tasks" or "disable all tasks". Each task is managed individually.
- Daemon mode: no long-running background process. Tasks only fire when the agent is idle between turns.
- Cross-session task sharing: tasks are scoped to the session they were created in. They do not persist across `/new` or `/resume` (though they survive within a session via JSONL persistence).

## Further Notes

### Why drain-on-idle (no polling timer)
Pi's extension model does not have a built-in message queue. Tasks are drained on `turn_end` events, which means tasks only fire when the agent is idle. This is a deliberate tradeoff:
- Simpler: no timers, no `unref()`, no clock drift, no idle overhead
- Natural fit: the agent is the one that needs to process the scheduled prompt, so checking when the agent becomes idle aligns with the execution model
- Acceptable latency: for most scheduling use cases (reminders, recurring checks), sub-minute latency while the agent is busy is not a problem

### Why store in session JSONL
Using `pi.appendEntry()` stores tasks in the session JSONL file, making them:
- Durable: survive process crashes, reloads, and session saves
- Discoverable: appear in session listings and can be inspected via `/session`
- Self-contained: no separate state files to manage

The tradeoff is that tasks may be pushed out of the LLM's context window during compaction. This is acceptable because:
- The entries still exist in the JSONL file (compaction only summarizes, doesn't delete)
- On session start, the extension scans all entries and restores the full task list
- If compaction becomes a real problem, the scheduler skill can instruct the model to scan for task entries during compaction

### Why one message per task
Each fired task becomes its own user message in the session. This means:
- Each task gets a full agent response
- Tasks are processed sequentially (one turn per task)
- If 5 tasks fire, the agent processes 5 turns in quick succession

Batching is deferred: if users report that multiple simultaneous tasks cause excessive turns, batching into a single message can be added later as an optimization.

### Skill placement
The scheduler skill is placed in `~/.pi/agent/skills/scheduler/SKILL.md` in the user's dotfiles (symlinked to `~/.pi`). This ensures:
- The skill is always available (global location)
- It survives Pi updates and reinstallations
- It works with both the default and custom system prompts (skills are appended regardless of custom prompt)
- The model auto-loads it when the skill's description matches the user's request

### Cron validation vs. generation
The tool validates the cron expression but does not generate it. The model's natural language understanding is used to convert the user's request into a cron expression, and the tool's validation ensures correctness. This leverages the model's existing reasoning capabilities rather than building a fragile NL-to-cron parser. If the model generates an invalid cron, the tool returns a clear error message that the model can use to retry.
