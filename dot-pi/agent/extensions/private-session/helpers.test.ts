import assert from 'node:assert/strict'
import { describe, it } from 'node:test'
import {
  authorizeSessionDeletion,
  deleteSessionFile,
  disableSessionPersistence,
  enablePrivateModeForProcess,
  enforcePrivateModeForProcess,
  isSessionPersisted,
  parseDeleteSessionArgs,
  runDeleteSessionCommand,
  shouldShowPrivateStatus,
  type DeleteOperations,
} from './helpers.ts'

describe('disableSessionPersistence', () => {
  it('disables persistence without changing session data', () => {
    const manager = { persist: true, entries: ['kept'], isPersisted() { return this.persist } }
    assert.equal(disableSessionPersistence(manager), true)
    assert.equal(manager.isPersisted(), false)
    assert.deepEqual(manager.entries, ['kept'])
  })

  it('is idempotent', () => {
    const manager = { persist: false, isPersisted() { return this.persist } }
    assert.equal(disableSessionPersistence(manager), false)
  })

  it('reads persistence through the compatibility boundary', () => {
    assert.equal(isSessionPersisted({ isPersisted: () => true }), true)
    assert.equal(isSessionPersisted({ isPersisted: () => false }), false)
  })

  it('fails clearly when the persistence query changes', () => {
    assert.throws(() => isSessionPersisted({}), /SessionManager persistence internals/)
  })

  it('wraps failures while inspecting persistence internals', () => {
    const manager = Object.defineProperty({}, 'isPersisted', {
      get() { throw new Error('internal getter changed') },
    })
    assert.throws(() => isSessionPersisted(manager), /SessionManager persistence internals/)
  })

  it('fails clearly when the persistence flag changes', () => {
    const manager = { isPersisted: () => true }
    assert.throws(() => disableSessionPersistence(manager), /SessionManager persistence internals/)
  })
})

describe('process-wide private mode', () => {
  it('does not change replacement sessions before private mode is enabled', () => {
    const state = { privateMode: false }
    const manager = { persist: true, isPersisted() { return this.persist } }

    assert.equal(enforcePrivateModeForProcess(state, manager), false)
    assert.equal(manager.isPersisted(), true)
  })

  it('disables persistence for the current and replacement sessions', () => {
    const state = { privateMode: false }
    const current = { persist: true, isPersisted() { return this.persist } }
    const replacement = { persist: true, isPersisted() { return this.persist } }

    assert.equal(enablePrivateModeForProcess(state, current), true)
    assert.equal(state.privateMode, true)
    assert.equal(current.isPersisted(), false)

    assert.equal(enforcePrivateModeForProcess(state, replacement), true)
    assert.equal(replacement.isPersisted(), false)
  })
})

describe('deleteSessionFile', () => {
  function operations(overrides: Partial<DeleteOperations> = {}): DeleteOperations {
    return {
      exists: () => true,
      trash: () => ({ status: 1, stderr: 'trash failed' }),
      unlink: () => {},
      ...overrides,
    }
  }

  it('succeeds when no file exists', () => {
    assert.deepEqual(deleteSessionFile('/session', operations({ exists: () => false })), {
      ok: true,
      method: 'absent',
    })
  })

  it('uses trash when available', () => {
    let unlinked = false
    const result = deleteSessionFile('/session', operations({
      trash: () => ({ status: 0 }),
      unlink: () => { unlinked = true },
    }))
    assert.deepEqual(result, { ok: true, method: 'trash' })
    assert.equal(unlinked, false)
  })

  it('falls back to unlink', () => {
    assert.deepEqual(deleteSessionFile('/session', operations()), { ok: true, method: 'unlink' })
  })

  it('reports both unlink and trash failures', () => {
    const result = deleteSessionFile('/session', operations({
      unlink: () => { throw new Error('unlink denied') },
    }))
    assert.equal(result.ok, false)
    if (!result.ok) assert.match(result.error, /unlink denied.*trash failed/)
  })
})

