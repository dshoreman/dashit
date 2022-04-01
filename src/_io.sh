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

firstboot_header() {
    cat <<EOF
#!/usr/bin/env bash
export DASHIT_USER="$4"
export DOTFILES_PATH="/home/\${DASHIT_USER}/${DASHIT_DOTFILES_DIR:-.files}"
echo; echo "##################################"
echo "##   DASHit First Boot Script   ##"
echo "###        Step: $2 of $3        ###"
echo "########### ${1^^} MODE ############"
echo
echo
EOF
}
