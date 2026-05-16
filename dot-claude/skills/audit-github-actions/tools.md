# Deterministic tooling integration

Static analysers for GitHub Actions are mature. They catch the obvious cases deterministically, freeing the agent for novel-variant reasoning. Three tools are **required** for this skill — if any is missing, install it before continuing; if installation is impossible, abort the audit and tell the user which tool is missing and how to install it.

## Required tools

| Tool | What it covers | Install | Run |
|---|---|---|---|
| [`zizmor`](https://github.com/zizmorcore/zizmor) | Workflow + composite action static analysis: template injection, unpinned actions, excessive permissions, dangerous triggers, artifact hygiene. The single highest-signal tool. | `uv tool install zizmor` or `pipx install zizmor` | `zizmor --format sarif .github/workflows/` |
| [`actionlint`](https://github.com/rhysd/actionlint) | Syntactic + shellcheck for `run:` blocks. Catches glob errors, deprecated actions, expression issues. | `brew install actionlint` (macOS) or `go install github.com/rhysd/actionlint/cmd/actionlint@latest` | `actionlint -format '{{json .}}' .github/workflows/*.yml` |
| [`pinact`](https://github.com/suzuki-shunsuke/pinact) | Verifies every `uses:` line is pinned to a 40-char SHA (`--check`) and that the SHA actually matches the version-annotation comment via the GitHub API (`--verify`). Catches force-pushed tags and pins where the SHA points at a different commit than the `# vX.Y.Z` claim. Replaces the manual `gh api repos/<owner>/<repo>/git/refs/tags/<v>` dance and the annotated-tag-dereferencing footgun. | `aqua g -i suzuki-shunsuke/pinact` or `brew install pinact` or `go install github.com/suzuki-shunsuke/pinact/v3/cmd/pinact@latest` | `pinact run --check --verify` (run from the audit root; honors `GITHUB_TOKEN` to avoid rate limits) |

## Operating mode

1. Probe for every required tool in one shot: `command -v zizmor actionlint pinact`.
2. For each missing tool, attempt installation yourself using the command in the table above. Do not ask the user. If installation fails (no `brew`/`uv`/`go`/`aqua`, network blocked, etc.), abort the audit with a one-line message naming the missing tool and the install command — do not produce a partial report.
3. Once all three are present, run them against the workflow surface in parallel with the agent walk. Capture SARIF / JSON / exit codes.
4. `pinact` is authoritative for the pin-legitimacy step (SKILL.md §3). Treat its `--verify` mismatches as High findings. Agent still owns:
   - **Owner-liveness / repojacking** probe (`curl -sI https://github.com/<owner>` — a 404 or 3xx redirect means the namespace is unclaimed or renamed, exposing future ref bumps even when the current SHA still resolves).
   - **Pins missing a version-annotation comment** — `pinact --verify` only validates `uses: owner/repo@<sha> # vX.Y.Z`. Bare `uses: owner/repo@<sha>` lines escape verification; grep for them and flag as Medium.
5. Fold findings:
   - Parse SARIF / JSON.
   - Map each tool finding to a location (`file:line`) and a rule ID.
   - When a tool finding and an agent finding describe the same vulnerability at the same location, merge them into one finding and list both sources.
   - When only the tool sees it, include it — but apply the same anti-noise rules (drop low-confidence style nits unless they map to a Critical/High pattern).
6. If a tool reports a category the threat model in [workflows.md](workflows.md) treats as Critical (template injection, unpinned action, dangerous trigger), prefer the tool's location and the threat model's severity.

## When to defer to tools

- Comprehensive scan of dozens of workflows where you would otherwise need to read every line.
- Confirming that a pattern you spotted is not a false positive (tool agreement = high confidence).
- Regression discipline — recommend wiring `zizmor` and `pinact` into CI in your report's "next steps" section.

## When tools are insufficient

The audit surface includes scripts invoked from workflows. `zizmor`, `actionlint`, and `pinact` do not follow into `package.json` scripts, shell files, Makefile recipes — that is your job per [scripts.md](scripts.md). They also miss multi-stage / obfuscated payloads. Use them for the YAML + pin-legitimacy layer; reason yourself for the rest.

## Don't run

- Any tool that opens network connections to non-localhost services other than `api.github.com` (pinact and the agent's pin checks both use that endpoint; nothing else is allowed).
- Tools that require granting credentials beyond a read-only `GITHUB_TOKEN`. The audit is read-only and uses no other secrets.
