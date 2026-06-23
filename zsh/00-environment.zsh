export PATH=\
$HOME/.local/bin:\
$PATH

export EDITOR=fresh   # terminal editor w/ multi-cursor — https://getfresh.dev/

# In tmux, enable mouse mode in less so the scrollwheel works in bat's pager.
# Outside tmux, terminals (e.g. Ghostty) handle alt-screen scroll natively.
if [[ -n "$TMUX" ]]; then
  export BAT_PAGER='less --RAW-CONTROL-CHARS --mouse --wheel-lines=3'
fi

# True when this shell is driven by an AI coding agent rather than a human, so
# human-only niceties (bat, htop, paging) can stay off — agents want plain,
# parseable output. AGENT/AI_AGENT is the emerging cross-tool standard
# (agentsmd/agents.md#136: Goose, Amp, Claude Code, …); the rest are per-tool
# vars for agents that haven't adopted it yet. Confirm a tool's marker with:
#   env | grep -iE 'agent|claude|codex|opencode|cursor|gemini|hermes|^pi'
_is_agent() {
  [[ -n "${AGENT-}${AI_AGENT-}" ]] && return 0
  local v
  for v in \
    CLAUDECODE \
    CURSOR_AGENT \
    GEMINI_CLI \
    CLINE_ACTIVE \
    AUGMENT_AGENT \
    OPENCODE \
    PI_CODING_AGENT \
    HERMES_SESSION_ID \
    CODEX_SANDBOX
  do
    [[ -n "${(P)v-}" ]] && return 0
  done
  return 1
}
