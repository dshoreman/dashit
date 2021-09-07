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

provision_partition() {
    set_target_disk "$@"
    set_mountpoint

    unavailable
    mount_disk && create_subvolumes
    unmount_disk
}

set_mountpoint() {
    rootMount="/mnt"
    log "Checking if /mnt is empty..."

    while [ ! -d "${rootMount}" ] || [ -n "$(ls -A "${rootMount}")" ]; do
        err "Current mount '${rootMount}' is not empty!"
        read -rp "Enter new mountpoint: " rootMount

        [ -d "${rootMount}" ] || mkdir -vp "${rootMount}"
        log "Checking if ${rootMount} is empty..."
    done

    echo "Mountpoint set to ${rootMount}"
}

create_subvolumes() {
    for subvolume in @ @home @varlog @vbox @snapshots; do
        echo "Creating '${subvolume}' subvolume..."
        btrfs subvolume create "${rootMount}/${subvolume}"
    done

    echo "Subvolumes created!"
    echo
}

mount_disk() {
    echo "Mounting ${targetDevice} at ${rootMount} to prep subvolumes..."
    mount -t btrfs "${dataPartition}" "${rootMount}"
}

mount_subvolumes() {
    # First, mount root subvolume named simply '@'
    mount -o noatime,compress-force=zstd:5,space_cache=v2,subvol=@ /dev/nvme0n1p2 /mnt

    # Create dirs for and mount ESP and other partitions
    [ -d /mnt/efi ] || mkdir /mnt/efi
    mount /dev/nvme0n1p1 /mnt/efi

    [ -d /mnt/home ] || mkdir /mnt/home
    [ -d /mnt/var/log ] || mkdir -p /mnt/var/log

    # Now mount other essential system subvolumes
    mount -o noatime,compress-force=zstd:5,space_cache=v2,subvol=@home /dev/nvme0n1p2 /mnt/home
    mount -o noatime,compress-force=zstd:5,space_cache=v2,subvol=@varlog /dev/nvme0n1p2 /mnt/var/log
}

unmount_disk() {
    echo -n "Unmounting ${rootMount}..."
    umount "${rootMount}" && echo "Done!"
}
