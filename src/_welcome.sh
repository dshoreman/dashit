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
            provision_partition "$@" ;;
        3)
            install_arch ;;
        q)
            exit 0
    esac
}

print_menu() {
    echo
    echo "What to do?"
    echo
    echo " [ 1] Partition and format disk"
    echo " [ 2] Create btrfs subvolumes"
    echo " [ 3] Install Arch Linux"
    echo " [ q] Quit"
    echo

    read -rn1 -p "Select option: " choice
    echo
}

print_system_info() {
    local architecture cpuModel cpuType

    process_system_info
    echo
    echo "Current System: ${cpuType} (${architecture})"
    echo "${cpuModel}"
}

process_system_info() {
    local cpuOutput
    cpuOutput="$(lscpu)"

    architecture="$(get_cpu_value 'Architecture')"
    cpuModel="$(get_cpu_value 'Model name')"
    cpuType="$(get_cpu_value 'Vendor ID')"
}

get_cpu_value() {
    grep "$1" <<< "$cpuOutput" | cut -d':' -f2 | awk '{$1=$1;print}'
}

install_arch() {
    unavailable
}
