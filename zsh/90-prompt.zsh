setopt promptsubst

prompt_vcs_sep() {
    git rev-parse --abbrev-ref HEAD 2> /dev/null | awk '{print " - "}'
}

prompt_vcs_branch() {
    git rev-parse --abbrev-ref HEAD 2> /dev/null | awk '{print $1}'
}

prompt_vcs_status() {
    git status --porcelain 2> /dev/null | awk '

        function red(str, cnt) {
            if (cnt) printf "\033[1;31m" cnt str "\033[0m "
        }
        function green(str, cnt) {
            if (cnt) printf "\033[1;32m" cnt str "\033[0m "
        }
        function yellow(str, cnt) {
            if (cnt) printf "\033[1;33m" cnt str "\033[0m "
        }
        function blue(str, cnt) {
            if (cnt) printf "\033[1;34m" cnt str "\033[0m "
        }
        function magenta(str, cnt) {
            if (cnt) printf "\033[1;35m" cnt str "\033[0m "
        }
        function cyan(str, cnt) {
            if (cnt) printf "\033[1;36m" cnt str "\033[0m "
        }

        $1 == "??" { u++ } # Untracked
        $1 == "A" { a++ } # Added
        $1 == "M" { m++ } # Modified
        $1 == "D" { d++ } # Deleted (from tracking)
        END   {
            printf yellow("~", m), green("+", a), red("-", d), magenta("?", u)
        }
    '
}

prompt_host="%{$fg[green]%}%n@%M%{$reset_color%}"
prompt_date="%{$fg[blue]%}%D %*%{$reset_color%}"
prompt_dollar="%{$fg[red]%}$ %{$reset_color%}"
prompt_path="%{$fg[magenta]%}%25<...<%~%<<%f%{$reset_color%}"

PROMPT=$'\n${prompt_host} - ${prompt_date}$(prompt_vcs_sep)%{$fg[cyan]%}$(prompt_vcs_branch)%{$reset_color%} $(prompt_vcs_status)\n${prompt_dollar}'
export RPROMPT="${prompt_path}"
