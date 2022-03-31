# DASHit

*Dave's Arch System helper/install tool* is a Bash script that automates the steps in the Arch Linux installation guide.

## Usage

Download and run the latest version from GitHub Releases:

```sh
curl -L https://github.com/dshoreman/dashit/releases/latest/download/dashit -o dashit && chmod +x $_
./dashit --help
```

Alternatively, modify this example script to your needs for a more complete install:

```bash
#!/usr/bin/env bash

export DASHIT_ENVIRONMENTS="i3"
export DASHIT_TERMINALS="alacritty"
export DASHIT_BROWSERS="firefox,vivaldi"

export DASHIT_FF_LOCALE="en-gb"
export DASHIT_EXTRA_UTILS="yes"

curl -L https://github.com/dshoreman/dashit/releases/latest/download/dashit -o dashit

chmod +x "$_" && ./dashit -d /dev/nvme0n1 -v
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

    Updates the host after enabling Pacman's parallel downloads feature, and installs `arch-install-scripts`.  
    Once done, the latest mirrors are fetched from archlinux.org and written to /etc/pacman.d/mirrorlist.

4. **Install Arch Linux**

    Enters the installation submenu.

    Configure microcode, hostname and username with the numbered options then press `i` or `I` to install.

    Interactive mode (`i`) assumes you have already ran steps 1-3 from the main menu; use unattended mode (`I`) to have them autorun. In both cases, **your user is created without a password, so you need to set it on first login**.

    Once install has completed and you're back at the menu, press `r` to unmount all the subvolumes and reboot.  

### Environment Variables

Several variables are available to predefine packages for install, where most accept a comma- or space-separated list:

#### `DASHIT_ENVIRONMENTS`
Installing i3 will also install needed xorg packages. Installing any of the KDEs will include plasma-wayland-session.
* **`i3`** will install i3 (Gaps variant) with Polybar (and its scripts), Picom, Redshift, Rofi and Dunst.
* **`kde`** will install the Plasma metapackage.
* **`kde-full`** will install the Plasma metapackage and *all additional applications*.
* **`kde-minimal`** will install the Plasma *desktop* package only.
* **`sway`** will install Sway with Waybar, Bemenu and Dunst.

#### `DASHIT_EXTRA_UTILS`
Setting this to any non-empty value will install bat, fd, fzf, lsof, mtr, pv, ripgrep, tree and rsync.

#### `DASHIT_EXTRA_EXTRACTORS`
Adds p7zip, unrar and unzip to the list of packages when set to a non-empty value.

#### `DASHIT_BROWSERS`
DASHit supports about 40 different browser packages. Most are set by lowercase name, with some exceptions:
* Brave, Dot, Icecat, Librewolf and Waterfox (current, g3 or classic) should be set **without** the `-bin` suffix.
* Firefox packages have `-18n-$DASHIT_FF_LOCALE` appended if it's set.
* Firefox Developer Edition can be shortened to `firefox-dev`.
* The `torbrowser-launcher` package is also aliased to `tor` and `torbrowser`.
* Google Chrome packages should be installed with `chrome`, `chrome-beta` or `chrome-dev`.

#### `DASHIT_DOTFILES_REPO` and `DASHIT_DOTFILES_BRANCH`
If the dotfiles repo is set, DASHit will automatically clone it to the specified branch. If branch isn't set, `master` is used.

#### `DASHIT_DOTFILES_DIR`
This can be used to change the target path for your dotfiles repo.

The path is relative to your homedir. If it's not set, `.files` is the default (equivalent to `$HOME/.files`).

#### `DASHIT_FF_LOCALE`
Sets the locale (e.g. `en-gb`) to use for Firefox packages. See [`DASHIT_BROWSERS`](#dashit_browsers).
