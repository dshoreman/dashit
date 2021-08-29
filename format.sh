#!/bin/bash

if [ $# -eq 0 ]; then
    echo "Missing required target device. Found the following devices:"
    lsblk -a

    read -rp "Enter target device name: " TARGET_DEVICE
else
    TARGET_DEVICE="$1"
fi

echo "Current partition layout for ${TARGET_DEVICE}:"
echo
fdisk -l "${TARGET_DEVICE}"

echo "ALL DATA WILL BE ERASED! IF THIS IS NOT THE RIGHT DISK, HIT CTRL-C NOW!"
echo "To continue partitioning ${TARGET_DEVICE}, press any other key."
echo
read -rsn1 -p "Waiting..."

OFFSET=2048
EFI_SIZE=267
PART_START=$((OFFSET*EFI_SIZE + OFFSET))
BTR_PARTITION="${TARGET_DEVICE}p2"

parted --script --align optimal "${TARGET_DEVICE}" \
    mklabel gpt \
    mkpart "efi" fat32 ${OFFSET}s $((PART_START-1))s \
    mkpart "arch" btrfs ${PART_START}s 100% \
    set 1 esp on \
    print

echo "Disk partitioned successfully! Formatting data partition..."
echo

mkfs.btrfs -n 32k -L ArchRoot "${BTR_PARTITION}"

. /_subvol.sh
