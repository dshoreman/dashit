#!/usr/bin/env bash

set -Eeo pipefail

SCRIPT_ROOT="$(cd "$(dirname "$0")" > /dev/null 2>&1; pwd -P)"

# shellcheck source=_io.sh
source "${SCRIPT_ROOT}/_io.sh"

trap 'err "Unexpected error; aborting." && exit 1' ERR
trap 'err "Aborted by user." && exit 1' SIGINT

readonly _VERSION="0.0.0"

usage() {
    echo
    echo "Usage:"
    echo "  dashit [OPTION]"
    echo
    echo "General Options:"
    echo " -h, --help           Display this help and exit"
    echo " -v, --verbose        Enable verbose output for debugging"
    echo " -V, --version        Output version information and exit"
    echo
}

main() {
    local debug=false

    check_bash_version
    parse_opts "$@"
}

check_bash_version() {
    # shellcheck disable=SC2251
    ! getopt -T > /dev/null
    if [[ ${PIPESTATUS[0]} -ne 4 ]]; then
        echo "Enhanced getopt is not available. Aborting."
        exit 1
    fi

    if [ "${BASH_VERSINFO:-0}" -lt 4 ]; then
        echo "Your version of Bash is ${BASH_VERSION} but dashit requires at least v4."
        exit 1
    fi
}

parse_opts() {
    local -r OPTS=hv
    local -r LONG=help,verbose

    # shellcheck disable=SC2251
    ! parsed=$(getopt -o "$OPTS" -l "$LONG" -n "$0" -- "$@")
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        echo "Run 'dashit --help' for a list of options."
        exit 1
    fi
    eval set -- "${parsed}"

    while true; do
        case "$1" in
            -h|--help)
                usage && exit 0 ;;
            -v|--verbose)
                log  "Enabling debug mode"
                debug=true; shift ;;
            -V|--version)
                echo "Dashit v${_VERSION}" && exit 0 ;;
            --)
                shift; break ;;
            *)
                echo "Option '$1' should be valid but couldn't be handled."
                exit 3 ;;
        esac
    done
}

main "$@"
