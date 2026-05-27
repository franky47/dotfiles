import type { ExtensionAPI, ExtensionContext } from '@earendil-works/pi-coding-agent'
import { describeCron, nextCronRunMs, parseCron, type ParsedCron } from './cron.ts'

export const TASK_ENTRY = 'scheduler-task'
export const FIRED_ENTRY = 'scheduler-fired'
export const DELETED_ENTRY = 'scheduler-deleted'

export interface TaskRecord {
  id: string
  cron: string
  prompt: string
  createdAt: number
  recurring: boolean
}

interface FiredRecord {
  id: string
  firedAt: number
}

interface DeletedRecord {
  id: string
}

export interface ActiveTask extends TaskRecord {
  parsed: ParsedCron
  lastFiredAt: number | undefined
  nextFireAt: number | null
}

// Manager keeps no persistent storage of its own — state is reconstructed
// from session JSONL entries on every session_start. In-memory cache only
// exists to avoid rescanning entries on every turn_end.
export class SchedulerManager {
  private tasks = new Map<string, ActiveTask>()

  constructor(private pi: ExtensionAPI) {}

  rebuild(ctx: ExtensionContext) {
    this.tasks.clear()
    const records = new Map<string, TaskRecord>()
    const firedById = new Map<string, number>()
    const deleted = new Set<string>()

    for (const entry of ctx.sessionManager.getEntries()) {
      if (entry.type !== 'custom') continue
      if (entry.customType === TASK_ENTRY) {
        const data = entry.data as TaskRecord | undefined
        if (data?.id) records.set(data.id, data)
      } else if (entry.customType === FIRED_ENTRY) {
        const data = entry.data as FiredRecord | undefined
        if (data?.id) {
          const prev = firedById.get(data.id) ?? 0
          if (data.firedAt > prev) firedById.set(data.id, data.firedAt)
        }
      } else if (entry.customType === DELETED_ENTRY) {
        const data = entry.data as DeletedRecord | undefined
        if (data?.id) deleted.add(data.id)
      }
    }

    for (const [id, record] of records) {
      if (deleted.has(id)) continue
      const parsed = parseCron(record.cron)
      const lastFiredAt = firedById.get(id)
      const baseline = lastFiredAt ?? record.createdAt
      const nextFireAt = nextCronRunMs(parsed, baseline)
      this.tasks.set(id, { ...record, parsed, lastFiredAt, nextFireAt })
    }
  }

  list(): ActiveTask[] {
    return [...this.tasks.values()].sort((a, b) => {
      const an = a.nextFireAt ?? Number.MAX_SAFE_INTEGER
      const bn = b.nextFireAt ?? Number.MAX_SAFE_INTEGER
      return an - bn
    })
  }

  get(id: string): ActiveTask | undefined {
    return this.tasks.get(id)
  }

  create(cron: string, prompt: string, recurring: boolean): ActiveTask {
    const parsed = parseCron(cron)
    const now = Date.now()
    const nextFireAt = nextCronRunMs(parsed, now)
    if (nextFireAt === null) {
      throw new Error(
        `Cron "${cron}" has no match in the next year — refusing to schedule a task that will never fire.`,
      )
    }
    const id = randomId()
    const record: TaskRecord = { id, cron, prompt, createdAt: now, recurring }
    this.pi.appendEntry<TaskRecord>(TASK_ENTRY, record)
    const task: ActiveTask = { ...record, parsed, lastFiredAt: undefined, nextFireAt }
    this.tasks.set(id, task)
    return task
  }

  delete(id: string): boolean {
    if (!this.tasks.has(id)) return false
    this.pi.appendEntry<DeletedRecord>(DELETED_ENTRY, { id })
    this.tasks.delete(id)
    return true
  }

  // Tasks whose nextFireAt has passed, oldest first.
  due(now: number): ActiveTask[] {
    const out: ActiveTask[] = []
    for (const task of this.tasks.values()) {
      if (task.nextFireAt !== null && task.nextFireAt <= now) out.push(task)
    }
    return out.sort((a, b) => (a.nextFireAt ?? 0) - (b.nextFireAt ?? 0))
  }

  // Mark a task as fired: append fired entry, update lastFiredAt and the
  // next fire time. One-shot tasks are deleted.
  markFired(id: string, firedAt: number) {
    const task = this.tasks.get(id)
    if (!task) return
    if (!task.recurring) {
      this.delete(id)
      return
    }
    this.pi.appendEntry<FiredRecord>(FIRED_ENTRY, { id, firedAt })
    task.lastFiredAt = firedAt
    task.nextFireAt = nextCronRunMs(task.parsed, firedAt)
  }
}

function randomId(): string {
  // 8 hex chars is plenty for per-session uniqueness; collisions are
  // self-correcting because rebuild() de-dupes by id.
  return Math.random().toString(16).slice(2, 10).padStart(8, '0')
}

export function formatTask(task: ActiveTask): string {
  const desc = describeCron(task.parsed)
  const next = task.nextFireAt ? new Date(task.nextFireAt).toLocaleString() : 'never'
  const recur = task.recurring ? 'recurring' : 'once'
  const preview = task.prompt.length > 60 ? `${task.prompt.slice(0, 57)}...` : task.prompt
  return `${task.id}  [${recur}]  ${desc}  → ${next}\n         ${preview}`
}
