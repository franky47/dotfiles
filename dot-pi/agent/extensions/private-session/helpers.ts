import { existsSync, unlinkSync } from 'node:fs'
import { spawnSync } from 'node:child_process'

/**
 * The SessionManager does not yet expose a public way to inspect or stop
 * persistence from an extension. Keep every internal access in this shim. Pi
 * currently stores the decision in a runtime `persist` boolean, which is also
 * what isPersisted() reports and what all append/rewrite paths check. Existing
 * entries and the session file path are retained so `/private` never deletes
 * history.
 */
const COMPATIBILITY_ERROR =
  'Cannot enter private mode: this Pi version no longer exposes the expected SessionManager persistence internals. Update the private-session extension.'

function compatibilityError(): Error {
  return new Error(COMPATIBILITY_ERROR)
}

function getPersistenceManager(manager: unknown): object & { isPersisted(): boolean } {
  if (!manager || typeof manager !== 'object') throw compatibilityError()

  let isPersisted: unknown
  try {
    isPersisted = Reflect.get(manager, 'isPersisted')
  } catch {
    throw compatibilityError()
  }
  if (typeof isPersisted !== 'function') throw compatibilityError()

  return manager as object & { isPersisted(): boolean }
}

export function isSessionPersisted(manager: unknown): boolean {
  const compatibleManager = getPersistenceManager(manager)
  let persisted: unknown
  try {
    persisted = compatibleManager.isPersisted()
  } catch {
    throw compatibilityError()
  }
  if (typeof persisted !== 'boolean') throw compatibilityError()
  return persisted
}

export function disableSessionPersistence(manager: unknown): boolean {
  const compatibleManager = getPersistenceManager(manager)
  if (!isSessionPersisted(compatibleManager)) return false

  const descriptor = findPropertyDescriptor(compatibleManager, 'persist')
  if (!descriptor || descriptor.writable === false) throw compatibilityError()

  try {
    if (!Reflect.set(compatibleManager, 'persist', false)) throw compatibilityError()
  } catch {
    throw compatibilityError()
  }

  if (isSessionPersisted(compatibleManager)) throw compatibilityError()
  return true
}

function findPropertyDescriptor(object: object, property: string): PropertyDescriptor | undefined {
  let current: object | null = object
  while (current) {
    const descriptor = Object.getOwnPropertyDescriptor(current, property)
    if (descriptor) return descriptor
    current = Object.getPrototypeOf(current) as object | null
  }
  return undefined
}

export interface PrivateProcessState {
  privateMode: boolean
}

export function enablePrivateModeForProcess(state: PrivateProcessState, manager: unknown): boolean {
  const changed = disableSessionPersistence(manager)
  state.privateMode = true
  return changed
}

export function enforcePrivateModeForProcess(state: PrivateProcessState, manager: unknown): boolean {
  if (!state.privateMode) return false
  return disableSessionPersistence(manager)
}

export function shouldShowPrivateStatus(isPersisted: boolean): boolean {
  return !isPersisted
}

export function parseDeleteSessionArgs(args: string): { force: boolean } {
  const tokens = args.trim() ? args.trim().split(/\s+/) : []
  if (tokens.length === 0) return { force: false }
  if (tokens.length === 1 && tokens[0] === '--force') return { force: true }
  throw new Error('Usage: /delete-session [--force]')
}

export type DeleteResult =
  | { ok: true; method: 'absent' | 'trash' | 'unlink' }
  | { ok: false; method: 'unlink'; error: string }

export type DeleteSessionMode = 'tui' | 'rpc' | 'json' | 'print'
export type DeleteAuthorization = 'allow' | 'confirm' | 'refuse'

export function authorizeSessionDeletion(mode: DeleteSessionMode, force: boolean): DeleteAuthorization {
  if (force) return 'allow'
  return mode === 'tui' ? 'confirm' : 'refuse'
}

export type DeleteSessionCommandResult =
  | { status: 'refused' }
  | { status: 'cancelled' }
  | { status: 'completed'; method: 'absent' | 'trash' | 'unlink' }
  | { status: 'private-failed'; error: string }
  | { status: 'delete-failed'; error: string }

export interface DeleteSessionCommandOperations {
  mode: DeleteSessionMode
  force: boolean
  confirm(): Promise<boolean>
  enterPrivateMode(): void
  deleteSession(): DeleteResult
}

export async function runDeleteSessionCommand(
  operations: DeleteSessionCommandOperations,
): Promise<DeleteSessionCommandResult> {
  const authorization = authorizeSessionDeletion(operations.mode, operations.force)
  if (authorization === 'refuse') return { status: 'refused' }
  if (authorization === 'confirm' && !(await operations.confirm())) return { status: 'cancelled' }

  // Privacy comes first. If compatibility checks fail, deletion never starts.
  try {
    operations.enterPrivateMode()
  } catch (error) {
    return {
      status: 'private-failed',
      error: error instanceof Error ? error.message : String(error),
    }
  }

  const result = operations.deleteSession()
  if (!result.ok) return { status: 'delete-failed', error: result.error }
  return { status: 'completed', method: result.method }
}

export interface DeleteOperations {
  exists(path: string): boolean
  trash(path: string): { status: number | null; error?: string; stderr?: string }
  unlink(path: string): void
}

const defaultDeleteOperations: DeleteOperations = {
  exists: existsSync,
  trash(path) {
    const args = path.startsWith('-') ? ['--', path] : [path]
    const result = spawnSync('trash', args, { encoding: 'utf8' })
    return {
      status: result.status,
      error: result.error?.message,
      stderr: result.stderr?.trim(),
    }
  },
  unlink: unlinkSync,
}

/** Matches Pi's session selector: trash first, then permanent unlink. */
export function deleteSessionFile(
  sessionPath: string | undefined,
  operations: DeleteOperations = defaultDeleteOperations,
): DeleteResult {
  if (!sessionPath || !operations.exists(sessionPath)) return { ok: true, method: 'absent' }

  const trash = operations.trash(sessionPath)
  if (trash.status === 0 || !operations.exists(sessionPath)) {
    return { ok: true, method: 'trash' }
  }

  try {
    operations.unlink(sessionPath)
    return { ok: true, method: 'unlink' }
  } catch (error) {
    const unlinkError = error instanceof Error ? error.message : String(error)
    const hints = [trash.error, trash.stderr?.split('\n')[0]].filter(Boolean).join(' · ').slice(0, 200)
    return {
      ok: false,
      method: 'unlink',
      error: hints ? `${unlinkError} (trash: ${hints})` : unlinkError,
    }
  }
}
