install_arch() {
    while true; do
        print_install_menu

        case "$choice" in
            1)
                set_initramfs_package ;;
            2)
                set_cpu_package ;;
            3)
                set_video_driver ;;
            4)
                set_hostname ;;
            5)
                set_user ;;
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
    grep "^$1" <<< "$cpuOutput" | cut -d':' -f2 | awk '{$1=$1;print}'
}

perform_install() {
    local packages=(base linux man-db man-pages polkit sudo) aurPackages=() xinitrc=""
    grep -q hypervisor /proc/cpuinfo || packages+=(linux-firmware)
    packages+=(base-devel htop git openssh refind reflector snap-pac zsh)

    set_target_disk
    set_mountpoint
    mount_subvolumes

    if [ -n "$cpuPackage" ]; then
        packages+=("$cpuPackage")
    fi

    if [ -n "$initramfsPackage" ]; then
        packages+=("$initramfsPackage")
    fi

    if [ -n "$DASHIT_EXTRA_UTILS" ]; then
        packages+=(bat fd fzf lsof mtr pv ripgrep tree rsync)
    fi
    if [ -n "$DASHIT_EXTRA_EXTRACTORS" ]; then
        packages+=(p7zip unrar unzip)
    fi
    if [ -n "$DASHIT_ENVIRONMENTS" ]; then
        for env_name in ${DASHIT_ENVIRONMENTS//,/ }; do case $env_name in
            i3)
                packages+=(i3-gaps dunst numlockx picom redshift rofi xorg-server xorg-xinit xorg-xinput)
                aurPackages+=(polybar polybar-scripts-git)
                xinitrc="numlockx &\npicom &\nredshift-gtk &\nexec i3"
                ;;
            kde) packages+=(plasma-meta plasma-wayland-session) ;;
            kde-full) packages+=(pasma-meta plasma-wayland-session kde-applications-meta) ;;
            kde-minimal) packages+=(plasma-desktop plasma-wayland-session) ;;
            sway) packages+=(sway bemenu-wayland dunst waybar xorg-xwayland) ;;
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
    if [ -n "$DASHIT_BROWSERS" ]; then
        if [[ "${DASHIT_BROWSERS[*]}" == "* firefox*" ]] && [ -n "$DASHIT_FF_LOCALE" ]; then
            ffSuffix="-i18n-${DASHIT_FF_LOCALE}"
        fi
        for browser in ${DASHIT_BROWSERS//,/ }; do case $browser in
            links|lynx|elinks|w3m|seamonkey|chromium|opera|vivaldi) packages+=("$browser") ;;
            falkon|konqueror|qutebrowser|min|eolie|epiphany|midori|vimb|otter-browser)
                packages+=("$browser") ;;
            brave|dot|icecat|librewolf|waterfox-current|waterfox-classic|waterfox-g3)
                aurPackages+=("$browser-bin") ;;
            chrome|chrome-beta|chrome-dev) aurPackages+=("google-${browser}") ;;
            badwolf|browsh|ephemeral|firedragon|google-chrome|nyxt|slimjet|surf)
                aurPackages+=("$browser") ;;
            firefox) packages+=("firefox${ffSuffix}") ;;
            tor|torbrowser) aurPackages+=(torbrowser-launcher) ;;
            firefox-dev|firefox-developer-edition) packages+=("firefox-developer-edition${ffSuffix}") ;;
            firefox-esr|firefox-esr-bin|firefox-beta|firefox-beta-bin|firefox-nightly)
                aurPackages+=("${browser}${ffSuffix}") ;;
        esac; done
    fi

    if $DRY_RUN; then
        log "pacstrap /mnt ${packages[*]}"
    else
        # Sometimes 1 or 2 packages fail to download, but work second time
        pacstrap /mnt "${packages[@]}" || pacstrap /mnt "${packages[@]}"
    fi

    create_firstboot_scripts

    post_install
    isInstalled=1

    echo
    echo "Install complete!"
    echo
    if [[ -f ${DASHIT_LOG_PATH:-/tmp/dashit.log} ]]; then
        mkdir -p "${rootMount}/var/log/dashit" && chmod 770 "$_"
        arch-chroot "${rootMount}" chown "$systemUser" /var/log/dashit
        cp "${DASHIT_LOG_PATH:-/tmp/dashit.log}" "${rootMount}/var/log/dashit/install.log"
        cp "${DASHIT_LOG_PATH:-/tmp/dashit.log}t" "${rootMount}/var/log/dashit/install.logt"
        echo; echo "Dashit's log file has been copied into /var/log/dashit/ on the target system."
        echo
    fi
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
    configure_snapper

    # GPU must be done after pacman prep for the multilib repo
    install_video_drivers
    install_refind
}

