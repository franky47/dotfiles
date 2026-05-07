# echo is Intel macOS → brew prefix /usr/local. Non-interactive ssh does
# not have /usr/local/bin on PATH, so mosh-server must be addressed by
# absolute path via --server.
alias mosh-echo='mosh --server=/usr/local/bin/mosh-server echo'
