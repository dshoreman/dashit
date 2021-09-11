#!/bin/bash

if [ "$EUID" -ne 0 ]; then
    echo "!!! This script must be run as root! Aborting."
    exit 1
fi





# . configure-network.sh
# Resolve hostname (hosts is empty on new systems, not sure if this is still needed)
sed -ie 's/localhost$/localhost\t'"$_HOSTNAME"'/g' /etc/hosts

# Get the interface name
echo
echo "Network interfaces:"
ip link
echo
read -rp "Enter interface name: " _INTERFACE

# Enable DHCP
echo "Enabling DHCP..."
systemctl enable dhcpcd@${_INTERFACE}.service
systemctl start dhcpcd@${_INTERFACE}.service





# Make the somewhat dangerous assumption that
# the user cloned this repo to ~/dotfiles...
mv /root/dotfiles /home/$_USERNAME/dotfiles
chown -R $_USERNAME:users /home/$_USERNAME/dotfiles





read -rsn1 -p $'Press any key to logout.\n'
logout
