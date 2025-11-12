# THE ULTIMATE GPU PASSTHROUGH SETUP GUIDE
## Lenovo IdeaPad Gaming 3 15ARH7 (Model 82SB) - Complete Setup from Scratch

**Hardware**: AMD Ryzen 5 6600H | NVIDIA RTX 3050 Mobile | AMD Radeon 660M | 16GB RAM | 512GB NVMe  
**Host OS**: Arch Linux (CachyOS Kernel 6.16.8) + Hyprland (Wayland)  
**Guest OS**: Windows 10 with GPU Passthrough  
**Display Solution**: Looking Glass (seamless VM display without hardware capture)

---

## TABLE OF CONTENTS

**PHASE 1**: Pre-Installation Checklist & BIOS Configuration  
**PHASE 2**: Arch Linux Kernel Configuration & VFIO Setup  
**PHASE 3**: Libvirt & KVM Installation  
**PHASE 4**: Hugepages & Performance Tuning  
**PHASE 5**: Looking Glass Installation  
**PHASE 6**: Windows 10 VM Creation & Configuration  
**PHASE 7**: Advanced Optimizations  
**PHASE 8**: Automation & Lifecycle Management  
**PHASE 9**: Troubleshooting & Verification  
**PHASE 10**: Final Testing & Benchmarking

**Estimated Total Time**: 4-6 hours (first-time setup)

***

# PHASE 1: PRE-INSTALLATION CHECKLIST & BIOS CONFIGURATION

## Step 1.1: Hardware Verification

**Verify your exact hardware configuration**:[2][10]

```bash
# System information
sudo dmidecode -t system | grep -E "Manufacturer|Product Name|Version"

# CPU verification
lscpu | grep -E "Model name|Thread|Core"

# GPU detection
lspci | grep -E "VGA|3D|Display"

# Expected output:
# 00:08.1 VGA compatible controller: Advanced Micro Devices, Inc. [AMD/ATI] Rembrandt [Radeon 660M] (rev c1)
# 01:00.0 VGA compatible controller: NVIDIA Corporation GA107M [GeForce RTX 3050 Mobile] (rev a1)
# 01:00.1 Audio device: NVIDIA Corporation GA107 High Definition Audio Controller (rev a1)
```

**Get NVIDIA device IDs** (critical for later configuration):

```bash
lspci -nn | grep -i nvidia

# Expected output:
# 01:00.0 VGA compatible controller [0300]: NVIDIA Corporation GA107M [GeForce RTX 3050 Mobile] [10de:25a2] (rev a1)
# 01:00.1 Audio device [0403]: NVIDIA Corporation GA107 High Definition Audio Controller [10de:2291] (rev a1)
```

**Write down these IDs**: `10de:25a2` (GPU) and `10de:2291` (Audio)

***

## Step 1.2: BIOS Configuration

**Access Lenovo BIOS**:[11][2]

1. **Restart computer**
2. Press **F2** or **Fn+F2** repeatedly during boot
3. Navigate to BIOS settings

**Required BIOS Settings**:[3][7][11]

| Setting | Required Value | Location |
|---------|---------------|----------|
| **AMD-V / SVM Mode** | Enabled | Configuration → Virtualization |
| **IOMMU / AMD-Vi** | Enabled | Configuration → AMD IOMMU (may be hidden) |
| **Above 4G Decoding** | Enabled | Advanced → PCI Subsystem Settings |
| **Resizable BAR** | Enabled | Advanced → PCI Subsystem Settings |
| **CSM Support** | Disabled | Boot → CSM Configuration |
| **Secure Boot** | Disabled | Security → Secure Boot |
| **Fast Boot** | Disabled | Boot Configuration |

**⚠️ Important Notes**:[12][11]
- Lenovo IdeaPad Gaming 3 may **hide IOMMU settings** in standard BIOS
- If "IOMMU" option not visible, it may be **enabled by default** on Ryzen 6000 series
- Some settings may not exist in your BIOS version (JNCN52WW V2.12)

**Save and Exit** → Computer will reboot

***

## Step 1.3: Verify IOMMU is Active (After BIOS Changes)

**After reboot, check if IOMMU is working**:

```bash
# Check kernel logs for IOMMU
dmesg | grep -i "IOMMU\|AMD-Vi"

# Expected output (should contain):
# AMD-Vi: Found IOMMU cap 0x40
# AMD-Vi: Interrupt remapping enabled
# AMD-Vi: Virtual APIC enabled
# perf/amd_iommu: Detected AMD IOMMU #0 (2 banks, 4 counters/bank)
```

**If you see these messages**, IOMMU is working! Proceed to next phase.

**If you see nothing**:[13][14]
- IOMMU may be disabled in BIOS
- Try updating BIOS to latest version[15]
- Check Lenovo support forums for BIOS unlock methods[11]

***

## Step 1.4: Check IOMMU Groups

**Verify NVIDIA GPU can be isolated**:[16][17]

```bash
# List all IOMMU groups
for d in /sys/kernel/iommu_groups/*/devices/*; do 
    n=${d#*/iommu_groups/*}; n=${n%%/*}
    printf 'IOMMU Group %s ' "$n"
    lspci -nns "${d##*/}"
done | sort -V | grep -E "01:00|VGA|NVIDIA"
```

**Ideal output**:[18][19]
```
IOMMU Group X 01:00.0 VGA compatible controller [0300]: NVIDIA Corporation GA107M [10de:25a2]
IOMMU Group X 01:00.1 Audio device [0403]: NVIDIA Corporation GA107 [10de:2291]
```

**✓ Perfect**: GPU and audio in same group, isolated  
**⚠️ Warning**: If GPU shares group with other devices, you may need ACS override patch[20]

***

## Step 1.5: Storage Preparation

**Check disk space and prepare VM storage**:[21]

```bash
# Check Btrfs usage
df -h /

# Expected: You have ~91% used, need to free space
# Minimum required: 80GB for Windows VM + drivers
```

**Create dedicated Btrfs subvolume for VMs**:[22][21]

```bash
# Create subvolume
sudo btrfs subvolume create /vm-images

# Disable Copy-on-Write (essential for VM performance)
sudo chattr +C /vm-images

# Verify CoW is disabled
lsattr -d /vm-images
# Should show: ---------------C------ /vm-images

# Create directory structure
sudo mkdir -p /vm-images/iso
sudo mkdir -p /vm-images/disks
sudo chown -R $USER:$USER /vm-images
```

**Add to /etc/fstab for optimized mounting**:[21]

```bash
sudo nvim /etc/fstab

# Add this line (adjust UUID to match your Btrfs partition):
UUID=YOUR-BTRFS-UUID /vm-images btrfs noatime,nodiratime,compress=no,space_cache=v2,autodefrag,ssd,discard=async,subvol=vm-images 0 0
```

**Find your UUID**:
```bash
sudo blkid | grep btrfs
```

**Mount the subvolume**:
```bash
sudo mount -a
df -h | grep vm-images
```

***

# PHASE 2: ARCH LINUX KERNEL CONFIGURATION & VFIO SETUP

## Step 2.1: GRUB Kernel Parameters

**Edit GRUB configuration**:[14][17][23]

```bash
sudo nvim /etc/default/grub
```

**Find the line starting with `GRUB_CMDLINE_LINUX_DEFAULT` and modify it**:

```bash
GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet amd_iommu=on iommu=pt iommu.strict=0 iommu.passthrough=1 video=efifb:off pci=noaer isolcpus=4-11 nohz_full=4-11 rcu_nocbs=4-11 vfio-pci.ids=10de:25a2,10de:2291"
```

**Parameter Breakdown**:

| Parameter | Purpose | Impact |
|-----------|---------|--------|
| `amd_iommu=on` | Enable AMD IOMMU | Required for passthrough [24][14] |
| `iommu=pt` | Passthrough mode (better performance) | +5-10% performance [14][17] |
| `iommu.strict=0` | Relaxed IOMMU TLB flushing | +10-15% I/O performance [14] |
| `iommu.passthrough=1` | Force passthrough for all devices | Performance optimization [14] |
| `video=efifb:off` | Disable EFI framebuffer on NVIDIA GPU | Prevents boot conflicts [23] |
| `pci=noaer` | Disable PCIe Advanced Error Reporting | Prevents GPU reset issues [25][26] |
| `isolcpus=4-11` | Isolate CPU cores from Linux scheduler | +20-30% VM latency reduction [27] |
| `nohz_full=4-11` | Disable timer ticks on VM cores | Reduces jitter [27] |
| `rcu_nocbs=4-11` | RCU callbacks offload | Prevents interruptions [27] |
| `vfio-pci.ids=` | Bind NVIDIA GPU to VFIO at boot | Essential for passthrough [14][17] |

