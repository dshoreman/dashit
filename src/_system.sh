install_arch() {
    unavailable
}

prepare_host() {
    unavailable

    update_host_packages
    install_arch_scripts
    update_mirrorlist
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
