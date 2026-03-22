function dll() {
    docker container ls -a
    echo
    docker volume ls
    echo
    docker network ls
    echo
    docker image ls
}

function drm() {
    echo -n "Containers: "
    docker container prune -f
    echo -n "Images:     "
    docker image prune -f
    echo -n "Volumes:    "
    docker volume prune -f
    docker network prune -f
}

alias dirm='docker image rm'
alias dcu='docker compose up -d'
alias dcd='docker compose down'
alias dcl='docker compose logs'
