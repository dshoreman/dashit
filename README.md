# DASHit

*Dave's Arch System helper/install tool* is a set of Bash scripts that automate the steps in the Arch Linux installation guide.

## Usage

Download and run the latest script from GitHub Releases:

```sh
wget https://github.com/dshoreman/dashit/releases/download/v0.1.0/dashit
sudo ./dashit --help
```

### Main Menu

When you run dashit, you'll be presented with a menu where you can:

1. **Partition and format disk**

    Provisions a disk, creating a small ESP formatted as FAT32, with remaining space used for the main btrfs partition.

2. **Create btrfs subvolumes**

    Mounts the main btrfs data partition and creates 5 subvolumes: `@`, `@home`, `@varlog`, `@snapshots` and `@vbox`.  
    By default, the partition will be mounted to **/mnt**. If it's not empty, you'll be prompted for a different mountpoint.

    Once the subvolumes have been created, the partition is unmounted.

3. **Prepare host system**

    Updates the host after enabling Pacman's parallel downloads feature, and installs the `arch-install-scripts` package.  
    Once done, the latest mirrors are fetched from archlinux.org and written to /etc/pacman.d/mirrorlist.

4. **Install Arch Linux**

    Enters the installation submenu.

    Configure microcode, hostname and username with the numbered options then press `i` or `I` to install. Interactive mode (`i`) assumes you have already ran steps 1-3 from the main menu; use unattended (`I`) to have them autorun.  
    In both cases, your user is created without a password, so you'll need to set that on first login.

    Once install has completed and you're back at the menu, press `r` to unmount all the subvolumes and reboot.  
