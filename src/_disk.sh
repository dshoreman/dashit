provision_disk() {
    echo
    echo " Partitioning target disk"
    echo
    set_target_disk

    partition_disk
    format_partition

    echo
    $AUTO_INSTALL || read -rsn1 -p $'Press any key to continue...\n'
}

set_target_disk() {
    local partnum

    if $debug && [ -b "$targetDevice" ]; then
        log "Target disk already set to ${targetDevice}"
    fi
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

    (( DASHIT_SIZE_SWAP > 0 )) && partnum=3 || partnum=2
    if [[ "${targetDevice}" =~ ^/dev/nvme.* ]]; then
        dataPartition="${targetDevice}p$partnum"
        efiPartition="${targetDevice}p1"
    else
        dataPartition="${targetDevice}$partnum"
        efiPartition="${targetDevice}1"
    fi
}

partition_disk() {
    local efiSize=${DASHIT_SIZE_ESP:-267} partitions partnum=2 sgdisk=sgdisk

    print_partition_layout
    prompt_before_erase

    echo "Partitioning..."
    echo
    if $DRY_RUN; then
        sgdisk="sgdisk --pretend"
    fi

    # TODO: To support ARM/ARM64 the 8304 typecode needs to be variable!
    partitions=(-n 1:0:"+${efiSize}M" -t 1:ef00 -c 1:esp)
    if (( DASHIT_SIZE_SWAP > 0 )); then
        partitions+=(-n 2:0:"+${DASHIT_SIZE_SWAP}G" -t 2:8200 -c 2:swap)
        partnum=3
    fi
    partitions+=(-N "$partnum" -t "$partnum":8304 -c "$partnum":arch)

    $sgdisk --clear -g "${partitions[@]}" --print "$targetDevice"

    echo "Disk partitioned successfully!"
    echo "Pausing for effect..." && sleep 10
    echo
}

print_partition_layout() {
    echo
    echo "Current partition layout for ${targetDevice}:"
    echo
    fdisk -l "${targetDevice}"
    echo
}

prompt_before_erase() {
    echo
    echo
    err "ALL DATA WILL BE ERASED! IF THIS IS NOT THE RIGHT DISK, HIT CTRL-C NOW!"
    echo
    echo "To continue partitioning ${targetDevice}, press any other key."
    echo
    read -rsn1 -p $'Waiting...\n\n'
}

format_partition() {
    echo "Formatting EFI partition..."
    if $DRY_RUN; then
        log "mkfs.fat -F32 \"${efiPartition}\""
    else
        mkfs.fat -F32 "${efiPartition}" && echo "Done"
    fi
    echo

    if (( DASHIT_SIZE_SWAP > 0 )); then
        echo "Setting up swap space..."
        if $DRY_RUN; then
            log "mkswap \"${targetDevice}p2\""
        else
            mkswap "${targetDevice}p2"
        fi
    fi

    echo "Formatting system data partition..."
    if $DRY_RUN; then
        log "mkfs.btrfs -n 32k -L ArchRoot -f \"${dataPartition}\""
    else
        mkfs.btrfs -n 32k -L ArchRoot -f "${dataPartition}" && echo "Done"
    fi
    echo
}

provision_partition() {
    echo
    echo "Creating subvolumes"
    echo
    set_target_disk
    set_mountpoint

    mount_disk && create_subvolumes
    unmount_disk

    echo
    $AUTO_INSTALL || read -rsn1 -p $'Press any key to continue...\n'
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
    for subvolume in @ @home @varlog @snapshots @snapshots/root @snapshots/home; do
        echo
        echo "Creating '${subvolume}' subvolume..."
        if $DRY_RUN; then
            log "btrfs subvolume create \"${rootMount}/${subvolume}\""
        else
            btrfs subvolume create "${rootMount}/${subvolume}"
        fi
    done

    echo "Subvolumes created!"
    echo

    echo "Setting '@' as the default subvolume... "
    if $DRY_RUN; then
        log "btrfs subvolume set-default \$(get_root_subvolume) \"$rootMount\""
    else
        btrfs subvolume set-default "$(get_root_subvolume)" "$rootMount" && echo "Done!"
    fi
}

get_root_subvolume() {
    btrfs subvolume show "$rootMount/@" | \
        grep 'Subvolume ID' | cut -d: -f2 | xargs
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
    local m="${rootMount}"
    local efiPath="${m}/efi" homePath="${m}/home" logPath="${m}/var/log"
    local mountString="noatime,compress-force=zstd:5,space_cache=v2,subvol="

    # First, mount root subvolume named simply '@'
    if $DRY_RUN; then
        log "mount -o ${mountString}@ \"$dataPartition\" \"${m}\""
    else
        mount -o ${mountString}@ "$dataPartition" "${m}"
    fi

    # Create dirs for and mount ESP and other top-level partitions
    if $DRY_RUN; then
        log "mkdir -vp \"${m}/.snapshots\" \"${efiPath}\" \"${homePath}\" \"${logPath}\""
        log "mount \"$efiPartition\" \"${efiPath}\""
        log "mount -o ${mountString}@home \"$dataPartition\" \"${homePath}\""
        log "mount -o ${mountString}@varlog \"$dataPartition\" \"${logPath}\""
    else
        mkdir -vp "${efiPath}" "${homePath}" "${logPath}"
        mount "$efiPartition" "${efiPath}"
        mount -o ${mountString}@home "$dataPartition" "${homePath}"
        mount -o ${mountString}@varlog "$dataPartition" "${logPath}"
    fi

    # Now create and mount snapshot subvolumes for Snapper
    # Note these are re-mounted later, but this makes fstab easier.
    if $DRY_RUN; then
        log "mkdir -vp \"${m}/.snapshots\" \"${m}/home/.snapshots\""
        log "mount \"$dataPartition\" \"${rootMount}/.snapshots\""
        log "mount \"$dataPartition\" \"${rootMount}/home/.snapshots\""
    else
        mkdir -vp "${m}/.snapshots" "${m}/home/.snapshots"
        mount -o ${mountString}@snapshots/root "$dataPartition" "${rootMount}/.snapshots"
        mount -o ${mountString}@snapshots/home "$dataPartition" "${rootMount}/home/.snapshots"
    fi
}

unmount_disk() {
    echo -n "Unmounting ${rootMount}..."
    if $DRY_RUN; then
        log "umount -R \"${rootMount}\"" && echo "Done!"
    else
        umount -R "${rootMount}" && echo "Done!"
    fi
}
