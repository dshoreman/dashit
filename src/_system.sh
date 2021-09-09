install_arch() {
    while true; do
        print_install_menu

        case "$choice" in
            1)
                set_cpu_package ;;
            2)
                perform_install
                break ;;
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
    update_host_packages
    install_arch_scripts
    update_mirrorlist
}

get_cpu_value() {
    grep "$1" <<< "$cpuOutput" | cut -d':' -f2 | awk '{$1=$1;print}'
}

perform_install() {
    mount_subvolumes

    if $DRY_RUN; then
        log "pacstrap /mnt base linux linux-firmware \"$cpuPackage\""
    else
        pacstrap /mnt base linux linux-firmware "$cpuPackage"
    fi
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
    echo
    echo -e "Dry run: $($DRY_RUN && echo -e "\e[1;32menabled" || echo -e "\e[1;31mdisabled")\e[0m"
}

process_system_info() {
    local cpuOutput
    cpuOutput="$(lscpu)"

    architecture="$(get_cpu_value 'Architecture')"
    cpuModel="$(get_cpu_value 'Model name')"
    cpuType="$(get_cpu_value 'Vendor ID')"
}

set_cpu_package() {
    local cpuAnswer selected="${cpuPackage:-none}"
    selected="${selected%%-*}"

    while [ -z "$cpuAnswer" ]; do
        read -rp "What type of CPU is in the target system? [${selected}] " cpuAnswer
        cpuAnswer="${cpuAnswer:-$selected}"

        case "${cpuAnswer,,}" in
            amd|intel)
                cpuPackage="${cpuAnswer,,}-ucode" ;;
            none|"")
                cpuPackage="" ;;
            *)
                err "Invalid CPU type '${cpuAnswer,,}'. Enter 'AMD', 'Intel' or 'none'."
                cpuAnswer=
    esac
    done
}

install_arch_scripts() {
    # If it's a manjaro install...
    # pacman-key --populate archlinux     # May or may not need this, we'll see.

    echo "Downloading Arch install scripts..."
    if $DRY_RUN; then
        log "pacman -Syy arch-install-scripts"
    else
        pacman -Syy arch-install-scripts     # Installs packages like pacstrap, arch-chroot etc
    fi
}

update_host_packages() {
    echo "Updating host system..."
    if $DRY_RUN; then
        log "pacman -Syyu"
    else
        pacman -Syyu
    fi
}

update_mirrorlist() {
    local filters="country=GB&protocol=https&ip_version=4&use_mirror_status=on"
    local mirrorlistUrl="https://archlinux.org/mirrorlist/?${filters}"

    echo "Fetching filtered mirrorlist..."
    if $DRY_RUN; then
        log "curl \"${mirrorlistUrl}\" > /etc/pacman.d/mirrorlist"
    else
        curl "${mirrorlistUrl}" > /etc/pacman.d/mirrorlist
    fi
}
