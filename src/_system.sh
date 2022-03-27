install_arch() {
    while true; do
        print_install_menu

        case "$choice" in
            1)
                set_cpu_package ;;
            2)
                set_hostname ;;
            3)
                set_username ;;
            4)
                set_initramfs_package ;;
            i)
                check_root_pass
                perform_install
                break ;;
            I)
                AUTO_INSTALL=true
                check_root_pass
                provision_disk
                provision_partition
                prepare_host
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
    $AUTO_INSTALL || read -rsn1 -p $'Press any key to continue...\n'
}

get_cpu_value() {
    grep "$1" <<< "$cpuOutput" | cut -d':' -f2 | awk '{$1=$1;print}'
}

perform_install() {
    local packages=(base linux man-db man-pages polkit sudo)
    grep -q hypervisor /proc/cpuinfo || packages+=(linux-firmware)
    packages+=(base-devel dhcpcd git refind reflector zsh)

    set_target_disk
    set_mountpoint
    mount_subvolumes

    if [ -n "$cpuPackage" ]; then
        packages+=("$cpuPackage")
    fi

    if [ -n "$initramfsPackage" ]; then
        packages+=("$initramfsPackage")
    fi

    if [ -n "$DASHIT_ENVIRONMENTS" ]; then
        for env_name in ${DASHIT_ENVIRONMENTS//,/ }; do case $env_name in
            i3) packages+=(i3-gaps dunst redshift rofi xorg-server xorg-xinit xorg-xinput) ;;
            kde) packages+=(plasma-meta plasma-wayland-session) ;;
            kde-full) packages+=(pasma-meta plasma-wayland-session kde-applications-meta) ;;
            kde-minimal) packages+=(plasma-desktop plasma-wayland-session) ;;
            sway) packages+=(sway bemenu-wayland dunst waybar) ;;
            *) err "Unsupported environemnt '${env_name}'"
        esac; done
    fi
    if [ -n "$DASHIT_TERMINALS" ]; then
        for termpkg in ${DASHIT_TERMINALS//,/ }; do case $termpkg in
            alacritty) packages+=(alacritty) ;;
            crt|coolretro|cool-retro-term) packages+=(cool-retro-term) ;;
            deepin) packages+=(deepin-terminal) ;;
            foot) packages+=(foot) ;;
            kitty) packages+=(kitty) ;;
            konsole) packages+=(konsole) ;;
            liri) packages+=(liri-terminal) ;;
            qterm|qterminal) packages+=(qterminal) ;;
            station) packages+=(maui-station) ;;
            terminology) packages+=(terminology) ;;
            urxvt|rxvt-unicode) packages+=(rxvt-unicode) ;;
            xterm) packages+=(xterm) ;;
            zutty) packages+=(zutty) ;;
            deepin-gtk) packages+=(deepin-terminal-gtk) ;;
            gnome) packages+=(gnome-terminal) ;;
            lxt|lxterm|lxterminal) packages+=(lxterminal) ;;
            mate) packages+=(mate-terminal) ;;
            pantheon) packages+=(pantheon-terminal) ;;
            sakura) packages+=(sakura) ;;
            terminator) packages+=(terminator) ;;
            termite) packages+=(termite termite-terminfo) ;;
            tilix) packages+=(tilix) ;;
            xfce) packages+=(xfce4-terminal) ;;
            *) err "Unsupported terminal '${termpkg}'"
        esac; done
    fi

    if $DRY_RUN; then
        log "pacstrap /mnt ${packages[*]}"
    else
        # Sometimes 1 or 2 packages fail to download, but work second time
        pacstrap /mnt "${packages[@]}" || pacstrap /mnt "${packages[@]}"
    fi

    post_install
    isInstalled=1

    echo
    echo "Install complete!"
    echo
    read -rsn1 -p $'Press any key to continue...\n'
}

post_install() {
    generate_fstab
    set_console_font
    set_date
    set_locale
    set_network
    set_shell
    create_user
    set_root
    prepare_pacman
    install_refind
}

generate_fstab() {
    echo
    echo -n "Generating fstab..."
    if $DRY_RUN; then
        log "genfstab -U \"${rootMount}\" >> \"${rootMount}/etc/fstab\""
    else
        genfstab -U "${rootMount}" >> "${rootMount}/etc/fstab" && echo "Done"
    fi
}

