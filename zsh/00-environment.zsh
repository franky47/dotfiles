export PATH=\
$HOME/.local/bin:\
$PATH

export EDITOR=fresh   # terminal editor w/ multi-cursor — https://getfresh.dev/

# In tmux, enable mouse mode in less so the scrollwheel works in bat's pager.
# Outside tmux, terminals (e.g. Ghostty) handle alt-screen scroll natively.
if [[ -n "$TMUX" ]]; then
  export BAT_PAGER='less --RAW-CONTROL-CHARS --mouse --wheel-lines=3'
fi
