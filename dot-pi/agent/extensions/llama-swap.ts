import type { ExtensionAPI } from '@earendil-works/pi-coding-agent'

// Models from ~/.config/opencode/opencode.json
const MODELS = [
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

function toProviderModel(m: {
  id: string
  name: string
  contextWindow: number
  maxTokens: number
}) {
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

  pi.registerProvider('llama-swap', {
    name: 'llama-swap (local)',
    baseUrl,
    api: 'openai-completions',
    apiKey: 'LLAMA_SWAP',
    models,
    compat: {
      supportsDeveloperRole: false,
      supportsReasoningEffort: false,
    },
  })

  pi.on('session_start', async (_event, ctx) => {
    try {
      if (ctx.hasUI) {
        ctx.ui.notify(
          `llama-swap provider registered (${models.length} model(s))`,
          'info',
        )
      }
    } catch {
      // ignore
    }
  })
}
