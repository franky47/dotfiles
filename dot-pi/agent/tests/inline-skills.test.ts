import assert from "node:assert/strict"
import { test } from "node:test"

import {
  createInlineAutocompleteProvider,
  findInlineSkillNames,
  InlineSkillState,
  normalizeSkillBody,
  skillRegistry,
  SKILL_CONTEXT_TYPE,
  type PreparedSkill,
  type SkillDefinition,
} from "../extensions/inline-skills/core.ts"

const skills = new Map<string, SkillDefinition>([
  ["tdd", { name: "tdd", path: "/skills/tdd/SKILL.md" }],
  ["work", { name: "work", path: "/skills/work/SKILL.md" }],
])

test("builds the registry only from valid Pi skill commands", () => {
  assert.deepEqual(
    [...skillRegistry([
      {
        name: "skill:tdd",
        description: "Test first",
        source: "skill",
        sourceInfo: { path: "/skills/tdd/SKILL.md" },
      },
      {
        name: "skill:Bad_Name",
        source: "skill",
        sourceInfo: { path: "/skills/bad/SKILL.md" },
      },
      {
        name: "review",
        source: "extension",
        sourceInfo: { path: "/extensions/review.ts" },
      },
    ])],
    [
      [
        "tdd",
        {
          name: "tdd",
          description: "Test first",
          path: "/skills/tdd/SKILL.md",
        },
      ],
    ],
  )
})

test("finds inline skill names without changing surrounding syntax", () => {
  assert.deepEqual(
    findInlineSkillNames("let's use (/tdd), then /work and /tdd", skills),
    ["tdd", "work"],
  )
  assert.deepEqual(findInlineSkillNames("use\f/tdd", skills), ["tdd"])
})

test("leaves commands, paths, URLs, and embedded slashes alone", () => {
  for (const text of [
    "/review use /tdd",
    "  /tdd",
    "use /TDD /tdd.md /tdd?fast=1",
    "visit https://example.com/tdd",
    "use //tdd or \\/tdd",
    "something/tdd",
  ]) {
    assert.deepEqual(findInlineSkillNames(text, skills), [], text)
  }
})

test("normalizes a complete skill body before hashing", () => {
  assert.equal(
    normalizeSkillBody("\ufeff---\r\nname: tdd\r\n---\r\n\r\n  Body\rline  \r\n"),
    "Body\nline",
  )
  assert.equal(
    normalizeSkillBody("--- \nignored: true\n--- \nBody"),
    "Body",
  )
  assert.throws(
    () => normalizeSkillBody("---\nname: tdd\nBody"),
    /frontmatter/i,
  )
})

const prepared = (body: string, hash: string): PreparedSkill => ({
  name: "tdd",
  path: "/skills/tdd/SKILL.md",
  body,
  hash,
})

test("records a body hash only after its matching custom message starts", () => {
  const state = new InlineSkillState()
  state.prepare([prepared("first", "hash-1")])

  const message = state.takeContextMessage()
  assert.equal(message?.customType, SKILL_CONTEXT_TYPE)
  assert.deepEqual(JSON.parse(message!.content).skills, [
    {
      name: "tdd",
      location: "/skills/tdd",
      body: "first",
    },
  ])

  state.recordIngested({ customType: SKILL_CONTEXT_TYPE, details: { batchId: "wrong" } })
  state.prepare([prepared("first", "hash-1")])
  assert.ok(state.takeContextMessage(), "a mismatched message must not record")

  const matching = state.pendingBatchId()
  state.recordIngested({
    customType: SKILL_CONTEXT_TYPE,
    details: { batchId: matching },
  })
  state.prepare([prepared("first", "hash-1")])
  assert.equal(state.takeContextMessage(), undefined)
})

test("drops preparation removed by a later prompt transform", () => {
  const state = new InlineSkillState()
  state.prepare([prepared("first", "hash-1")])
  assert.equal(state.takeContextMessage(new Set(["work"])), undefined)
})

test("compaction invalidates hashes but keeps the current preparation", () => {
  const state = new InlineSkillState()
  state.prepare([prepared("first", "hash-1")])
  const first = state.takeContextMessage()!
  state.recordIngested({ customType: first.customType, details: first.details })

  state.prepare([prepared("first", "hash-1")])
  state.compact()
  assert.ok(state.takeContextMessage(), "current skill must return after compaction")

  state.reset()
  assert.equal(state.takeContextMessage(), undefined)
})

test("offers and applies an inline completion over the whole fragment", async () => {
  const delegated = {
    async getSuggestions() {
      return { items: [{ value: "file", label: "file" }], prefix: "" }
    },
    applyCompletion(lines: string[], cursorLine: number, cursorCol: number) {
      return { lines, cursorLine, cursorCol }
    },
  }
  const provider = createInlineAutocompleteProvider(() => skills, delegated)
  const suggestions = await provider.getSuggestions(
    ["use /w", "next"],
    0,
    6,
    { signal: new AbortController().signal },
  )

  assert.deepEqual(suggestions, {
    prefix: "w",
    items: [
      {
        value: "work",
        label: "inline skill /work",
        description: undefined,
      },
    ],
  })

  assert.deepEqual(
    provider.applyCompletion(
      ["use /w|ork now".replace("|", "")],
      0,
      6,
      suggestions!.items[0]!,
      suggestions!.prefix,
    ),
    { lines: ["use /work now"], cursorLine: 0, cursorCol: 9 },
  )
})

test("delegates command-start, embedded, and unmatched completion requests", async () => {
  let calls = 0
  const delegated = {
    async getSuggestions() {
      calls += 1
      return { items: [{ value: "native", label: "native" }], prefix: "n" }
    },
    applyCompletion(lines: string[], cursorLine: number, cursorCol: number) {
      return { lines, cursorLine, cursorCol }
    },
  }
  const provider = createInlineAutocompleteProvider(() => skills, delegated)
  const signal = new AbortController().signal

  for (const [line, cursor] of [
    ["/t", 2],
    ["something/", 10],
    ["use /missing", 12],
    ["use /w.txt", 6],
    ["use /w/folder", 6],
    ["use /w?fast=1", 6],
  ] as const) {
    assert.equal(
      (await provider.getSuggestions([line], 0, cursor, { signal }))?.prefix,
      "n",
    )
  }
  assert.equal(calls, 6)
})

test("leaves the editor untouched for a stale owned completion", async () => {
  const delegated = {
    async getSuggestions() {
      return null
    },
    applyCompletion(lines: string[], cursorLine: number, cursorCol: number) {
      return {
        lines: [...lines, "delegated"],
        cursorLine,
        cursorCol,
      }
    },
  }
  const provider = createInlineAutocompleteProvider(() => skills, delegated)
  const suggestions = await provider.getSuggestions(
    ["use /t"],
    0,
    6,
    { signal: new AbortController().signal },
  )

  assert.deepEqual(
    provider.applyCompletion(
      ["use /tx"],
      0,
      7,
      suggestions!.items[0]!,
      suggestions!.prefix,
    ),
    { lines: ["use /tx"], cursorLine: 0, cursorCol: 7 },
  )
})
