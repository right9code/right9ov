# Arch Installation Guide

## 1. Setup SSH
1. Install the OpenSSH Package
```bash
sudo pacman -S openssh --needed
```

2. Enable and Start the SSH Service
```bash
systemctl enable sshd.service 
systemctl start sshd.service
```

You can verify the status of the service by running:
```bash
sudo systemctl status sshd.service
```

3. Configure the Firewall
If you have a firewall like ufw or firewalld enabled, you'll need to open the default SSH port, which is port 22.

For ufw users:
```
sudo ufw allow 22/tcp
sudo ufw reload
```

For firewalld users:

```bash
sudo firewall-cmd --permanent --add-service=ssh
sudo firewall-cmd --reload
```

4. Set root password 
```bash
passwd
```

5. Connect to Your SSH Server
Once the server is running and the firewall is configured, you can connect to your Arch Linux machine from another computer. The command to connect is 
```bash
ssh <root>@<IP_address>.
```

---

## 2.  Verify Boot Mode

This command confirms that you have booted the live media in UEFI mode. This is critical as the rest of this guide will assume a UEFI installation.

```bash
ls /sys/firmware/efi/efivars
```

If you have booted correctly in UEFI mode, this command will list the contents of a directory without any error. If you see an error like "No such file or directory," it means you have likely booted in legacy BIOS mode and will need to restart and adjust your settings.

---

## 3. Set the Keyboard Layout (Optional)

The default keyboard layout in the live environment is US. If you are not using a US keyboard, this first command will help you find your specific layout.

```bash
ls /usr/share/kbd/keymaps/**/*.map.gz
```
*   Then, set your desired layout using `loadkeys`. For example, for a German keyboard:
    ```bash
    loadkeys de-latin1
    ```

---

## 4. Check Internet Connection

An internet connection is required to download the base system and other packages. We will first test if your wired Ethernet connection is working automatically, which it often does.

```bash
ping -c 3 archlinux.org
```

If you don't find success check your connection or connect WIFI

---
## 5. Setup WiFi Connection


1.  **Start `iw` Utility**

    ```bash
    iwctl
    ```

    After running this, your command prompt will change to `[iwd]#`, indicating you are now inside the `iwctl` utility.

2.  **List your Wi-Fi devices**

    This will show you the name of your wireless device, which is usually `wlan0`.

    ```bash
    device list
    ```

3.  **Scan for networks**

    Use the device name from the previous command. For example, if your device was `wlan0`, you would run:

    ```bash
    station wlan0 scan
    ```

4.  **List the available networks**

    This shows you the names (SSIDs) of the networks that were found.

    ```bash
    station wlan0 get-networks
    ```

5.  **Connect to your network**

    Replace `"Your_SSID"` with the name of your Wi-Fi network, keeping the double quotes.

    ```bash
    station wlan0 connect "Your_SSID"
    ```

    After you press Enter, you will be prompted to enter your Wi-Fi password. Type it in and press Enter.

6.  **Exit the utility**

    Once it has successfully connected, you can leave the `iwctl` tool.

    ```bash
    exit
    ```

    After you have exited `iwctl`, you will be back at the standard `#` prompt. Now, you should test your connection again. It should work now.

---

## 6. Update the System Clock

This command will ensure the system's clock is accurate by synchronizing it with network time servers. This is important to prevent potential errors when downloading and installing packages.

```bash
timedatectl set-ntp true
```

You can verify the status with:
```bash
timedatectl status | sed -n '1p;/NTP service/p;/System clock synchronized/p'
```

---
## 7. Partition the Disk (`/dev/nvme0n1`)  

1. List Partitions:

```bash
lsblk
```

2. Use `cfdisk`
```bash
cfdisk /dev/nvme0n1
```
- **Partition 1 (EFI System Partition)**: 512 MiB, type `EFI System`  
-   **Partition 2 (Btrfs)**: Remaining ~350.5 GiB,type `Linux filesystem`

---

## 8. Format Filesystems  

```bash
mkfs.fat -F32 /dev/nvme0n1p1
mkfs.btrfs -f /dev/nvme0n1p2
```

---

## 9.  Mount Btrfs Partition Temporarily and Create Subvolumes

```bash
mount /dev/nvme0n1p2 /mnt
cd /mnt
btrfs subvolume create @
btrfs subvolume create @home
btrfs subvolume create @opt
btrfs subvolume create @srv
btrfs subvolume create @tmp
btrfs subvolume create @log
btrfs subvolume create @spool
btrfs subvolume create @var_tmp
btrfs subvolume create @lv
btrfs subvolume create @lv_images
btrfs subvolume create @wd
btrfs subvolume create @wd_images
btrfs subvolume create @pkg
cd /
umount /mnt
```

---

## 10. Mount Subvolumes

Create mount points and mount with optimal options:
```bash
mount -o rw,relatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@ /dev/nvme0n1p2 /mnt
mkdir -p /mnt/{efi,home,opt,srv,tmp,var,var/log,var/spool,var/tmp,var/lib/libvirt,,var/lib/waydroid,var/cache/pacman/pkg}
mount -o rw,relatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@home /dev/nvme0n1p2 /mnt/home
mount -o rw,relatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@opt /dev/nvme0n1p2 /mnt/opt
mount -o rw,relatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@srv /dev/nvme0n1p2 /mnt/srv
mount -o rw,relatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@tmp /dev/nvme0n1p2 /mnt/tmp
mount -o rw,relatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@log /dev/nvme0n1p2 /mnt/var/log
mount -o rw,relatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@spool /dev/nvme0n1p2 /mnt/var/spool
mount -o rw,relatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@var_tmp /dev/nvme0n1p2 /mnt/var/tmp
mount -o rw,relatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@lv /dev/nvme0n1p2 /mnt/var/lib/libvirt
mount -o rw,relatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@wd /dev/nvme0n1p2 /mnt/var/lib/waydroid
mount -o rw,relatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@pkg /dev/nvme0n1p2 /mnt/var/cache/pacman/pkg
mkdir -p /mnt/{var/lib/libvirt/images,var/lib/waydroid/images}
mount -o rw,relatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@lv_images /dev/nvme0n1p2 /mnt/var/lib/libvirt/images
mount -o rw,relatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@wd_images /dev/nvme0n1p2 /mnt/var/lib/waydroid/images
mount /dev/nvme0n1p1 /mnt/efi
```

