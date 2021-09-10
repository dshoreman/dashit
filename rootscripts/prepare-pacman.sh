#!/bin/bash

echo "Configuring pacman..."

# Install reflector for mirror prioritisation
pacman -Syy && pacman -S reflector
reflector --save /etc/pacman.d/mirrorlist --sort rate -c "United Kingdom"

# One last mirror update
pacman -Syy
