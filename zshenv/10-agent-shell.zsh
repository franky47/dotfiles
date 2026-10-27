if [[ ! -o interactive && -n $ZSH_EXECUTION_STRING && ( -n $CLAUDECODE || -n $CODEX_THREAD_ID ) ]]; then
  setopt sh_word_split no_nomatch no_equals
fi
