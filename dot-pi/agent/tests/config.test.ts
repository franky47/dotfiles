import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { spawnSync } from 'node:child_process'
import { fileURLToPath } from 'node:url'
import { describe, it } from 'node:test'

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), '../../..')

const readJson = (path: string) => JSON.parse(readFileSync(resolve(repoRoot, path), 'utf8'))

describe('Pi package configuration', () => {
  it('uses @tintinweb/pi-subagents without durable run records', () => {
    const settings = readJson('dot-pi/agent/settings.json')
    const subagents = readJson('dot-pi/agent/subagents.json')

    assert.ok(settings.packages.includes('npm:@tintinweb/pi-subagents'))
    assert.ok(!settings.packages.includes('npm:pi-subagents'))
    assert.equal(subagents.outputTranscript, false)
    assert.equal(subagents.schedulingEnabled, false)
  })

  it('launches Pi with in-memory task storage', () => {
    const result = spawnSync(
      'zsh',
      ['-f', '-c', 'compdef() { :; }; source ./zsh/60-ai.zsh; PI_BIN=/usr/bin/env; π'],
      {
        cwd: repoRoot,
        encoding: 'utf8',
        env: Object.fromEntries(Object.entries(process.env).filter(([key]) => key !== 'PI_TASKS')),
      },
    )

    assert.equal(result.status, 0, result.stderr)
    assert.match(result.stdout, /^PI_TASKS=off$/m)
  })
})
