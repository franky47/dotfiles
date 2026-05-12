# Auditing `.github/workflows/*.yml`

Patterns to hunt for in workflow YAML. Severity assumes a public OSS repo. Use this as a prompt for reasoning, not as a strict checklist — novel variants exist.

## Triggers — the attack surface starts here

The trigger defines who can run the workflow. Privilege depends on it:

| Trigger | Who can launch | Has secrets? | Has write-scoped `GITHUB_TOKEN`? |
|---|---|---|---|
| `push`, `release`, `workflow_dispatch`, `schedule` | Repo collaborators | Yes | Yes |
| `pull_request` | Anyone with a fork | **No** (forks get read-only token, no secrets) | No |
| `pull_request_target` | Anyone with a fork | **Yes** | **Yes** — runs in base-repo context |
| `issue_comment`, `issues`, `discussion_comment` | Anyone | Yes | Yes |
| `workflow_run` | Triggered by another workflow | Yes | Yes |

`pull_request_target`, `issue_comment`, `workflow_run` are the high-blast-radius triggers. Audit them with extreme prejudice.

## Patterns to hunt

### 1. `pull_request_target` + checkout of the PR head (CRITICAL)

The single highest-risk pattern. Trigger gives secrets + write token; checkout of `github.event.pull_request.head.sha` pulls in attacker-controlled code; subsequent steps run it. This is exactly how Nx s1ngularity exfiltrated the NPM publish token.

Look for `on: pull_request_target` co-occurring with any of:
- `uses: actions/checkout` and `with.ref: ${{ github.event.pull_request.head.* }}`
- `uses: actions/checkout` with no explicit `ref:` *and* a later step that runs PR-fetched code (e.g. `npm install`, `npm test`, `pnpm build`)

Also flag the "fixed on main but vulnerable on a stale branch" variant — the historical sub-agent handles that sweep.

### 2. Expression injection into `run:` blocks (CRITICAL)

Any `${{ github.event.* }}` interpolation directly inside a `run:` line where the value is attacker-controlled. Untrusted fields include but are not limited to:

- `github.event.pull_request.title`, `.body`, `.head.ref`, `.head.label`
- `github.event.issue.title`, `.body`
- `github.event.comment.body`
- `github.event.head_commit.message`, `.author.email`, `.author.name`
- `github.event.review.body`
- `github.event.discussion.title`, `.body`
- `github.event.workflow_run.head_branch`

The attacker controls the literal text → it becomes shell. Same applies to `${{ github.head_ref }}` in `pull_request` triggers. Branch names accept characters that turn into shell metacharacters.

Reason from intent: if the value comes from outside the org and ends up in a shell, that is a finding even if the field is not on the list above.

### 3. Missing or over-broad `permissions:` (HIGH)

If the workflow has no top-level `permissions:` block, `GITHUB_TOKEN` defaults to write-all on any repo created before February 2023 and on any repo where the org has not flipped the default. An exploited step can push commits, create releases, write packages.

Flag:
- No `permissions:` key anywhere in the file → assume write-all.
- `permissions: write-all` explicitly.
- Job-level `permissions:` granting `contents: write`, `packages: write`, `id-token: write`, etc. on steps that do not need them.

Recommend least-privilege: top-level `permissions: contents: read`, escalate per-job only where needed.

### 4. Unpinned third-party actions (CRITICAL)

`uses: owner/repo@v1` / `@main` / `@master` / `@latest` / `@v2.3.4` (any tag) is unpinned. Tag mutability is how tj-actions/changed-files and reviewdog/action-setup compromised 23,000+ repositories in March 2025 — the attacker force-moved the tag, every consumer rolled forward to malicious code.

Pinning rule: `uses: owner/repo@<40-char-hex-sha>  # vX.Y.Z` is the only acceptable form for third-party actions. First-party `actions/*` and `github/*` actions are still preferable to pin, but lower severity (GitHub controls the tag).

For every third-party pin, verify SHA legitimacy per the SKILL.md flow (gh / git ls-remote / curl).

### 5. Self-hosted runners on public repos (CRITICAL)

`runs-on:` set to anything outside the GitHub-hosted families (`ubuntu-*`, `windows-*`, `macos-*`). A single malicious PR runs on the runner, secrets are visible via `ps`, and the runner often has persistent state.

If the workflow is triggered by `pull_request` or `pull_request_target` and uses a self-hosted runner, that is Critical and immediate. Ephemeral JIT runners mitigate but are rarely seen.

