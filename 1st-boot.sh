#!/bin/bash

if [ "$EUID" -ne 0 ]; then
    echo "!!! This script must be run as root! Aborting."
    exit 1
fi

echo "####################"
echo "# HERE BE DRAGONS! #"
echo "####################"
echo
echo "This script is designed to be ran only once and that's"
echo "at the time of first boot on a new Arch Linux install."
echo
echo "If you've already ran this script previously, please"
echo "abort it now. Instead, run bootstrap.sh to continue."
echo
read -rsn1 -p $'Press any key to continue or Ctrl+C to exit.\n'

cd "${0%/*}/rootscripts"


# . configure-network.sh
# Resolve hostname (hosts is empty on new systems, not sure if this is still needed)
sed -ie 's/localhost$/localhost\t'$_HOSTNAME'/g' /etc/hosts

# Get the interface name
echo
echo "We are about to print a list of network devices"
echo "present in your system. When prompted,  type in"
echo "the name of your ethernet device e.g. 'enp2s0'."
echo
ip link
echo
read -p "Enter interface name: " _INTERFACE

# Enable DHCP
echo "Enabling DHCP..."
systemctl enable dhcpcd@${_INTERFACE}.service
systemctl start dhcpcd@${_INTERFACE}.service


# . create-user.sh
echo "Creating primary user..."

read -p "Enter a username: " _USERNAME
echo "$_USERNAME ALL=(ALL) ALL" > /etc/sudoers.d/$_USERNAME

useradd -mg users -G games,uucp,systemd-journal,wheel $_USERNAME
passwd $_USERNAME


# . prepare-pacman.sh
echo "Configuring pacman..."

# Install reflector for mirror prioritisation
pacman -Syy && pacman -S reflector
reflector --save /etc/pacman.d/mirrorlist --sort rate -c "United Kingdom"

# One last mirror update
pacman -Syy


# Make the somewhat dangerous assumption that
# the user cloned this repo to ~/dotfiles...
mv /root/dotfiles /home/$_USERNAME/dotfiles
chown -R $_USERNAME:users /home/$_USERNAME/dotfiles

echo "##################"
echo "# !!! HUZZAH !!! #"
echo "##################"
echo
echo "First boot setup gubbins have finished. At last!"
echo
echo "Now, it's time we boot you back to the login screen."
echo "When you get there, log in as $_USERNAME and then we"
echo "can continue this process by running bootstrap.sh..."
echo
echo "Sound good? Good!"
echo
echo
read -rsn1 -p $'Press any key to logout.\n'

logout
