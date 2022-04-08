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

    if [[ "${targetDevice}" =~ ^/dev/nvme.* ]]; then
        dataPartition="${targetDevice}p2"
        efiPartition="${targetDevice}p1"
    else
        dataPartition="${targetDevice}2"
        efiPartition="${targetDevice}1"
    fi
}

partition_disk() {
    local efiSize=267 sgdisk=sgdisk

    print_partition_layout
    prompt_before_erase

    echo "Partitioning..."
    echo
    if $DRY_RUN; then
        sgdisk="sgdisk --pretend"
    fi

    # TODO: To support ARM/ARM64 the 8304 typecode needs to be variable!
    $sgdisk --clear -g \
        -n 1:0:+${efiSize}M -t 1:ef00 -c 1:esp \
        -N 2 -t 2:8304 -c 2:arch \
        --print "$targetDevice"

    echo "Disk partitioned successfully!"
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
    for subvolume in @ @home @varlog @vbox @snapshots; do
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

    # Create dirs for and mount ESP and other partitions
    if $DRY_RUN; then
        [ -d "$efiPath" ] || log "mkdir \"${efiPath}\""
        log "mount \"$efiPartition\" \"${efiPath}\""
    else
        [ -d "$efiPath" ] || mkdir "${efiPath}"
        mount "$efiPartition" "${efiPath}"
    fi

    if $DRY_RUN; then
        [ -d "$homePath" ] || log "mkdir \"${homePath}\""
        [ -d "$logPath" ] || log "mkdir -p \"${logPath}\""
    else
        [ -d "$homePath" ] || mkdir "${homePath}"
        [ -d "$logPath" ] || mkdir -p "${logPath}"
    fi

    # Now mount other essential system subvolumes
    if $DRY_RUN; then
        log "mount -o ${mountString}@home \"$dataPartition\" \"${homePath}\""
        log "mount -o ${mountString}@varlog \"$dataPartition\" \"${logPath}\""
    else
        mount -o ${mountString}@home "$dataPartition" "${homePath}"
        mount -o ${mountString}@varlog "$dataPartition" "${logPath}"
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
