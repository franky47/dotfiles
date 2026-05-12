# Fix recipes

Concrete snippets to attach to findings. The skill does not apply these — the user does. The job is to make remediation obvious and copy-pasteable.

## 1. Replace long-lived `NPM_TOKEN` with OIDC trusted publishing

Configure the package on npmjs.com under **Settings → Trusted Publishers → Add Trusted Publisher (GitHub Actions)** with the repo owner, repo name, workflow filename, and environment name (if any). npm trusted publishing went GA on 2025-07-31; npm CLI ≥ 11.5.1 required.

Workflow change:

```yaml
permissions:
  contents: read
  id-token: write  # required for OIDC

jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@<sha>  # vN.M.K
      - uses: actions/setup-node@<sha>  # vN.M.K
        with:
          node-version: '24'
          registry-url: 'https://registry.npmjs.org'
      - run: npm ci --ignore-scripts
      - run: npm publish
        # no NODE_AUTH_TOKEN — OIDC handles auth, provenance is automatic
```

Refs: https://docs.npmjs.com/trusted-publishers/, https://github.blog/changelog/2025-07-31-npm-trusted-publishing-with-oidc-is-generally-available/

## 2. Pin a third-party action to a 40-char SHA

Find the SHA from the action's release page or:

```sh
git ls-remote https://github.com/<owner>/<repo> refs/tags/v<X.Y.Z>
# or
gh api repos/<owner>/<repo>/git/refs/tags/v<X.Y.Z> --jq .object.sha
```

Then:

```yaml
# before
- uses: foo/bar@v1

# after
- uses: foo/bar@8a4e9f06c1ed62b6ab27a09f0d75cf90a8b3c46b  # v1.2.3
```

GitHub now supports org-level policy to require SHA pinning (announced 2025-08-15). Recommend enabling it in the report's next-steps line.

## 3. Pass attacker-controlled fields safely

```yaml
# before — vulnerable
- run: echo "PR title is ${{ github.event.pull_request.title }}"

# after — quoted env var
- env:
    TITLE: ${{ github.event.pull_request.title }}
  run: echo "PR title is $TITLE"
```

The env-var indirection prevents the field's value from becoming shell syntax. Always double-quote the variable expansion. For multi-line input, use `<<<` heredoc and never `eval`.

For complex needs, use `actions/github-script` with the field passed as a JS argument:

```yaml
- uses: actions/github-script@<sha>  # vN
  with:
    script: |
      const title = context.payload.pull_request.title
      // ... use `title` as a string
```

## 4. Add least-privilege `permissions:`

Top of every workflow:

```yaml
permissions:
  contents: read
```

Escalate per-job only:

```yaml
jobs:
  publish:
    permissions:
      contents: read
      id-token: write
      packages: write   # only if also publishing to GitHub Packages
```

Refs: https://docs.github.com/en/actions/reference/security/secure-use

## 5. Disable install scripts in CI

```sh
npm ci --ignore-scripts
pnpm install --ignore-scripts
yarn install --ignore-scripts
bun install --ignore-scripts
```

Or set in `.npmrc` at repo root:

```
ignore-scripts=true
```

For packages that legitimately need install scripts, allowlist them with `lavamoat/allow-scripts` or pnpm's `onlyBuiltDependencies` in `package.json`.

## 6. Move from `pull_request_target` to a safe split

The "artifact hand-off" pattern: low-privilege `pull_request` job builds an artifact; privileged `workflow_run` job processes it with explicit author/PR checks.

```yaml
# .github/workflows/pr-build.yml
on: pull_request
permissions:
  contents: read
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@<sha>
      - run: npm ci --ignore-scripts
      - run: npm run build
      - uses: actions/upload-artifact@<sha>
        with: { name: build-output, path: dist/ }
```

```yaml
# .github/workflows/pr-process.yml
on:
  workflow_run:
    workflows: [pr-build]
    types: [completed]
permissions:
  contents: read
  pull-requests: write
jobs:
  process:
    if: github.event.workflow_run.conclusion == 'success'
    runs-on: ubuntu-latest
    steps:
      # download artifact, comment on PR with results, etc.
```

Refs: https://securitylab.github.com/resources/github-actions-preventing-pwn-requests/

## 7. Isolate cache scope across trust boundaries

If a PR workflow and a release workflow both use `actions/cache`, give them disjoint `key:` prefixes so a PR cannot poison the release cache:

```yaml
# pull_request workflow
- uses: actions/cache@<sha>
  with:
    key: pr-${{ runner.os }}-${{ hashFiles('**/pnpm-lock.yaml') }}
    restore-keys: pr-${{ runner.os }}-

# release workflow
- uses: actions/cache@<sha>
  with:
    key: release-${{ runner.os }}-${{ hashFiles('**/pnpm-lock.yaml') }}
    restore-keys: release-${{ runner.os }}-
```

For very-high-trust workflows (publishing), prefer skipping the cache entirely and rebuilding from `pnpm-lock.yaml` — the time cost is small relative to the supply-chain risk. TanStack postmortem: https://tanstack.com/blog/npm-supply-chain-compromise-postmortem.

## 8. Disable credential persistence on checkout

```yaml
- uses: actions/checkout@<sha>  # v6+, or any pinned version
  with:
    persist-credentials: false
```

`actions/checkout@v6` flipped the default; older pinned versions still need the explicit setting. Also avoid `actions/upload-artifact` with `path: .` — upload only `dist/` (or the specific output directory).

## 9. Gate `issue_comment` / `workflow_run` on actor authorization

```yaml
on:
  issue_comment:
    types: [created]

jobs:
  triage:
    if: |
      github.event.comment.author_association == 'OWNER' ||
      github.event.comment.author_association == 'MEMBER' ||
      github.event.comment.author_association == 'COLLABORATOR'
    runs-on: ubuntu-latest
    steps: # ...
```

Never use a username allowlist — accounts can be renamed, deleted, or impersonated by a similar handle.

## 10. Wire `zizmor` into CI

```yaml
# .github/workflows/zizmor.yml
on:
  push: { branches: [main] }
  pull_request:
  schedule: [{ cron: '0 12 * * 1' }]
permissions:
  contents: read
  security-events: write
jobs:
  zizmor:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@<sha>
        with: { persist-credentials: false }
      - uses: astral-sh/setup-uv@<sha>
      - run: uvx zizmor --format sarif . > zizmor.sarif
      - uses: github/codeql-action/upload-sarif@<sha>
        with: { sarif_file: zizmor.sarif }
```

## 11. Protect `.github/workflows/` with CODEOWNERS

In `.github/CODEOWNERS`:

```
/.github/workflows/ @security-team-or-trusted-reviewer
/action.yml @security-team-or-trusted-reviewer
```

Combine with a branch protection rule on the default branch that requires CODEOWNERS review. Stops a worm with a stolen contributor token from silently adding `.github/workflows/shai-hulud-workflow.yml`.