describe('command helpers', () => {
  it('only accepts the optional force flag', () => {
    assert.deepEqual(parseDeleteSessionArgs(''), { force: false })
    assert.deepEqual(parseDeleteSessionArgs(' --force '), { force: true })
    assert.throws(() => parseDeleteSessionArgs('--force extra'), /Usage/)
  })

  it('shows status only for non-persisted sessions', () => {
    assert.equal(shouldShowPrivateStatus(true), false)
    assert.equal(shouldShowPrivateStatus(false), true)
  })

  it('authorizes deletion from mode and force', () => {
    assert.equal(authorizeSessionDeletion('tui', false), 'confirm')
    assert.equal(authorizeSessionDeletion('tui', true), 'allow')
    for (const mode of ['rpc', 'json', 'print'] as const) {
      assert.equal(authorizeSessionDeletion(mode, false), 'refuse')
      assert.equal(authorizeSessionDeletion(mode, true), 'allow')
    }
  })
})

describe('runDeleteSessionCommand', () => {
  it('refuses non-interactive deletion unless forced', async () => {
    const events: string[] = []
    const result = await runDeleteSessionCommand({
      mode: 'print',
      force: false,
      confirm: async () => { events.push('confirm'); return true },
      enterPrivateMode: () => { events.push('private') },
      deleteSession: () => { events.push('delete'); return { ok: true, method: 'trash' } },
    })

    assert.deepEqual(result, { status: 'refused' })
    assert.deepEqual(events, [])
  })

  it('stops when interactive confirmation is cancelled', async () => {
    const events: string[] = []
    const result = await runDeleteSessionCommand({
      mode: 'tui',
      force: false,
      confirm: async () => { events.push('confirm'); return false },
      enterPrivateMode: () => { events.push('private') },
      deleteSession: () => { events.push('delete'); return { ok: true, method: 'trash' } },
    })

    assert.deepEqual(result, { status: 'cancelled' })
    assert.deepEqual(events, ['confirm'])
  })

  it('enters private mode before deleting', async () => {
    const events: string[] = []
    const result = await runDeleteSessionCommand({
      mode: 'tui',
      force: false,
      confirm: async () => { events.push('confirm'); return true },
      enterPrivateMode: () => { events.push('private') },
      deleteSession: () => { events.push('delete'); return { ok: true, method: 'trash' } },
    })

    assert.deepEqual(result, { status: 'completed', method: 'trash' })
    assert.deepEqual(events, ['confirm', 'private', 'delete'])
  })

  it('allows forced non-interactive deletion without confirming', async () => {
    const events: string[] = []
    const result = await runDeleteSessionCommand({
      mode: 'json',
      force: true,
      confirm: async () => { events.push('confirm'); return false },
      enterPrivateMode: () => { events.push('private') },
      deleteSession: () => { events.push('delete'); return { ok: true, method: 'unlink' } },
    })

    assert.deepEqual(result, { status: 'completed', method: 'unlink' })
    assert.deepEqual(events, ['private', 'delete'])
  })

  it('does not delete when private mode cannot be enabled', async () => {
    const events: string[] = []
    const result = await runDeleteSessionCommand({
      mode: 'tui',
      force: true,
      confirm: async () => true,
      enterPrivateMode: () => { events.push('private'); throw new Error('compatibility changed') },
      deleteSession: () => { events.push('delete'); return { ok: true, method: 'trash' } },
    })

    assert.deepEqual(result, { status: 'private-failed', error: 'compatibility changed' })
    assert.deepEqual(events, ['private'])
  })

  it('keeps private mode enabled when deletion fails', async () => {
    const events: string[] = []
    const result = await runDeleteSessionCommand({
      mode: 'rpc',
      force: true,
      confirm: async () => true,
      enterPrivateMode: () => { events.push('private') },
      deleteSession: () => {
        events.push('delete')
        return { ok: false, method: 'unlink', error: 'denied' }
      },
    })

    assert.deepEqual(result, { status: 'delete-failed', error: 'denied' })
    assert.deepEqual(events, ['private', 'delete'])
  })
})
