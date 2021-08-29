#!/bin/bash

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
