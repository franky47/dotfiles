export PATH=\
./.bin:\
./node_modules/.bin:\
$HOME/.npm-packages/bin:\
$HOME/.yarn/bin:\
$HOME/.config/yarn/global/node_modules/.bin:\
$HOME/.local/bin:\
$HOME/.meteor:\
$PATH

export EDITOR=nano

# In tmux, enable mouse mode in less so the scrollwheel works in bat's pager.
# Outside tmux, terminals (e.g. Ghostty) handle alt-screen scroll natively.
if [[ -n "$TMUX" ]]; then
  export BAT_PAGER='less --RAW-CONTROL-CHARS --mouse --wheel-lines=3'
fi
