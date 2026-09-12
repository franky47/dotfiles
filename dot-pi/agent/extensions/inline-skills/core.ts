import { createHash } from "node:crypto"
import { dirname } from "node:path"

export const SKILL_CONTEXT_TYPE = "inline-skill-context/v5"

const NAME_PATTERN = /^[a-z0-9](?:[a-z0-9-]{0,62}[a-z0-9])?$/
const NAME_CHARACTER = /[a-z0-9-]/
const ASCII_WHITESPACE = /[\t\v\f\r ]/
const LEFT_BOUNDARIES = "([{\'\""
const TRAILING_PUNCTUATION = ".,;!?)]}\'\""

function isLeftBoundary(character: string): boolean {
  return ASCII_WHITESPACE.test(character) || LEFT_BOUNDARIES.includes(character)
}

export type SkillDefinition = {
  name: string
  path: string
  description?: string
}

export type PreparedSkill = SkillDefinition & {
  body: string
  hash: string
}

type CommandInfo = {
  name?: unknown
  description?: unknown
  source?: unknown
  sourceInfo?: { path?: unknown }
}

export function skillRegistry(
  commands: readonly CommandInfo[],
): Map<string, SkillDefinition> {
  const skills = new Map<string, SkillDefinition>()
  for (const command of commands) {
    if (
      command.source !== "skill" ||
      typeof command.name !== "string" ||
      !command.name.startsWith("skill:") ||
      typeof command.sourceInfo?.path !== "string"
    ) {
      continue
    }
    const name = command.name.slice("skill:".length)
    if (!isSkillName(name)) continue
    skills.set(name, {
      name,
      path: command.sourceInfo.path,
      description:
        typeof command.description === "string"
          ? command.description
          : undefined,
    })
  }
  return skills
}

export function isSkillName(name: string): boolean {
  return NAME_PATTERN.test(name)
}

export function findInlineSkillNames(
  text: string,
  skills: ReadonlyMap<string, SkillDefinition>,
): string[] {
  if (text.startsWith("/")) return []

  const found: string[] = []
  const seen = new Set<string>()

  for (const line of text.split("\n")) {
    for (let slash = line.indexOf("/"); slash !== -1; slash = line.indexOf("/", slash + 1)) {
      if (slash === 0 || !isLeftBoundary(line[slash - 1] ?? "")) continue
      if (!/\S/.test(line.slice(0, slash))) continue

      let end = slash + 1
      while (end < line.length && NAME_CHARACTER.test(line[end]!)) end += 1
      const name = line.slice(slash + 1, end)
      if (!isSkillName(name) || !skills.has(name)) continue

      if (!hasRightBoundary(line, end)) continue

      if (!seen.has(name)) {
        seen.add(name)
        found.push(name)
      }
    }
  }

  return found
}

export function normalizeSkillBody(raw: string): string {
  let body = raw.replace(/^\ufeff/, "").replace(/\r\n?/g, "\n")
  if (body.startsWith("---")) {
    const close = body.indexOf("\n---", 3)
    if (close === -1) throw new Error("Unclosed skill frontmatter")
    body = body.slice(close + 4)
  }
  return body.trim()
}

export function hashSkillBody(body: string): string {
  return createHash("sha256").update(body, "utf8").digest("hex")
}

type ContextMessage = {
  customType: typeof SKILL_CONTEXT_TYPE
  content: string
  display: true
  details: { version: 5; batchId: string; skills: string[] }
}

type StartedMessage = {
  customType?: unknown
  details?: unknown
}

export class InlineSkillState {
  private prepared?: PreparedSkill[]
  private pendingCommit?: { batchId: string; hashes: [string, string][] }
  private readonly bodyHashes = new Map<string, string>()
  private batchSequence = 0

  beginInput(): void {
    this.prepared = undefined
    this.pendingCommit = undefined
  }

  prepare(skills: PreparedSkill[]): void {
    this.beginInput()
    this.prepared = skills
  }

  takeContextMessage(allowedNames?: ReadonlySet<string>): ContextMessage | undefined {
    const prepared = this.prepared
    this.prepared = undefined
    if (!prepared) return undefined

    const changed = prepared.filter(
      ({ name, hash }) =>
        (allowedNames === undefined || allowedNames.has(name)) &&
        this.bodyHashes.get(name) !== hash,
    )
    if (changed.length === 0) return undefined

    const batchId = `inline-skills-${++this.batchSequence}`
    this.pendingCommit = {
      batchId,
      hashes: changed.map(({ name, hash }) => [name, hash]),
    }

    return {
      customType: SKILL_CONTEXT_TYPE,
      content: JSON.stringify({
        kind: SKILL_CONTEXT_TYPE,
        instruction:
          "The user explicitly invoked these inline skills for this turn. Follow each body as user-provided instructions and resolve relative paths from its location.",
        skills: changed.map(({ name, path, body }) => ({
          name,
          location: dirname(path),
          body,
        })),
      }),
      display: true,
      details: {
        version: 5,
        batchId,
        skills: changed.map(({ name }) => name),
      },
    }
  }

  pendingBatchId(): string | undefined {
    return this.pendingCommit?.batchId
  }

