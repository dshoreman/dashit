#!/bin/bash

echo "Updating live system..."
pacman -Syyu

# If it's a manjaro install...
# pacman-key --populate archlinux     # May or may not need this, we'll see.
echo "Downloading Arch install scripts..."
pacman -Syy arch-install-scripts     # Installs packages like pacstrap, arch-chroot etc

echo "Fetching filtered mirrorlist..."
curl "https://archlinux.org/mirrorlist/?country=GB&protocol=https&ip_version=4&use_mirror_status=on" > /etc/pacman.d/mirrorlist
