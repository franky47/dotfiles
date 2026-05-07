# `brew bundle` upgrades outdated formulae by default. Skip that — on
# older macOS (e.g. echo) bottle misses trigger long source builds for
# Rust/C++ formulae like uv. Pass `--upgrade` explicitly when wanted, or
# run `brew upgrade <formula>` directly.
export HOMEBREW_BUNDLE_NO_UPGRADE=1
