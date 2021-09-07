provision_disk() {
    set_target_disk "$@"

    unavailable
    partition_disk
    format_partition
}

set_target_disk() {
    if [ $# -eq 0 ]; then
        err "Missing required target device."
        echo
        echo "Found the following devices:"
        lsblk -nado PATH,SIZE,PTTYPE,MODEL
        echo

        read -rp "Enter target device path: " targetDevice
    else
        targetDevice="$1"
    fi
}

partition_disk() {
    local efiSize=267 offset=2048 dataStart=$((offset*efiSize + offset))
    dataPartition="${targetDevice}p2"

    print_partition_layout
    prompt_before_erase

    parted --script --align optimal "${targetDevice}" \
        mklabel gpt \
        mkpart "efi" fat32 ${offset}s $((dataStart-1))s \
        mkpart "arch" btrfs ${dataStart}s 100% \
        set 1 esp on \
        print

    echo "Disk partitioned successfully!"
    echo
}

print_partition_layout() {
    echo "Current partition layout for ${targetDevice}:"
    echo
    fdisk -l "${targetDevice}"
}

prompt_before_erase() {
    echo "ALL DATA WILL BE ERASED! IF THIS IS NOT THE RIGHT DISK, HIT CTRL-C NOW!"
    echo "To continue partitioning ${targetDevice}, press any other key."
    echo
    read -rsn1 -p "Waiting..."
    echo
}

format_partition() {
    echo "Formatting system data partition..."
    echo
    mkfs.btrfs -n 32k -L ArchRoot "${dataPartition}"
}
