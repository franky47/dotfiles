import { readFile } from "node:fs/promises"
import { isAbsolute, resolve } from "node:path"

import {
  CustomEditor,
  type ExtensionAPI,
  type KeybindingsManager,
  type SlashCommandInfo,
} from "@earendil-works/pi-coding-agent"
import {
  decodeKittyPrintable,
  type EditorTheme,
  type TUI,
} from "@earendil-works/pi-tui"

import {
  canOpenInlineAutocomplete,
  createInlineAutocompleteProvider,
  findInlineSkillNames,
  hashSkillBody,
  InlineSkillState,
  normalizeSkillBody,
  skillRegistry,
  type SkillDefinition,
} from "./core.ts"

type TriggerableEditor = {
  tryTriggerAutocomplete?: () => void
}

export default function inlineSkills(pi: ExtensionAPI): void {
  const state = new InlineSkillState()
  const getSkills = (): Map<string, SkillDefinition> =>
    skillRegistry(pi.getCommands() as SlashCommandInfo[])
  let conflictNotified = false

  class InlineSkillEditor extends CustomEditor {
    override handleInput(data: string): void {
      const typedSlash = data === "/" || decodeKittyPrintable(data) === "/"
      if (!typedSlash) {
        super.handleInput(data)
        return
      }

      const beforeLines = this.getLines()
      const beforeCursor = this.getCursor()
      super.handleInput(data)

      const afterLines = this.getLines()
      const afterCursor = this.getCursor()
      const expectedLines = [...beforeLines]
      const line = expectedLines[beforeCursor.line]
      if (line === undefined) return
      expectedLines[beforeCursor.line] =
        line.slice(0, beforeCursor.col) + "/" + line.slice(beforeCursor.col)

      if (
        afterCursor.line !== beforeCursor.line ||
        afterCursor.col !== beforeCursor.col + 1 ||
        afterLines.length !== expectedLines.length ||
        afterLines.some((value, index) => value !== expectedLines[index]) ||
        getSkills().size === 0 ||
        !canOpenInlineAutocomplete(
          afterLines,
          afterCursor.line,
          afterCursor.col,
        )
      ) {
        return
      }

      const trigger = (this as unknown as TriggerableEditor)
        .tryTriggerAutocomplete
      if (typeof trigger === "function") trigger.call(this)
    }
  }

  const editorFactory = (
    tui: TUI,
    theme: EditorTheme,
    keybindings: KeybindingsManager,
  ) => new InlineSkillEditor(tui, theme, keybindings)

  pi.on("session_start", async (_event, ctx) => {
    state.reset()
    if (ctx.mode !== "tui") return

    const currentEditor = ctx.ui.getEditorComponent()
    if (currentEditor === editorFactory) return
    if (currentEditor !== undefined) {
      if (!conflictNotified) {
        conflictNotified = true
        ctx.ui.notify(
          "inline-skills: another custom editor is active; automatic completion is disabled",
          "warning",
        )
      }
      return
    }

    ctx.ui.addAutocompleteProvider((current) =>
      createInlineAutocompleteProvider(getSkills, current),
    )
    ctx.ui.setEditorComponent(editorFactory)
  })

  pi.on("input", async (event, ctx) => {
    state.beginInput()
    if (
      ctx.mode !== "tui" ||
      event.source !== "interactive" ||
      event.streamingBehavior !== undefined ||
      event.text.startsWith("/")
    ) {
      return { action: "continue" }
    }

    const registry = getSkills()
    const names = findInlineSkillNames(event.text, registry)
    if (names.length === 0) return { action: "continue" }

    const reads = await Promise.allSettled(
      names.map(async (name) => {
        const skill = registry.get(name)!
        const path = isAbsolute(skill.path)
          ? skill.path
          : resolve(ctx.cwd, skill.path)
        const body = normalizeSkillBody(await readFile(path, "utf8"))
        return { ...skill, path, body, hash: hashSkillBody(body) }
      }),
    )

    const failures = reads.flatMap((result, index) =>
      result.status === "rejected"
        ? [
            `${names[index]}: ${result.reason instanceof Error ? result.reason.message : String(result.reason)}`,
          ]
        : [],
    )
    if (failures.length > 0) {
      ctx.ui.notify(`inline-skills: ${failures.join("; ")}`, "error")
      return { action: "handled" }
    }

    state.prepare(
      reads.map((result) => {
        if (result.status !== "fulfilled") throw new Error("unreachable")
        return result.value
      }),
    )
    return { action: "continue" }
  })

  pi.on("before_agent_start", async (event) => {
    const finalNames = new Set(
      findInlineSkillNames(event.prompt, getSkills()),
    )
    const message = state.takeContextMessage(finalNames)
    return message ? { message } : undefined
  })

  pi.on("message_start", async (event) => {
    state.commit(event.message)
  })

  pi.on("session_compact", async () => {
    state.compact()
  })

  pi.on("session_tree", async () => {
    state.reset()
  })
}
