#!/bin/bash

echo "Mounting "${TARGET_DEVICE}" at /mnt to prep subvolumes..."
mount -t btrfs "${TARGET_DEVICE}p2" /mnt

for SUBVOLUME in @ @home @varlog @vbox @snapshots; do
    echo "Creating '${SUBVOLUME}' subvolume..."
    btrfs subvolume create /mnt/${SUBVOLUME}
done

echo -n "Partitioning complete! Unmounting..."
umount /mnt
