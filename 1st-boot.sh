#!/bin/bash

if [ "$EUID" -ne 0 ]; then
    echo "!!! This script must be run as root! Aborting."
    exit 1
fi





# Make the somewhat dangerous assumption that
# the user cloned this repo to ~/dotfiles...
mv /root/dotfiles /home/$_USERNAME/dotfiles
chown -R $_USERNAME:users /home/$_USERNAME/dotfiles





read -rsn1 -p $'Press any key to logout.\n'
logout
