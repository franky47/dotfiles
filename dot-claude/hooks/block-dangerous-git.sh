#!/bin/bash
# PreToolUse hook (matcher: Bash). Hard-blocks destructive git operations that
# irreversibly discard local work: reset --hard, clean -f, branch -D,
# checkout ., restore . . `git push` is intentionally NOT blocked.
#
# Mechanism: exit 2 (+ stderr) is the only block that pre-empts permission-rule
# evaluation, so it holds under defaultMode=bypassPermissions and cannot be
# overridden by the `allow` rules for git in settings.json. exit 0 = no opinion.
#
# Matching is tokenized, not substring. The old version grep'd the raw string
# for "git reset --hard" etc., which:
#   - false-NEGATIVE'd on anything that split `git` from its subcommand
#     (`git -C <path> reset --hard`, `git -c k=v ...`, `GIT_DIR=... git ...`,
#      a dangerous op after `&&`/`;`/`|`/newline or inside `$(...)`), and
#   - false-POSITIVE'd on benign mentions (`git log --grep="reset --hard"`,
#     `git commit -m "... reset --hard ..."`).
# The awk pass below splits the command into shell segments (honoring quotes so
# separators inside a quoted commit message do not split), strips env-var
# prefixes and command wrappers, skips git's global options to find the real
# subcommand, then matches the subcommand + its flags.
#
# Threat model is an inattentive agent, not an adversary. Accepted residual
# gaps an agent essentially never emits: deeply nested quote+substitution
# (e.g. "$(git reset --hard)"), git long-option abbreviation (--ha for --hard),
# and wrappers that take positional args (timeout 5 git …). The user's own
# `! git …` prompt prefix never reaches this hook and is the deliberate escape
# hatch.

INPUT=$(cat)
TOOL=$(printf '%s' "$INPUT" | jq -r '.tool_name // "Bash"')
[ "$TOOL" = "Bash" ] || exit 0
COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')
[ -n "$COMMAND" ] || exit 0

printf '%s' "$COMMAND" | awk '
  { full = full $0 "\n" }

  function basename(s) { sub(/^\\/, "", s); sub(/.*\//, "", s); return s }

  # Inspect one shell segment (held in seg[1..nw]); exit 2 if it is a
  # blocked git invocation.
  function flush(   j, t, b, sub_cmd, k, a, hasDelete, hasForce, hasDot, staged, worktree) {
    if (nw == 0) return

    j = 1
    # Strip leading env-var assignments and transparent command wrappers so
    # `GIT_DIR=… git …`, `env git …`, `command git …`, `sudo git …` resolve.
    while (j <= nw) {
      t = seg[j]
      if (t ~ /^[A-Za-z_][A-Za-z0-9_]*=/) { j++; continue }
      b = basename(t)
      if (b=="command"||b=="builtin"||b=="env"||b=="sudo"||b=="nohup"||b=="nice"||b=="exec"||b=="time") { j++; continue }
      break
    }
    if (j > nw || basename(seg[j]) != "git") return
    j++

    # Skip git global options to reach the subcommand. Value-taking options
    # consume their argument; any other leading-dash token is a boolean global
    # option; the first non-dash token is the subcommand.
    while (j <= nw) {
      t = seg[j]
      if (t ~ /^--[a-z][a-z-]*=/) { j++; continue }
      if (t=="-C"||t=="-c"||t=="--git-dir"||t=="--work-tree"||t=="--namespace"||t=="--exec-path"||t=="--super-prefix"||t=="--config-env") { j += 2; continue }
      if (t ~ /^-/) { j++; continue }
      break
    }
    if (j > nw) return
    sub_cmd = seg[j]

    if (sub_cmd == "reset") {
      for (k = j+1; k <= nw; k++) if (seg[k] == "--hard") block("git reset --hard")
    } else if (sub_cmd == "clean") {
      for (k = j+1; k <= nw; k++) {
        if (seg[k] == "--force") block("git clean --force")
        if (seg[k] ~ /^-[a-zA-Z]*f/) block("git clean -f")
      }
    } else if (sub_cmd == "branch") {
      hasDelete = 0; hasForce = 0
      for (k = j+1; k <= nw; k++) {
        a = seg[k]
        if (a ~ /^-[a-zA-Z]*D/) block("git branch -D")
        if (a == "--delete" || a ~ /^-[a-zA-Z]*d/) hasDelete = 1
        if (a == "--force" || a ~ /^-[a-zA-Z]*f/) hasForce = 1
      }
      if (hasDelete && hasForce) block("git branch --delete --force")
    } else if (sub_cmd == "checkout") {
      for (k = j+1; k <= nw; k++) if (seg[k] == "." || seg[k] == "./") block("git checkout .")
    } else if (sub_cmd == "restore") {
      hasDot = 0; staged = 0; worktree = 0
      for (k = j+1; k <= nw; k++) {
        a = seg[k]
        if (a == "." || a == "./") hasDot = 1
        if (a == "--staged" || a == "-S") staged = 1
        if (a == "--worktree" || a == "-W") worktree = 1
      }
      # --staged alone only unstages (worktree preserved) — that is safe.
      if (hasDot && (worktree || !staged)) block("git restore .")
    }
  }

  function block(what) {
    printf "BLOCKED: %s discards local work and is disabled by a safety hook. The user has prevented you from doing this; if it is genuinely intended, ask them to run it themselves via `! <command>`.\n", what > "/dev/stderr"
    exit 2
  }

  function endword() { if (w != "") { seg[++nw] = w; w = "" } }
  function sep() { endword(); flush(); nw = 0; delete seg }

  END {
    SQ = "\047"; DQ = "\042"; BT = "\140"
    w = ""; nw = 0; inS = 0; inD = 0
    n = length(full)
    for (i = 1; i <= n; i++) {
      c = substr(full, i, 1)
      if (inS) { if (c == SQ) inS = 0; else w = w c; continue }
      if (inD) {
        if (c == "\\") { nc = substr(full, i+1, 1); i++; if (nc != "\n") w = w nc; continue }
        if (c == DQ) { inD = 0; continue }
        w = w c; continue
      }
      if (c == SQ) { inS = 1; continue }
      if (c == DQ) { inD = 1; continue }
      if (c == "\\") { nc = substr(full, i+1, 1); i++; if (nc != "\n") w = w nc; continue }
      if (c == "$" && substr(full, i+1, 1) == "(") { sep(); i++; continue }
      if (c == BT || c == "(" || c == ")" || c == ";" || c == "&" || c == "|" || c == "\n" || c == "{" || c == "}") { sep(); continue }
      if (c == " " || c == "\t") { endword(); continue }
      w = w c
    }
    sep()
  }
'
