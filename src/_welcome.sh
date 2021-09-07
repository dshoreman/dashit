# shellcheck source=_disk.sh
source "${SCRIPT_ROOT}/_disk.sh"

welcome_screen() {
    echo
    echo "Welcome to Dashit!"

    print_system_info
    print_menu

    case "$choice" in
        1)
            provision_disk "$@" ;;
        2)
            install_arch ;;
        q)
            exit 0
    esac
}

print_menu() {
    echo
    echo "What to do?"
    echo
    echo " [ 1] Provision disk"
    echo " [ 2] Install Arch Linux"
    echo " [ q] Quit"
    echo

    read -rn1 -p "Select option: " choice
    echo
}

print_system_info() {
    local CPU_ARCH CPU_MODEL CPU_TYPE

    process_system_info
    echo
    echo "Current System: ${CPU_TYPE} (${CPU_ARCH})"
    echo "${CPU_MODEL}"
}

process_system_info() {
    CPU_ARCH="$(lscpu | grep 'Architecture' | cut -d':' -f2)"
    CPU_TYPE="$(lscpu | grep 'Vendor ID' | cut -d':' -f2)"
    CPU_MODEL="$(lscpu | grep 'Model name' | cut -d':' -f2)"
}

install_arch() {
    unavailable
}