set_console_font() {
    echo -n "Setting console font..."
    if $DRY_RUN; then
        log "setfont Lat2-Terminus16"
        log "echo \"FONT=Lat2-Terminus16\" > \"${rootMount}/etc/vconsole.conf\""
    else
        setfont Lat2-Terminus16
        echo "FONT=Lat2-Terminus16" > "${rootMount}/etc/vconsole.conf" && echo "Done"
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
        log "arch-chroot \"${rootMount}\" timedatectl set-ntp true"
    else
        arch-chroot "${rootMount}" timedatectl set-ntp true && echo "Done"
    fi

    echo -n "Generating /etc/adjtime... "
    if $DRY_RUN; then
        log "arch-chroot \"${rootMount}\" hwclock --systohc"
    else
        arch-chroot "${rootMount}" hwclock --systohc && echo "Done"
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

set_network() {
    echo
    echo "Setting up network options"
    echo

    echo -n "Setting hostname... "
    if [ -z "${systemHostname}" ]; then
        log "Skipping, hostname isn't set"
    elif $DRY_RUN; then
        log "echo \"${systemHostname}\" > \"${rootMount}/etc/hostname\""
    else
        echo "${systemHostname}" > "${rootMount}/etc/hostname" && echo "Done"
    fi

    echo "Enabling DHCP..."
    if $DRY_RUN; then
        log "arch-chroot \"${rootMount}\" systemctl enable dhcpcd.service"
    else
        arch-chroot "${rootMount}" systemctl enable dhcpcd.service && echo "Done"
    fi
}

set_shell() {
    echo
    echo "Shell setup"
    echo

    echo -n "Setting default shell to zsh... "
    if $DRY_RUN; then
        log "sed -ie 's@^SHELL=/bin/bash\$@SHELL=/bin/zsh@' \"${rootMount}/etc/default/useradd\""
    else
        sed -ie 's@^SHELL=/bin/bash$@SHELL=/bin/zsh@' "${rootMount}/etc/default/useradd" && echo "Done"
    fi

    echo -n "Removing redundant .bash files from user skeleton... "
    if $DRY_RUN; then
        log "rm \"${rootMount}\"/etc/skel/.bash*"
    else
        rm "${rootMount}"/etc/skel/.bash* && echo "Done"
    fi
}

create_user() {
    local groups="users,adm,games,uucp,systemd-journal,wheel"

    echo
    echo "Creating user account"
    echo

    echo -n "Creating new user... "
    if $DRY_RUN; then
        log "arch-chroot \"${rootMount}\" useradd -mUG $groups \"${systemUser}\""
    else
        arch-chroot "${rootMount}" useradd -mUG $groups "${systemUser}" && echo "Done"
    fi

    echo -n "Cloning dotfiles... "
    branch="${DASHIT_DOTFILES_BRANCH:-master}"
    clonePath="/home/${systemUser}/${DASHIT_DOTFILES_DIR:-.files}"
    if [[ -n $DASHIT_DOTFILES_REPO ]] && $DRY_RUN; then
        log "arch-chroot \"${rootMount}\" git clone -b \"${branch}\" \"${DASHIT_DOTFILES_REPO}\" \"${clonePath}\""
        log "arch-chroot \"${rootMount}\" chown -R \"${systemUser}\":\"${systemUser}\" \"${clonePath}\""
    elif [[ -n $DASHIT_DOTFILES_REPO ]]; then
        arch-chroot "$rootMount" git clone -b "$branch" "$DASHIT_DOTFILES_REPO" "$clonePath" \
            && arch-chroot "$rootMount" chown -R "${systemUser}":"${systemUser}" "$clonePath" \
            && echo "Done"
    else
        echo "Skipped!"
    fi

    echo -n "Adding ${systemUser} to sudoers... "
    if $DRY_RUN; then
        log "echo \"${systemUser} ALL=(ALL) ALL\" > \"${rootMount}/etc/sudoers.d/${systemUser}\""
    else
        echo "${systemUser} ALL=(ALL) ALL" > "${rootMount}/etc/sudoers.d/${systemUser}" && echo "Done"
    fi

    echo "Forcing password reset for ${systemUser}... "
    if $DRY_RUN; then
        log "arch-chroot \"${rootMount}\" passwd -qde \"${systemUser}\""
    else
        arch-chroot "${rootMount}" passwd -qde "${systemUser}" && echo "Done"
    fi
}

check_root_pass() {
    local should_set_root

    getent shadow root | grep -q '^root::' || return 0

    echo
    err "Missing root password!"
    echo
    echo "  Root's password will be copied from the host machine,"
    echo "   but the root account currently has no password set."
    echo

    while true; do
        read -rn1 -p "  Set root password now? [Yn] " should_set_root
        echo

        case "$should_set_root" in
            y|"")
                # Only break from loop on success to allow n chances
                echo; passwd && break ;;
            n)
                echo "Continuing without root password..."
                break ;;
            *)
                err "Invalid option" ;;
        esac
    done
}

