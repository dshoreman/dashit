#!/bin/bash

echo "Mounting /dev/nvme0n1 at /mnt to prep subvolumes..."
mount -t btrfs /dev/nvme0n1p2 /mnt

for SUBVOLUME in @ @home @varlog @vbox @snapshots; do
    echo "Creating '${SUBVOLUME}' subvolume..."
    btrfs subvolume create /mnt/${SUBVOLUME}
done

echo -n "Partitioning complete! Unmounting..."
umount /mnt
