This repository is public on GitHub: https://github.com/franky47/dotfiles,
you **MUST** filter out secrets & sensitive information before bringing it into the repo.
If you are unsure, ask me.

## Before committing

Update `README.md` (e.g. the skills table) and any relevant tests to reflect your changes, then commit them together.

## Adding a model to llama-swap

1. **Config** `dot-config/llama-swap/config.<machineName>.yml`: add a model block (`-hf <repo>:<TAG>`, copy an existing block's flags). Ask whether to **fork** a new entry (to A/B against an existing model) or **update** one in place — never mutate a live entry when experimenting.
2. **Expose to clients** (reuse the same model id):
   - pi: add `llama-swap/<id>` to `enabledModels` in `dot-pi/agent/settings.json` **and** a `MODELS` entry in `dot-pi/agent/extensions/llama-swap.ts`.
   - opencode: add a model entry under the provider in `dot-config/opencode/opencode.json`.
3. **Pre-pull the GGUF before first use**:  Map the tag `<repo>:<TAG>` → `<ModelName>-<TAG>.gguf`, then: `hf download <repo> <ModelName>-<TAG>.gguf`
   (writes `~/.cache/huggingface/hub`, the cache llama.cpp's `-hf` reads). Monitor the download, then query once and confirm `/running` reaches `ready`.

### Private (unversioned) models

Models that must stay out of this public repo live in `~/.config/llama-swap.private/`
(a real directory, never stowed or committed):

- llama-swap loads every `*.yml` in there additively via `-config-dir` (hot-reloaded
  by `-watch-config`). Add a standard model block to e.g. `models.yml`.
- pi picks them up from `~/.config/llama-swap.private/pi-models.json`
  (`{ "models": [{ id, name, contextWindow, maxTokens }] }`), registered under the
  `llama-swap-private` provider and enabled by the versioned `llama-swap-private/*` glob —
  private model names never appear in tracked files.
- opencode: private entries would go in the versioned `opencode.json`, so private models
  are not exposed there.
