# Deterministic tooling integration

Static analysers for GitHub Actions are mature. Run them in parallel with the agent walk and fold the findings — they catch the obvious cases deterministically, freeing the agent for novel-variant reasoning.

## Tool selection

| Tool | What it covers | Install | Run |
|---|---|---|---|
| [`zizmor`](https://github.com/zizmorcore/zizmor) | Workflow + composite action static analysis: template injection, unpinned actions, excessive permissions, dangerous triggers, artifact hygiene. The single highest-signal tool. | `uv tool install zizmor` or `pipx install zizmor` | `zizmor --format sarif .github/workflows/` |
| [`actionlint`](https://github.com/rhysd/actionlint) | Syntactic + shellcheck for `run:` blocks. Catches glob errors, deprecated actions, expression issues. | `brew install actionlint` (macOS) or `go install github.com/rhysd/actionlint/cmd/actionlint@latest` | `actionlint -format '{{json .}}' .github/workflows/*.yml` |
| [`octoscan`](https://github.com/synacktiv/octoscan) | Synacktiv-built complementary scanner — extra reachability and source-tracking checks. | See repo README | `octoscan all .github/workflows/` |

## Operating mode

1. Probe for each tool with `command -v zizmor actionlint octoscan` in one shot.
2. For every tool that is present, run it against the workflow surface in parallel with your agent walk. Capture SARIF or JSON.
3. If a tool is missing, install it yourself when feasible. The user does not run install commands; either you install or you skip. Skip silently — do not pad the report with "X would have caught Y".
4. Fold findings:
   - Parse SARIF/JSON.
   - Map each tool finding to a location (`file:line`) and a rule ID.
   - When a tool finding and an agent finding describe the same vulnerability at the same location, merge them into one finding and list both sources.
   - When only the tool sees it, include it — but apply the same anti-noise rules (drop low-confidence style nits unless they map to a Critical/High pattern).
5. If the tool reports a category the threat model in [workflows.md](workflows.md) treats as Critical (template injection, unpinned action, dangerous trigger), prefer the tool's location and the threat model's severity.

## When to defer to tools

- Comprehensive scan of dozens of workflows where you would otherwise need to read every line.
- Confirming that a pattern you spotted is not a false positive (tool agreement = high confidence).
- Regression discipline — recommend wiring `zizmor` into CI in your report's "next steps" section.

## When tools are insufficient

The audit surface includes scripts invoked from workflows. `zizmor` and `actionlint` do not follow into `package.json` scripts, shell files, Makefile recipes — that is your job per [scripts.md](scripts.md). They also miss multi-stage / obfuscated payloads. Use them for the YAML layer; reason yourself for the rest.

## Don't run

- Any tool that opens network connections to non-localhost services. Static analysers stay local.
- Tools that require granting credentials or tokens. The audit is read-only and uses no secrets.