---

## 11. Setup `pacman.conf`

1.  **Open `pacman.conf`*
```bash
sudo nano /etc/pacman.conf
```

2. **Set parallel download values to 10 and add ILoveCandy flag**.
```nano
...
ParallelDownloads = 10
DownloadUser = alpm
#DisableSandbox
ILoveCandy
...
```

 
3.  **Uncomment the `[multilib]` section** 
Remove the `#` from the two lines so they look like this:
```ini
[multilib]
Include = /etc/pacman.d/mirrorlist
```

4.  **Save and exit:**
 If you're using `nano`, press `Ctrl + S` to save, press `Enter` to confirm the filename, and then press `Ctrl + X` to exit.

5.  **Update your package database:** 
```bash
sudo pacman -Sy
```

---

## 12. Initial `pacstrap`

```bash
pacstrap -K /mnt base base-devel linux-firmware linux linux-headers dkms amd-ucode btrfs-progs git nano bash-completion openssh tmux terminus-font
```
`786 MiB`

Zen Kernel:
```bash
pacstrap -K /mnt base base-devel linux-firmware linux-zen linux-zen-headers dkms amd-ucode btrfs-progs git nano bash-completion openssh tmux terminus-font
```
`808 MiB`



## 13. Generate fstab

This command generates the `fstab` (file systems table) file, which tells your system how to mount all the partitions and subvolumes you so carefully configured. We use the `-U` flag to identify drives by their UUIDs, which is more reliable than device names like `/dev/nvme0n1p2`.
```bash
genfstab -U /mnt >> /mnt/etc/fstab
```

---

## 14. Chroot into New System

This command, `arch-chroot`, will change the root directory from the live environment (/) to the system you've just installed (/mnt). From this point forward, every command you run will be configuring your actual Arch Linux installation on the hard drive.

```bash
arch-chroot /mnt
```

---

## 15. Disable CoW in Images Subvolumes

```bash
chattr -VR +C /var/lib/libvirt/images
chattr -VR +C /var/lib/waydroid/images
```

---

## 16. Set the Time Zone

We'll create a symbolic link that points to your time zone file. This ensures your system clock is correct.
```bash
ln -sf /usr/share/zoneinfo/Region/City /etc/localtime
```

Replace `Region/City` with your time zone. For example, to list time zones in Europe, you would use `ls /usr/share/zoneinfo/Europe`. If you live in Berlin, the command would be:
```bash
ln -sf /usr/share/zoneinfo/Asia/Kolkata /etc/localtime
```

---

## 17. Synchronize Hardware Clock**

```bash
hwclock --systohc
```

This command writes the current system time (which is now correctly set to your time zone) to the hardware clock, ensuring time is kept correctly even when the machine is powered off.

---

## 18. Configure the Locale**

1. **Open `local.gen`**
```bash
nano /etc/locale.gen
```

2. **Uncomment  US locale**  
From
```ini
#en_US.UTF-8 UTF-8
```

To
```ini
en_US.UTF-8 UTF-8
```

Once you have done that, press `Ctrl+S` and `Ctrl+X` to exit

---

## 19.  Generate the Locales**

```bash
locale-gen
```

This command will read the `/etc/locale.gen` file you just edited and create the necessary locale files. You should see it output the name of the locale you uncommented, confirming that it was successful. 

---

## 20. Set the System Language**

This command creates the configuration file that sets the primary language for the entire system.
```bash
echo "LANG=en_US.UTF-8" > /etc/locale.conf
```

You should replace `en_US.UTF-8` with the locale you uncommented in the previous step if you chose a different one. This ensures that system messages, programs, and the user interface will use the correct language.

---

## 21. Set the Hostname

The hostname is the name your computer will have on the network.

```bash
echo "right9xPC" > /etc/hostname
```

You can replace `"right9xPC"` with any name you prefer for your machine.

---

## 22. Configure the Hosts File

This command adds an entry to the hosts file that maps your new hostname to the local machine's IP address. This is a standard and important configuration step.
```bash
echo "127.0.1.1        right9xPC.localdomain        right9xPC" >> /etc/hosts
```

This ensures that network applications will run correctly. Just copy and paste the entire command block.

---

## 23. Create a New User

This command will create a new user and their home directory. It will also add them to the `wheel` group, which is the standard group for users who are allowed to perform administrative tasks with `sudo`.
```bash
useradd -m -G wheel,audio,video,optical,storage,kvm right9zzz
```

Set Password for new user:
```bash
passwd right9zzz
```

---

## 24. Allow `wheel` Group to Use `sudo`**

1. **Open `sudoers` file**
```bash
nano /etc/sudoers
# or EDITOR=nano visudo
```

2. **Uncomment wheel**
From
```ini
# %wheel ALL=(ALL:ALL) ALL
```

To
```ini
%wheel ALL=(ALL:ALL) ALL
```

Save and Exit.

- **Optional**: Set Display Name in `/etc/passwd`
```bash
nano /etc/passwd
```

Here `mrBRIGHTSID3` is the Display Name
```ini
right9zzz:x:1000:1000:mrBRIGHTSID3:/home/right9zzz:/bin/bash
```

---

## 25. Fix vconsolefonts and Generate the Initramfs

Set the Console Font

Edit /etc/vconsole.conf:
```bash
nano /etc/vconsole.conf
```
Add the following lines:
```nano
KEYMAP=us
FONT=ter-120b
```


The `mkinitcpio` command creates the initial RAM filesystem images for all the kernels you installed. The `-P` preset flag makes it do this for every kernel automatically (standard, lts, and zen).
```bash
mkinitcpio -P
```

---

## 26. Install Bootloader and System Utilities

