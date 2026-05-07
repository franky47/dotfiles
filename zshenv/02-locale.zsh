# macOS leaves LANG empty in non-interactive ssh sessions, leaking
# LC_CTYPE=UTF-8 with no language. mosh-server rejects that and refuses
# to start. Set a real UTF-8 locale here (zshenv runs for every shell,
# including the non-interactive one ssh launches mosh-server in).
export LANG=en_GB.UTF-8
