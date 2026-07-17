import { readFileSync } from 'node:fs'
import { homedir } from 'node:os'
import { join } from 'node:path'
import type { ExtensionAPI } from '@earendil-works/pi-coding-agent'

type LocalModel = {
  id: string
  name: string
  contextWindow: number
  maxTokens: number
}

// Models from ~/.config/opencode/opencode.json
const MODELS: LocalModel[] = [
  {
    id: 'qwen3.6-35b-a3b-q4_k_m',
    name: 'Qwen 3.6 35B A3B (Q4_K_M)',
    contextWindow: 262144,
    maxTokens: 262144,
  },
  {
    id: 'ornith-1.0-35b-q4_k_m',
    name: 'Ornith 1.0 35B (Q4_K_M)',
    contextWindow: 262144,
    maxTokens: 262144,
  },
  {
    id: 'qwen3.6-27b-q4_k_xl',
    name: 'Qwen 3.6 27B (Q4_K_XL)',
    contextWindow: 262144,
    maxTokens: 262144,
  },
  {
    id: 'qwen3.6-27b-q6_k_xl',
    name: 'Qwen 3.6 27B (Q6_K_XL)',
    contextWindow: 262144,
    maxTokens: 262144,
  },
  {
    id: 'gemma4-31b-q4_k_m',
    name: 'Gemma 4 31B (Q4_K_M)',
    contextWindow: 65536,
    maxTokens: 65536,
  },
  {
    id: 'lfm2.5-8b-a1b',
    name: 'LFM2.5 8B A1B',
    contextWindow: 65536,
    maxTokens: 65536,
  },
]

// Unversioned models, kept out of the public dotfiles repo. Their llama-swap
// entries live in ~/.config/llama-swap.private/*.yml (loaded via -config-dir);
// this manifest mirrors them for pi. Enabled via the llama-swap-private/* glob
// in settings.json, so model names never appear in versioned files.
function loadPrivateModels(): LocalModel[] {
  const manifest = join(homedir(), '.config/llama-swap.private/pi-models.json')
  try {
    const parsed = JSON.parse(readFileSync(manifest, 'utf-8'))
    const models = Array.isArray(parsed.models) ? parsed.models : []
    return models.filter(
      (m: Partial<LocalModel>) =>
        typeof m.id === 'string' &&
        typeof m.name === 'string' &&
        typeof m.contextWindow === 'number' &&
        typeof m.maxTokens === 'number',
    )
  } catch {
    return []
  }
}

function toProviderModel(m: LocalModel) {
  return {
    id: m.id,
    name: m.name,
    reasoning: true,
    input: ['text'],
    cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
    contextWindow: m.contextWindow,
    maxTokens: m.maxTokens,
  }
}

export default async function (pi: ExtensionAPI) {
  const baseUrl = 'http://127.0.0.1:10001/v1'

  const models = MODELS.map(toProviderModel)
  const privateModels = loadPrivateModels().map(toProviderModel)

  const compat = {
    supportsDeveloperRole: false,
    supportsReasoningEffort: false,
  }

  pi.registerProvider('llama-swap', {
    name: 'llama-swap (local)',
    baseUrl,
    api: 'openai-completions',
    apiKey: 'LLAMA_SWAP',
    models,
    compat,
  })

  if (privateModels.length > 0) {
    pi.registerProvider('llama-swap-private', {
      name: 'llama-swap (private)',
      baseUrl,
      api: 'openai-completions',
      apiKey: 'LLAMA_SWAP',
      models: privateModels,
      compat,
    })
  }

  pi.on('session_start', async (_event, ctx) => {
    try {
      if (ctx.hasUI) {
        ctx.ui.notify(
          `llama-swap provider registered (${models.length} public, ${privateModels.length} private model(s))`,
          'info',
        )
      }
    } catch {
      // ignore
    }
  })
}