```bash
pacman -S zram-generator grub efibootmgr networkmanager dosfstools bluez bluez-utils --needed
```
`25 MiB`

---

## 27. Configure ZRAM**

We will create a simple configuration file to enable ZRAM with sensible defaults.
```bash
echo -e "[zram0]\nzram-size = ram / 2\ncompression-algorithm = zstd\nswap-priority = 100" > /etc/systemd/zram-generator.conf
```

This single command creates the configuration file and tells ZRAM to:
*   Use the fast `zstd` compression algorithm (which matches our Btrfs compression).
*   Create a ZRAM device that is half the size of your total physical RAM.

This service will be automatically enabled and started on the next boot.

---

## 28. Setup Dual-Boot Support 

1. Install the required packages
```bash
pacman -S fuse3 ntfs-3g os-prober --needed
```
`1MiB`
*   **`os-prober`**: The script that detects other operating systems.
*   **`ntfs-3g`**: Allows Linux to read and write to the NTFS partitions used by Windows. This is required for `os-prober` to detect a Windows installation.
*   **`fuse3`**: A dependency for `ntfs-3g`.

2. Enable os-prober by uncommenting the last line in `/etc/default/grub`:
```bash
nano /etc/default/grub
```

3. Uncomment the line below:
```ini
GRUB_DISABLE_OS_PROBER=false
```

---

## 29. Install the GRUB Bootloader**

This command will install the necessary GRUB files to your EFI partition, making the system bootable.

```bash
grub-install --target=x86_64-efi --efi-directory=/efi --boot-directory=/boot --bootloader-id=right9ARCH --recheck
```

*   `--target=x86_64-efi`: Specifies we are installing for a 64-bit UEFI system.
*   `--efi-directory=/efi`: Tells GRUB where our EFI partition is mounted.
*   `--bootloader-id=right9ARCH`: Sets the name of the boot entry in the UEFI firmware.
*   `--recheck`: This tells grub-install to probe devices again, which can prevent certain errors.

If successful, the command should finish with the message "Installation finished. No error reported."

---

## 30. Generate GRUB Configuration File

```bash
grub-mkconfig -o /boot/grub/grub.cfg
```

This command will scan your system for kernels and other operating systems and write the results to `/boot/grub/grub.cfg`. You should see it detect your Arch Linux kernels and potentially other OSes if they exist.

- **Optional**: Repair FAT32 errors on esp partition
```bash
sudo fsck.fat -v -a /dev/nvme0n1p1 
```

---

## 31. Enable Network, Bluetooth and SSH Service**

```bash
systemctl enable NetworkManager
```
```bash
systemctl enable bluetooth.service
```
```bash
systemctl enable sshd.service
```

---
## 32. Enable Systemd Timesync Service

This ensures that your system's clock will be automatically synchronized over the network on every boot, which we previously configured with `timedatectl`.
```bash
systemctl enable systemd-timesyncd
```

---
## 33. Exit chroot and Reboot** 

1.  **Exit the Chroot Environment**
```bash
exit
```

2.  **Unmount All Partitions**
```bash
umount -R /mnt
```

3.  **Reboot**
```bash
reboot
```
4. Set Up `ssh` for root login
```nano
# Edit SSH configuration
sudo nano /etc/ssh/sshd_config

# Find and change this line:
#PermitRootLogin prohibit-password
PermitRootLogin yes

# Save and exit

# Restart SSH service
sudo systemctl restart sshd.service

# Set root password (if not already set)
sudo passwd root

```

**Crucially, remember to remove the installation USB drive as soon as the computer reboots.**

---

## 34.  Setup CachyOS Repos on Arch

```sh
# 1. Download the installer archive
curl -O https://mirror.cachyos.org/cachyos-repo.tar.xz

# 2. Extract the archive and enter the directory
tar xvf cachyos-repo.tar.xz && cd cachyos-repo

# 3. Run the installer script with sudo privileges
sudo ./cachyos-repo.sh

# 4. Do full system upgrade 
sudo pacman -Syu

# Remove obsolete folders and files
rm -rf cachyos-repo
rm -rf cachyos-repo.tar.xz
```
- This script auto-detects your CPU, configures the best CachyOS repositories, and backs up your existing pacman configuration.
- 
## 35. Setup Optimized cachyos Kernels

```bash
sudo pacman -S linux-cachyos linux-cachyos-headers linux-cachyos-server linux-cachyos-server-headers
```
`378 MiB`
Reboot.
- **Optional** if it's doesn't show regenerate `grub` config
```bash
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

Reboot Again
```bash
reboot
```

**OPTIONAL**: To fix the issue of saving grub preferences to last saved
1. **Open the file**
```bash
sudo nano /etc/default/grub
```

2. **Add or ensure these exact lines**
```ini
GRUB_DEFAULT=saved  
GRUB_SAVEDEFAULT=true  
GRUB_DISABLE_SUBMENU=y #optional
```


3. **Check lines exist (optional quick check)**
```
file=/etc/default/grub; for line in 'GRUB_DEFAULT=saved' 'GRUB_SAVEDEFAULT=true' 'GRUB_DISABLE_SUBMENU=y'; do grep -qxF "$line" "$file" || echo "MISSING: $line"; done
```

4. **Rebuild GRUB config**
```bash
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

5. **Verify saved default is active**
```bash
grep -q 'set default="${saved_entry}"' /boot/grub/grub.cfg && echo OK || echo MISSING
```

## 36. Install Essential Base CLI Programs


```bash
sudo pacman -S btop wget curl eza yazi fzf iwd wireless_tools tldr ncdu zoxide nethogs noto-fonts-emoji --needed
```
`25 MiB`

