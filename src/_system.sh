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
    echo
    echo " Preparing host"
    echo
    update_host_packages
    install_arch_scripts
    update_mirrorlist

    echo
    read -rsn1 -p "Press any key to continue..."
    echo
}

get_cpu_value() {
    grep "$1" <<< "$cpuOutput" | cut -d':' -f2 | awk '{$1=$1;print}'
}

perform_install() {
    local packages=(base linux linux-firmware)

    set_target_disk
    set_mountpoint
    mount_subvolumes

    if [ -n "$cpuPackage" ]; then
        packages+=("$cpuPackage")
    fi

    if $DRY_RUN; then
        log "pacstrap /mnt ${packages[*]}"
    else
        pacstrap /mnt "${packages[@]}"
    fi

    post_install

    echo
    echo "Install complete!"
    echo
    read -rsn1 -p "Press any key to continue..."
    echo
}

post_install() {
    set_console_font
    set_date
    set_locale
    prepare_pacman
}

set_console_font() {
    echo "Setting console font..."
    if $DRY_RUN; then
        log "setfont Lat2-Terminus16"
        log "echo \"FONT=Lat2-Terminus16\" > \'${rootMount}/etc/vconsole.conf\""
    else
        setfont Lat2-Terminus16
        echo "FONT=Lat2-Terminus16" > "${rootMount}/etc/vconsole.conf"
    fi
}

set_date() {
    echo
    echo "Setting up date/time"
    echo

    echo -n "Setting timezone to Europe/London... "
    if $DRY_RUN; then
        log "arch-chroot \"${rootMount}\" ln -sf /usr/share/zoneinfo/Europe/London /etc/localtime"
    else
        arch-chroot "${rootMount}" ln -sf /usr/share/zoneinfo/Europe/London /etc/localtime && echo "Done"
    fi

    echo -n "Enabling NTP... "
    if $DRY_RUN; then
        log "arch-chroot \"${rootMount}\" timedatectl --set-ntp true"
    else
        arch-chroot "${rootMount}" timedatectl --set-ntp true && echo "Done"
    fi

    echo -n "Generating /etc/adjtime... "
    if $DRY_RUN; then
        log "arch-chroot \"${rootMount}\" hwclock --systohc"
    else
        arch-chroot "${rootMount}" hwclock --systohc
    fi
}

set_locale() {
    echo "Setting locale..."
    if $DRY_RUN; then
        log "sed -ie 's/^#en_GB/en_GB/g' ${rootMount}/etc/locale.gen"
        log "arch-chroot \"${rootMount}\" locale-gen"
        log "echo \"LANG=en_GB.UTF-8\" > ${rootMount}/etc/locale.conf"
    else
        sed -ie 's/^#en_GB/en_GB/g' "${rootMount}/etc/locale.gen"
        arch-chroot "${rootMount}" locale-gen
        echo "LANG=en_GB.UTF-8" > "${rootMount}/etc/locale.conf"
    fi
}

prepare_pacman() {
    echo
    echo "Setting up Pacman"
    echo

    echo -n "Enabling colour and chomp progress... "
    if $DRY_RUN; then
        log "sed -ie 's/^#Color/Color\nILoveCandy/' \"${rootMount}/etc/pacman.conf\""
    else
        sed -ie 's/^#Color/Color\nILoveCandy/' "${rootMount}/etc/pacman.conf" && echo "Done"
    fi

    echo -n "Enabling parallel downloads... "
    if $DRY_RUN; then
        log "sed -ie 's/^#ParallelDownloads/ParallelDownloads/' \"${rootMount}/etc/pacman.conf\""
    else
        sed -ie 's/^#ParallelDownloads/ParallelDownloads/' "${rootMount}/etc/pacman.conf" && echo "Done"
    fi

    echo -n "Enabling multilib repository... "
    if $DRY_RUN; then
        log "sed -ie '/^#\[multilib]$/{N;s/#\[multilib]\n#/[multilib]\n/}' \"${rootMount}/etc/pacman.conf\""
    else
        sed -ie '/^#\[multilib]$/{N;s/#\[multilib]\n#/[multilib]\n/}' \
            "${rootMount}/etc/pacman.conf" && echo "Done"
    fi
}

print_install_menu() {
    tput clear
    echo
    echo " Installation menu"
    print_system_info
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
        echo
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
        log "curl \"${mirrorlistUrl}\" | sed 's/^#S/S/' > /etc/pacman.d/mirrorlist"
    else
        curl "${mirrorlistUrl}" | sed 's/^#S/S/' > /etc/pacman.d/mirrorlist
    fi
}
