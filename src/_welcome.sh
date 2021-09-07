# shellcheck source=_disk.sh
source "${SCRIPT_ROOT}/_disk.sh"
# shellcheck source=_system.sh
source "${SCRIPT_ROOT}/_system.sh"

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
            prepare_host ;;
        4)
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
    echo " [ 3] Prepare host system"
    echo " [ 4] Install Arch Linux"
    echo " [ q] Quit"
    echo

    read -rn1 -p "Select option: " choice
    echo
}