create_firstboot_scripts() {
    local rootScript rootService userScript userScriptExtra="\n" userService xinitCmd="\n"

    if [[ -n "$xinitrc" ]]; then
        xinitCmd="[[ -f ~/.xinitrc ]] || echo 'No xinitrc found, creating one...'\n"
        xinitCmd+="[[ -f ~/.xinitrc ]] || echo -e '$xinitrc' > ~/.xinitrc\n"
    fi
    if [[ -n "${aurPackages[*]}" ]]; then
        userScriptExtra+="echo 'Some core packages are only available in the AUR.'\n"
        userScriptExtra+="echo 'Installing them now with yay...'\n"
        userScriptExtra+="yay --noconfirm --removemake -S --needed ${aurPackages[*]}\n"
    fi

    rootScript=$(cat <<EOF
$(firstboot_header root 1 2 "$systemUser")
echo "Waiting for a bit for other tasks to finish..." && sleep 5
echo
echo "Enabling sticky boot messages on all TTYs..."
mkdir -p /etc/systemd/system/getty@.service.d
echo -e "[Service]\\\nTTYVTDisallocate=no" > /etc/systemd/system/getty@.service.d/noclear.conf
echo
echo "Enabling numlock on boot..."
echo -e "[Service]\\\nExecStartPre=/bin/sh -c 'setleds -D +num < /dev/%I'" \
    > /etc/systemd/system/getty@.service.d/activate-numlock.conf
systemctl daemon-reload
echo -n "Checking for a first-boot root script in your dotfiles... "
fbRoot="\$DOTFILES_PATH/dashit/firstboot.root.bash"
if [[ -f "\$fbRoot" ]]; then
    echo -e "Success!\\\nRunning custom script...\\\n\\\n"
    bash "\$DOTFILES_PATH/dashit/firstboot.root.bash"
else echo "None found."; fi
EOF
    ); userScript=$(cat <<EOF
$(firstboot_header user 2 2 "$systemUser")
${userScriptExtra}
echo
echo -n "Checking for a first-boot user script in your dotfiles... "
fbRoot="\$DOTFILES_PATH/dashit/firstboot.user.bash"
if [[ -f "\$fbRoot" ]]; then
    echo -e "Success!\\\nRunning custom script...\\\n\\\n"
    bash "\$DOTFILES_PATH/dashit/firstboot.user.bash"
else echo "None found."; fi
echo
echo "Checking for an xinit rc file in your home directory..."
${xinitCmd}
echo -e "\\\n\\\n\\\n\\\n\\\n Setup complete!\\\n\\\n\\\n"
echo -e " Full logs are saved in /var/log/dashit and can be replayed with scriptreplay:\\\n\\\n"
cat <<EOTXT
   for log in install firstboot.user firstboot.root; do
     scriptreplay -T /var/log/dashit/\${log}{t,}
   done
EOTXT
echo -e "\\\n\\\n Note: You'll be switched over to TTY1 when you continue."
echo "       You can get back here by switching to TTY4."
read -rsn1 -p \$'\\\n\\\n\\\nPress any key to continue...\\\n'
sudo systemctl disable dashit.first-boot.user.service
sudo systemctl disable dashit.first-boot.root.service
sudo chvt 1
EOF
    ); rootService=$(cat <<EOF
[Unit]
Description=DASHit first-boot root script
Before=dashit.first-boot.user.service
After=network-online.target nss-lookup.target
Wants=network-online.target

[Service]
Type=oneshot
TTYPath=/dev/tty4
ExecStartPre=/usr/bin/chvt 4
ExecStart=/usr/bin/script -c /firstboot.root.sh -aB /var/log/dashit/firstboot.root.log -T /var/log/dashit/firstboot.root.logt
StandardInput=tty

[Install]
WantedBy=multi-user.target
EOF
    ); userService=$(cat <<EOF
[Unit]
Description=DASHit first-boot user script
Before=systemd-logind.service getty@tty1.service
After=dashit.first-boot.root.service
Wants=dashit.first-boot.root.service

[Service]
User=${systemUser}
Group=${systemUser}
Type=oneshot
TTYPath=/dev/tty4
ExecStart=/usr/bin/script -c /firstboot.user.sh -aB /var/log/dashit/firstboot.user.log -T /var/log/dashit/firstboot.user.logt
StandardInput=tty

[Install]
WantedBy=multi-user.target
EOF
    )

    echo "Writing first-boot scripts..."
    if $DRY_RUN; then
        log "echo \"$rootScript\" > \"${rootMount}/firstboot.root.sh\""
        log "echo \"$userScript\" > \"${rootMount}/firstboot.user.sh\""
    else
        echo -e "$rootScript" > "${rootMount}/firstboot.root.sh"
        echo -e "$userScript" > "${rootMount}/firstboot.user.sh"
        chmod +x "${rootMount}"/firstboot.*.sh
    fi

    echo "Creating first-boot services... "
    if $DRY_RUN; then
        log "echo \"$rootScript\" > \"${rootMount}/etc/systemd/system/dashit.first-boot.root.service\""
        log "echo \"$userScript\" > \"${rootMount}/etc/systemd/system/dashit.first-boot.user.service\""
        log "arch-chroot \"${rootMount}\" systemctl enable dashit.first-boot.root.service"
        log "arch-chroot \"${rootMount}\" systemctl enable dashit.first-boot.user.service"
    else
        echo "$rootService" > "${rootMount}/etc/systemd/system/dashit.first-boot.root.service"
        echo "$userService" > "${rootMount}/etc/systemd/system/dashit.first-boot.user.service"
        arch-chroot "${rootMount}" systemctl enable dashit.first-boot.root.service
        arch-chroot "${rootMount}" systemctl enable dashit.first-boot.user.service
    fi
}

