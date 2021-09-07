err() {
    echo -e " \n\e[1;31m[ERROR]\e[21m ${*}\e[0m" >&2
}

log() {
    if [[ ${debug:=} = true ]]; then
        echo -e " \e[1;33m[DEBUG]\e[0m ${*}" >&2
    fi
}

unavailable() {
    err "This option is currently unavailable"
    exit 2
}
