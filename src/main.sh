#!/usr/bin/env bash

if [[ -z $_DASHIT_LOGGED_IO ]]; then
    script -c "_DASHIT_LOGGED_IO=1 $0 $*" \
        -B "${DASHIT_LOG_PATH:-/tmp/dashit.log}" \
        -T "${DASHIT_LOG_PATH:-/tmp/dashit.log}t"
    exit
fi

set -Eeo pipefail

SCRIPT_ROOT="$(cd "$(dirname "$0")" > /dev/null 2>&1; pwd -P)"

# shellcheck source=_io.sh
source "${SCRIPT_ROOT}/_io.sh"
# shellcheck source=_welcome.sh
source "${SCRIPT_ROOT}/_welcome.sh"

trap 'err "Unexpected error; aborting." && exit 1' ERR
trap 'err "Aborted by user." && exit 1' SIGINT

readonly _VERSION="0.2.1"

usage() {
    echo
    echo "Usage:"
    echo "  dashit [OPTION]"
    echo
    echo "General Options:"
    echo " -d, --device=TARGET  Target device to provision for Arch"
    echo " -D, --dry-run        Don't make any changes (implies --verbose)"
    echo " -h, --help           Display this help and exit"
    echo " -v, --verbose        Enable verbose output for debugging"
    echo " -V, --version        Output version information and exit"
    echo
}

main() {
    if [ "$EUID" -ne 0 ]; then
        err "Dashit must be run as root! Aborting."
        exit 1
    fi

    local debug=false AUTO_INSTALL=false DRY_RUN=false

    check_bash_version
    parse_opts "$@"

    while true; do
        welcome_screen "$@"
    done
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
    local -r OPTS=d:Dhv
    local -r LONG=device,dry-run,help,verbose

    # shellcheck disable=SC2251
    ! parsed=$(getopt -o "$OPTS" -l "$LONG" -n "$0" -- "$@")
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        echo "Run 'dashit --help' for a list of options."
        exit 1
    fi
    eval set -- "${parsed}"

    while true; do
        case "$1" in
            -d|--device)
                TARGET_DEVICE=${2//=}; shift 2 ;;
            -D|--dry-run)
                debug=true; DRY_RUN=true; shift ;;
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
