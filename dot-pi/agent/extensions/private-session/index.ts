import type { ExtensionAPI, ExtensionContext } from '@earendil-works/pi-coding-agent'
import {
  deleteSessionFile,
  enablePrivateModeForProcess,
  enforcePrivateModeForProcess,
  isSessionPersisted,
  parseDeleteSessionArgs,
  runDeleteSessionCommand,
  shouldShowPrivateStatus,
  type PrivateProcessState,
} from './helpers.ts'

const STATUS_ID = 'private-session'
const PROCESS_STATE_KEY = Symbol.for('pi.private-session.process-state')

const processState = (() => {
  const root = globalThis as typeof globalThis & { [PROCESS_STATE_KEY]?: PrivateProcessState }
  return (root[PROCESS_STATE_KEY] ??= { privateMode: false })
})()

type StatusContext = Pick<ExtensionContext, 'sessionManager' | 'ui'>

function updateStatus(ctx: StatusContext) {
  const text = shouldShowPrivateStatus(isSessionPersisted(ctx.sessionManager))
    ? ctx.ui.theme.fg('warning', '🕵️ private')
    : undefined
  ctx.ui.setStatus(STATUS_ID, text)
}

function enterPrivateMode(ctx: StatusContext): boolean {
  const changed = enablePrivateModeForProcess(processState, ctx.sessionManager)
  updateStatus(ctx)
  return changed
}

export default function privateSessionExtension(pi: ExtensionAPI) {
  pi.on('session_start', (_event, ctx) => {
    try {
      // Once explicitly enabled, carry privacy through /new, /resume, /fork,
      // /clone, and extension reloads for the lifetime of this Pi process.
      enforcePrivateModeForProcess(processState, ctx.sessionManager)
      updateStatus(ctx)
    } catch (error) {
      ctx.ui.setStatus(STATUS_ID, ctx.ui.theme.fg('warning', '⚠ private mode failed'))
      ctx.ui.notify(error instanceof Error ? error.message : String(error), 'error')
    }
  })

  pi.registerCommand('private', {
    description: 'Stop recording future entries; keep existing saved history',
    handler: async (_args, ctx) => {
      try {
        const changed = enterPrivateMode(ctx)
        ctx.ui.notify(
          changed
            ? 'Private mode enabled. Future entries will not be saved; existing history is unchanged.'
            : 'This session is already private. Existing saved history is unchanged.',
          'info',
        )
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error)
        ctx.ui.notify(message, 'error')
        throw error
      }
    },
  })

  pi.registerCommand('delete-session', {
    description: 'Stop recording and delete the current saved transcript',
    handler: async (args, ctx) => {
      let force: boolean
      try {
        force = parseDeleteSessionArgs(args).force
      } catch (error) {
        ctx.ui.notify(error instanceof Error ? error.message : String(error), 'error')
        return
      }

      const result = await runDeleteSessionCommand({
        mode: ctx.mode,
        force,
        confirm: () => ctx.ui.confirm(
          'Delete current session?',
          'The saved transcript will be moved to trash when possible. The in-memory conversation will remain private.',
        ),
        enterPrivateMode: () => { enterPrivateMode(ctx) },
        deleteSession: () => deleteSessionFile(ctx.sessionManager.getSessionFile()),
      })

      if (result.status === 'refused') {
        ctx.ui.notify('Refusing to delete a session outside the interactive TUI. Use /delete-session --force.', 'error')
        return
      }
      if (result.status === 'cancelled') {
        ctx.ui.notify('Session deletion cancelled.', 'info')
        return
      }
      if (result.status === 'private-failed') {
        ctx.ui.notify(`Session was not deleted because private mode could not be enabled: ${result.error}`, 'error')
        return
      }
      if (result.status === 'delete-failed') {
        ctx.ui.notify(`Private mode is enabled, but the session could not be deleted: ${result.error}`, 'error')
        return
      }

      const message = {
        absent: 'No saved session file existed. Private mode is enabled.',
        trash: 'Session moved to trash. Private mode is enabled.',
        unlink: 'Session permanently deleted. Private mode is enabled.',
      }[result.method]
      ctx.ui.notify(message, 'info')
    },
  })
}
