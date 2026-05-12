# Real-world incident library

Brief case studies. Use these when an unfamiliar workflow shape looks like a variant of a known attack — pattern-match the _kill chain_, not the specific filenames. Every Critical/High finding in your report should anchor to one of these (or an analogous public incident) so the user sees the precedent.

## Shai-Hulud v1 (2025-09-15) and v2 (2025-11-21)

**Scale.** v1 ~180-200 npm packages including `@ctrl/tinycolor` and `@crowdstrike/*`. v2 ~700-1,000 packages and 20,000-28,000+ GitHub repositories across Zapier, ENS, AsyncAPI, PostHog, Postman.

**Chain.**

1. Phish a maintainer with a fake "NPM security alert" email harvesting username + password + live TOTP.
2. Publish a malicious version with a `postinstall` (v1) or `preinstall` (v2) hook that runs before any test step.
3. Hook runs `trufflehog` on the runner filesystem, harvests `~/.npmrc`, `~/.ssh`, cloud creds (AWS / GCP / Azure / IMDS), Atlassian + Datadog API keys, environment variables.
4. Hook uses the stolen `GITHUB_TOKEN` to write `.github/workflows/shai-hulud-workflow.yml` (v1) or `discussion.yaml` (v2) into every repo it can reach. v2 also registers infected machines as self-hosted GitHub Actions runners named `SHA1HULUD` for ongoing RCE.
5. Stolen npm token enumerates the maintainer's other packages and republishes them with the same payload — true self-replication.
6. Exfil pushes data to attacker-created **public** repos named `<victim>-migration` (private repos are forcibly mirrored to public) and to `webhook.site` as double-base64 `data.json`.

**Audit anchor.** Long-lived `NPM_TOKEN`, `--ignore-scripts` absent in CI, no OIDC trusted publishing, no CODEOWNERS on `.github/workflows/`, missing branch protection.

## Nx s1ngularity (2025-08-26) — CVE-2025-10894 / GHSA-cxm3-wv7p-598c

**Scale.** Eight `@nx/*` packages plus root `nx` (4.6 M weekly downloads). 2,349 GitHub / cloud / AI credentials leaked publicly across >1,000 victim accounts.

**Chain.**

1. The Nx repo had a `pull_request_target` workflow that interpolated the **PR title** into a bash command — classic expression injection. Fix had landed on `main` but the workflow still existed on an older branch.
2. Attacker opens a PR (from any fork) with a crafted title against the vulnerable branch. Workflow runs with base-repo secrets and write `GITHUB_TOKEN`.
3. Workflow exfiltrates the npm publish token from secrets.
4. Attacker publishes malicious versions with a `postinstall` hook → `telemetry.js`.
5. Hook scans for SSH keys, npm tokens, `.gitconfig`, wallet files, env vars. **Novel:** prompts installed AI CLIs (`claude`, `gemini`, `q`) to identify sensitive files.
6. Stolen data pushed to **public** GitHub repos named `s1ngularity-repository*` under each victim's own account.

**Audit anchor.** `pull_request_target` + expression injection on PR field; stale-branch vulnerability invisible from `main`; long-lived publish token; AI-CLI reconnaissance signature.

## tj-actions/changed-files + reviewdog/action-setup (2025-03-12 to 2025-03-15) — CVE-2025-30066 / CVE-2025-30154

**Scale.** `tj-actions/changed-files` used by >23,000 repositories.

**Chain.**

1. Origin: `reviewdog/action-setup` `v1` tag force-moved to a malicious commit on 2025-03-11.
2. Transitive dependency chain: `reviewdog/action-setup` → `tj-actions/eslint-changed-files` → `tj-actions/changed-files`.
3. Tag mutability — consumers pinned to `@v35`, `@v44`, etc. silently rolled forward.
4. Malicious code dumped runner memory looking for secrets and printed them, **double-base64 encoded**, into the workflow log. On public repos those logs are world-readable.
5. Investigators concluded Coinbase was the original target; opportunistic expansion to all consumers.

**Audit anchor.** Unpinned third-party actions, public workflow logs as exfil channel, transitive supply-chain compromise.

## TanStack "Mini Shai-Hulud" (2026-05-11)

**Scale.** 84 malicious versions across 42 `@tanstack/*` packages.

**Chain.** (Source: https://tanstack.com/blog/npm-supply-chain-compromise-postmortem)

1. The `bundle-size.yml` workflow ran on `pull_request_target` and shared a pnpm-store cache key (`Linux-pnpm-store-${hashFiles('**/pnpm-lock.yaml')}`) with `release.yml`, the production publish workflow.
2. The attacker forked the repo and opened PR #7378 with a ~30,000-line obfuscated payload at `packages/history/vite_setup.mjs`. Because the trigger was `pull_request_target`, the workflow ran in the _base_ repo's cache scope.
3. The payload executed during the PR build and wrote poisoned data into the pnpm store under the exact cache key `release.yml` would restore from.
4. Critically, `permissions: contents: read` on the PR workflow did **not** block the cache write — `actions/cache` uses a runner-internal token outside the workflow's `permissions:` model.
5. On the next push to `main`, `release.yml` restored the poisoned pnpm store. The injected binaries ran with `id-token: write` set.
6. The malware read `/proc/<pid>/maps` and `/proc/<pid>/mem` of the runner worker to extract the OIDC token that the runner mints lazily in memory for npm trusted publishing.
7. With the stolen OIDC token, the attacker posted directly to the npm registry, bypassing the workflow's legitimate publish step. 42 packages, 84 versions.

**Audit anchor.** Shared cache scope across trust boundaries; OIDC tokens in privileged workflows are crown-jewels extractable from process memory; `permissions: contents: read` is not a cache write boundary. For very-high-trust publish workflows, skip caching entirely.

## qix / chalk / debug (2025-09-08)

**Scale.** 18+ packages including `chalk`, `debug`, `strip-ansi`, `color-convert`, `wrap-ansi`, `ansi-styles`. Billions of weekly downloads.

**Chain.**

1. Phishing email from spoofed domain `npmjs.help` requested 2FA reset.
2. Maintainer entered username + password + live TOTP — token-relay phishing.
3. Malicious version published with a browser-only crypto-wallet drainer (intercepted `window.ethereum` / `web3`).
4. Did not touch filesystem or CI — limited blast radius. Reverted in ~2 hours.

**Audit anchor.** Single-maintainer foundational packages are SPOFs; hardware-key WebAuthn cannot be phished by TOTP-relay; npm "2FA Only" package setting rejects token-based publishes.
