#!/bin/bash

OFFSET=2048
EFI_SIZE=267
PART_START=$((OFFSET*EFI_SIZE + OFFSET))

parted --script --align optimal /dev/nvme0n1 \
    mklabel gpt \
    mkpart "efi" fat32 ${OFFSET}s $((PART_START-1))s \
    mkpart "arch" btrfs ${PART_START}s 100% \
    set 1 esp on \
    print

echo "Disk partitioned successfully! Formatting data partition..."
echo

mkfs.btrfs -n 32k -L ArchRoot /dev/nvme0n1p2
