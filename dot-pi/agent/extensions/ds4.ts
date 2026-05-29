import type { ExtensionAPI } from '@earendil-works/pi-coding-agent'

const MODELS = [
  {
    id: 'deepseek-v4-flash',
    name: 'DeepSeek V4 Flash (ds4.c local, q2-imatrix)',
    contextWindow: 131072,
    maxTokens: 131072,
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
  const baseUrl = 'http://127.0.0.1:9999/v1'

  const models = MODELS.map(toProviderModel)

  pi.registerProvider('ds4', {
    name: 'ds4.c (local)',
    baseUrl,
    api: 'openai-completions',
    apiKey: 'DS4_LOCAL',
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
          `ds4 provider registered (${models.length} model(s))`,
          'info',
        )
      }
    } catch {
      // ignore
    }
  })
}