install_video_drivers() {
    local kmsModule packages

    echo -e "\nChecking video drivers..."
    case ${DASHIT_GPU_DRIVER,,} in
        amd)
            packages=(libva-mesa-driver mesa mesa-vdpau radeontop vulkan-radeon xf86-video-amdgpu)
            packages+=(lib32-libva-mesa-driver lib32-mesa lib32-mesa-vdpau lib32-vulkan-radeon) ;;
        intel)
            kmsModule=i915
            packages=(intel-media-driver mesa lib32-mesa vulkan-intel lib32-vulkan-intel) ;;
        intel-legacy)
            kmsModule=i915
            packages=(libva-intel-driver mesa lib32-mesa) ;;
        nvidia)
            kmsModule="nvidia nvidia_modeset nvidia_uvm nvidia_drm"
            packages=(nvidia nvidia-utils) ;;
        *) err "Invalid or no drivers selected! Continuing without any." ;;
    esac

    echo "Found ${#packages[@]} packages to install!"
    (( ${#packages[@]} > 0 )) || return

    if [[ -n $kmsModule ]]; then
        echo "Adding kernel modules (${kmsModule// /, }) for early KMS..."
        if $DRY_RUN; then
            log "sed -i -e \"s/^MODULES=(/MODULES=(${kmsModule}/\" \"${rootMount}/etc/mkinitcpio.conf\""
        else
            sed -i -e "s/^MODULES=(/MODULES=(${kmsModule}/" "${rootMount}/etc/mkinitcpio.conf"
        fi
    fi

    echo -e "\nInstalling GPU packages (${packages[*]// /, })..."
    if $DRY_RUN; then
        log "arch-chroot \"${rootMount}\" pacman -Sy --noconfirm \"${packages[*]}\""
    else
        arch-chroot "${rootMount}" pacman -Sy --noconfirm "${packages[@]}"
    fi

    echo -e "\nDone!\n\n"
}

generate_fstab() {
    echo
    echo -n "Generating fstab..."
    if $DRY_RUN; then
        log "genfstab -t PARTLABEL \"${rootMount}\" | grep -vE \"(^#|^$|/(efi|\s+btrfs))\" |\\"
        log "    sed 's/compress-force=.*,subvol=/subvol=/' >> \"${rootMount}/etc/fstab\""
    else
        genfstab -t PARTLABEL "${rootMount}" | grep -vE "(^#|^$|/(efi|\s+btrfs))" |\
            sed 's/compress-force=.*,subvol=/subvol=/' >> "${rootMount}/etc/fstab" && echo "Done"
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
        arch-chroot "${rootMount}" timedatectl set-ntp true && sleep 3 && echo "Done"
    fi

    echo -n "Generating /etc/adjtime... "
    if $DRY_RUN; then
        log "arch-chroot \"${rootMount}\" hwclock --systohc"
    else
        arch-chroot "${rootMount}" hwclock --utc --systohc && echo "Done"
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

    echo -n "Writing basic DHCP-enabled config... "
    if $DRY_RUN; then
        log "echo -e \"[Match]\nName=en*\n\n[Network]\nDHCP=yes\" > \"${rootMount}/etc/systemd/network/20-wired.network\""
    else
        echo -e "[Match]\nName=en*\n\n[Network]\nDHCP=yes" > "${rootMount}/etc/systemd/network/20-wired.network" && echo "Done"
    fi

    echo "Enabling network manager..."
    local resolvLink="ln -srf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf"
    if $DRY_RUN; then
        log "arch-chroot \"${rootMount}\" systemctl enable systemd-networkd.service"
        log "arch-chroot \"${rootMount}\" systemctl enable systemd-resolved.service"
        log "arch-chroot \"${rootMount}\" bash -c \"umount /etc/resolv.conf || echo; $resolvLink\""
    else
        arch-chroot "${rootMount}" systemctl enable systemd-networkd.service
        arch-chroot "${rootMount}" systemctl enable systemd-resolved.service
        arch-chroot "${rootMount}" bash -c "umount /etc/resolv.conf || echo; $resolvLink"
        echo "Done"
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

    echo -n "Setting password for ${systemUser}... "
    if $DRY_RUN; then
        log "echo \"${systemUser}:*******\" | chpasswd --root \"$rootMount\""
    else
        echo "${systemUser}:${systemUserPass}" | chpasswd --root "$rootMount"
    fi

    echo -n "Cloning dotfiles... "
    branch="${DASHIT_DOTFILES_BRANCH:-master}"
    clonePath="/home/${systemUser}/${DASHIT_DOTFILES_DIR:-.files}"
    if [[ -n $DASHIT_DOTFILES_REPO ]] && $DRY_RUN; then
        log "arch-chroot \"${rootMount}\" git clone --recurse-submodules -j5 -b \"${branch}\" \"${DASHIT_DOTFILES_REPO}\" \"${clonePath}\""
        log "arch-chroot \"${rootMount}\" chown -R \"${systemUser}\":\"${systemUser}\" \"${clonePath}\""
    elif [[ -n $DASHIT_DOTFILES_REPO ]]; then
        arch-chroot "$rootMount" git clone --recurse-submodules -j5 -b "$branch" "$DASHIT_DOTFILES_REPO" "$clonePath" \
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

configure_snapper() {
    echo
    echo "Setting up Snapper snapshots"
    echo
    systemctl daemon-reload
    create_snapper_config root /
    create_snapper_config home /home
    mod_snapper_config root timeline-create no
    mod_snapper_config home timeline-limit-monthly 11
    mod_snapper_config home timeline-limit-yearly 3

    echo -n "[snap-pac] Enabling 'important' flag on Pacman snapshots... "
    if $DRY_RUN; then
        log "sed -ie 's/^#\(\[root]\|important_\)/\/g' \"${rootMount}/etc/snap-pac.ini\""
    else
        sed -i -e 's/^#\(\[root]\|important_\)/\1/g' "${rootMount}/etc/snap-pac.ini" && echo "Done!"
    fi
}

create_snapper_config() {
    local shortpath="$2/.snapshots" snapsub subvol="${2//\//@}/.snapshots"
    shortpath="${shortpath//\/\//\/}"
    snapsub="${rootMount}${shortpath}"

    echo -n "[$1] Unmounting ${snapsub}... "
    if $DRY_RUN; then
        log "umount \"${snapsub}\" && rm -d \"${snapsub}\""
    else
        umount "$snapsub" && rm -d "$snapsub" && echo "Done!"
    fi

    echo -n "[$1] Creating config... "
    if $DRY_RUN; then
        log "arch-chroot \"${rootMount}\" /usr/bin/env LC_ALL=C snapper --no-dbus -c \"$1\" create-config \"$2\""
    else
        arch-chroot "${rootMount}" /usr/bin/env LC_ALL=C snapper --no-dbus -c "$1" create-config "$2" && echo "Done!"
    fi

    echo -n "[$1] Removing snapper's $subvol subvolume... "
    if $DRY_RUN; then
        log "btrfs -q subvolume delete -c \"$snapsub\""
    else
        btrfs -q subvolume delete -c "$snapsub" && echo "Done!"
    fi

    echo -n "[$1] Re-creating ${snapsub} dir... "
    if $DRY_RUN; then
        log "mkdir \"$snapsub\""
    else
        mkdir "$snapsub" && echo "Done!"
    fi

    echo -n "[$1] Mounting custom @snapshots/$1 subvolume... "
    if $DRY_RUN; then
        log "arch-chroot \"${rootMount}\" mount \"$shortpath\" && echo \"Done!\""
    else
        arch-chroot "${rootMount}" mount "$shortpath" && echo "Done!"
    fi
}

mod_snapper_config() {
    local config=$1 option=${2//-/_} value=$3
    option=${option^^}

    echo -n "[$1] Setting option $option to $value... "
    if $DRY_RUN; then
        log "sed -i -e \"s/^${option}=.*/${option}=\\\"$value\\\"/\" \"$rootMount/etc/snapper/configs/$config\""
    else
        sed -i -e "s/^${option}=.*/${option}=\"$value\"/" "$rootMount/etc/snapper/configs/$config" && echo "Done!"
    fi
}

install_refind() {
    local bootConf rootFlags
    echo
    echo "Installing refind to ${efiPartition}"
    echo

    if $DRY_RUN; then
        log "arch-chroot \"${rootMount}\" refind-install"
    else
        arch-chroot "${rootMount}" refind-install
    fi

    echo "Generating refind_linux.conf..."
    rootFlags="root=PARTLABEL=arch rw rootflags=noatime,compress-force=zstd:5,space_cache=v2"

    if [ -n "$cpuPackage" ]; then
        echo "Adding @\\boot\\${cpuPackage}.img to enable microcode updates..."
        rootFlags="${rootFlags} initrd=boot\\${cpuPackage}.img"
    fi

    bootConf=$(cat <<EOF
"Boot using default options"     "${rootFlags} initrd=boot\initramfs-%v.img audit=off"
"Boot using fallback initramfs"  "${rootFlags} initrd=boot\initramfs-%v-fallback.img"
"Boot to terminal"               "${rootFlags} initrd=boot\initramfs-%v.img systemd.unit-multi-user.target"
EOF
)
    echo -n "Saving config to /boot/refind_linux.conf... "
    if $DRY_RUN; then
        log "echo \"$bootConf\" > \"${rootMount}/boot/refind_linux.conf\""
    else
        echo "$bootConf" > "${rootMount}/boot/refind_linux.conf" && echo "Done"
    fi

    echo -n "Enabling Systemd EFI variable writing... "
    mod_refind_conf 's/^#\(write_systemd_vars\) \(true\|false\)$/\1 true/'

    echo -n "Enabling kernel detection... "
    mod_refind_conf 's/^#\(extra_kernel_version_strings\) \([linux,-ts]\+\)$/\1 linux-hardened,linux-zen,\2/'

    echo -n "Enabling graphical boot... "
    mod_refind_conf 's/^#\(use_graphics_for \)/\1/'
}

mod_refind_conf() {
    local refindconf="${rootMount}/efi/EFI/refind/refind.conf"

    if $DRY_RUN; then log "sed -ie '$1' \"$refindconf\""
    else sed -ie "$1" "$refindconf" && echo "Done!"; fi
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
    echo " [ 1] Set initramfs generator (${initramfsPackage:-all})"
    echo " [ 2] Set microcode package (${cpuPackage:-none})"
    echo " [ 3] Select GPU drivers (${DASHIT_GPU_DRIVER:-none})"
    echo
    echo " [ 4] Set a hostname (${systemHostname:-none})"
    echo " [ 5] Set default sudo user (${systemUser:-none})"
    echo;echo
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
    echo "Current System: ${cpuType} (${architecture} ${byteOrder})"
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
    byteOrder="$(get_cpu_value 'Byte Order')"
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

set_video_driver() {
    local detected gpuAnswer likelyGpu selected="${DASHIT_GPU_DRIVER:-none}"

    tput clear; echo "Detecting GPU..."
    detected="$(lspci -v | grep -e VGA -e 3D | tail -n1)"
    case $detected in
        *AMD*) likelyGpu=AMD ;;
        *NVIDIA*) likelyGpu=NVIDIA ;;
        *Intel*) echo "Seems to be Intel. You're on yer own, bud!" ;;
    esac

    if [[ -n $likelyGpu ]]; then
        echo -e "\nLooks like you have an $likelyGpu GPU!\nThis would add the following packages:\n"
        list_video_packages $likelyGpu
        read -rsn1 -p $'\n\nIs that correct? [Y/n]\n' useauto
        if [[ -z $useauto || ${useauto,,} == "y" ]]; then
            DASHIT_GPU_DRIVER=${likelyGpu,,}
            return
        fi
    fi

    while [[ -z $gpuAnswer ]]; do
        echo
        echo "The following drivers are available for selection:"
        echo
        echo "         AMD :  $(list_video_packages amd)"
        echo "       Intel :  $(list_video_packages intel)"
        echo "Intel-Legacy :  $(list_video_packages intel-legacy)"
        echo "      NVIDIA :  $(list_video_packages nvidia)"
        echo
        read -rp "Which GPU drivers do you want to install? [${selected}] " gpuAnswer
        gpuAnswer="${gpuAnswer:-$selected}"

        case "${gpuAnswer,,}" in
            amd|nvidia|intel|intel-legacy) DASHIT_GPU_DRIVER=${gpuAnswer,,} ;;
            n|no|none) unset DASHIT_GPU_DRIVER ;;
            *)
                err "Invalid selection '${gpuAnswer,,}'. Enter 'AMD', 'NVIDIA', 'Intel', 'Intel-legacy' or 'None'."
                gpuAnswer=
        esac
    done
    export DASHIT_GPU_DRIVER
}

