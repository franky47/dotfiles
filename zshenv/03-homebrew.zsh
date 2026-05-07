# Non-interactive ssh shells skip /etc/zprofile (where path_helper
# normally adds Homebrew bin dirs), so commands like mosh-server end up
# off PATH and remote invocation fails. Prepend both prefixes here so
# login-vs-non-login parity is maintained — non-existent dirs on a given
# machine are harmless.
typeset -U path
path=(/opt/homebrew/bin /usr/local/bin $path)
export PATH

# `brew bundle` upgrades outdated formulae by default. Skip that — on
# older macOS (e.g. echo) bottle misses trigger long source builds for
# Rust/C++ formulae like uv. Pass `--upgrade` explicitly when wanted, or
# run `brew upgrade <formula>` directly.
export HOMEBREW_BUNDLE_NO_UPGRADE=1