- `openssh` is the premier suite of tools for secure remote login and file transfer over an insecure network, like the internet. 
- `btop` is a modern, fast, and visually appealing resource monitor for the terminal. It provides a comprehensive and real-time overview of your system's performance.
- `wget` and `curl` Both are command-line tools used to transfer data from or to a server. They are essential for downloading files, testing APIs, and automating web-related tasks.
- `eza` is a modern and feature-rich replacement for the classic `ls` command. It is written in Rust, which makes it very fast.
- `yazi` is a blazingly fast terminal-based file manager, also written in Rust. It provides a visual, multi-pane interface for managing your files and directories directly within the terminal, similar to classic tools like `ranger` or `midnight commander`, but with a focus on speed and modern features.
* `fzf` is an interactive, general-purpose fuzzy finder for the command line. "Fuzzy finding" means you can type a few scattered characters from a filename or command, and `fzf` will intelligently find all the matching lines.
- `iwd` (iNet Wireless Daemon) is a modern wireless daemon for Linux developed by Intel. It aims to be a lightweight and efficient replacement for `wpa_supplicant`, which has been the standard for many years.
- `wireless_tools` This package provides a set of classic, simple tools for configuring wireless network interfaces. It includes utilities like `iwconfig` and `iwlist`. While `iwd` and the newer `iw` command are now preferred for managing connections, `wireless_tools` can still be useful for quick diagnostics and simple scripting.
- `tldr` (Too Long; Didn't Read) is a community-driven project that provides simplified, practical examples for command-line tools. While `man` pages are comprehensive and technically detailed, `tldr` pages give you just the common, practical examples you need to get started.

## 37. Setup Firewall

```bash
sudo pacman -S ufw
sudo systemctl enable --now ufw
sudo ufw enable
sudo ufw allow 22/tcp # or sudo ufw allow ssh
sudo ufw limit ssh # rate-limit brute force
```

---

## 38. Setup  Btrfs Subvolumes for Important HOME Directories 

1. **Current subvolumes Status**
```bash
sudo btrfs su list /
sudo btrfs filesystem label / RIGHT9ARCH # setup file system label
sudo btrfs filesystem usage / # to see system usage
```

2. **Create required subvolumes**
```bash
sudo btrfs subvolume create --parents ~/.zen
sudo btrfs subvolume create --parents ~/.mozilla
sudo btrfs subvolume create --parents ~/.config/BraveSoftware
sudo btrfs subvolume create --parents ~/.config/chromium
sudo btrfs subvolume create --parents ~/.config/vivaldi 
sudo btrfs subvolume create --parents ~/.config/VSCodium
sudo btrfs subvolume create --parents ~/.vscode-oss
sudo btrfs subvolume create --parents ~/.vscode
sudo btrfs subvolume create --parents ~/.config/qBittorrent
sudo btrfs subvolume create --parents ~/.local/share/qBittorrent
sudo btrfs subvolume create --parents ~/Downloads
sudo btrfs subvolume create --parents ~/.local/share/fonts
sudo btrfs subvolume create --parents ~/.config/vesktop
sudo btrfs subvolume create --parents ~/.cache/yay
sudo btrfs subvolume create --parents ~/.abdm
sudo btrfs subvolume create --parents ~/.local/share/AyuGramDesktop
sudo btrfs subvolume create --parents ~/.ssh
sudo btrfs subvolume create --parents ~/Z
sudo btrfs subvolume create --parents ~/.var/app
```

3. **Change ownership to `$USER`**
```bash
sudo chown -Rv $USER:  ~/.zen ~/.mozilla ~/.config/BraveSoftware ~/.config/chromium ~/.config/vivaldi ~/.config/VSCodium ~/.vscode-oss ~/.vscode ~/.config/qBittorrent ~/.local/share/qBittorrent ~/Downloads ~/.local ~/.local/share/fonts ~/.config/vesktop ~/.cache/yay ~/.abdm ~/.local/share/AyuGramDesktop ~/.ssh ~/Z ~/.var/app ~/ /var/lib/libvirt /var/lib/waydroid /var/lib/libvirt/images /var/lib/waydroid/images

```

---

## 39. Set Up yay for AUR access**

1. **Clone YAY repo and install ya**y
```bash
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si
```

2. Remove `yay` Directory
```bash
rm -rf yay
```

3.  **Open `pacman.conf`*
```bash
sudo nano /etc/pacman.conf
```

2. **Set parallel download values to 10 and add ILoveCandy flag**.
```nano
...
ParallelDownloads = 10
DownloadUser = alpm
#DisableSandbox
ILoveCandy
...
```

3.  **Uncomment the `[multilib]` section** 
Remove the `#` from the two lines so they look like this:
```ini
[multilib]
Include = /etc/pacman.d/mirrorlist
```

4.  **Save and exit:**
 If you're using `nano`, press `Ctrl + S` to save, press `Enter` to confirm the filename, and then press `Ctrl + X` to exit.

5.  **Update your package database:** 
```bash
sudo pacman -Sy
```

---

### OPTIONAL : SETUP `chaotic-aur`
1. **Retrieving the primary key to enable the installation of our keyring and mirror list**
```bash
sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
sudo pacman-key --lsign-key 3056513887B78AEB
```

2. **Install our chaotic-keyring and chaotic-mirrorlist packages**
```bash
sudo pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst'
sudo pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
```

3. **Append (adding at the end) the following to` /etc/pacman.conf`**
```ini
[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist
```

4. **Sync package list**
```bash
sudo pacman -Syy
```

---

## 40. Setup Snapper

1. **Install Required Packages**
```bash
sudo pacman -S snapper grub-btrfs inotify-tools plocate smartmontools dialog --needed 
```

2. **Now Setup Snapper for `root` and `home` sub volumes**
```bash
sudo snapper -c root create-config /
sudo snapper -c home create-config /home
sudo snapper list-configs
```

3. **Allow `$user` to manage snapshots**
```bash
sudo snapper -c root set-config ALLOW_USERS="$USER" SYNC_ACL=yes
sudo snapper -c root set-config ALLOW_USERS="$USER" SYNC_ACL=yes
```

4. **Edit `/etc/updatedb.conf` to add `.snapshots` to PRUNENAMES so it is not indexed in the system by locate/plocate**
```bash
sudo nano /etc/updatedb.conf
```

5. **Disable Automatic timeline snapshots**
```bash
sudo systemctl disable --now snapper-timeline.timer snapper-cleanup.timer
```

---

## 41. Enable OverlayFS in mkinitcpio.conf

Booting a Btrfs snapshot from the boot menu is read‑only, so the system can’t write to essential folders like /var or /tmp; enabling the overlay hook lets the initramfs put a temporary, RAM‑backed “write layer” on top so everything can run normally without changing the snapshot.

1. **Edit `mkinitcpio.conf`**
```bash
sudo nano /etc/mkinitcpio.conf
```

2. **Add `grub-btrfs-overlayfs` in `HOOKS`**
```ini
HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block filesystems fsck grub-btrfs-overlayfs)
```

3. **Regenrate initramfs**
```bash
sudo mkinitcpio -P
```

---

## 42. Setup Zsh

1. **Install Core Dependencies**
```bash
sudo pacman -S zsh git fzf zoxide --needed
```

2. **Install Oh My Zsh**
```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

3. **Install Additional Tools and Plugins**

```bash
# For Powerlevel10k Theme
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

# For Autosuggestions (Fish-like suggestions)
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

# For Syntax Highlighting
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

# For FZF Tab Completion
git clone https://github.com/Aloxaf/fzf-tab ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/fzf-tab

# For additional community completions
git clone https://github.com/zsh-users/zsh-completions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-completions

# For history substring search
git clone https://github.com/zsh-users/zsh-history-substring-search ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-history-substring-search

# For notifications on long-running commands
git clone https://github.com/MichaelAquilina/zsh-auto-notify.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/auto-notify
```

4. **Install helper applications**
```bash
sudo pacman -S bat thefuck nitch zsh-theme-powerlevel10k zsh-completions auto-notify --needed
```

5. **Configure `.zshrc`**
```bash
nano ~/.zshrc
```

6. **Delete all existing content and paste the following**

```ini
# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Oh My Zsh path
export ZSH="$HOME/.oh-my-zsh"

# Theme
ZSH_THEME="powerlevel10k/powerlevel10k"

# Plugins
plugins=(
    git
    fzf-tab
    zsh-history-substring-search
    zsh-completions
    zsh-autosuggestions
    auto-notify
    zsh-syntax-highlighting
)

# Load Oh My Zsh
source $ZSH/oh-my-zsh.sh

# FZF Customization (with preview on right using bat)
export FZF_DEFAULT_OPTS='
  --layout=reverse
  --info=inline
  --border=rounded
  --margin=1
  --padding=1
  --height=80%
  --preview-window=right:60%
  --preview="bat --color=always --style=numbers --line-range :500 {}"
'

# Run nitch on startup
nitch
export QT_QPA_PLATFORMTHEME=qt6ct

# Aliases
alias i="yay -S"
alias s="yay"
alias r="yay -Rsu"
alias hyprc="hyprctl clients"
alias gc="git clone"
alias codehypr="code $HOME/.config/hypr/"
alias codezzz='code "$HOME/Downloads/00 - Vaults/00 - right9zZz/"'
alias cat='bat'

# Key bindings for fzf
if [ -f /usr/share/fzf/key-bindings.zsh ]; then
    source /usr/share/fzf/key-bindings.zsh
fi

# Initialize tools
eval "$(zoxide init zsh)"
eval $(thefuck --alias)

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Setup eza alias
alias ld='eza -lD'
alias lf='eza -lF --color=always | grep -v /'
alias lh='eza -dl .* --group-directories-first'
alias ll='eza -al --group-directories-first'
# alias ls='eza -alF --color=always --sort=size | grep -v /'
alias lt='eza -al --sort=modified'

```

7. **Set Zsh as Default Shell**
```bash
chsh -s $(which zsh)
```

Log out and log back in or reboot to setup power10ktheme.

---

## 43. Enable Grub Btrfs Service**

It's essential for snapshots to register in grub menu. 
```bash
sudo systemctl enable --now grub-btrfsd.service
reboot
```

---

## 44. Take Inital `Base System` Snapshot

```bash
sudo snapper -c root create --description "Base System" --cleanup-algorithm empty
sudo snapper -c home create --description "Base System" --cleanup-algorithm empty

```

--cleanup-algorithm empty make sure the snapshot is not deleted automatically.

---

## 45. Setup Graphics and Display**

1. **First we setup for integrated `amdgpu`**
```bash
sudo pacman -S --needed xorg-server xorg-xinit mesa libva-mesa-driver vulkan-radeon vulkan-mesa-layers lib32-mesa lib32-vulkan-radeon lib32-vulkan-mesa-layers mesa-utils vulkan-tools xf86-video-amdgpu  nvtop
```
`156MiB`

```bash
yay -S libva-vdpau-driver lib32-libva-vdpau-driver
```
- `xorg-server`: The X11 display server that provides the graphical session backend for desktop environments and window managers.  
- `xorg-xinit`: Utilities (like startx) to start X sessions manually or from minimal setups.  
- `mesa`: Open-source OpenGL implementation and Gallium drivers that provide 3D acceleration on AMD GPUs.  
- `libva-mesa-driver`: VA-API implementation via Mesa to enable hardware-accelerated video decode/encode on AMD.  
- `vulkan-radeon`: RADV Vulkan driver for AMD GPUs, enabling Vulkan support for native apps and games.  
- `vulkan-mesa-layers`: Useful Vulkan layers (validation, overlays, etc.) that aid compatibility and debugging.  
- `lib32-mesa`: 32-bit OpenGL libraries needed by 32-bit applications, Proton, and Wine on a 64-bit system.  
- `lib32-vulkan-radeon`: 32-bit RADV Vulkan driver for running 32-bit Vulkan apps and Proton titles.  
- `lib32-vulkan-mesa-layers`: 32-bit Vulkan layers matching the native set for compatibility with 32-bit workloads.  
- `mesa-utils`: Small OpenGL tools (e.g., glxinfo, glxgears) to verify and troubleshoot OpenGL acceleration.  
- `vulkan-tools`: Vulkan utilities (e.g., vulkaninfo/vkinfo) to inspect and verify Vulkan drivers and capabilities.  
- `xf86-video-amdgpu`: Optional AMD-specific Xorg DDX driver that can help with features like TearFree and certain hardware quirks (most systems are fine with the generic modesetting driver).  
- `libva-vdpau-driver`: Translation layer to expose VDPAU through VA-API for better compatibility with some media stacks.  
- `lib32-libva-vdpau-driver`: 32-bit counterpart of the VA-API↔VDPAU translation layer for 32-bit apps.  
- `nvtop`: Terminal-based GPU usage monitor that supports AMD, useful for tracking load, clocks, and temperature.

2. **Next we Setup `nvidia-gpu`**
```bash
sudo pacman -S --needed linux-cachyos-nvidia linux-cachyos-server-nvidia nvidia-utils lib32-nvidia-utils nvidia-prime nvidia-settings egl-wayland vulkan-icd-loader lib32-vulkan-icd-loader opencl-nvidia
```

- `nvidia-dkms equivalent for cachyos kernels`: Builds the proprietary NVIDIA kernel module against installed kernels automatically, avoiding breakage on kernel updates.
- `nvidia-utils`: NVIDIA userspace libraries and tools (e.g., nvidia-smi) required for OpenGL/Vulkan and runtime functionality.
- `lib32-nvidia-utils`: 32‑bit NVIDIA userspace libraries for Proton/Wine/legacy 32‑bit games and apps.
- `nvidia-prime`: Convenience wrapper (prime-run) and helpers to launch applications on the discrete NVIDIA GPU via PRIME Render Offload.
- `nvidia-settings`: NVIDIA X Server Settings GUI and CLI to inspect and adjust GPU parameters and profiles.
- `egl-wayland`: EGL backend for Wayland compositors to improve compatibility and performance of NVIDIA on Wayland.
- `vulkan-icd-loader`: The Vulkan loader that selects and dispatches to the correct Vulkan driver (ICD) at runtime.
- `lib32-vulkan-icd-loader`: 32‑bit Vulkan loader for 32‑bit Vulkan applications and Proton titles.
- `opencl-nvidia`: NVIDIA OpenCL implementation (ICD) for GPU compute in apps like Blender, some video tools, and scientific workloads.

3. **To manage both `gpu`**
```bash
sudo pacman -S power-profiles-daemon
yay -S envycontrol 
```

4. **Edit GRUB kernel parameters**
```bash
sudo nano /etc/default/grub
```

5. **Enable NVIDIA DRM KMS at boot for smoother modesetting and compositor compatibility appended `nvidia-drm.modeset=1` (and optionally `nvidia-drm.fbdev=1`) to `GRUB_CMDLINE_LINUX_DEFAULT`**
```ini
...
GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 hibernate.compressor=lz4 quiet nvidia-drm.modeset=1 nvidia-drm.fbdev=1"
...
```

6. **Generate `grub` config**
```bash
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

7. **Edit `mkinitcpio.conf` to enable nvidia modules**
```bash
sudo nano /etc/mkinitcpio.conf
```

6. **Add `MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)`**
```ini
...
MODULES=(btrfs nvidia nvidia_modeset nvidia_uvm nvidia_drm)
...
```

7. Rebuild `mkinitcpio.conf`
```bash
sudo mkinitcpio -P
```

- **OPTIONAL**: If its a VM setup:
```bash
sudo  pacman -S xorg-server xorg-xinit mesa vulkan-swrast --needed
```

---

## 42. Take a Snapshot with Base+Graphics

```bash
sudo snapper -c root create --description "Base System+Graphics" --cleanup-algorithm empty
sudo snapper -c home create --description "Base System+Graphics" --cleanup-algorithm empty
```

---

## 43. Set Audio System

```bash
sudo pacman -S \
pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber gst-plugin-pipewire libpulse \
alsa-utils rtkit \
lib32-pipewire lib32-pipewire-jack lib32-libpulse
```
`33MiB`
- pipewire: The core multimedia server providing unified audio/video routing, low-latency processing, and screen capture infrastructure on Linux.
- pipewire-alsa: ALSA compatibility layer that redirects ALSA clients to PipeWire so legacy apps work without changes.
- pipewire-pulse: Drop-in PulseAudio server replacement so PulseAudio apps talk to PipeWire transparently.
- pipewire-jack: JACK compatibility so JACK-aware apps can use PipeWire without a separate JACK server.
- wireplumber: The modern PipeWire session and policy manager that handles device discovery, profiles, and routing decisions.
- gst-plugin-pipewire: GStreamer plugin enabling multimedia apps to use PipeWire for audio/video paths and screen capture.
- libpulse: PulseAudio client library needed by applications to communicate with the PulseAudio (on PipeWire) server.
- alsa-utils: Essential ALSA tools like alsamixer and speaker-test for device control and troubleshooting.
- rtkit: Grants real-time scheduling to user processes (like audio) to reduce latency and avoid dropouts.    
- lib32-pipewire: 32-bit PipeWire client libraries so multilib apps (e.g., Wine/Steam) can access PipeWire. 
- lib32-pipewire-jack: 32-bit JACK compatibility libraries for 32-bit apps to use PipeWire’s JACK layer.
- lib32-libpulse: 32-bit PulseAudio client library for 32-bit applications to talk to the Pulse server on PipeWire.

---

## 44. Take a Snapshot with Base+Graphics+Audio**

```bash
sudo snapper -c root create --description "Base System+Graphics+Audio" --cleanup-algorithm empty
sudo snapper -c home create --description "Base System+Graphics+Audio" --cleanup-algorithm empty
```

---

## 45.  Setup Desktop Environment

For `Gnome`
```bash
sudo pacman -S gnome-shell gnome-control-center  gnome-terminal nautilus gnome-tweaks gnome-browser-connector gnome-shell-extension-appindicator network-manager-applet xdg-utils pavucontrol sddm unrar ark gnome-screenshot extension-manager gnome-browser-connector#gdm
```

```bash
sudo pacman -S gvfs gvfs-afc gvfs-dnssd gvfs-goa gvfs-google gvfs-gphoto2 gvfs-mtp gvfs-nfs gvfs-onedrive gvfs-smb gvfs-wsdd
```

For `KDE`

```bash
sudo  pacman -S plasma-meta konsole kate dolphin ark plasma-workspace network-manager-applet xdg-utils pavucontrol sddm unrar
```
```bash
sudo pacman -S kio-extras kio-gdrive --needed 
```

---

## 46. Enable SDDM**
```bash
sudo systemctl enable --now sddm
```

---

## 47. Take A Snapshot with Base+Graphics+Audio+DE basic**

For `GNOME`
```bash
sudo snapper -c root create --description "Base System+Graphics+Audio+GNOME basic" --cleanup-algorithm empty
sudo snapper -c home create --description "Base System+Graphics+Audio+GNOME basic" --cleanup-algorithm empty
```

For `KDE`
```bash
sudo snapper -c root create --description "Base System+Graphics+Audio+KDE basic" --cleanup-algorithm empty
sudo snapper -c home create --description "Base System+Graphics+Audio+KDE basic" --cleanup-algorithm empty
```

---

## 48. Install Basic Utilities

```bash
sudo pacman -S udiskie 7zip fastfetch pandoc grim slurp satty wl-clipboard network-manager-applet pandoc
```

```bash
yay -S cachyos-rate-mirrors cachyos-hello cachyos-kernel-manager
```

**Optional**: To Setup  fast mirrors with `rate-mirror`:
```bash
sudo rate-mirrors --allow-root --protocol https arch | grep -v '^#' | sudo tee /etc/pacman.d/mirrorlist
```

## 49. Install Your 
bind = ,XF86Calculator, exec, grim -g "$(slurp)" - | satty --filename - --output-filename ~/Pictures/Screenshots/Screenshot_$(date +'%F_%T').png#--copy-command wl-copy
bind = $mainMod, XF86Calculator, exec, grim - | satty --filename - --output-filename ~/Pictures/Screenshot_$(date +'%F_%T').png
bind = $mainMod+Alt, XF86Calculator, exec, bash -c 'grim - | tee ~/Pictures/Screenshot_$(date +%F_%H-%M-%S).png | wl-copy'
bind = $mainMod SHIFT, XF86Calculator, exec, grim -g "$(slurp)" - | tesseract stdin stdout -l eng | wl-copy
WorkFlow Programs

2. Install Official repo packages:
```bash
sudo  pacman -S ghostty chromium qbittorrent nicotine+ vlc vlc-plugins-all mpv calibre obsidian code scrcpy --needed
```

  * **ghostty:** A fast, feature-rich terminal emulator.
  * **chromium:** An open-source web browser developed by Google.
  * **qbittorrent:** A free and open-source BitTorrent client.
  * **nicotine+:** A graphical client for the Soulseek peer-to-peer network.
  * **vlc:** A highly portable multimedia player and framework.
  * **vlc-plugins-all:** All available plugins for VLC.
  * **mpv:** A free, open-source, and cross-platform media player.
  * **calibre:** An open-source e-book management tool.

2. Install AUR packages:
```bash
yay -S zen-browser-bin brave-bin ab-download-manager ayugram-desktop vesktop-bin stremio sioyek localsend-bin kdenlive obs-studio btrfs-assistant --needed
```
* **zen-browser-bin:** A web browser focusing on privacy and security.
* **brave-bin:** A web browser that blocks ads and website trackers by default.
* **ab-download-manager-bin:** An advanced download manager.
* **ayugram-desktop:** A Telegram client with additional features.
* **vesktop-bin:** A Discord client with enhanced features and theming.
* **stremio:** An application for streaming video content.
* **sioyek:** A PDF viewer with a focus on a clean user interface.
* **localsend-bin:** A free and open-source cross-platform app to securely share files and messages to nearby devices.
* **kdenlive:** A free and open-source video editing software.
* **obs-studio:** Software for video recording and live streaming.
* **btrfs-assistant:** A graphical tool for managing Btrfs filesystems.

3. Install optional programs:
```bash
sudo  pacman -S filezilla mission-center neovim 7zip --needed
```

- **filezilla:** A free FTP solution.
* **mission-center:** A system monitor similar to Windows Task Manager.
* **neovim:** A Vim-based text editor with modern features.
* **7zip:** A file archiver with high compression ratios.

4. Install optional AUR packages
```bash
yay -S showmethekey-git spotify-adblock-git koreader-appimage auto-cpufreq overskride-bin qpdfview pimpmystremio-bin gemini-cli --needed
```

  * **showmethekey-git:** A utility to show key presses on screen for screen recording.
  * **spotify-adblock-git:** A tool to block ads on Spotify.
  * **koreader-bin:** An e-book reader application.
  * **auto-cpufreq:** An automatic CPU speed and power optimizer for laptops.
  * **overskride-bin:** A utility to manage Bluetooth
  * **qpdfview:** A simple tabbed document viewer.
  * **pimpmystremio-bin:** An addon manager for Stremio.

---

## 50. Setup flathub

1. **Install Flatpak**
```bash
sudo pacman -S flatpak
```

2. **Add the Flathub Repository**
```bash
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
```

3. **Install Flatpak Applications(Wearhouse & Flatseal)** 
```bash
flatpak install flathub io.github.flattool.Warehouse flathub com.github.tchx84.Flatseal
```

---

## 51. Gaming Setup

```bash
yay -S --needed --noconfirm \
wine winetricks steam lutris goverlay \
gnutls lib32-gnutls base-devel gtk2 gtk3 lib32-gtk2 lib32-gtk3 \
libpulse lib32-libpulse alsa-lib lib32-alsa-lib alsa-utils alsa-plugins lib32-alsa-plugins \
giflib lib32-giflib libpng lib32-libpng \
libldap lib32-libldap openal lib32-openal \
libxcomposite lib32-libxcomposite libxinerama lib32-libxinerama \
ncurses lib32-ncurses vulkan-icd-loader lib32-vulkan-icd-loader \
ocl-icd lib32-ocl-icd libva lib32-libva \
gst-plugins-base-libs lib32-gst-plugins-base-libs \
sdl2 lib32-sdl2 v4l-utils lib32-v4l-utils \
sqlite lib32-sqlite protonplus lib32-gamemod
```

---

## 52. Virtualization Setup

1. **Install Required Packages**
```bash
sudo pacman -S qemu-full libvirt virt-manager edk2-ovmf dnsmasq iptables-nft dmidecode bridge-utils swtpm virt-install virt-viewer libosinfo guestfs-tools qemu-img --needed
```

- `qemu-full`: Meta package pulling QEMU with KVM acceleration and most device backends to run diverse guest OSes.
- `libvirt`: Virtualization API/daemon that manages VMs, storage, networks, and interfaces for QEMU/KVM.
- `virt-manager`: GTK GUI to create, configure, and control libvirt-managed virtual machines.
- `edk2-ovmf`: UEFI firmware binaries (OVMF) used to boot UEFI guests under QEMU/KVM.
- `dnsmasq`: Lightweight DNS/DHCP/TFTP service used by libvirt for NATed virtual networks.
- `iptables-nft`: nftables-based iptables compatibility layer used by libvirt for VM network NAT/firewall rules(yes, replace iptables).
- `dmidecode`: Tool to read SMBIOS/DMI data; helps virt-manager/libvirt detect host capabilities and templates.
- `bridge-utils`: Utilities to create and manage Linux Ethernet bridges for bridged VM networking to the LAN.
- `swtpm`: Software TPM emulator providing vTPM 1.2/2.0 devices to guests (useful for Windows 11, secure boot tests).
- `virt-install`: CLI tool to create and install VMs via libvirt with reproducible command lines.
- `virt-viewer`: Lightweight console viewer to connect to libvirt VMs’ SPICE/VNC displays.
- `libosinfo`: Database of OS metadata enabling automatic defaults (CPU, devices, drivers) in virt tools.
- `guestfs-tools`: Tools for inspecting and editing VM disk images offline (mount, copy, edit files).
- `qemu-img`: Utility to create, convert, resize, and inspect virtual disk images (qcow2, raw, vmdk, etc.).

2. **Enable LibVirt Services**
```bash
sudo systemctl enable --now libvirtd.service
sudo usermod -aG libvirt "$USER"
newgrp libvirt
```

- `sudo systemctl enable --now libvirtd.service` Enables the libvirt daemon to start at boot and starts it immediately, so tools like virt-manager can manage VMs via qemu:///system right away.
- `sudo usermod -aG libvirt "$USER"`  Adds the current user to the libvirt Unix group, allowing non‑root management of VMs and networks through libvirt’s RW socket without needing sudo each time.
- `newgrp libvirt`  Opens a new shell with updated group membership so the added libvirt group takes effect immediately, avoiding a full logout/login cycle

---

## 53. Waydroid Setup


1. Install Necessary Packages
```bash
yay -S waydroid # binder_linux-dkms for kernels that dont have binder
```

````optional for kernel without headers
Load Binder Module (**For Kernels without binder only**)
```bash
sudo modprobe binder_linux devices=binder,hwbinder,vndbinder  # some kernels use module name `binder` instead of `binder_linux`
```
binder module load (modprobe binder_linux …): Not needed and typically fails as “busy” because binder is already built-in/initialized on linux-zen.

Create and mount binderfs (**For Kernels without binder only**)
```bash
sudo mkdir -p /dev/binderfs && sudo mount -t binder none /dev/binderfs
```
create and mount binderfs: Do not mkdir/mount binderfs manually; Waydroid’s current setup handles binder nodes without manual mounts on Arch with linux-zen.

Persist binder module at boot (**For Kernels without binder only**)
```bash
echo binder_linux | sudo tee /etc/modules-load.d/waydroid.conf
# if your kernel uses `binder` instead:
# echo binder | sudo tee /etc/modules-load.d/waydroid.conf
```
persist binder module at boot: Do not write binder or binder_linux into /etc/modules-load.d; linux-zen already includes binder, so forcing module loads is unnecessary

Persist binderfs mount (**For Kernels without binder only**)
```bash
echo 'none /dev/binderfs binder nofail 0 0' | sudo tee -a /etc/fstab
```
persist binderfs mount in /etc/fstab: Avoid binderfs entries; modern Waydroid/zen do not require fstab mounts and incorrect entries can cause boot issues
````

2. **Enable and start the container**
```bash
sudo systemctl enable --now waydroid-container
```

3. Initialize images
```bash
sudo waydroid init -i /etc/lib/waydroid/images
# sudo waydroid init             # vanilla
# or with Google apps (if available for your image):
# sudo waydroid init -s GAPPS
```

4. **Launch and Verify**
```bash
# start the background services and session
waydroid session start &
# show the full Android UI window
waydroid show-full-ui
# optional: check binder devices and module
lsmod | grep binder; mount | grep binder; ls -l /dev/binderfs
```

5. **Update Image Later**
```bash
sudo waydroid upgrade
```

## 54. WiFi Pentest Setup

```bash
yay -S aircrack-ng hcxtools hashcat seclists cuda rocm-opencl-runtime --needed
```

## 55. Mega App Repo Setup

1. **Add the MEGA GPG key**
```bash
sudo pacman-key --recv-keys 1A664B787094A482
sudo pacman-key --lsign-key 1A664B787094A482
```

2. **Edit `pacman.conf`**
```bash
sudo nano /etc/pacman.conf
```

3.  **Add the following lines at the end of the file. This creates a new repository entry for MEGA's packages**
```
[DEB_Arch_Extra]
SigLevel = PackageRequired
Server = https://mega.nz/linux/repo/Arch_Extra/$arch
```

4.  Save and close the file. In `nano`, press `Ctrl + X`, then `Y`, and `Enter`.

5. Update Package List and Install MEGAsync
```bash
sudo pacman -Syy
sudo pacman -S megasync nautilus-megasync
```


This process will also install the necessary dependencies, including **megacmd** (the command-line interface for MEGA) and **megasync**, the GUI application.

---

