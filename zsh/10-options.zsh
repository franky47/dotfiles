setopt autocd
setopt chase_links
setopt extended_glob
setopt complete_in_word
setopt always_to_end
setopt interactive_comments
setopt print_exit_value

autoload -U colors
colors

autoload -U zmv
alias zcp='zmv -C'
alias zln='zmv -L'