**Save and regenerate GRUB**:

```bash
sudo grub-mkconfig -o /boot/grub/grub.cfg

# Verify parameters will be applied
grep "amd_iommu" /boot/grub/grub.cfg
```

***

## Step 2.2: VFIO Module Configuration

**Create VFIO configuration**:[17][16]

```bash
sudo nvim /etc/modprobe.d/vfio.conf
```

**Add the following**:

```bash
# Bind NVIDIA GPU to VFIO at boot
options vfio-pci ids=10de:25a2,10de:2291

# Softdep ensures vfio-pci loads before other GPU drivers
softdep nvidia pre: vfio-pci
softdep nvidia* pre: vfio-pci
softdep nouveau pre: vfio-pci
softdep amdgpu pre: vfio-pci

# VFIO options
options vfio-pci disable_vga=1
options vfio_iommu_type1 allow_unsafe_interrupts=1
```

***

## Step 2.3: Blacklist NVIDIA Drivers on Host

**Create blacklist configuration**:[28][16]

```bash
sudo nvim /etc/modprobe.d/blacklist-nvidia.conf
```

**Add**:

```bash
# Prevent host from using NVIDIA GPU
blacklist nvidia
blacklist nvidia_drm
blacklist nvidia_modeset
blacklist nvidia_uvm
blacklist nouveau
blacklist nvidiafb
```

**Note**: This ensures AMD Radeon 660M handles all host graphics.[4][19][29]

***

## Step 2.4: Mkinitcpio Configuration (Early VFIO Loading)

**Edit mkinitcpio configuration**:[30][17]

```bash
sudo nvim /etc/mkinitcpio.conf
```

**Find the `MODULES` line and modify**:

```bash
MODULES=(vfio_pci vfio vfio_iommu_type1 vfio_virqfd vendor-reset)
```

**Find the `HOOKS` line and verify it contains**:

```bash
HOOKS=(base udev autodetect modconf kms keyboard keymap consolefont block filesystems fsck)
```

**Critical**: `modconf` must be present to read `/etc/modprobe.d/` files.[17][30]

**Save and regenerate initramfs**:

```bash
sudo mkinitcpio -P

# This will regenerate all kernel initramfs images
```

***

## Step 2.5: Install Vendor-Reset Module (AMD GPU Compatibility)

**Install vendor-reset for better GPU reset**:[26]

```bash
yay -S vendor-reset-dkms-git

# This prevents GPU hanging between VM restarts
```

***

## Step 2.6: Reboot and Verify VFIO Binding

**Reboot system**:

```bash
sudo reboot
```

**After reboot, verify NVIDIA GPU is bound to vfio-pci**:

```bash
# Check kernel parameters are active
cat /proc/cmdline | grep amd_iommu

# Check NVIDIA GPU driver
lspci -nnk -d 10de:25a2

# Expected output:
# 01:00.0 VGA compatible controller [0300]: NVIDIA Corporation GA107M [GeForce RTX 3050 Mobile] [10de:25a2]
#         Subsystem: Lenovo Device [17aa:XXXX]
#         Kernel driver in use: vfio-pci
#         Kernel modules: nouveau, nvidia
```

**✓ Success**: If you see `Kernel driver in use: vfio-pci`, proceed!

**✗ Failure**: If you see `nouveau` or `nvidia`, troubleshoot:

```bash
# Check dmesg for errors
dmesg | grep -i vfio
dmesg | grep -i nvidia

# Verify modules loaded
lsmod | grep vfio
```

***

# PHASE 3: LIBVIRT & KVM INSTALLATION

## Step 3.1: Install Virtualization Packages

**Install complete virtualization stack**:

```bash
sudo pacman -S qemu-full libvirt virt-manager virt-viewer \
               edk2-ovmf dnsmasq iptables-nft bridge-utils \
               spice-vdagent spice-protocol dmidecode
```

**Package purposes**:
- `qemu-full`: Full QEMU with all architectures and features
- `libvirt`: Virtualization API and management
- `virt-manager`: GUI for VM management
- `edk2-ovmf`: UEFI firmware for VMs
- `dnsmasq`: DNS/DHCP for VM networking
- `spice-*`: Remote display protocol (for initial setup)

***

## Step 3.2: Configure Libvirt

**Enable and start libvirt services**:

```bash
sudo systemctl enable --now libvirtd
sudo systemctl enable --now virtlogd

# Check status
sudo systemctl status libvirtd
```

**Add your user to required groups**:

```bash
sudo usermod -a -G libvirt,kvm,input $(whoami)

# Apply group changes (or logout/login)
newgrp libvirt
```

**Verify group membership**:

```bash
groups
# Should show: ... libvirt kvm input ...
```

***

## Step 3.3: Configure Default Network

**Start and autostart default network**:

```bash
sudo virsh net-start default
sudo virsh net-autostart default

# Verify
sudo virsh net-list --all

# Expected output:
# Name      State    Autostart   Persistent
# ------------------------------------------
# default   active   yes         yes
```

***

## Step 3.4: Configure Libvirt for Performance

**Edit QEMU configuration**:[31][32]

```bash
sudo nvim /etc/libvirt/qemu.conf
```

**Find and uncomment/modify these lines**:

```bash
# Run QEMU as your user (replace 'your_username')
user = "your_username"
group = "kvm"

# Hugepages support
hugetlbfs_mount = "/dev/hugepages"

# Security driver (use none if no SELinux/AppArmor)
security_driver = "none"

# Clear emulator capabilities (optional, for better performance)
clear_emulator_capabilities = 0

# Logging
log_level = 3
log_outputs = "3:file:/var/log/libvirt/qemu-win10.log"
```

**Save and restart libvirtd**:

```bash
sudo systemctl restart libvirtd
```

***

# PHASE 4: HUGEPAGES & PERFORMANCE TUNING

## Step 4.1: Calculate and Allocate Hugepages

**Memory allocation strategy**:[32][33]
- **Total RAM**: 16 GB
- **VM allocation**: 10 GB (10240 MB)
- **Host reserved**: 6 GB (for Hyprland + system)
- **Hugepage size**: 2 MB (standard)
- **Required pages**: 10240 MB / 2 MB = **5120 pages**

**Create hugepages configuration**:[32]

```bash
sudo nvim /etc/sysctl.d/90-hugepages.conf
```

**Add**:

```bash
# Allocate 5120 hugepages (10 GB for VM)
vm.nr_hugepages = 5120

# Hugepage shared memory group (kvm group)
vm.hugetlb_shm_group = 36

# Memory tuning for VM performance
vm.swappiness = 10
vm.dirty_ratio = 10
vm.dirty_background_ratio = 5
vm.compaction_proactiveness = 0

# Disable transparent hugepage defragmentation (reduces latency spikes)
# Note: This requires manual setting, see below
```

**Apply configuration**:

```bash
sudo sysctl -p /etc/sysctl.d/90-hugepages.conf
```

**Disable THP defragmentation** (requires manual setting):

```bash
echo never | sudo tee /sys/kernel/mm/transparent_hugepage/defrag
echo never | sudo tee /sys/kernel/mm/transparent_hugepage/khugepaged/defrag
```

**Make THP settings persistent**:

```bash
sudo nvim /etc/tmpfiles.d/thp.conf
```

**Add**:

```bash
w /sys/kernel/mm/transparent_hugepage/defrag - - - - never
w /sys/kernel/mm/transparent_hugepage/khugepaged/defrag - - - - never
```

**Verify hugepages allocation**:

```bash
cat /proc/meminfo | grep -i huge

# Expected output:
# AnonHugePages:         0 kB
# ShmemHugePages:        0 kB
# FileHugePages:         0 kB
# HugePages_Total:    5120
# HugePages_Free:     5120
# HugePages_Rsvd:        0
# HugePages_Surp:        0
# Hugepagesize:       2048 kB
```

***

## Step 4.2: IRQ Affinity Configuration (Advanced)

**Create IRQ affinity script**:[27]

```bash
sudo nvim /usr/local/bin/set-irq-affinity.sh
```

**Add**:

