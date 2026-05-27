import assert from 'node:assert/strict'
import { describe, it } from 'node:test'
import { describeCron, nextCronRunMs, parseCron } from './cron.ts'

// Fixed reference: Wed 2026-05-27 14:32:15 local time.
const REF = new Date(2026, 4, 27, 14, 32, 15).getTime()

const at = (y: number, mo: number, d: number, h: number, mi: number) =>
  new Date(y, mo - 1, d, h, mi, 0, 0).getTime()

describe('parseCron', () => {
  it('parses wildcards', () => {
    const p = parseCron('* * * * *')
    assert.equal(p.minute.length, 60)
    assert.equal(p.hour.length, 24)
    assert.equal(p.dom.length, 31)
    assert.equal(p.month.length, 12)
    assert.equal(p.dow.length, 7)
    assert.equal(p.domRestricted, false)
    assert.equal(p.dowRestricted, false)
  })

  it('parses step expressions', () => {
    assert.deepEqual(parseCron('*/15 * * * *').minute, [0, 15, 30, 45])
    assert.deepEqual(parseCron('0 */6 * * *').hour, [0, 6, 12, 18])
  })

  it('parses ranges with step', () => {
    assert.deepEqual(parseCron('1-10/2 * * * *').minute, [1, 3, 5, 7, 9])
  })

  it('parses lists', () => {
    assert.deepEqual(parseCron('0 9,12,17 * * *').hour, [9, 12, 17])
  })

  it('parses month and dow aliases', () => {
    assert.deepEqual(parseCron('0 0 1 JAN MON').month, [1])
    assert.deepEqual(parseCron('0 0 1 JAN MON').dow, [1])
    // 7 normalizes to 0 (Sunday)
    assert.deepEqual(parseCron('0 0 * * 7').dow, [0])
  })

  it('rejects wrong arity', () => {
    assert.throws(() => parseCron('* * * *'))
    assert.throws(() => parseCron('* * * * * *'))
  })

  it('rejects out-of-range values', () => {
    assert.throws(() => parseCron('60 * * * *'))
    assert.throws(() => parseCron('* 24 * * *'))
    assert.throws(() => parseCron('* * 32 * *'))
    assert.throws(() => parseCron('* * * 13 *'))
    assert.throws(() => parseCron('* * * * 8'))
  })

  it('rejects garbage tokens', () => {
    assert.throws(() => parseCron('foo * * * *'))
    assert.throws(() => parseCron('*/0 * * * *'))
    assert.throws(() => parseCron('5-1 * * * *'))
  })
})

describe('nextCronRunMs', () => {
  it('every minute fires next minute boundary', () => {
    const next = nextCronRunMs(parseCron('* * * * *'), REF)
    assert.equal(next, at(2026, 5, 27, 14, 33))
  })

  it('every 5 minutes', () => {
    // From 14:32:15 -> next */5 boundary is 14:35
    const next = nextCronRunMs(parseCron('*/5 * * * *'), REF)
    assert.equal(next, at(2026, 5, 27, 14, 35))
  })

  it('daily at 09:00 — past time today rolls to tomorrow', () => {
    const next = nextCronRunMs(parseCron('0 9 * * *'), REF)
    assert.equal(next, at(2026, 5, 28, 9, 0))
  })

  it('daily at 23:30 — same day', () => {
    const next = nextCronRunMs(parseCron('30 23 * * *'), REF)
    assert.equal(next, at(2026, 5, 27, 23, 30))
  })

  it('pinned crons in the future', () => {
    // Feb 27 14:30 — well past for 2026; next is 2027-02-27 14:30
    const next = nextCronRunMs(parseCron('30 14 27 2 *'), REF)
    assert.equal(next, at(2027, 2, 27, 14, 30))
  })

  it('weekday DoW match (next Friday at 09:00)', () => {
    // REF is Wed 2026-05-27. Next Friday is 2026-05-29.
    const next = nextCronRunMs(parseCron('0 9 * * FRI'), REF)
    assert.equal(next, at(2026, 5, 29, 9, 0))
  })

  it('DoM and DoW both restricted = OR semantics', () => {
    // 15th of the month OR Monday. From Wed 2026-05-27, next Monday is
    // 2026-06-01 (earlier than the 15th).
    const next = nextCronRunMs(parseCron('0 0 15 * MON'), REF)
    assert.equal(next, at(2026, 6, 1, 0, 0))
  })

  it('returns null when nothing matches in horizon', () => {
    // Feb 30 never exists.
    const next = nextCronRunMs(parseCron('0 0 30 2 *'), REF)
    assert.equal(next, null)
  })

  it('handles month rollover correctly', () => {
    // Last day of May, 23:59 — next minute should jump into June 1 if pattern
    // is every minute.
    const lateMay = at(2026, 5, 31, 23, 59)
    const next = nextCronRunMs(parseCron('* * * * *'), lateMay + 30_000)
    assert.equal(next, at(2026, 6, 1, 0, 0))
  })
})

describe('describeCron', () => {
  it('recognizes common shorthands', () => {
    assert.equal(describeCron(parseCron('* * * * *')), 'every minute')
    assert.equal(describeCron(parseCron('*/5 * * * *')), 'every 5 minutes')
    assert.equal(describeCron(parseCron('30 * * * *')), 'every hour at :30')
    assert.equal(describeCron(parseCron('15 9 * * *')), 'daily at 09:15')
  })

  it('falls back to raw for unknown patterns', () => {
    assert.equal(describeCron(parseCron('0 9 * * FRI')), 'cron(0 9 * * FRI)')
  })
})
