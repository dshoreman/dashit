#!/bin/bash

MOUNTPOINT="/mnt"
echo "Checking if /mnt is empty..."

while [ ! -d "${MOUNTPOINT}" ] || [ -n "$(ls -A "${MOUNTPOINT}")" ]; do
    read -rp "Oh no! ${MOUNTPOINT} is not empty. Enter new mountpoint: " MOUNTPOINT
    [ -d "${MOUNTPOINT}" ] || mkdir -vp "${MOUNTPOINT}"
    echo "Checking if ${MOUNTPOINT} is empty..."
done

echo "${MOUNTPOINT} will be used as the temporary mount for the new install."

echo "Mounting ${TARGET_DEVICE} at ${MOUNTPOINT} to prep subvolumes..."
mount -t btrfs "${BTR_PARTITION}" "${MOUNTPOINT}"

for SUBVOLUME in @ @home @varlog @vbox @snapshots; do
    echo "Creating '${SUBVOLUME}' subvolume..."
    btrfs subvolume create "${MOUNTPOINT}/${SUBVOLUME}"
done

echo -n "Partitioning complete! Unmounting..."
umount "${MOUNTPOINT}" && echo "Done!"
