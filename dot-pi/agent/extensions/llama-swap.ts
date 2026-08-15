import type { ExtensionAPI } from '@earendil-works/pi-coding-agent'

type ChatTemplateVariable = {
  $var: 'thinking.enabled' | 'thinking.effort'
  omitWhenOff?: boolean
}

type ModelCompat = {
  supportsReasoningEffort?: boolean
  thinkingFormat?: 'chat-template'
  chatTemplateKwargs?: {
    [name: string]: boolean | ChatTemplateVariable
  }
}

type LocalModel = {
  id: string
  name: string
  contextWindow: number
  maxTokens: number
  input?: ('text' | 'image')[]
  samplingParams?: {
    [name: string]: number
  }
  thinkingLevelMap?: {
    [level: string]: string | null
  }
  compat?: ModelCompat
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
    id: 'qwen3.8-27b-q6_k_xl',
    name: 'Qwen 3.8 27B (Q6_K_XL)',
    contextWindow: 262144,
    maxTokens: 262144,
    input: ['text', 'image'],
    samplingParams: {
      temperature: 1.0,
      top_p: 0.95,
      top_k: 20,
      min_p: 0.0,
      presence_penalty: 0.0,
      repeat_penalty: 1.0,
    },
    thinkingLevelMap: {
      off: null,
      minimal: 'low',
      low: 'low',
      medium: 'medium',
      high: 'xhigh',
      xhigh: 'xhigh',
      max: 'xhigh',
    },
    compat: {
      supportsReasoningEffort: true,
      thinkingFormat: 'chat-template',
      chatTemplateKwargs: {
        enable_thinking: { $var: 'thinking.enabled' },
        preserve_thinking: true,
        reasoning_effort: { $var: 'thinking.effort' },
      },
    },
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

function toProviderModel(m: LocalModel) {
  return {
    id: m.id,
    name: m.name,
    reasoning: true,
    input: m.input ?? ['text'],
    samplingParams: m.samplingParams,
    thinkingLevelMap: m.thinkingLevelMap,
    compat: m.compat,
    cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
    contextWindow: m.contextWindow,
    maxTokens: m.maxTokens,
  }
}

export default async function (pi: ExtensionAPI) {
  const baseUrl = 'http://127.0.0.1:10001/v1'

  const models = MODELS.map(toProviderModel)

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
