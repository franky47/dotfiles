import type { ExtensionAPI } from '@earendil-works/pi-coding-agent'
import { Type } from 'typebox'
import { describeCron } from './cron.ts'
import { formatTask, SchedulerManager } from './manager.ts'

export default function (pi: ExtensionAPI) {
  const manager = new SchedulerManager(pi)
  // Single timer armed for the soonest due task. Without this, tasks would
  // only fire on turn_end — leaving idle sessions silent past the fire time.
  let timer: ReturnType<typeof setTimeout> | undefined

  function clearFireTimer() {
    if (timer) {
      clearTimeout(timer)
      timer = undefined
    }
  }

  function drainDue() {
    const now = Date.now()
    const due = manager.due(now)
    if (due.length === 0) return
    for (const task of due) {
      manager.markFired(task.id, now)
      pi.sendUserMessage(task.prompt, { deliverAs: 'followUp' })
    }
  }

  function armFireTimer() {
    clearFireTimer()
    const upcoming = manager
      .list()
      .map((t) => t.nextFireAt)
      .filter((n): n is number => n !== null)
    if (upcoming.length === 0) return
    const next = Math.min(...upcoming)
    const delay = Math.max(0, next - Date.now())
    timer = setTimeout(() => {
      timer = undefined
      drainDue()
      armFireTimer()
    }, delay)
    // Don't keep pi alive solely on the scheduler timer.
    timer.unref?.()
  }

  pi.on('session_start', async (_event, ctx) => {
    manager.rebuild(ctx)
    const overdue = manager.due(Date.now())
    if (overdue.length > 0 && ctx.hasUI) {
      const summary =
        overdue.length === 1
          ? `1 scheduled task is overdue — firing now.`
          : `${overdue.length} scheduled tasks are overdue — firing now.`
      ctx.ui.notify(summary, 'info')
    }
    armFireTimer()
  })

  pi.on('turn_end', async () => {
    drainDue()
    armFireTimer()
  })

  pi.on('session_shutdown', async () => {
    clearFireTimer()
  })

  pi.registerTool({
    name: 'schedule',
    label: 'Schedule',
    description:
      'Schedule a prompt to be re-sent to yourself at a future time using a 5-field cron expression. Use for reminders, recurring checks, or any time-based prompt. The prompt fires as a follow-up user message when the cron pattern next matches.\n\nCRITICAL: you have no built-in clock. Before computing any cron expression involving a relative offset ("in 5 minutes", "tomorrow", "next Friday", "in 2 hours"), you MUST first run `date "+%Y-%m-%d %H:%M %A"` via bash to get the current local time. The tool\'s response includes the current time so you can sanity-check the next-fire output before reporting back to the user.',
    promptSnippet: 'Schedule a future prompt with a cron expression',
    promptGuidelines: [
      'When the user says "remind me", "every N minutes/hours/days", "at HH:MM", or otherwise asks for a time-based action, use the schedule tool instead of trying to remember manually.',
      'You DO NOT know the current time. Before scheduling anything with a relative offset ("in N min", "tomorrow", "next week"), run `date "+%Y-%m-%d %H:%M %A"` first.',
      'Convert the user\'s natural-language time into a 5-field cron expression (minute hour day-of-month month day-of-week). For one-shot reminders, pin the cron to the exact minute (e.g. "30 14 27 5 *") and set recurring=false. Always sanity-check the tool\'s reported "next fire" against the current time.',
      'The prompt argument is what gets sent back to you when the task fires — write it as a complete instruction, not a summary. The agent reading it on fire has no memory of this conversation.',
      'Use the /schedule command (or tell the user to) to list and delete tasks.',
    ],
    parameters: Type.Object({
      cron: Type.String({
        description:
          '5-field cron expression: "minute hour day-of-month month day-of-week". Wildcards (*), steps (*/5), ranges (1-5), and lists (1,3,5) supported. Local time, minute precision. Example: "0 9 * * MON-FRI" = 9am every weekday.',
      }),
      prompt: Type.String({
        description:
          'The prompt text to send back to yourself when the task fires. Should be a complete, standalone instruction.',
      }),
      recurring: Type.Optional(
        Type.Boolean({
          description:
            'If true (default), the task fires every time the cron matches. If false, the task fires once and auto-deletes.',
        }),
      ),
    }),
    async execute(_id, params) {
      const recurring = params.recurring ?? true
      try {
        const task = manager.create(params.cron, params.prompt, recurring)
        const desc = describeCron(task.parsed)
        const now = new Date()
        const next = task.nextFireAt ? new Date(task.nextFireAt) : null
        const nextStr = next ? next.toLocaleString() : 'never'
        const deltaMs = next ? next.getTime() - now.getTime() : 0
        const deltaStr = next ? formatDuration(deltaMs) : 'n/a'
        // Loud warning when a one-shot lands suspiciously far out — usually
        // means the agent guessed the wrong year without checking the clock.
        const sanity =
          !recurring && deltaMs > 7 * 24 * 60 * 60 * 1000
            ? `\n  ⚠ WARNING: this one-shot fires in ${deltaStr}. Did you mean to schedule that far in the future? If not, run \`date\` to check the current year and reschedule.`
            : ''
        const text =
          `Scheduled task ${task.id}\n` +
          `  current time: ${now.toLocaleString()}\n` +
          `  schedule: ${desc} (${task.cron})\n` +
          `  recurring: ${recurring}\n` +
          `  next fire: ${nextStr} (in ${deltaStr})\n` +
          `  prompt: ${params.prompt}` +
          sanity
        // turn_end will re-arm, but arm now too so an isolated tool invocation
        // outside the normal turn lifecycle still gets a timer.
        armFireTimer()
        return {
          content: [{ type: 'text' as const, text }],
          details: { taskId: task.id, nextFireAt: task.nextFireAt },
        }
      } catch (error) {
        const msg = error instanceof Error ? error.message : String(error)
        return {
          content: [
            {
              type: 'text' as const,
              text: `Failed to schedule: ${msg}\n\nCron format: "minute hour day-of-month month day-of-week". Valid ranges: minute 0-59, hour 0-23, day 1-31, month 1-12 (or JAN-DEC), day-of-week 0-7 (or SUN-SAT, both 0 and 7 mean Sunday).`,
            },
          ],
          details: { taskId: '', nextFireAt: null },
          isError: true,
        }
      }
    },
  })

  pi.registerCommand('schedule', {
    description:
      'List or delete scheduled tasks. Usage: /schedule [delete <id>]',
    async handler(args, ctx) {
      const trimmed = args.trim()
      if (trimmed.startsWith('delete ') || trimmed.startsWith('rm ')) {
        const id = trimmed.split(/\s+/, 2)[1]?.trim()
        if (!id) {
          ctx.ui.notify('Usage: /schedule delete <id>', 'warning')
          return
        }
        const ok = manager.delete(id)
        ctx.ui.notify(
          ok ? `Deleted task ${id}` : `No such task: ${id}`,
          ok ? 'info' : 'warning',
        )
        // Command path doesn't trigger turn_end, so re-arm here.
        armFireTimer()
        return
      }

      const tasks = manager.list()
      if (tasks.length === 0) {
        ctx.ui.notify('No scheduled tasks.', 'info')
        return
      }
      const body = tasks.map(formatTask).join('\n\n')
      ctx.ui.notify(
        `${tasks.length} scheduled task${tasks.length === 1 ? '' : 's'}:\n\n${body}`,
        'info',
      )
    },
  })

  pi.registerCommand('schedule-help', {
    description: 'Show cron syntax examples for the scheduler.',
    async handler(_args, ctx) {
      const examples = [
        'Cron format: "minute hour day-of-month month day-of-week"',
        '',
        'Examples:',
        '  */5 * * * *       every 5 minutes',
        '  0 9 * * *         daily at 9:00',
        '  0 9 * * MON-FRI   weekdays at 9:00',
        '  30 14 * * *       daily at 14:30',
        '  0 0 1 * *         first of every month at midnight',
        '  0 */2 * * *       every 2 hours on the hour',
      ].join('\n')
      ctx.ui.notify(examples, 'info')
    },
  })
}

function formatDuration(ms: number): string {
  const abs = Math.abs(ms)
  const sec = Math.round(abs / 1000)
  if (sec < 60) return `${sec}s`
  const min = Math.round(sec / 60)
  if (min < 60) return `${min}m`
  const hr = Math.round(min / 60)
  if (hr < 48) return `${hr}h`
  const day = Math.round(hr / 24)
  if (day < 60) return `${day}d`
  const mo = Math.round(day / 30)
  if (mo < 24) return `${mo}mo`
  return `${(day / 365).toFixed(1)}y`
}