```bash
#!/bin/bash
# Pin all IRQs to host cores (0-3), keep VM cores (4-11) interrupt-free

for irq in $(awk '!/CPU0/ {print $1}' /proc/interrupts | sed 's/://'); do
    if [ -f "/proc/irq/$irq/smp_affinity_list" ]; then
        echo "0-3" > "/proc/irq/$irq/smp_affinity_list" 2>/dev/null || true
    fi
done

echo "IRQ affinity set to cores 0-3"
```

```bash
sudo chmod +x /usr/local/bin/set-irq-affinity.sh
```

**Create systemd service for IRQ affinity**:

```bash
sudo nvim /etc/systemd/system/irq-affinity.service
```

**Add**:

```ini
[Unit]
Description=Set IRQ Affinity for VM Performance
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/set-irq-affinity.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now irq-affinity.service
```

***

## Step 4.3: I/O Scheduler Optimization

**Set NVMe I/O scheduler to 'none'**:[34]

```bash
# Check current scheduler
cat /sys/block/nvme0n1/queue/scheduler

# Set to none (best for NVMe)
echo none | sudo tee /sys/block/nvme0n1/queue/scheduler
```

**Make persistent with udev rule**:

```bash
sudo nvim /etc/udev/rules.d/60-ioschedulers.rules
```

**Add**:

```bash
# NVMe devices: use none scheduler
ACTION=="add|change", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/scheduler}="none"
```

***

# PHASE 5: LOOKING GLASS INSTALLATION

## Step 5.1: Calculate IVSHMEM Size

**Formula for shared memory**:[35][36]

$$
\text{Size} = \text{Width} \times \text{Height} \times 4 \text{ (RGBA)} \times 2 \text{ (double buffer)} + \text{Overhead}
$$

**For 1920x1080@120Hz**:

$$
1920 \times 1080 \times 4 \times 2 = 16,588,800 \text{ bytes} \approx 16 \text{ MB}
$$

**Recommended size**: **256 MB** (provides headroom for high refresh rates and HDR)[37][35]

---

## Step 5.2: Configure IVSHMEM Shared Memory

**Create shared memory file**:

```bash
sudo touch /dev/shm/looking-glass
sudo chown $USER:kvm /dev/shm/looking-glass
sudo chmod 660 /dev/shm/looking-glass
```

**Make persistent with systemd tmpfiles**:[35]

```bash
sudo nvim /etc/tmpfiles.d/looking-glass.conf
```

**Add** (replace `your_username`):

```bash
# Type Path                      Mode UID          GID  Age Argument
f     /dev/shm/looking-glass     0660 your_username kvm  -   -
```

**Update /etc/fstab to ensure adequate tmpfs size**:

```bash
sudo nvim /etc/fstab
```

**Add or modify tmpfs line**:

```bash
tmpfs /dev/shm tmpfs defaults,size=512M 0 0
```

**Remount**:

```bash
sudo mount -o remount /dev/shm
```

***

## Step 5.3: Install Looking Glass Client Dependencies

**Install build dependencies**:

```bash
sudo pacman -S cmake gcc git binutils pkgconf \
               libx11 nettle libxi libxinerama libxss \
               libxcursor libxpresent libxkbcommon \
               wayland-protocols ttf-dejavu freetype2 \
               spice-protocol fontconfig libsamplerate \
               libpipewire pipewire
```

***

## Step 5.4: Build Looking Glass Client

**Clone and build**:[38][35]

```bash
# Create builds directory
mkdir -p ~/builds
cd ~/builds

# Clone Looking Glass repository
git clone --recursive https://github.com/gnif/LookingGlass.git
cd LookingGlass

# Checkout stable version (B6 or latest)
git checkout stable

# Build client
cd client
mkdir build && cd build

# Configure with Wayland support
cmake ../ \
    -DENABLE_WAYLAND=ON \
    -DENABLE_X11=ON \
    -DENABLE_PIPEWIRE=ON \
    -DENABLE_DMABUF=ON

# Compile (use all CPU cores)
make -j$(nproc)

# Install
sudo make install

# Verify installation
which looking-glass-client
```

***

## Step 5.5: Configure Looking Glass Client

**Create configuration directory**:

```bash
mkdir -p ~/.config/looking-glass
```

**Create client configuration**:[38][35]

```bash
nvim ~/.config/looking-glass/client.ini
```

**Add** (optimized for Hyprland Wayland + 120Hz):

```ini
[app]
renderer=EGL
shmFile=/dev/shm/looking-glass

[win]
size=1920x1080
fullScreen=no
autoResize=yes
keepAspect=yes
borderless=no
jitRender=yes
showFPS=yes

[input]
grabKeyboard=yes
grabKeyboardOnFocus=yes
releaseKeysOnFocusLoss=yes
rawMouse=yes
mouseRedraw=yes
escapeKey=KEY_SCROLLLOCK

[egl]
vsync=no
doubleBuffer=yes
multisample=no
nvGainMax=1
nvGain=0

[spice]
enable=yes
host=127.0.0.1
port=5900

[audio]
# PipeWire audio (auto-detected on Arch)
micDefault=allow
```

***

## Step 5.6: Download Looking Glass Host for Windows

**Download host installer**:[35]

```bash
cd ~/Downloads

# Visit https://looking-glass.io/downloads
# Download latest Windows host installer (e.g., looking-glass-host-setup.exe)

# Or use wget (check latest version URL)
# wget https://looking-glass.io/artifact/stable/host
```

**Keep this file ready for Windows VM installation (Phase 6)**.

***

# PHASE 6: WINDOWS 10 VM CREATION & CONFIGURATION

## Step 6.1: Download Required ISOs

**Download Windows 10 ISO**:

```bash
cd /vm-images/iso

# Option 1: Official Microsoft Media Creation Tool (run in existing Windows)
# Download from: https://www.microsoft.com/software-download/windows10

# Option 2: Use your existing Ventoy USB drive
# You already have Windows ISOs on your Ventoy drive at:
# /run/media/right9zzz/Ventoy/

# Copy or symlink to vm-images
ln -s /run/media/right9zzz/Ventoy/Win10_22H2_English_x64.iso \
      /vm-images/iso/windows10.iso
```

**Download VirtIO drivers**:

```bash
cd /vm-images/iso

# Download latest VirtIO drivers
wget https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso

# Or get latest version
# wget https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/latest-virtio/virtio-win.iso
```

***

## Step 6.2: Create VM Disk Image

**Create raw disk image**:[21]

```bash
cd /vm-images/disks

# Create 80GB raw disk image (better performance on Btrfs with CoW disabled)
qemu-img create -f raw windows10.img 80G

# Verify
ls -lh windows10.img
```

**Alternative: qcow2 format** (allows snapshots, slightly slower):

```bash
# If you prefer snapshots capability
qemu-img create -f qcow2 windows10.qcow2 80G
```

***

## Step 6.3: Launch Virt-Manager and Create Initial VM

**Launch virt-manager**:

```bash
virt-manager
```

**Create new VM**:[16]

1. Click **Create a new virtual machine**
2. Choose **Local install media (ISO image or CDROM)**
3. Click **Forward**

**Choose Installation Media**:
4. Click **Browse...**
5. Navigate to `/vm-images/iso/windows10.iso`
6. Select it and click **Choose Volume**
7. **Uncheck** "Automatically detect from the installation media/source"
8. Type: **Microsoft Windows 10**
9. Click **Forward**

**Memory and CPU Configuration**:
10. Memory: **10240** MiB (10 GB)
11. CPUs: **8**
12. Click **Forward**

