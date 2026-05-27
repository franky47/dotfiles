// 5-field cron parser (minute, hour, day-of-month, month, day-of-week).
// Local time. Minute-level precision. No timezone conversion.

export interface ParsedCron {
  minute: number[]
  hour: number[]
  dom: number[]
  month: number[]
  dow: number[]
  domRestricted: boolean
  dowRestricted: boolean
  raw: string
}

interface FieldSpec {
  min: number
  max: number
  // Map of named aliases to numeric values (e.g. "JAN" -> 1, "SUN" -> 0).
  aliases?: Record<string, number>
  // Optional normalization (e.g. dow 7 -> 0).
  normalize?: (n: number) => number
}

const MINUTE: FieldSpec = { min: 0, max: 59 }
const HOUR: FieldSpec = { min: 0, max: 23 }
const DOM: FieldSpec = { min: 1, max: 31 }
const MONTH: FieldSpec = {
  min: 1,
  max: 12,
  aliases: {
    JAN: 1, FEB: 2, MAR: 3, APR: 4, MAY: 5, JUN: 6,
    JUL: 7, AUG: 8, SEP: 9, OCT: 10, NOV: 11, DEC: 12,
  },
}
const DOW: FieldSpec = {
  min: 0,
  max: 7,
  aliases: {
    SUN: 0, MON: 1, TUE: 2, WED: 3, THU: 4, FRI: 5, SAT: 6,
  },
  normalize: n => (n === 7 ? 0 : n),
}

function expandField(raw: string, spec: FieldSpec): number[] {
  const values = new Set<number>()
  for (const part of raw.split(',')) {
    const trimmed = part.trim()
    if (!trimmed) throw new Error(`Empty term in field "${raw}"`)

    let step = 1
    let range = trimmed
    const slash = trimmed.indexOf('/')
    if (slash !== -1) {
      const stepStr = trimmed.slice(slash + 1)
      step = parseInt(stepStr, 10)
      if (!Number.isInteger(step) || step < 1) {
        throw new Error(`Invalid step "${stepStr}" in "${raw}"`)
      }
      range = trimmed.slice(0, slash)
    }

    let lo: number
    let hi: number
    if (range === '*') {
      lo = spec.min
      hi = spec.max
    } else if (range.includes('-')) {
      const [a, b] = range.split('-', 2).map(s => parseFieldValue(s, spec, raw))
      lo = a
      hi = b
      if (lo > hi) throw new Error(`Inverted range "${range}" in "${raw}"`)
    } else {
      const v = parseFieldValue(range, spec, raw)
      lo = v
      hi = slash === -1 ? v : spec.max
    }

    if (lo < spec.min || hi > spec.max) {
      throw new Error(`Out of range "${range}" in "${raw}" (allowed ${spec.min}-${spec.max})`)
    }

    for (let v = lo; v <= hi; v += step) {
      values.add(spec.normalize ? spec.normalize(v) : v)
    }
  }
  return [...values].sort((a, b) => a - b)
}

function parseFieldValue(token: string, spec: FieldSpec, raw: string): number {
  const upper = token.trim().toUpperCase()
  if (spec.aliases && upper in spec.aliases) return spec.aliases[upper]
  const n = parseInt(token, 10)
  if (!Number.isInteger(n) || String(n) !== token.trim()) {
    throw new Error(`Invalid value "${token}" in "${raw}"`)
  }
  return n
}

export function parseCron(expr: string): ParsedCron {
  const fields = expr.trim().split(/\s+/)
  if (fields.length !== 5) {
    throw new Error(
      `Cron expression must have 5 fields (M H DoM Mon DoW), got ${fields.length}: "${expr}"`,
    )
  }
  const [m, h, dom, mon, dow] = fields
  return {
    minute: expandField(m, MINUTE),
    hour: expandField(h, HOUR),
    dom: expandField(dom, DOM),
    month: expandField(mon, MONTH),
    dow: expandField(dow, DOW),
    domRestricted: dom !== '*',
    dowRestricted: dow !== '*',
    raw: expr.trim(),
  }
}

// Compute the next epoch-ms >= `fromMs` matching `parsed`. Returns null if
// no match within `withinMs` (default: 1 year).
export function nextCronRunMs(
  parsed: ParsedCron,
  fromMs: number,
  withinMs: number = 366 * 24 * 60 * 60 * 1000,
): number | null {
  // Round up to the next minute boundary so we never re-fire the same minute.
  const start = new Date(fromMs)
  start.setSeconds(0, 0)
  start.setMinutes(start.getMinutes() + 1)

  const deadline = fromMs + withinMs

  const minuteSet = new Set(parsed.minute)
  const hourSet = new Set(parsed.hour)
  const monthSet = new Set(parsed.month)
  const domSet = new Set(parsed.dom)
  const dowSet = new Set(parsed.dow)

  const cursor = new Date(start)
  while (cursor.getTime() <= deadline) {
    if (!monthSet.has(cursor.getMonth() + 1)) {
      cursor.setMonth(cursor.getMonth() + 1, 1)
      cursor.setHours(0, 0, 0, 0)
      continue
    }
    if (!matchesDay(cursor, domSet, dowSet, parsed.domRestricted, parsed.dowRestricted)) {
      cursor.setDate(cursor.getDate() + 1)
      cursor.setHours(0, 0, 0, 0)
      continue
    }
    if (!hourSet.has(cursor.getHours())) {
      cursor.setHours(cursor.getHours() + 1, 0, 0, 0)
      continue
    }
    if (!minuteSet.has(cursor.getMinutes())) {
      cursor.setMinutes(cursor.getMinutes() + 1, 0, 0)
      continue
    }
    return cursor.getTime()
  }
  return null
}

function matchesDay(
  d: Date,
  domSet: Set<number>,
  dowSet: Set<number>,
  domRestricted: boolean,
  dowRestricted: boolean,
): boolean {
  const domMatch = domSet.has(d.getDate())
  const dowMatch = dowSet.has(d.getDay())
  // Standard cron semantics: when both DoM and DoW are restricted, match
  // either; otherwise AND.
  if (domRestricted && dowRestricted) return domMatch || dowMatch
  if (domRestricted) return domMatch
  if (dowRestricted) return dowMatch
  return true
}

// Compact human description of a cron expression. Falls back to the raw
// expression when no friendly form is recognized.
export function describeCron(parsed: ParsedCron): string {
  const e = parsed.raw
  // A handful of common shorthands.
  if (e === '* * * * *') return 'every minute'
  const everyN = e.match(/^\*\/(\d+) \* \* \* \*$/)
  if (everyN) return `every ${everyN[1]} minutes`
  const hourly = e.match(/^(\d+) \* \* \* \*$/)
  if (hourly) return `every hour at :${hourly[1].padStart(2, '0')}`
  const daily = e.match(/^(\d+) (\d+) \* \* \*$/)
  if (daily) {
    return `daily at ${pad(daily[2])}:${pad(daily[1])}`
  }
  return `cron(${e})`
}

function pad(s: string): string {
  return s.padStart(2, '0')
}
