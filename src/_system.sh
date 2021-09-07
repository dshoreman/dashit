install_arch() {
    unavailable

    mount_subvolumes
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