list_video_packages() {
    # This list is purely visual (for selection). It is not used by the install function.
    case ${1,,} in
        amd) echo "  libva-mesa-driver, xf86-video-amdgpu, mesa, mesa-vdpau, vulkan-radeon and radeontop" ;;
        intel) echo "  intel-media-driver mesa vulkan-intel" ;;
        intel-legacy) echo "  libva-intel-driver mesa" ;;
        nvidia) echo "  nvidia and nvidia-utils" ;;
    esac
}

set_hostname() {
    local hostnameAnswer
    while [ -z "$hostnameAnswer" ]; do
        echo
        read -rp "Enter a new hostname: " hostnameAnswer
    done
    systemHostname="${hostnameAnswer}"
}

set_user() {
    local confirmed usernameAnswer passAnswer
    while [ -z "$usernameAnswer" ]; do
        echo
        read -rp "Enter a new username: " usernameAnswer
    done
    while [[ -z $passAnswer || $passAnswer != "$confirmed" ]]; do
        confirmed="" passAnswer=""
        read -rsp "Enter a new password for $usernameAnswer: " passAnswer
        echo
        if [[ -n $passAnswer ]]; then
            read -rsp "Confirm the password for $usernameAnswer: " confirmed
            [[ $passAnswer == "$confirmed" ]] || err "Passwords don't match!"
        fi
    done
    systemUser="${usernameAnswer}"
    systemUserPass="${passAnswer}"
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