**Storage Configuration**:
13. **Uncheck** "Enable storage for this virtual machine"
14. Click **Forward** (we'll add disk manually in XML)

**Final Configuration**:
15. Name: **win10-gaming**
16. **Check** "Customize configuration before install"
17. Network selection: **Default NAT (virbr0)**
18. Click **Finish**

---

## Step 6.4: Configure VM XML (Complete Optimized Configuration)

**The VM configuration window will open. Go to "Overview" → "XML" tab.**

**Replace the entire XML with this optimized configuration**:[3][31][16][32]

```xml
<domain xmlns:qemu="http://libvirt.org/schemas/domain/qemu/1.0" type="kvm">
  <name>win10-gaming</name>
  <uuid>REPLACE-WITH-UUIDGEN-OUTPUT</uuid>
  <metadata>
    <libosinfo:libosinfo xmlns:libosinfo="http://libosinfo.org/xmlns/libvirt/domain/1.0">
      <libosinfo:os id="http://microsoft.com/win/10"/>
    </libosinfo:libosinfo>
  </metadata>
  
  <memory unit="KiB">10485760</memory>
  urrentntMemory unit="KiB">10485760</currentMemory>
  
  <!-- Hugepages for reduced TLB misses -->
  <memoryBacking>
    <hugepages/>
    <locked/>
  </memoryBacking>
  
  <vcpu placement="static">8</vcpu>
  
  <!-- CPU pinning: Reserve threads 0-3 for host, pin 4-11 to VM -->
  <cputune>
    <vcpupin vcpu="0" cpuset="4"/>
    <vcpupin vcpu="1" cpuset="5"/>
    <vcpupin vcpu="2" cpuset="6"/>
    <vcpupin vcpu="3" cpuset="7"/>
    <vcpupin vcpu="4" cpuset="8"/>
    <vcpupin vcpu="5" cpuset="9"/>
    <vcpupin vcpu="6" cpuset="10"/>
    <vcpupin vcpu="7" cpuset="11"/>
    <emulatorpin cpuset="0-3"/>
    <iothreadpin iothread="1" cpuset="0-3"/>
    <iothreadpin iothread="2" cpuset="0-3"/>
  </cputune>
  
  <iothreads>2</iothreads>
  
  <os>
    <type arch="x86_64" machine="pc-q35-9.0">hvm</type>
    <loader readonly="yes" type="pflash">/usr/share/edk2/x64/OVMF_CODE.4m.fd</loader>
    <nvram template="/usr/share/edk2/x64/OVMF_VARS.4m.fd">/var/lib/libvirt/qemu/nvram/win10-gaming_VARS.fd</nvram>
    <boot dev="hd"/>
    <boot dev="cdrom"/>
  </os>
  
  <features>
    <acpi/>
    <apic/>
    
    <!-- Hyper-V Enlightenments for Windows optimization -->
    <hyperv mode="custom">
      <relaxed state="on"/>
      <vapic state="on"/>
      <spinlocks state="on" retries="8191"/>
      <vpindex state="on"/>
      <runtime state="on"/>
      <synic state="on"/>
      <stimer state="on">
        <direct state="on"/>
      </stimer>
      <reset state="on"/>
      <vendor_id state="on" value="GenuineIntel"/>
      <frequencies state="on"/>
      <reenlightenment state="on"/>
      <tlbflush state="on"/>
      <ipi state="on"/>
      <evmcs state="off"/> <!-- MUST be OFF for NVIDIA -->
    </hyperv>
    
    <!-- Hide KVM from VM (prevents NVIDIA driver detection issues) -->
    <kvm>
      <hidden state="on"/>
    </kvm>
    
    <vmport state="off"/>
    <smm state="on"/>
    <ioapic driver="kvm"/>
  </features>
  
  <!-- CPU configuration: host-passthrough for maximum performance -->
  pu mode="host-passthrough" check="none" migratable="offff">
    <topology sockets="1" dies="1" cores="4" threads="2"/>
    <cache mode="passthrough"/>
    <feature policy="require" name="topoext"/>
    <feature policy="require" name="invtsc"/>
    <feature policy="require" name="svm"/>
  </cpu>
  
  <!-- Clock configuration for Windows VMs -->
  lock offset="="localtime">
    <timer name="rtc" tickpolicy="catchup"/>
    <timer name="pit" tickpolicy="delay"/>
    <timer name="hpet" present="no"/>
    <timer name="hypervclock" present="yes"/>
    <timer name="tsc" present="yes" mode="native"/>
  </clock>
  
  <on_poweroff>destroy</on_poweroff>
  <on_reboot>restart</on_reboot>
  <on_crash>destroy</on_crash>
  
  <pm>
    <suspend-to-mem enabled="no"/>
    <suspend-to-disk enabled="no"/>
  </pm>
  
  <devices>
    <emulator>/usr/bin/qemu-system-x86_64</emulator>
    
    <!-- Windows 10 Disk: VirtIO-SCSI with optimal settings -->
    <disk type="file" device="disk">
      <driver name="qemu" type="raw" cache="none" io="native" discard="unmap" iothread="1" queues="4"/>
      <source file="/vm-images/disks/windows10.img"/>
      <target dev="sda" bus="scsi"/>
      <address type="drive" controller="0" bus="0" target="0" unit="0"/>
    </disk>
    
    <!-- Windows 10 Installation ISO -->
    <disk type="file" device="cdrom">
      <driver name="qemu" type="raw"/>
      <source file="/vm-images/iso/windows10.iso"/>
      <target dev="sdb" bus="sata"/>
      <readonly/>
      <address type="drive" controller="0" bus="0" target="0" unit="1"/>
    </disk>
    
    <!-- VirtIO Drivers ISO -->
    <disk type="file" device="cdrom">
      <driver name="qemu" type="raw"/>
      <source file="/vm-images/iso/virtio-win.iso"/>
      <target dev="sdc" bus="sata"/>
      <readonly/>
      <address type="drive" controller="0" bus="0" target="0" unit="2"/>
    </disk>
    
    <!-- SCSI Controller -->
    ontroller type="scsi" index="0"0" model="virtio-scsi">
      <driver iothread="1" queues="8"/>
      <address type="pci" domain="0x0000" bus="0x03" slot="0x00" function="0x0"/>
    </controller>
    
    ontroller type="pci" index="0" model="="pcie-root"/>
    ontroller type="pci" index="1" model="p"pcie-root-port">
      <model name="pcie-root-port"/>
      <target chassis="1" port="0x10"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x02" function="0x0" multifunction="on"/>
    </controller>
    ontroller type="pci" index="2" model="pcie-rootot-port">
      <model name="pcie-root-port"/>
      <target chassis="2" port="0x11"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x02" function="0x1"/>
    </controller>
    ontroller type="pci" index="3" model="pcie-rootot-port">
      <model name="pcie-root-port"/>
      <target chassis="3" port="0x12"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x02" function="0x2"/>
    </controller>
    ontroller type="pci" index="4" model="pcie-rootot-port">
      <model name="pcie-root-port"/>
      <target chassis="4" port="0x13"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x02" function="0x3"/>
    </controller>
    ontroller type="pci" index="5" model="pcie-rootot-port">
      <model name="pcie-root-port"/>
      <target chassis="5" port="0x14"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x02" function="0x4"/>
    </controller>
    ontroller type="pci" index="6" model="pcie-rootot-port">
      <model name="pcie-root-port"/>
      <target chassis="6" port="0x15"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x02" function="0x5"/>
    </controller>
    ontroller type="pci" index="7" model="pcie-rootot-port">
      <model name="pcie-root-port"/>
      <target chassis="7" port="0x16"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x02" function="0x6"/>
    </controller>
    
    ontroller type="s"sata" index="0">
      <address type="pci" domain="0x0000" bus="0x00" slot="0x1f" function="0x2"/>
    </controller>
    
    ontroller type="usb" index="0" model="qemu-xhcici" ports="15">
      <address type="pci" domain="0x0000" bus="0x02" slot="0x00" function="0x0"/>
    </controller>
    
    <!-- VirtIO Network with multi-queue -->
    <interface type="network">
      <mac address="52:54:00:AA:BB:CC"/>
      <source network="default"/>
      <model type="virtio"/>
      <driver name="vhost" queues="8" rx_queue_size="1024" tx_queue_size="1024">
        <host mrg_rxbuf="on" tso4="on" tso6="on" gso="on"/>
        <guest tso4="on" tso6="on" gso="on"/>
      </driver>
      <address type="pci" domain="0x0000" bus="0x01" slot="0x00" function="0x0"/>
    </interface>
    
    <!-- GPU Passthrough: NVIDIA RTX 3050 Mobile -->
    <hostdev mode="subsystem" type="pci" managed="yes">
      <source>
        <address domain="0x0000" bus="0x01" slot="0x00" function="0x0"/>
      </source>
      <driver name="vfio"/>
      <!-- Uncomment if VBIOS is required (see Phase 9 if Code 43 occurs) -->
      <!-- <rom file="/usr/share/vgabios/rtx3050_mobile_patched.rom"/> -->
      <address type="pci" domain="0x0000" bus="0x04" slot="0x00" function="0x0" multifunction="on"/>
    </hostdev>
    
    <!-- GPU Passthrough: NVIDIA Audio Controller -->
    <hostdev mode="subsystem" type="pci" managed="yes">
      <source>
        <address domain="0x0000" bus="0x01" slot="0x00" function="0x1"/>
      </source>
      <driver name="vfio"/>
      <address type="pci" domain="0x0000" bus="0x04" slot="0x00" function="0x1"/>
    </hostdev>
    
    <!-- Spice display for initial Windows installation -->
    <graphics type="spice" autoport="yes">
      <listen type="address"/>
      <image compression="off"/>
      <gl enable="no"/>
    </graphics>
    
    <!-- QXL video (temporary, remove after GPU passthrough confirmed working) -->
    <video>
      <model type="qxl" ram="65536" vram="65536" vgamem="16384" heads="1" primary="yes"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x01" function="0x0"/>
    </video>
    
    <!-- VirtIO Input Devices -->
    <input type="keyboard" bus="virtio">
      <address type="pci" domain="0x0000" bus="0x05" slot="0x00" function="0x0"/>
    </input>
    <input type="tablet" bus="virtio">
      <address type="pci" domain="0x0000" bus="0x06" slot="0x00" function="0x0"/>
    </input>
    <input type="mouse" bus="ps2"/>
    <input type="keyboard" bus="ps2"/>
    
    <!-- VirtIO Balloon for dynamic memory management -->
    <memballoon model="virtio">
      <address type="pci" domain="0x0000" bus="0x07" slot="0x00" function="0x0"/>
    </memballoon>
    
    <!-- VirtIO RNG for entropy -->
    <rng model="virtio">
      <backend model="random">/dev/urandom</backend>
      <address type="pci" domain="0x0000" bus="0x08" slot="0x00" function="0x0"/>
    </rng>
    
    <!-- TPM 2.0 (Windows 11 compatibility, optional for Windows 10) -->
    <tpm model="tpm-crb">
      <backend type="emulator" version="2.0"/>
    </tpm>
    
    <!-- Audio: PulseAudio/PipeWire passthrough -->
    <sound model="ich9">
      <audio id="1"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x1b" function="0x0"/>
    </sound>
    <audio id="1" type="pipewire">
      <input mixingEngine="no"/>
      <output mixingEngine="no" latency="512"/>
    </audio>
  </devices>
  
  <!-- Looking Glass IVSHMEM device (256MB shared memory) -->
  <qemu:commandline>
    <qemu:arg value="-device"/>
    <qemu:arg value="ivshmem-plain,memdev=ivshmem,bus=pcie.0"/>
    <qemu:arg value="-object"/>
    <qemu:arg value="memory-backend-file,id=ivshmem,share=on,mem-path=/dev/shm/looking-glass,size=256M"/>
  </qemu:commandline>
</domain>
```

**Important XML modifications you MUST make**:

1. **Generate UUID**:
```bash
uuidgen
# Copy output and replace "REPLACE-WITH-UUIDGEN-OUTPUT" in XML
```

2. **Verify file paths match your system**:
   - `/vm-images/disks/windows10.img`
   - `/vm-images/iso/windows10.iso`
   - `/vm-images/iso/virtio-win.iso`

3. **Verify PCI addresses match your NVIDIA GPU**:
```bash
lspci | grep -i nvidia
# Should show 01:00.0 and 01:00.1
```

**Click "Apply" to save the XML configuration.**

***

## Step 6.5: Start Windows Installation

**Click "Begin Installation" at top-left of virt-manager window.**

**Windows Installation Steps**:

1. VM will boot into Windows Setup
2. Select language, time, keyboard
3. Click **Install now**
4. Enter product key or click **"I don't have a product key"**
5. Select **Windows 10 Pro** (or your edition)
6. Accept license terms

**Load VirtIO SCSI Driver** (critical step):

7. When prompted **"Where do you want to install Windows?"**, you'll see **no drives**
8. Click **"Load driver"**
9. Click **"Browse"**
10. Navigate to **E:\ (virtio-win) → amd64 → w10**
11. Select **"Red Hat VirtIO SCSI controller"** driver
12. Click **OK**
13. Your **80GB disk** will now appear
14. Click **Next** to install

**Complete Windows installation normally** (username, password, privacy settings).

---

## Step 6.6: Install VirtIO Drivers in Windows

**After first boot into Windows**:

1. Open **File Explorer**
2. Navigate to **D:\ (virtio-win CD)**
3. Run **virtio-win-gt-x64.exe** or **virtio-win-guest-tools.exe**
4. Install all drivers:
   - VirtIO Balloon
   - VirtIO Network
   - VirtIO Serial
   - VirtIO RNG
   - Spice agent
   - QEMU Guest Agent

5. **Reboot Windows VM**

***

## Step 6.7: Install NVIDIA Drivers in Windows

**Download NVIDIA drivers**:[39]

1. In Windows VM, open browser
2. Go to https://www.nvidia.com/download/index.aspx
3. Select:
   - Product Type: **GeForce**
   - Series: **RTX 30 Series (Notebooks)**
   - Product: **GeForce RTX 3050 Mobile**
   - Operating System: **Windows 10 64-bit**
   - Download Type: **Game Ready Driver**

4. Download and install driver
5. **Reboot Windows VM**

**Check Device Manager**:
- Open Device Manager (devmgmt.msc)
- Look for **"NVIDIA GeForce RTX 3050"** under Display adapters
- Should show **no errors** (no yellow triangle)

**If you see "Code 43" error**, see Phase 9: Troubleshooting.

***

## Step 6.8: Install Looking Glass Host in Windows

**Install Looking Glass host application**:[35]

1. Copy **looking-glass-host-setup.exe** from host to VM:
   - Use shared folder, USB drive, or network share
   - Or download directly in VM from https://looking-glass.io/downloads

2. Run **looking-glass-host-setup.exe** as Administrator
3. Install to default location
4. When prompted, install **IVSHMEM driver**

**Configure Looking Glass host**:

5. Open **Services** (services.msc)
6. Find **"Looking Glass (host)"**
7. Set **Startup type** to **Automatic**
8. Click **Start** to start service immediately

**Verify IVSHMEM device**:
- Device Manager → System devices
- Should show **"IVSHMEM device"** with no errors

***

## Step 6.9: Test GPU Passthrough in Windows

**Verify NVIDIA GPU is working**:

1. Open **Task Manager** (Ctrl+Shift+Esc)
2. Go to **Performance** tab
3. Should show **"GPU 0 - NVIDIA GeForce RTX 3050"**

**Run basic tests**:
- Open **NVIDIA Control Panel**
- Check GPU is recognized
- Try running a game or benchmark (3DMark demo, Unigine Heaven)

***

# PHASE 7: ADVANCED OPTIMIZATIONS

## Step 7.1: Remove QXL Display (Transition to Looking Glass)

**After confirming GPU passthrough works**, remove Spice display:[35]

```bash
# Shutdown VM first
virsh shutdown win10-gaming

# Edit VM XML
virsh edit win10-gaming
```

**Find and comment out or remove these sections**:

```xml
<!-- REMOVE THESE:
<graphics type="spice" autoport="yes">
  ...
</graphics>

<video>
  <model type="qxl" .../>
</video>
-->
```

**Save and exit** (`:wq` in vim).

***

## Step 7.2: Test Looking Glass Client

**Start VM**:

```bash
virsh start win10-gaming
```

**Wait 30 seconds for Windows to boot.**

**Launch Looking Glass client**:[38]

```bash
# Set Wayland environment
export SDL_VIDEODRIVER=wayland
export GDK_BACKEND=wayland

# Launch Looking Glass
looking-glass-client -F -m KEY_SCROLLLOCK
```

**You should see Windows desktop in Looking Glass window!**

**Keyboard shortcuts**:
- **Scroll Lock**: Toggle input capture (mouse/keyboard control)
- **Scroll Lock + Q**: Quit Looking Glass
- **Scroll Lock + F**: Toggle fullscreen

***

## Step 7.3: Windows Guest Optimizations

**Disable Windows bloat**:[31][32]

1. **Disable Windows Defender** (during gaming):
   - Settings → Update & Security → Windows Security → Virus & threat protection
   - Turn off real-time protection

2. **Disable Windows Search indexing**:
   - Services → Windows Search → Stop and Disable

3. **Disable Superfetch/SysMain**:
   - Services → SysMain → Stop and Disable

4. **Set Power Plan to High Performance**:
   - Control Panel → Power Options → High performance

5. **Disable visual effects**:
   - System → Advanced system settings → Performance Settings
   - Select "Adjust for best performance"

6. **Disable HPET** (use TSC timer):[32]
   - Open cmd as Administrator:
   ```
   bcdedit /deletevalue useplatformclock
   bcdedit /set disabledynamictick yes
   ```

7. **Disable CPU mitigations** (performance boost):
   - Open Registry Editor (regedit)
   - Navigate to: `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management`
   - Create DWORD: `FeatureSettingsOverride` = `3`
   - Create DWORD: `FeatureSettingsOverrideMask` = `3`

8. **Enable MSI mode for GPU** (reduces latency):
   - Download **MSI Utility v3**
   - Enable MSI mode for NVIDIA GPU and audio

9. **NVIDIA Control Panel settings**:[40]
   - Power management mode → **Prefer maximum performance**
   - Low Latency Mode → **Ultra**
   - Vertical sync → **Off**

10. **Disable Windows Update automatic restarts**:
    - Settings → Update & Security → Advanced options
    - Set active hours or pause updates

**Reboot Windows VM after changes.**

***

## Step 7.4: NVIDIA Registry Tweak (Disable Power Management)

**Prevent NVIDIA GPU power state issues**:[26][40]

1. Open **Registry Editor** (regedit)
2. Navigate to:
   ```
   HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000
   ```
3. Create **DWORD**: `DisableDynamicPstate` = `1`
4. Reboot Windows

***

# PHASE 8: AUTOMATION & LIFECYCLE MANAGEMENT

## Step 8.1: Create VM Pre-Launch Script

**Create preparation script**:

```bash
sudo nvim /usr/local/bin/vm-prepare.sh
```

**Add** (comprehensive pre-launch optimization):

```bash
#!/bin/bash
# VM Pre-Launch Preparation Script

set -e

VM_NAME="win10-gaming"
LOG_FILE="/var/log/vm-launch.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "=== VM Pre-Launch Sequence Started ==="

# Check if VM is already running
if virsh list --state-running | grep -q "$VM_NAME"; then
    log "ERROR: VM is already running!"
    exit 1
fi

# Clear cache and free memory
log "Clearing cache..."
sync
echo 3 | sudo tee /proc/sys/vm/drop_caches > /dev/null

# Set CPU governor to performance
log "Setting CPU governor to performance..."
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    echo "performance" | sudo tee "$cpu" > /dev/null
done

# Verify hugepages
HUGE_FREE=$(grep HugePages_Free /proc/meminfo | awk '{print $2}')
log "Hugepages free: $HUGE_FREE"

if [ "$HUGE_FREE" -lt 5000 ]; then
    log "WARNING: Insufficient hugepages, reallocating..."
    echo 5120 | sudo tee /proc/sys/vm/nr_hugepages > /dev/null
    sleep 2
fi

# Verify GPU is bound to vfio-pci
GPU_DRIVER=$(lspci -ks 01:00.0 | grep "Kernel driver in use" | awk '{print $5}')
if [ "$GPU_DRIVER" != "vfio-pci" ]; then
    log "ERROR: NVIDIA GPU not bound to vfio-pci"
    exit 1
fi

# Stop non-essential services
log "Stopping non-essential services..."
sudo systemctl stop bluetooth.service 2>/dev/null || true
sudo systemctl stop cups.service 2>/dev/null || true

# Set IRQ affinity
log "Setting IRQ affinity..."
/usr/local/bin/set-irq-affinity.sh

# Verify Looking Glass shared memory
if [ ! -f /dev/shm/looking-glass ]; then
    log "Creating Looking Glass shared memory..."
    sudo touch /dev/shm/looking-glass
    sudo chown $USER:kvm /dev/shm/looking-glass
    sudo chmod 660 /dev/shm/looking-glass
fi

# System status
log "System ready - Load: $(cat /proc/loadavg | awk '{print $1, $2, $3}')"
log "Free memory: $(free -h | grep Mem | awk '{print $7}')"

log "=== VM Pre-Launch Complete ==="
```

```bash
sudo chmod +x /usr/local/bin/vm-prepare.sh
```

***

## Step 8.2: Create VM Launch Script

```bash
sudo nvim /usr/local/bin/vm-launch.sh
```

**Add**:

```bash
#!/bin/bash
# VM Launch Script with Looking Glass

VM_NAME="win10-gaming"

echo "Preparing system for VM launch..."
/usr/local/bin/vm-prepare.sh || exit 1

echo "Starting VM: $VM_NAME..."
virsh start "$VM_NAME"

echo "Waiting for VM to boot (20 seconds)..."
sleep 20

echo "Launching Looking Glass client..."
export SDL_VIDEODRIVER=wayland
export GDK_BACKEND=wayland

# Launch Looking Glass in background
looking-glass-client -F -m KEY_SCROLLLOCK &

echo "VM launched successfully!"
echo "Press Scroll Lock to toggle input capture"
```

```bash
sudo chmod +x /usr/local/bin/vm-launch.sh
```

***

## Step 8.3: Create VM Shutdown Script

```bash
sudo nvim /usr/local/bin/vm-shutdown.sh
```

**Add**:

```bash
#!/bin/bash
# VM Graceful Shutdown Script

VM_NAME="win10-gaming"
LOG_FILE="/var/log/vm-shutdown.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "=== VM Shutdown Sequence Started ==="

# Check if VM is running
if ! virsh list --state-running | grep -q "$VM_NAME"; then
    log "VM is not running"
    exit 0
fi

# Send ACPI shutdown
log "Sending ACPI shutdown signal..."
virsh shutdown "$VM_NAME"

# Wait for graceful shutdown (max 60 seconds)
TIMEOUT=60
ELAPSED=0
while virsh list --state-running | grep -q "$VM_NAME"; do
    if [ $ELAPSED -ge $TIMEOUT ]; then
        log "WARNING: Timeout reached, forcing shutdown..."
        virsh destroy "$VM_NAME"
        break
    fi
    sleep 2
    ELAPSED=$((ELAPSED + 2))
done

log "VM stopped after ${ELAPSED} seconds"

# Kill Looking Glass client
pkill -x "looking-glass-client" 2>/dev/null || true

# Wait for complete shutdown
sleep 3

log "=== VM Shutdown Complete ==="
```

```bash
sudo chmod +x /usr/local/bin/vm-shutdown.sh
```

***

## Step 8.4: Create VM Cleanup Script

```bash
sudo nvim /usr/local/bin/vm-cleanup.sh
```

**Add**:

```bash
#!/bin/bash
# Post-VM Cleanup Script

LOG_FILE="/var/log/vm-cleanup.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "=== Post-VM Cleanup Started ==="

# Restore CPU governor to powersave
log "Restoring CPU governor..."
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    echo "powersave" | sudo tee "$cpu" > /dev/null
done

# Restart services
log "Restarting services..."
sudo systemctl start bluetooth.service 2>/dev/null || true
sudo systemctl start cups.service 2>/dev/null || true

# Compact memory
echo 1 | sudo tee /proc/sys/vm/compact_memory > /dev/null

log "System restored - Load: $(cat /proc/loadavg | awk '{print $1, $2, $3}')"
log "=== Cleanup Complete ==="
```

```bash
sudo chmod +x /usr/local/bin/vm-cleanup.sh
```

***

## Step 8.5: Create VM Status Script

```bash
sudo nvim /usr/local/bin/vm-status.sh
```

**Add**:

```bash
#!/bin/bash
# VM Status Dashboard

VM_NAME="win10-gaming"

echo "===================================" 
echo "VM Status Dashboard"
echo "==================================="
echo ""

# VM State
if virsh list --state-running | grep -q "$VM_NAME"; then
    echo "VM State: RUNNING ✓"
    echo ""
    echo "--- CPU Stats ---"
    virsh cpu-stats "$VM_NAME" --total 2>/dev/null | head -4
    echo ""
    echo "--- Memory Stats ---"
    virsh dommemstat "$VM_NAME" 2>/dev/null | head -6
else
    echo "VM State: STOPPED ✗"
fi

# GPU Status
echo ""
echo "--- GPU Status ---"
GPU_DRIVER=$(lspci -ks 01:00.0 | grep "Kernel driver in use" | awk '{print $5}')
echo "NVIDIA GPU driver: $GPU_DRIVER"

# Looking Glass
echo ""
echo "--- Looking Glass ---"
if pgrep -x "looking-glass-client" > /dev/null; then
    echo "Client: RUNNING ✓"
else
    echo "Client: STOPPED ✗"
fi

if [ -f /dev/shm/looking-glass ]; then
    echo "Shared memory: $(ls -lh /dev/shm/looking-glass | awk '{print $5}')"
fi

# System Resources
echo ""
echo "--- Host System ---"
echo "CPU Governor: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)"
echo "Load Average: $(cat /proc/loadavg | awk '{print $1, $2, $3}')"
echo "Free Memory: $(free -h | grep Mem | awk '{print $7}')"
echo "Hugepages Free: $(grep HugePages_Free /proc/meminfo | awk '{print $2}')"

# Temperatures
if command -v sensors &> /dev/null; then
    echo ""
    echo "--- Temperatures ---"
    sensors | grep -E "Tctl|edge"
fi

echo ""
echo "==================================="
```

```bash
sudo chmod +x /usr/local/bin/vm-status.sh
```

***

## Step 8.6: Configure Libvirt Hooks

**Create libvirt hook**:[41]

```bash
sudo nvim /etc/libvirt/hooks/qemu
```

**Add**:

```bash
#!/bin/bash
# Libvirt Hook for VM Lifecycle Management

GUEST_NAME="$1"
HOOK_NAME="$2"
STATE_NAME="$3"

LOG_FILE="/var/log/libvirt-hooks.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$GUEST_NAME] $1" >> "$LOG_FILE"
}

if [ "$GUEST_NAME" == "win10-gaming" ]; then
    case "$HOOK_NAME" in
        "release")
            if [ "$STATE_NAME" == "end" ]; then
                log "VM stopped - running cleanup"
                /usr/local/bin/vm-cleanup.sh &
            fi
            ;;
    esac
fi
```

```bash
sudo chmod +x /etc/libvirt/hooks/qemu
sudo systemctl restart libvirtd
```

***

## Step 8.7: Add Hyprland Keybindings

**Edit Hyprland config**:

```bash
nvim ~/.config/hypr/hyprland.conf
```

**Add keybindings**:

```bash
# VM Management Hotkeys
bind = SUPER, F12, exec, /usr/local/bin/vm-launch.sh
bind = SUPER SHIFT, F12, exec, /usr/local/bin/vm-shutdown.sh
bind = SUPER CTRL, F12, exec, /usr/local/bin/vm-status.sh

# Looking Glass window rules
windowrulev2 = workspace 9 silent, class:(looking-glass-client)
windowrulev2 = fullscreen, class:(looking-glass-client)
windowrulev2 = noanim, class:(looking-glass-client)
windowrulev2 = stayfocused, class:(looking-glass-client)
```

**Reload Hyprland**: `Super+Shift+R`

***

## Step 8.8: Create Shell Aliases

**Add to `~/.zshrc`**:

```bash
# VM Management Aliases
alias vm-start='vm-launch.sh'
alias vm-stop='vm-shutdown.sh'
alias vm-stat='vm-status.sh'
alias vm-console='virt-manager'
```

```bash
source ~/.zshrc
```

***

# PHASE 9: TROUBLESHOOTING & VERIFICATION

## Problem 1: NVIDIA "Code 43" Error

**Symptoms**: Device Manager shows "Windows has stopped this device because it has reported problems. (Code 43)"

**Solutions**:[42][39]

### Solution A: Verify Hyper-V Settings

```bash
virsh edit win10-gaming
```

**Ensure these are present**:

```xml
<hyperv mode="custom">
  <vendor_id state="on" value="GenuineIntel"/>
  ...
  <evmcs state="off"/> <!-- MUST be OFF -->
</hyperv>

<kvm>
  <hidden state="on"/>
</kvm>
```

### Solution B: Dump and Patch VBIOS

**If Code 43 persists**, you need a patched VBIOS:[43][42]

**1. Dump VBIOS from Windows** (before passthrough):

- Download **GPU-Z**
- GPU-Z → Click GPU BIOS icon → Save to file
- Save as `rtx3050_mobile.rom`
- Transfer file to Linux host

**2. Patch VBIOS on Linux**:

```bash
cd ~/builds
git clone https://github.com/Matoking/NVIDIA-vBIOS-VFIO-Patcher
cd NVIDIA-vBIOS-VFIO-Patcher

python nvidia_vbios_vfio_patcher.py \
    -i ~/rtx3050_mobile.rom \
    -o ~/rtx3050_mobile_patched.rom

# Copy to system location
sudo mkdir -p /usr/share/vgabios/
sudo cp ~/rtx3050_mobile_patched.rom /usr/share/vgabios/
```

**3. Add ROM to VM XML**:

```bash
virsh edit win10-gaming
```

**Find the GPU hostdev section and add rom line**:

```xml
<hostdev mode="subsystem" type="pci" managed="yes">
  <source>
    <address domain="0x0000" bus="0x01" slot="0x00" function="0x0"/>
  </source>
  <driver name="vfio"/>
  <rom file="/usr/share/vgabios/rtx3050_mobile_patched.rom"/>
  <address type="pci" domain="0x0000" bus="0x04" slot="0x00" function="0x0"/>
</hostdev>
```

**4. Restart VM and reinstall NVIDIA driver**.

### Solution C: Try rombar=off

**Alternative to VBIOS patching**:[39]

```xml
<hostdev mode="subsystem" type="pci" managed="yes">
  <source>
    <address domain="0x0000" bus="0x01" slot="0x00" function="0x0"/>
  </source>
  <rom bar="off"/>
  <address type="pci" domain="0x0000" bus="0x04" slot="0x00" function="0x0"/>
</hostdev>
```

***

## Problem 2: VM Won't Start / Black Screen

**Check VM logs**:

```bash
sudo journalctl -u libvirtd -f
sudo tail -f /var/log/libvirt/qemu/win10-gaming.log
```

**Common causes**:

1. **Hugepages not allocated**:
   ```bash
   cat /proc/meminfo | grep Huge
   # If HugePages_Free is 0, reallocate:
   echo 5120 | sudo tee /proc/sys/vm/nr_hugepages
   ```

2. **OVMF firmware missing**:
   ```bash
   ls /usr/share/edk2/x64/
   # Should show OVMF_CODE.4m.fd and OVMF_VARS.4m.fd
   # If missing: sudo pacman -S edk2-ovmf
   ```

3. **VFIO binding failed**:
   ```bash
   lspci -k | grep -A 3 "01:00.0"
   # Should show vfio-pci, not nvidia/nouveau
   ```

4. **IVSHMEM file missing**:
   ```bash
   ls -lh /dev/shm/looking-glass
   # If missing, recreate:
   sudo touch /dev/shm/looking-glass
   sudo chown $USER:kvm /dev/shm/looking-glass
   sudo chmod 660 /dev/shm/looking-glass
   ```

***

## Problem 3: Poor VM Performance

**Check CPU pinning is active**:

```bash
virsh vcpuinfo win10-gaming
# Should show specific CPUs assigned to each vCPU
```

**Verify hugepages in use**:

```bash
cat /proc/meminfo | grep Huge
# HugePages_Rsvd should be non-zero when VM runs
```

**Monitor disk I/O**:

```bash
sudo iotop -o
# Check if VM disk operations are slow
```

**Check system load**:

```bash
uptime
# If load > 8, investigate with htop
```

***

## Problem 4: Looking Glass Black Screen

**Verify IVSHMEM device in Windows**:
- Device Manager → System devices → "IVSHMEM device"
- Should show no errors

**Check Looking Glass host service**:
- Services → "Looking Glass (host)" → Status: Running

**Check Looking Glass host logs** (in Windows):
- `C:\ProgramData\Looking Glass (host)\looking-glass-host.txt`

**Test with Spice first**:
- Re-add Spice graphics to VM XML
- Confirm GPU passthrough works
- Then remove Spice and use Looking Glass

***

## Problem 5: Audio Issues

**Audio crackling/desync**:

Edit VM XML audio section:

```xml
<audio id="1" type="pipewire">
  <input mixingEngine="no"/>
  <output mixingEngine="no" latency="1024"/>
</audio>
```

Increase `latency` value (512 → 1024 → 2048) until stable.

**Alternative: Use SCREAM** (network audio):

1. Install SCREAM on host: `yay -S scream`
2. Install SCREAM driver in Windows VM
3. Run receiver on host:
   ```bash
   scream -i virbr0 -p 4010
   ```

***

# PHASE 10: FINAL TESTING & BENCHMARKING

## Step 10.1: Performance Verification

**Test GPU in Windows VM**:

1. **Download 3DMark Demo** (Steam)
2. Run **Time Spy** benchmark
3. Compare score to native Windows performance (should be 85-95%)

**Monitor performance while running**:

On host:

```bash
# CPU usage
htop

# GPU binding
lspci -k | grep -A 3 "01:00"

# VM stats
virsh domstats win10-gaming --cpu-total --balloon --block
```

In Windows:
- Task Manager → Performance → GPU
- HWiNFO64 (monitor clocks, temps, power)

***

## Step 10.2: Thermal Monitoring

**Monitor temperatures during VM operation**:[44]

```bash
# Host temperatures
watch -n 1 sensors

# Expected:
# Tctl (CPU): < 85°C
# AMD Radeon 660M edge: < 70°C
```

**If temperatures exceed 85°C**:
- Use laptop cooling pad
- Ensure vents are clean
- Consider undervolting with `ryzenadj`:
  ```bash
  yay -S ryzenadj
  sudo ryzenadj --stapm-limit=40000 --fast-limit=50000 --slow-limit=40000
  ```

***

## Step 10.3: Latency Testing

**Input latency**:
- Play a fast-paced game (CS:GO, Valorant)
- Input lag should be imperceptible (<5ms added latency)

**Looking Glass latency**:
- Enable FPS counter in Looking Glass: `showFPS=yes` in config
- Should maintain 120 FPS at 1920x1080

---

## Step 10.4: Daily Usage Workflow

**Morning gaming session**:

```bash
# Launch VM
vm-start

# Looking Glass opens automatically
# Press Scroll Lock to capture input
# Game in Windows VM

# When done:
vm-stop
```

**Check status anytime**:

```bash
vm-stat
```

***

## COMPLETE CONFIGURATION SUMMARY

### Files Created/Modified

| File | Purpose |
|------|---------|
| `/etc/default/grub` | Kernel parameters (IOMMU, isolation) |
| `/etc/modprobe.d/vfio.conf` | VFIO binding configuration |
| `/etc/modprobe.d/blacklist-nvidia.conf` | Blacklist NVIDIA drivers on host |
| `/etc/mkinitcpio.conf` | Early VFIO module loading |
| `/etc/sysctl.d/90-hugepages.conf` | Hugepages allocation |
| `/etc/tmpfiles.d/looking-glass.conf` | Looking Glass shared memory |
| `/etc/tmpfiles.d/thp.conf` | Transparent hugepage settings |
| `/etc/udev/rules.d/60-ioschedulers.rules` | I/O scheduler optimization |
| `/etc/libvirt/qemu.conf` | Libvirt performance settings |
| `/etc/libvirt/hooks/qemu` | VM lifecycle hooks |
| `/usr/local/bin/set-irq-affinity.sh` | IRQ pinning script |
| `/usr/local/bin/vm-prepare.sh` | Pre-launch preparation |
| `/usr/local/bin/vm-launch.sh` | VM launcher |
| `/usr/local/bin/vm-shutdown.sh` | Graceful shutdown |
| `/usr/local/bin/vm-cleanup.sh` | Post-shutdown cleanup |
| `/usr/local/bin/vm-status.sh` | Status dashboard |
| `

[1](https://forum.qubes-os.org/t/why-lenovo-ideapad-gaming-3-15arh7-type-82sb-not-support/25396?page=2)
[2](https://pcsupport.lenovo.com/us/en/products/laptops-and-netbooks/gaming-series/ideapad-gaming-3-15arh7/82sb/document-userguide)
[3](https://github.com/bryansteiner/gpu-passthrough-tutorial)
[4](https://forums.lenovo.com/t5/Lenovo-IdeaPad-1xx-3xx-5xx-7xx-Edge-LaVie-Z-Flex-Laptops/Change-display-GPU-from-integrated-to-dedicated-Ideapad-Gaming-3/m-p/5230789)
[5](https://www.reddit.com/r/GamingLaptops/comments/15unk7u/external_graphics_card_ideapad_gaming_3_15arh7/)
[6](https://forums.lenovo.com/t5/Gaming-Laptops/Lenovo-IdeaPad-Gaming-3-15ARH7/m-p/5341151)
[7](https://forum.proxmox.com/threads/successful-experience-with-laptop-gpu-passthrough.95683/)
[8](https://lenovopress.lenovo.com/lp1470-configuring-a-passthrough-gpu-in-a-linux-vm)
[9](https://forums.lenovo.com/t5/Lenovo-IdeaPad-1xx-3xx-5xx-7xx-Edge-LaVie-Z-Flex-Laptops/i-have-ideapad-gaming-3-15arh7-i-have-query-about-port-and-their-connection-to-gpu/m-p/10005269)
[10](https://www.reddit.com/r/GamingLaptops/comments/114d08y/accessing_lenovo_ideapad_gaming_3_15ach6_advanced/)
[11](https://www.youtube.com/watch?v=7SWCwh1HQLQ)
[12](https://winraid.level1techs.com/t/howto-enable-hidden-features-of-lenovo-legion-5-15arh05/35995)
[13](https://discuss.cachyos.org/t/qemu-missing-iommu-support/12926)
[14](https://thedev.uk/grub-parameters-for-gpu-passthrough-a-comprehensive-guide/)
[15](https://support.lenovo.com/in/en/downloads/ds557707-bios-update-for-windows-11-64-bit-ideapad-gaming-3-15arh7-ideapad-gaming-3-16arh7)
[16](https://github.com/clayfreeman/gpu-passthrough)
[17](https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF)
[18](https://forum.proxmox.com/threads/simple-working-gpu-passthrough-on-uptodate-pve-and-amd-hardware.145462/)
[19](https://www.reddit.com/r/VFIO/comments/16izhnm/gpu_passthrough_stops_working_once_a_secondary/)
[20](https://forums.developer.nvidia.com/t/acs-override-patch-to-isolate-target-device-from-iommu-group/224283)
[21](https://wiki.archlinux.org/title/Btrfs)
[22](https://bbs.archlinux.org/viewtopic.php?id=302014)
[23](https://badai.xyz/articles/2023-02-28-linux-6.x-efi-framebuffer-crash-vfio.html)
[24](https://github.com/isc30/ryzen-gpu-passthrough-proxmox)
[25](https://forum.proxmox.com/threads/gpu-nvidia-rtx3050-pcie-passthrough-error-unable-to-start-vm.117848/)
[26](https://www.heiko-sieger.info/12-years-gpu-passthrough/)
[27](https://www.acldigital.com/blogs/performance-tuning-vm-cpu-pinning)
[28](https://blog.moroz.cc/post/gpu-pci-passthrough-to-windows-kvm-on-arch-linux/)
[29](https://forums.unraid.net/topic/144180-trying-to-passthrough-igpu-with-a-radeon-5-6600h-to-a-win11-vmno-joy/)
[30](https://bbs.archlinux.org/viewtopic.php?id=280512)
[31](https://www.qemu.org/docs/master/system/i386/hyperv.html)
[32](https://mathiashueber.com/performance-tweaks-gaming-on-virtual-machines/)
[33](https://bobcares.com/blog/cpu-pinning-in-kvm/)
[34](https://wiki.archlinux.org/title/Improving_performance)
[35](https://looking-glass.io/docs/B6/install/)
[36](https://forum.level1techs.com/t/solved-unable-to-increase-ivshmem-size-for-1440p-monitor/174864)
[37](https://www.reddit.com/r/VFIO/comments/ldr8rs/looking_glass_how_much_performance_hit_is_there/)
[38](https://www.reddit.com/r/hyprland/comments/120i21r/hyprland_looking_glass_for_vfio_wayland/)
[39](https://www.reddit.com/r/VFIO/comments/fduuvi/a_reminder_that_passthrough_of_nvidia_gpus/)
[40](https://www.youtube.com/watch?v=n0P6wXfhWPA)
[41](https://github.com/joeknock90/Single-GPU-Passthrough)
[42](https://github.com/Matoking/NVIDIA-vBIOS-VFIO-Patcher)
[43](https://www.youtube.com/watch?v=FWn6OCWl63o)
[44](https://forum.garudalinux.org/t/btrfs-cleaner-high-cpu-usage/16779)