  commit(message: StartedMessage): void {
    if (
      message.customType !== SKILL_CONTEXT_TYPE ||
      !message.details ||
      typeof message.details !== "object" ||
      !("batchId" in message.details) ||
      message.details.batchId !== this.pendingCommit?.batchId
    ) {
      return
    }

    for (const [name, hash] of this.pendingCommit.hashes) {
      this.bodyHashes.set(name, hash)
    }
    this.pendingCommit = undefined
  }

  compact(): void {
    this.bodyHashes.clear()
    this.pendingCommit = undefined
  }

  reset(): void {
    this.prepared = undefined
    this.pendingCommit = undefined
    this.bodyHashes.clear()
  }
}

export type AutocompleteItem = {
  value: string
  label: string
  description?: string
}

export type AutocompleteSuggestions = {
  items: AutocompleteItem[]
  prefix: string
}

export type AutocompleteProvider = {
  triggerCharacters?: string[]
  getSuggestions(
    lines: string[],
    cursorLine: number,
    cursorCol: number,
    options: { signal: AbortSignal; force?: boolean },
  ): Promise<AutocompleteSuggestions | null>
  applyCompletion(
    lines: string[],
    cursorLine: number,
    cursorCol: number,
    item: AutocompleteItem,
    prefix: string,
  ): { lines: string[]; cursorLine: number; cursorCol: number }
  shouldTriggerFileCompletion?(
    lines: string[],
    cursorLine: number,
    cursorCol: number,
  ): boolean
}

function hasRightBoundary(line: string, end: number): boolean {
  let boundary = end
  while (
    boundary < line.length &&
    TRAILING_PUNCTUATION.includes(line[boundary]!)
  ) {
    boundary += 1
  }
  return boundary === line.length || ASCII_WHITESPACE.test(line[boundary]!)
}

type CompletionCandidate = {
  slash: number
  end: number
  query: string
}

function completionCandidate(
  lines: string[],
  cursorLine: number,
  cursorCol: number,
): CompletionCandidate | undefined {
  if (lines.join("\n").startsWith("/")) return undefined
  const line = lines[cursorLine]
  if (line === undefined || cursorCol < 0 || cursorCol > line.length) return undefined

  let nameStart = cursorCol
  while (nameStart > 0 && NAME_CHARACTER.test(line[nameStart - 1]!)) {
    nameStart -= 1
  }
  const slash = nameStart - 1
  if (slash < 1 || line[slash] !== "/") return undefined
  if (!isLeftBoundary(line[slash - 1] ?? "")) return undefined
  if (!/\S/.test(line.slice(0, slash))) return undefined

  let end = cursorCol
  while (end < line.length && NAME_CHARACTER.test(line[end]!)) end += 1
  if (!hasRightBoundary(line, end)) return undefined
  return { slash, end, query: line.slice(nameStart, cursorCol) }
}

export function canOpenInlineAutocomplete(
  lines: string[],
  cursorLine: number,
  cursorCol: number,
): boolean {
  return completionCandidate(lines, cursorLine, cursorCol) !== undefined
}

export function createInlineAutocompleteProvider(
  getSkills: () => ReadonlyMap<string, SkillDefinition>,
  current: AutocompleteProvider,
): AutocompleteProvider {
  const ownedItems = new WeakSet<AutocompleteItem>()

  return {
    triggerCharacters: current.triggerCharacters,

    async getSuggestions(lines, cursorLine, cursorCol, options) {
      const candidate = completionCandidate(lines, cursorLine, cursorCol)
      if (!candidate) {
        return current.getSuggestions(lines, cursorLine, cursorCol, options)
      }

      const matches = [...getSkills().values()]
        .filter(({ name }) => name.startsWith(candidate.query))
        .sort((a, b) => a.name.localeCompare(b.name))
        .slice(0, 30)
      if (options.signal.aborted || matches.length === 0) {
        return current.getSuggestions(lines, cursorLine, cursorCol, options)
      }

      const items = matches.map(({ name, description }) => {
        const item = {
          value: name,
          label: `inline skill /${name}`,
          description,
        }
        ownedItems.add(item)
        return item
      })
      return { items, prefix: candidate.query }
    },

    applyCompletion(lines, cursorLine, cursorCol, item, prefix) {
      if (!ownedItems.has(item)) {
        return current.applyCompletion(
          lines,
          cursorLine,
          cursorCol,
          item,
          prefix,
        )
      }

      const candidate = completionCandidate(lines, cursorLine, cursorCol)
      if (
        !candidate ||
        prefix !== candidate.query ||
        !isSkillName(item.value) ||
        !item.value.startsWith(candidate.query) ||
        !getSkills().has(item.value)
      ) {
        return { lines, cursorLine, cursorCol }
      }

      const nextLines = [...lines]
      const line = nextLines[cursorLine]!
      const suffix = candidate.end === line.length ? " " : ""
      nextLines[cursorLine] =
        line.slice(0, candidate.slash) +
        `/${item.value}${suffix}` +
        line.slice(candidate.end)
      return {
        lines: nextLines,
        cursorLine,
        cursorCol: candidate.slash + item.value.length + 1 + suffix.length,
      }
    },

    shouldTriggerFileCompletion(lines, cursorLine, cursorCol) {
      if (completionCandidate(lines, cursorLine, cursorCol)) return true
      return (
        current.shouldTriggerFileCompletion?.(lines, cursorLine, cursorCol) ??
        false
      )
    },
  }
}