### 6. `actions/checkout` without `persist-credentials: false` (HIGH)

`actions/checkout@v5` and earlier default `persist-credentials: true`, which writes a write-scoped `GITHUB_TOKEN` into `.git/config`. Subsequent steps and especially `actions/upload-artifact` can leak it.

v6 (released late 2025) changed the default. Flag any pre-v6 checkout without explicit `with: persist-credentials: false`.

Also flag `actions/upload-artifact` with `path: .` or `path: ./` — uploads the entire working tree including `.git/config`.

### 7. `issue_comment` / `workflow_run` without strict actor checks (HIGH)

Anyone can comment on a public issue. If the workflow runs on `issue_comment` and references secrets, it must gate every privileged step on `github.event.comment.author_association in ('OWNER','MEMBER','COLLABORATOR')`. Username allowlists are wrong — accounts get deleted, renamed, or impersonated.

Same logic for `workflow_run` — the triggering workflow's permissions do not transfer; check the actor.

### 8. Cache poisoning across trust boundaries (CRITICAL)

If a `pull_request` or `pull_request_target` workflow and a release / publish workflow both use `actions/cache` with overlapping `key:` prefixes, a PR can poison the cache that the release workflow restores from. This is the TanStack vector (May 2026, 84 malicious versions across 42 packages).

**The trap.** `permissions: contents: read` does *not* block cache writes. The cache action uses a runner-internal token that the workflow `permissions:` block has no control over. A `pull_request_target` workflow set to read-only can still poison the cache.

**The extraction.** Once the release workflow restores the poisoned cache, the injected code runs in a context with `id-token: write` and OIDC. The OIDC token is minted lazily in memory by the runner — the attacker reads `/proc/<pid>/maps` and `/proc/<pid>/mem` of the runner worker process to extract it, then publishes directly to npm using the stolen short-lived token. The workflow's own publish step is bypassed.

**What to hunt:**
- Any pair of workflows in the same repo where one is `pull_request` / `pull_request_target` and the other is `push` / `release` / `workflow_dispatch`, and both use `actions/cache` (or any action that wraps it) with overlapping `key:` / `restore-keys:` prefixes. The classic shape is a shared pnpm/npm/yarn store cache keyed on the lockfile hash.
- Privileged workflows that both `id-token: write` and consume restored caches from prior runs.
- `pull_request_target` workflows that build PR code (running attacker-controlled scripts) and write any cache.

**Fix:** disjoint cache key prefixes across trust levels; for the highest-trust publish workflows, skip caching entirely. See [remediation.md](remediation.md) §7.

Ref: https://tanstack.com/blog/npm-supply-chain-compromise-postmortem

### 9. Long-lived `NPM_TOKEN` / `NODE_AUTH_TOKEN` (CRITICAL)

Any `npm publish` step using a secret-stored token. npm classic tokens were revoked on 2025-12-09; granular tokens remain but are still long-lived bait. OIDC trusted publishing (GA 2025-07-31) eliminates the secret entirely.

Recommend migration. See [remediation.md](remediation.md).

### 10. `--ignore-scripts` not used in CI installs (HIGH)

`npm install` / `npm ci` / `pnpm install` without `--ignore-scripts` (or `.npmrc` setting `ignore-scripts=true`) runs every transitive `postinstall` / `preinstall`. This is the universal initial-access vector for npm worms (event-stream, ua-parser-js, Shai-Hulud).

Mitigation: `--ignore-scripts` in CI; explicit allowlist with `lavamoat/allow-scripts` or pnpm `onlyBuiltDependencies` for the few packages that truly need install scripts.

### 11. Workflow-level `env:` exposing secrets (MEDIUM)

A top-level `env:` block with `${{ secrets.* }}` exposes that secret to every step in the workflow, including `npm install` of a malicious transitive dependency. Scope secrets to the single step that needs them.

### 12. `curl | bash` and remote opaque execution (HIGH)

`run:` blocks fetching code from the network and executing it (`curl -fsSL ... | bash`, `wget -qO- ... | sh`, `eval "$(curl ...)"`, downloading a binary and `chmod +x`). Even from a "trusted" domain — the domain can be compromised, the URL can be hijacked, the binary is opaque.

If the URL is a `raw.githubusercontent.com` URL pinned to a specific commit SHA, it is somewhat better but still flag — out-of-band code paths defeat the rest of the audit.

## After the walk

Hand control back to SKILL.md step 5 (fold findings).