set_root() {
    echo
    echo "Setting root password"
    echo

    if $DRY_RUN; then
        log "systemd-firstboot --root \"${rootMount}\" --copy-root-password --copy-root-shell --force"
    else
        systemd-firstboot \
            --root "${rootMount}" \
            --copy-root-password \
            --copy-root-shell \
            --force && echo "Done"
    fi
}

prepare_pacman() {
    local pacmanconf="${rootMount}/etc/pacman.conf"
    echo
    echo "Setting up Pacman"
    echo

    echo -n "Enabling colour and chomp progress... "
    if $DRY_RUN; then
        log "sed -ie 's/^#Color/Color\nILoveCandy/' \"${pacmanconf}\""
    else
        sed -ie 's/^#Color/Color\nILoveCandy/' "${pacmanconf}" && echo "Done"
    fi

    echo -n "Enabling parallel downloads... "
    if $DRY_RUN; then
        log "sed -ie 's/^#ParallelDownloads/ParallelDownloads/' \"${pacmanconf}\""
    else
        sed -ie 's/^#ParallelDownloads/ParallelDownloads/' "${pacmanconf}" && echo "Done"
    fi

    echo -n "Enabling multilib repository... "
    if $DRY_RUN; then
        log "sed -ie '/^#\[multilib]$/{N;s/#\[multilib]\n#/[multilib]\n/}' \"${pacmanconf}\""
        log "arch-chroot \"${rootMount}\" pacman -Syy"
    else
        sed -ie '/^#\[multilib]$/{N;s/#\[multilib]\n#/[multilib]\n/}' \
            "${pacmanconf}" && echo "Done! Updating repos..."
        arch-chroot "${rootMount}" pacman -Syy
    fi

    echo "Enabling Reflector service with timer... "
    if $DRY_RUN; then
        log "arch-chroot \"${rootMount}\" systemctl enable reflector.service"
        log "arch-chroot \"${rootMount}\" systemctl enable reflector.timer"
        log "sed -ie 's@^#NoExtract   =\$@NoExtract   = etc/pacman.d/mirrorlist@' \"${pacmanconf}\""
    else
        arch-chroot "${rootMount}" systemctl enable reflector.service
        arch-chroot "${rootMount}" systemctl enable reflector.timer
        sed -ie 's@^#NoExtract   =$@NoExtract   = etc/pacman.d/mirrorlist@' "${pacmanconf}"
    fi

    install_yay
}

install_refind() {
    local bootConf partUuid rootFlags
    echo
    echo "Installing refind to ${efiPartition}"
    echo

    if $DRY_RUN; then
        log "arch-chroot \"${rootMount}\" refind-install"
    else
        arch-chroot "${rootMount}" refind-install
    fi

    echo "Finding PARTUUID of system partition..."
    partUuid="$(blkid -o value -s PARTUUID "${dataPartition}")"

    echo "Generating refind_linux.conf..."
    rootFlags="root=PARTUUID=${partUuid} rw rootflags=subvol=@"

    if [ -n "$cpuPackage" ]; then
        echo "Adding @\\boot\\${cpuPackage}.img to enable microcode updates..."
        rootFlags="${rootFlags} initrd=@\\boot\\${cpuPackage}.img"
    fi

    bootConf=$(cat <<EOF
"Boot using default options"     "${rootFlags} initrd=@\boot\initramfs-%v.img audit=off"
"Boot using fallback initramfs"  "${rootFlags} initrd=@\boot\initramfs-%v-fallback.img"
"Boot to terminal"               "${rootFlags} initrd=@\boot\initramfs-%v.img systemd.unit-multi-user.target"
EOF
)
    echo -n "Saving config to /boot/refind_linux.conf... "
    if $DRY_RUN; then
        log "echo \"$bootConf\" > \"${rootMount}/boot/refind_linux.conf\""
    else
        echo "$bootConf" > "${rootMount}/boot/refind_linux.conf" && echo "Done"
    fi

    echo -n "Enabling kernel detection... "
    sedopt='s/^#\(extra_kernel_version_strings\) \([linux,-ts]\+\)$/\1 linux-hardened,linux-zen,\2/'
    if $DRY_RUN; then
        log "sed -ie '${sedopt}' \"${rootMount}/efi/EFI/refind/refind.conf\""
    else
        sed -ie "$sedopt" "${rootMount}/efi/EFI/refind/refind.conf"
    fi
}

