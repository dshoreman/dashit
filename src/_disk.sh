provision_disk() {
    set_target_disk "$@"

    partition_disk
    format_partition
}

set_target_disk() {
    if [ -z "$targetDevice" ] && [ -b "$TARGET_DEVICE" ]; then
        log "Setting target device from option to ${TARGET_DEVICE}"
        targetDevice="${TARGET_DEVICE}"
    fi

    while [ ! -b "$targetDevice" ]; do
        err "Missing target device or device is not a block target"
        echo
        echo "Found the following devices:"
        lsblk -nado PATH,SIZE,PTTYPE,MODEL
        echo
        read -rp "Enter target device path: " targetDevice
    done
}

partition_disk() {
    local efiSize=267 offset=2048 dataStart=$((offset*efiSize + offset))
    dataPartition="${targetDevice}p2"

    print_partition_layout
    prompt_before_erase

    if $DRY_RUN; then
        log "parted --script --align optimal \"${targetDevice}\" \\"
        log "    mklabel gpt \\"
        log "    mkpart \"efi\" fat32 ${offset}s $((dataStart-1))s \\"
        log "    mkpart \"arch\" btrfs ${dataStart}s 100% \\"
        log "    set 1 esp on \\"
        log "    print"
    else
        parted --script --align optimal "${targetDevice}" \
            mklabel gpt \
            mkpart "efi" fat32 ${offset}s $((dataStart-1))s \
            mkpart "arch" btrfs ${dataStart}s 100% \
            set 1 esp on \
            print
    fi

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
    if $DRY_RUN; then
        log "mkfs.btrfs -n 32k -L ArchRoot \"${dataPartition}\""
    else
        mkfs.btrfs -n 32k -L ArchRoot "${dataPartition}"
    fi
}

provision_partition() {
    set_target_disk "$@"
    set_mountpoint

    mount_disk && create_subvolumes
    unmount_disk
}

set_mountpoint() {
    local createdInDryrun=false
    rootMount="/mnt"
    log "Checking if /mnt is empty..."

    while [ ! -d "${rootMount}" ] || [ -n "$(ls -A "${rootMount}")" ]; do
        err "Current mount '${rootMount}' is not empty!"
        read -rp "Enter new mountpoint: " rootMount

        if $DRY_RUN; then
            if [ ! -d "${rootMount}" ]; then
                log "Temporarily creating mountpoint..."
                mkdir -vp "${rootMount}" && createdInDryrun=true
            fi
        else
            [ -d "${rootMount}" ] || mkdir -vp "${rootMount}"
        fi
        log "Checking if ${rootMount} is empty..."
    done

    echo "Mountpoint set to ${rootMount}"
    if $createdInDryrun; then
        log "Cleaning up temporary mountpoint"
        rm -vd "${rootMount}"
    fi
}

create_subvolumes() {
    for subvolume in @ @home @varlog @vbox @snapshots; do
        echo "Creating '${subvolume}' subvolume..."
        if $DRY_RUN; then
            log "btrfs subvolume create \"${rootMount}/${subvolume}\""
        else
            btrfs subvolume create "${rootMount}/${subvolume}"
        fi
    done

    echo "Subvolumes created!"
    echo
}

mount_disk() {
    echo "Mounting ${targetDevice} at ${rootMount} to prep subvolumes..."
    if $DRY_RUN; then
        log "mount -t btrfs \"${dataPartition}\" \"${rootMount}\""
    else
        mount -t btrfs "${dataPartition}" "${rootMount}"
    fi
}

mount_subvolumes() {
    # First, mount root subvolume named simply '@'
    if $DRY_RUN; then
        log "mount -o noatime,compress-force=zstd:5,space_cache=v2,subvol=@ /dev/nvme0n1p2 /mnt"
    else
        mount -o noatime,compress-force=zstd:5,space_cache=v2,subvol=@ /dev/nvme0n1p2 /mnt
    fi

    # Create dirs for and mount ESP and other partitions
    if $DRY_RUN; then
        [ -d /mnt/efi ] || log "mkdir /mnt/efi"
        log "mount /dev/nvme0n1p1 /mnt/efi"
    else
        [ -d /mnt/efi ] || mkdir /mnt/efi
        mount /dev/nvme0n1p1 /mnt/efi
    fi

    if $DRY_RUN; then
        [ -d /mnt/home ] || log "mkdir /mnt/home"
        [ -d /mnt/var/log ] || log "mkdir -p /mnt/var/log"
    else
        [ -d /mnt/home ] || mkdir /mnt/home
        [ -d /mnt/var/log ] || mkdir -p /mnt/var/log
    fi

    # Now mount other essential system subvolumes
    if $DRY_RUN; then
        log "mount -o noatime,compress-force=zstd:5,space_cache=v2,subvol=@home /dev/nvme0n1p2 /mnt/home"
        log "mount -o noatime,compress-force=zstd:5,space_cache=v2,subvol=@varlog /dev/nvme0n1p2 /mnt/var/log"
    else
        mount -o noatime,compress-force=zstd:5,space_cache=v2,subvol=@home /dev/nvme0n1p2 /mnt/home
        mount -o noatime,compress-force=zstd:5,space_cache=v2,subvol=@varlog /dev/nvme0n1p2 /mnt/var/log
    fi
}

unmount_disk() {
    echo -n "Unmounting ${rootMount}..."
    if $DRY_RUN; then
        log "umount \"${rootMount}\"" && echo "Done!"
    else
        umount "${rootMount}" && echo "Done!"
    fi
}
