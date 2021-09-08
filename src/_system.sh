install_arch() {
    while true; do
        print_install_menu

        case "$choice" in
            1)
                set_cpu_package ;;
            2)
                perform_install ;;
            b)
                break ;;
            q)
                exit 0 ;;
            *)
                err "Invalid option"
                ;;
        esac
    done
}

prepare_host() {
    unavailable

    update_host_packages
    install_arch_scripts
    update_mirrorlist
}

get_cpu_value() {
    grep "$1" <<< "$cpuOutput" | cut -d':' -f2 | awk '{$1=$1;print}'
}

perform_install() {
    unavailable
    mount_subvolumes

    pacstrap /mnt base linux linux-firmware "$cpuPackage"
}

print_install_menu() {
    echo
    echo " [ 1] Set microcode package (${cpuPackage:-none})"
    echo " [ 2] Perform install"
    echo
    echo " [ b] Back to main menu"
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

set_cpu_package() {
    local cpuAnswer

    while [ -z "$cpuAnswer" ]; do
        read -rp "What type of CPU is in the target system? [none] " cpuAnswer

        case "${cpuAnswer,,}" in
            amd|intel)
                cpuPackage="${cpuAnswer,,}-ucode" ;;
            none|"")
                cpuAnswer="none"; cpuPackage="" ;;
            *)
                echo "Invalid CPU type. Enter 'AMD', 'Intel' or 'none'."
                cpuAnswer=
    esac
    done
}

install_arch_scripts() {
    # If it's a manjaro install...
    # pacman-key --populate archlinux     # May or may not need this, we'll see.

    echo "Downloading Arch install scripts..."
    pacman -Syy arch-install-scripts     # Installs packages like pacstrap, arch-chroot etc
}

update_host_packages() {
    echo "Updating host system..."
    pacman -Syyu
}

update_mirrorlist() {
    echo "Fetching filtered mirrorlist..."
    curl "https://archlinux.org/mirrorlist/?country=GB&protocol=https&ip_version=4&use_mirror_status=on" > /etc/pacman.d/mirrorlist
}