install_yay() {
    local yayRepo="https://aur.archlinux.org/yay-bin.git"

    echo
    echo "Installing AUR helper"
    echo

    echo "Fetching PKGBUILD from AUR..."
    if $DRY_RUN; then
        log "arch-chroot \"${rootMount}\" git clone \"${yayRepo}\" /opt/yay-bin"
    else
        arch-chroot "${rootMount}" git clone "${yayRepo}" /opt/yay-bin
    fi

    echo "Building package..."
    if $DRY_RUN; then
        log "chown -R nobody \"${rootMount}/opt/yay-bin\""
        log "arch-chroot -u nobody \"${rootMount}\" sh -c 'cd /opt/yay-bin && makepkg'"
    else
        chown -R nobody "${rootMount}/opt/yay-bin"
        arch-chroot -u nobody "${rootMount}" sh -c 'cd /opt/yay-bin && makepkg'
    fi

    echo "Installing yay..."
    if $DRY_RUN; then
        log "arch-chroot \"${rootMount}\" pacman --noconfirm -U /opt/yay-bin/yay-bin-*.pkg.tar.zst"
    else
        pkgFile="$(arch-chroot "${rootMount}" find /opt/yay-bin -name '*.pkg.*')"
        arch-chroot "${rootMount}" pacman --noconfirm -U "${pkgFile}"
    fi
}

print_install_menu() {
    tput clear
    echo
    echo " Installation menu"
    print_system_info
    echo
    echo " [ 1] Set microcode package (${cpuPackage:-none})"
    echo " [ 2] Set a hostname (${systemHostname:-none})"
    echo " [ 3] Set default sudo user (${systemUser:-none})"
    echo " [ 4] Set initramfs generator (${initramfsPackage:-all})"
    echo
    echo " [ i] Perform install"
    echo " [ I] Perform clean install (runs all steps on main menu)"
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

set_hostname() {
    local hostnameAnswer
    while [ -z "$hostnameAnswer" ]; do
        echo
        read -rp "Enter a new hostname: " hostnameAnswer
    done
    systemHostname="${hostnameAnswer}"
}

set_username() {
    local usernameAnswer
    while [ -z "$usernameAnswer" ]; do
        echo
        read -rp "Enter a new username: " usernameAnswer
    done
    systemUser="${usernameAnswer}"
}

set_initramfs_package() {
    local answer selected
    tput clear
    echo
    echo " Initial RAMDisk Generator"
    echo
    echo "The following providers are available:"
    echo
    echo " [ 1] mkinitcpio"
    echo " [ 2] Booster"
    echo " [ 3] Dracut"
    echo
    echo "Note this option only sets the package(s) to install."
    echo -e "Some parts of DASHit \e[4mmay\e[24m target mkinitcpio explicitly."
    echo
    echo "To install all packages, enter 'a' or 'all'."

    case "${initramfsPackage:-mkinitcpio}" in
        mkinitcpio) selected=1 ;;
        booster) selected=2 ;;
        dracut) selected=3 ;;
        "") selected="all" ;;
    esac

    while [ -z "$answer" ]; do
        echo
        read -rp "Select package: [${selected}] " answer
        answer="${answer:-$selected}"

        case "${answer,,}" in
            a|all) initramfsPackage="" ;;
            1) initramfsPackage=mkinitcpio ;;
            2) initramfsPackage=booster ;;
            3) initramfsPackage=dracut ;;
            *)
                err "Invalid option '${answer}'!"
                answer="" ;;
        esac
    done
}

install_arch_scripts() {
    echo
    echo "Downloading Arch install scripts..."
    if $DRY_RUN; then
        log "pacman -Syy --needed --noconfirm arch-install-scripts"
    else
        pacman -Syy --needed --noconfirm arch-install-scripts     # Installs pacstrap, arch-chroot etc
    fi
}

update_host_packages() {
    echo -n "Enabling parallel downloads in host's Pacman... "
    if $DRY_RUN; then
        log "sed -ie 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf"
    else
        sed -ie 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf && echo "Done"
    fi

    echo "Updating host system..."
    if grep -q '^IMAGE_ID=archlinux$' /etc/os-release; then
        err "ArchISO: Update skipped!"
        err "  Limited disk space can prevent upgrades of larger packages."
        err "  If you encounter issues, fetch a more recent ISO instead."
    elif $DRY_RUN; then
        log "pacman -Syyu --noconfirm"
    else
        pacman -Syyu --noconfirm
    fi
}

update_mirrorlist() {
    local filters="country=GB&protocol=https&ip_version=4&use_mirror_status=on"
    local mirrorlistUrl="https://archlinux.org/mirrorlist/?${filters}"
    local mirrorlist=/etc/pacman.d/mirrorlist

    echo "Fetching filtered mirrorlist..."
    if grep -q '^IMAGE_ID=archlinux$' /etc/os-release && \
        grep -q "$(date '+%Y-%m-%s')" $mirrorlist; then
        echo "  Skipped! Already using recent Arch mirrors."
    elif $DRY_RUN; then
        log "curl \"${mirrorlistUrl}\" | sed 's/^#S/S/' > $mirrorlist"
    else
        curl "${mirrorlistUrl}" | sed 's/^#S/S/' > $mirrorlist
    fi
}
