# Auditing scripts invoked from workflows

When a workflow step runs `pnpm run X`, `bash ./scripts/foo.sh`, `make release`, `just publish`, etc., the audit follows into the script. The script inherits the workflow's privileges — secrets in `env:`, `GITHUB_TOKEN` permissions, the runner's filesystem and network — so a vulnerability inside the script is a vulnerability of the workflow.

## Resolving script references

| Workflow snippet | Resolve to |
|---|---|
| `npm run foo` / `pnpm run foo` / `yarn foo` / `bun run foo` | `package.json` → `scripts.foo` (recurse into that command) |
| `bash ./scripts/x.sh` / `sh ./x.sh` / `./x.sh` | The file at the given path |
| `make target` | The recipe under `target:` in `Makefile` |
| `just recipe` | The recipe under `recipe:` in `justfile` |
| `task foo` | The task under `foo:` in `Taskfile.yml` (go-task) |
| `npx tsx ./scripts/x.ts` / `node ./scripts/x.js` / `bun ./x.ts` | The script file (treat as opaque if not present in the repo) |
| `python ./x.py` / `uv run ./x.py` | The script file |

Follow the chain recursively. `package.json` scripts often chain: `"build": "pnpm clean && pnpm compile && pnpm bundle"` — each sub-command resolves the same way.

## Termination — what NOT to follow

- External binaries on PATH: linters, formatters, compilers, test runners, archivers, signing tools, `gh`, `git`. Treat as opaque.
- Compiled native tools.
- Network fetches — flag as a High finding (see below), do not follow.
- Files not present in the repo — note and continue (could indicate the script writes them at runtime; flag if suspicious).

## Patterns to hunt for in scripts

### 1. Untrusted input flowing into shell commands (CRITICAL)

The workflow passes env vars or arguments into the script. If any of those originate from `github.event.*` (PR title, comment body, branch name), every shell expansion of them is potential injection.

Trace the data flow: which env vars does the workflow set? Which originate from untrusted GitHub context? Where does the script use them?

```bash
# Vulnerable if PR_TITLE comes from github.event.pull_request.title
echo "Building $PR_TITLE"     # OK — printed only
git tag "$PR_TITLE"            # vulnerable — title with backticks runs them
sh -c "echo $PR_TITLE"         # always vulnerable
```

Quoting saves only the simple cases. Shell features such as dynamic evaluation, command substitution `$( ... )` on untrusted input, and unquoted expansions in `[` / `[[` tests can all be exploited.

### 2. Secret echo / logging (HIGH — but rarely the dumb form)

Direct `echo $NPM_TOKEN`, `set -x` with secrets in the environment, `env | grep` are easy to spot and rare in real attacks. The realistic forms are:

- Secret values written to a file that is later uploaded as an artifact, committed to a branch, or sent over the network.
- Secret values printed to stdout in a step where workflow logs are public.
- Secret values base64-encoded (or double-base64, the tj-actions trick) and inserted into otherwise-innocent output.
- Secret values used as part of a URL or HTTP header to a non-`registry.npmjs.org` / non-`api.github.com` endpoint.

Trace where the secret goes, not whether `echo $SECRET` exists.

### 3. Network exfiltration paths (HIGH)

`curl`, `wget`, `nc`, `httpie`, JS `fetch`, Python `requests`, `gh api` to anywhere other than the canonical service endpoints. Especially:

- POST to `webhook.site` (Shai-Hulud C2)
- POST to Discord / Telegram / pastebin / Cloudflare Workers
- Any `*.workers.dev`, `*.ngrok-free.app`, `*.trycloudflare.com`
- Pushing to a repo named `*-migration` or `*-repository*` (Shai-Hulud / Nx s1ngularity IOC)
- Creating a public gist with content

Even outbound DNS lookups to attacker-controlled domains can leak data — but DNS-based exfil is rare and noisy, focus on HTTP first.

### 4. Filesystem reconnaissance (HIGH)

Real-world worms scan the filesystem before exfil. Look for:

- Reading `~/.npmrc`, `~/.docker/config.json`, `~/.aws/credentials`, `~/.config/gh/hosts.yml`, `~/.ssh/`, `~/.kube/`, `~/.netrc`, `~/.gitconfig`
- Running `trufflehog`, `gitleaks`, or similar secret scanners *during the script* (not as a security check — as exfil prep)
- Walking `$HOME` looking for files named `*token*`, `*secret*`, `*credentials*`, `id_rsa`, etc.
- Invoking installed AI CLIs (`claude`, `gemini`, `q`, `aider`) to identify sensitive files — the Nx s1ngularity novelty

### 5. Self-mutation of CI (CRITICAL)

The script writes to:

- `.github/workflows/*.yml` — adding or modifying workflows (Shai-Hulud persistence)
- `.git/config` — modifying remotes or hooks
- Any `~/.npmrc` write that adds an `_authToken` or `_password`

Legitimate scripts essentially never need to write to these locations.

### 6. Dynamic code generation (HIGH)

Shell dynamic-evaluation, `bash -c "$dynamic"`, `node -e "$dynamic"`, Python dynamic-evaluation, dynamic `require()` paths, base64-decoded payloads piped to a shell. xz-utils-style multi-stage payloads use exactly these constructs to keep the malicious code out of the obviously-suspicious place.

If a script decodes / decompresses / decrypts data and runs the result, that is a finding regardless of what the data "currently" contains. The audit is about *what can happen*, not what does happen on the day you read it.

### 7. Unverified network installations (HIGH)

`curl ... | bash`, `wget ... -O - | sh`, downloading a binary and `chmod +x` without checksum/signature verification.

Even when the URL points to a trusted vendor — supply-chain attacks compromise vendors. Pin to a SHA-256 verified by the script.

## After the walk

Hand control back to SKILL.md step 5.
