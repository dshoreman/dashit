#!/bin/bash

while [ -z "$MICROCODE_PKG" ]; do
    read -rp "What type of CPU is in the target system? " CPU_TYPE

    if [ "${CPU_TYPE,,}" = "amd" ]; then
        MICROCODE_PKG=amd-ucode
    elif [ "${CPU_TYPE,,}" = "intel" ]; then
        MICROCODE_PKG=intel-ucode
    else
        echo "Invalid CPU type detected. Enter 'AMD' or 'Intel'."
    fi
done

pacstrap /mnt base linux linux-firmware $MICROCODE_PKG
