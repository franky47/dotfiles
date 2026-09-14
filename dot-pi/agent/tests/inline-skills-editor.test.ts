import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import { test } from "node:test"
import { setImmediate } from "node:timers/promises"

import type {
  CustomEditor,
  ExtensionContext,
} from "@earendil-works/pi-coding-agent"
import {
  KeybindingsManager,
  StdinBuffer,
  type AutocompleteProvider,
  type EditorTheme,
} from "@earendil-works/pi-tui"

import inlineSkills from "../extensions/inline-skills/index.ts"

type EditorFactory = NonNullable<
  Parameters<ExtensionContext["ui"]["setEditorComponent"]>[0]
>

const identity = (text: string) => text
const theme: EditorTheme = {
  borderColor: identity,
  selectList: {
    selectedPrefix: identity,
    selectedText: identity,
    description: identity,
    scrollInfo: identity,
    noMatch: identity,
  },
}

async function createEditor() {
  let start: (event: unknown, ctx: unknown) => Promise<void>
  let provider: AutocompleteProvider = {
    async getSuggestions() { return null },
    applyCompletion(lines, cursorLine, cursorCol) {
      return { lines, cursorLine, cursorCol }
    },
  }
  let editor: CustomEditor
  const keybindings = new KeybindingsManager({
    "app.clipboard.pasteImage": { defaultKeys: "ctrl+v" },
  })

  inlineSkills({
    on(name: string, handler: typeof start) {
      if (name === "session_start") start = handler
    },
    getCommands() {
      return [{
        name: "skill:tdd",
        source: "skill",
        sourceInfo: { path: "/skills/tdd/SKILL.md" },
      }]
    },
  } as never)

  await start!({}, {
    mode: "tui",
    ui: {
      getEditorComponent() { return undefined },
      addAutocompleteProvider(wrap: (current: AutocompleteProvider) => AutocompleteProvider) {
        provider = wrap(provider)
      },
      setEditorComponent(factory: EditorFactory) {
        editor = factory({
          terminal: { columns: 100, rows: 30 },
          requestRender() {},
        } as never, theme, keybindings as never) as CustomEditor
        editor.setAutocompleteProvider(provider)
        editor.onPasteImage = () => editor.insertTextAtCursor("/tmp/pi-test-image.png")
      },
    },
  })

  return { editor: editor!, keybindings }
}

for (const text of ["clipboard text", "line one\nline two", "/tmp/copied-image.png", "use /tdd"]) {
  test(`a terminal paste inserts ${JSON.stringify(text)} once without reading the clipboard`, async () => {
    const { editor } = await createEditor()
    editor.handleInput(`\x1b[200~${text}\x1b[201~`)
    assert.equal(editor.getText(), text)
    assert.equal(editor.isShowingAutocomplete(), false)
  })
}

for (const slash of ["/", "\x1b[47u"]) {
  test(`typing ${JSON.stringify(slash)} still opens inline skill completion`, async () => {
    const { editor } = await createEditor()
    editor.setText("use ")
    editor.handleInput(slash)
    await setImmediate()
    assert.equal(editor.isShowingAutocomplete(), true)
    editor.handleInput("\t")
    assert.equal(editor.getText(), "use /tdd ")
  })
}

test("Pi's input buffer delivers a split empty paste as one image paste", async () => {
  const { editor } = await createEditor()
  const input = new StdinBuffer()
  input.on("paste", (text: string) => editor.handleInput(`\x1b[200~${text}\x1b[201~`))
  try {
    for (const chunk of ["\x1b[20", "0~", "\x1b[", "201~"]) input.process(chunk)
    assert.equal(editor.getText(), "/tmp/pi-test-image.png")
  } finally {
    input.destroy()
  }
})

test("an empty terminal paste inserts the image path through Pi's clipboard handler", async () => {
  const { editor } = await createEditor()
  editor.setText("describe ")
  editor.handleInput("\x1b[200~\x1b[201~")
  assert.equal(editor.getText(), "describe /tmp/pi-test-image.png")
})

test("configured Ctrl+V and Cmd+V insert an image path once", async () => {
  const { editor, keybindings } = await createEditor()
  keybindings.setUserBindings(JSON.parse(readFileSync(
    new URL("../keybindings.json", import.meta.url), "utf8",
  )))

  for (const key of ["\x16", "\x1b[118;9u"]) {
    editor.setText("describe ")
    editor.handleInput(key)
    assert.equal(editor.getText(), "describe /tmp/pi-test-image.png")
  }
})
