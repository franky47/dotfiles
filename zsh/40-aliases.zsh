alias ls='ls -F'
alias ll='ls -hlaGF $1'
alias rmds="find . -name '*.DS_Store' -type f -delete"
# bat for humans; plain cat for agents (its pager/decorations hurt parsing).
_is_agent || alias cat='bat'
alias top='htop'
# Plain alias on purpose: quitting yazi keeps the shell where it started.
# For cd-on-exit instead, use yazi's shell-wrapper `y()`: https://yazi-rs.github.io/docs/quick-start#shell-wrapper
alias y='yazi'
alias flushdns='sudo killall -HUP mDNSResponder'
alias lns='ln -s'
alias python='python3'
alias brewup='brew update && brew upgrade'

# Playwright
alias pw='playwright'
alias pwt='playwright test'
alias pwtu='playwright test --ui'


# Security - Socket firewall
export SFW_SILENT=true

sfw() {
  # sfw's proxy only speaks CONNECT and 405s plain-HTTP/WS loopback traffic,
  # breaking test suites that spin up local servers (SocketDev/sfw-free#49).
  # Exempting loopback loses nothing: registry traffic is never loopback.
  local -x NO_PROXY="localhost,127.0.0.1,::1${NO_PROXY:+,$NO_PROXY}"
  local -x no_proxy="$NO_PROXY"
  local ts="$(date +%Y-%m-%d_%H-%M-%S)-$$-$RANDOM"
  local tmp_dir="${TMPDIR%/}/sfw"
  local keep_dir="$HOME/.cache/sfw"
  local report="$tmp_dir/${ts}.json"
  mkdir -p "$tmp_dir"
  local code
  if [[ -t 1 ]]; then
    SFW_JSON_REPORT_PATH="$report" command sfw "$@"
    code=$?
  else
    SFW_JSON_REPORT_PATH="$report" command sfw "$@" \
      > >(grep --line-buffered -v "^sfw report written to: ")
    code=$?
  fi
  if [[ $code -ne 0 && -f "$report" ]]; then
    mkdir -p "$keep_dir"
    mv "$report" "$keep_dir/"
    echo "[Socket Firewall] report saved at $keep_dir/${ts}.json" >&2
  fi
  return $code
}

alias bun='sfw bun'
alias bunx='sfw bunx'
alias npm='sfw npm'
alias npx='sfw npx'
alias pnpm='sfw pnpm'
alias pnpx='sfw pnpx'
alias pn='sfw pn'
alias pnx='sfw pnx'
alias yarn='sfw yarn'
alias cargo='sfw cargo'
alias pip='sfw pip'
alias pipx='sfw pipx'
alias uv='sfw uv'