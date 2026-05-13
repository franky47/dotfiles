# Severity catalog (reference)

Quick-reference table of the patterns to check. Use as a *prompt for what to look for*, not as a closed list — novel variants must be reasoned about. Per-surface details live in [workflows.md](workflows.md), [composite-actions.md](composite-actions.md), and [scripts.md](scripts.md). Real-world incident anchors live in [incidents.md](incidents.md).

## CRITICAL

| Pattern | Detection hint | Anchored to |
|---|---|---|
| `pull_request_target` + checkout of PR head ref | `on.pull_request_target` co-occurring with `actions/checkout` and `with.ref: github.event.pull_request.head.*` (or default checkout in a privileged trigger) | Nx s1ngularity (2025-08) |
| `workflow_run` + checkout of triggering branch | `on.workflow_run` co-occurring with `actions/checkout` and `with.ref: ${{ github.event.workflow_run.head_branch \| head_sha \| head_commit.* }}` | Structural twin of `pull_request_target` checkout |
| Expression injection of attacker-controlled fields into `run:` or `actions/github-script` `script:` | Any `${{ github.event.* }}` from PR/issue/comment/discussion/head_commit inside a `run:` line, **or** inside `with.script:` of `actions/github-script` (GHA expands `${{ }}` before JS executes) | Nx s1ngularity |
| Long-lived `NPM_TOKEN` / `NODE_AUTH_TOKEN` for publishing | `npm publish` with `NODE_AUTH_TOKEN` or `NPM_TOKEN` from `secrets.*` | Shai-Hulud, qix |
| Unpinned third-party action | `uses: owner/repo@<not-a-40-char-sha>` (tag, branch, `latest`) | tj-actions / reviewdog (2025-03) |
| Repojackable action owner (unpinned consumer) | `uses: owner/repo@<tag-or-branch>` where `HEAD https://github.com/<owner>` returns `404` (namespace unclaimed) or `3xx` (owner renamed) | Generic namespace-reuse hijack |
| Self-hosted runner on public repo | `runs-on:` outside `ubuntu-*` / `windows-*` / `macos-*` families | Shai-Hulud 2.0 self-hosted runner registration |
| Script self-mutates `.github/workflows/*` or `.git/config` | Scripts that write into those paths | Shai-Hulud worm persistence |
| Composite-action input interpolated into `run:` | Action publisher: `${{ inputs.* }}` in a `runs.steps[*].run:` | tj-actions chain |
| Cache poisoning across trust boundaries | A `pull_request` / `pull_request_target` workflow shares an `actions/cache` key prefix with a release/publish workflow; OIDC `id-token: write` in the privileged workflow extractable from runner memory after restoring poisoned cache | TanStack (2026-05) |
| Dynamic / obfuscated code execution from data | Base64-decoded payloads piped to a shell; multi-stage decoders | xz-utils (2024-03, non-npm but same shape) |

## HIGH

| Pattern | Detection hint | Anchored to |
|---|---|---|
| Missing or `write-all` `permissions:` | No `permissions:` block at workflow or job level, or `permissions: write-all` | Default-write `GITHUB_TOKEN` risk |
| `actions/checkout` with `persist-credentials: true` (pre-v6) | `actions/checkout@<v6` without `persist-credentials: false` | Token leak via `.git/config` and artifacts |
| `npm install` / `pnpm install` / `yarn install` without `--ignore-scripts` | CI install command without the flag, no `.npmrc` `ignore-scripts=true` | event-stream, ua-parser-js, Shai-Hulud |
| `issue_comment` / `workflow_run` without `author_association` gate | Trigger references secrets without an `if:` checking `OWNER`/`MEMBER`/`COLLABORATOR` | Multiple Pwn-Request CVEs |
| `curl \| bash` / `wget -O- \| sh` / remote opaque binary | Network fetch piped to a shell or executed via `chmod +x` | Generic supply-chain pivot |
| Network exfiltration paths in scripts | POST to `webhook.site`, Discord, pastebin, ngrok, workers.dev | Shai-Hulud, Nx |
| Filesystem credential reconnaissance | Reading `~/.npmrc`, `~/.aws/`, `~/.ssh/`, running `trufflehog`/`gitleaks` mid-build | Shai-Hulud |
| No npm `--provenance` and no OIDC trusted publishing | `npm publish` without provenance or `id-token: write` | Forgery defence absent |
| Action `dist/` distributed without build-verification gate | Committed `dist/` for a JS action with no CI step ensuring it matches source | Generic JS-action risk |
| Docker action with mutable image tag | `runs.image:` not pinned to `@sha256:` digest | Container registry tag mutability |
| Repojackable action owner (SHA-pinned consumer) | `uses: owner/repo@<sha>` where the owner namespace is 404 or redirects — current SHA still resolves but future bumps roll onto attacker code | Generic namespace-reuse hijack |

## MEDIUM

| Pattern | Detection hint |
|---|---|
| Workflow-level `env:` exposing secrets to every step | Top-level `env:` referencing `${{ secrets.* }}` |
| `actions/upload-artifact` with `path: .` or `path: ./` | Uploads full working tree, including `.git/config` |
| `actions/checkout` for the PR head in a non-default-trigger workflow with secrets accessible | Combine trigger + checkout + secret access |
| No `.github/CODEOWNERS` coverage for `.github/workflows/` | CODEOWNERS file present but no rule for the workflow path |

## LOW

| Pattern | Detection hint |
|---|---|
| No deterministic-tooling step in CI (`zizmor`, OpenSSF Scorecard, Harden-Runner) | Workflows do not include any periodic security scan |
| No `npm audit signatures` on install | Install step does not verify signatures |
| Inconsistent action pinning style across the repo | Some pinned, some not — review hygiene |
