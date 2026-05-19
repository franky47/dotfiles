import type {
  ExtensionAPI,
  ExtensionContext,
} from '@earendil-works/pi-coding-agent'
import { VERSION } from '@earendil-works/pi-coding-agent'

const BLUE = '\x1b[38;2;0;136;255m'
const RESET = '\x1b[0m'
const BOLD = '\x1b[1m'

/**
 * Pi splash header — replaces the default built-in header.
 *
 * █▀█  Pi v<version>
 * █▀ █ <model> · <provider> · <cwd>
 */
export default function (pi: ExtensionAPI) {
  let renderable: {
    render(width: number): string[]
    invalidate?(): void
  } | null = null

  function installSplash(ctx: ExtensionContext): void {
    ctx.ui.setHeader((tui, theme) => {
      const dim = (text: string) => theme.fg('dim', text)

      renderable = {
        render(): string[] {
          // const cwdBasename = ctx.cwd.split('/').pop() || 'session'
          //   const cwdDisplay = ctx.cwd.startsWith(process.env.HOME || '')
          //     ? ctx.cwd.replace(process.env.HOME || '', '~')
          //     : cwdBasename
          const infoLine = [ctx.model?.id, ctx.model?.provider]
            .filter((x) => !!x)
            .join(' · ')

          return [
            ` ${BLUE}█▀█ ${RESET}  ${BOLD}Pi${RESET} ${dim(`v${VERSION}`)}`,
            ` ${BLUE}█▀ █${RESET}  ${dim(infoLine)}`,
          ]
        },
        invalidate() {
          tui.requestRender()
        },
      }
      return renderable
    })
  }

  pi.on('session_start', (_event, ctx) => {
    if (!ctx.hasUI) return
    installSplash(ctx)
  })

  pi.on('model_select', (_event) => {
    renderable?.invalidate?.()
  })

  pi.on('session_shutdown', (_event, ctx) => {
    if (ctx.hasUI) {
      ctx.ui.setHeader(undefined)
      renderable = null
    }
  })
}
