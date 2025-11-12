Now I'll compile the comprehensive master tutorial for your GPU passthrough setup based on all the research gathered.

---

# ULTIMATE GPU PASSTHROUGH MASTER TUTORIAL
## Lenovo IdeaPad Gaming 3 15ARH7 - Windows 10 VM with NVIDIA RTX 3050 Mobile Passthrough

[10][11][12][13][14][15][16][17][18][19]

***

## Executive Summary

### Feasibility Assessment

Your Lenovo IdeaPad Gaming 3 15ARH7 configuration is **highly favorable** for GPU passthrough. The dual-GPU setup (AMD Radeon 660M integrated + NVIDIA RTX 3050 Mobile discrete) is ideal for maintaining host display functionality while passing the NVIDIA GPU to a Windows 10 VM.[11][14][20][21][10]

**Key Advantages:**
- AMD Ryzen 5 6600H has excellent IOMMU support (AMD-Vi)[14]
- Dual GPU configuration eliminates single-GPU passthrough complexity[22][23]
- CachyOS kernel 6.16.8 includes all necessary VFIO/IOMMU patches[24]
- 16GB RAM and 12-thread CPU provide adequate resources for VM[25][26]
- Wayland + Hyprland compatible with Looking Glass[27][28]

**Critical Challenges:**
1. **BIOS Limitations**: Lenovo laptops often hide advanced IOMMU settings; may require BIOS unlocking[13][29]
2. **NVIDIA Mobile GPU**: Ampere mobile GPUs sometimes require VBIOS patching[30][31][32]
3. **Storage Constraints**: 91% full Btrfs volume; need 60-80GB for Windows VM[2][3]
4. **Thermal Management**: Laptop cooling limitations during simultaneous host/VM workload[33]
5. **High System Load**: Current 4.64 load average indicates resource contention[1]

**Recommended Approach**: Dual-GPU passthrough with Looking Glass for seamless display integration, avoiding single-GPU complexity while maintaining host usability.[34][22][27]

**Expected Performance**: 85-95% native GPU performance in VM with proper configuration.[35][36][37]

---

## PART 1: Pre-Configuration Analysis

### 1.1 Verify IOMMU Groups and Device Isolation

First, check if IOMMU is enabled and examine device grouping:[15][18]

```bash
# Check IOMMU status
dmesg | grep -i -e DMAR -e IOMMU | grep -i enabled

# List all IOMMU groups
for d in /sys/kernel/iommu_groups/*/devices/*; do 
    n=${d#*/iommu_groups/*}; n=${n%%/*}
    printf 'IOMMU Group %s ' "$n"
    lspci -nns "${d##*/}"
done | sort -V
```

**Critical Output to Find**:[18][38]
```
IOMMU Group X 01:00.0 VGA compatible controller [0300]: NVIDIA Corporation GA107M [GeForce RTX 3050 Mobile] [10de:25a2]
IOMMU Group X 01:00.1 Audio device [0403]: NVIDIA Corporation GA107 High Definition Audio Controller [10de:2291]
```

**Get detailed GPU PCI information**:[19][15]
```bash
# Identify your NVIDIA GPU
lspci -nnk | grep -i nvidia -A 3

# Get vendor:device IDs (you'll need these)
lspci -nn | grep -i nvidia

# Check PCIe generation and link speed
lspci -vv -s 01:00.0 | grep -i "lnkcap\|lnksta"

# Verify NVIDIA companion devices
lspci -nnk | grep -i "nvidia\|vga\|3d\|audio" -A 2
```

**Expected NVIDIA Device IDs**:[12][32]
- GPU: `10de:25a2` (RTX 3050 Mobile)
- Audio: `10de:2291` (NVIDIA Audio Controller)

### 1.2 BIOS Configuration Requirements

**Access Lenovo Advanced BIOS**:[29][13]

Your Lenovo IdeaPad Gaming 3 15ARH7 (BIOS JNCN52WW V2.12) may have hidden advanced settings. Standard access:

1. **Enter BIOS**: Press `F2` or `Fn+F2` during boot
2. **Look for these settings**:
   - **Virtualization**: AMD-V / SVM Mode → **Enabled**
   - **IOMMU**: AMD-Vi → **Enabled** (may be under "System Configuration" or "Advanced")
   - **Above 4G Decoding**: → **Enabled** (if available)
   - **Resizable BAR**: → **Enabled** (optional, improves performance)
   - **CSM/Legacy Boot**: → **Disabled** (use pure UEFI)

**If IOMMU option is missing**:[13][29]
- Lenovo often hides this setting
- IOMMU may be enabled by default on Ryzen 6000 series
- Verify with: `dmesg | grep AMD-Vi`
- If disabled and no BIOS option exists, you may need BIOS modding (advanced, not recommended for beginners)

### 1.3 NVIDIA RTX 3050 Mobile VBIOS Considerations

**Check if VBIOS dump is required**:[31][32][30]

Modern NVIDIA mobile GPUs (Ampere generation) often work without VBIOS patching, but some laptops require it:[32][12]

```bash
# Check if GPU ROM is accessible
ls -l /sys/bus/pci/devices/0000:01:00.0/rom

# Attempt to read ROM (may fail if locked)
echo 1 | sudo tee /sys/bus/pci/devices/0000:01:00.0/rom
sudo cat /sys/bus/pci/devices/0000:01:00.0/rom > rtx3050_mobile.rom
echo 0 | sudo tee /sys/bus/pci/devices/0000:01:00.0/rom
```

**If ROM read fails**:[30][32]
- You'll need to dump VBIOS from Windows using GPU-Z or NVFlash
- Patch the ROM using NVIDIA-vBIOS-VFIO-Patcher if error 43 occurs[31]
- Store patched ROM in `/usr/share/vgabios/`

**Decision Point**: Start without VBIOS ROM first; only dump/patch if VM shows "Code 43" error in Device Manager.[32]

### 1.4 Kernel and Module Verification

**Verify CachyOS kernel supports VFIO**:[39][24]

```bash
# Check if VFIO modules are available
modinfo vfio
modinfo vfio_pci
modinfo vfio_iommu_type1

# Check kernel config (should show =y or =m)
zcat /proc/config.gz | grep -i vfio
zcat /proc/config.gz | grep -i iommu
```

**Expected output**:[18]
```
CONFIG_VFIO=m
CONFIG_VFIO_PCI=m
CONFIG_VFIO_IOMMU_TYPE1=m
CONFIG_AMD_IOMMU=y
CONFIG_AMD_IOMMU_V2=y
```

CachyOS kernel 6.16.8 includes all necessary patches.[24][39]

### 1.5 Btrfs Storage Assessment

**Current situation**:[3][2]
- 91% full (318.97 GB / 350.50 GB used)
- Windows 10 VM needs: 60-80 GB minimum
- Looking Glass IVSHMEM: ~128-256 MB RAM

**Create dedicated subvolume for VM images**:[2][3]

```bash
# Check current subvolumes
sudo btrfs subvolume list /

# Create VM subvolume with optimized settings
sudo btrfs subvolume create /vm-images

# Mount with performance options (add to /etc/fstab)
# Disable CoW for VM images (reduces fragmentation)
sudo chattr +C /vm-images

# Optional: Create compressed subvolume for VM storage
# Add to /etc/fstab:
# UUID=xxx /vm-images btrfs noatime,compress=zstd:3,space_cache=v2,subvol=vm-images 0 0
```

**Btrfs-specific considerations**:[4][2]
- **Disable CoW for VM images**: Prevents fragmentation and improves performance[2]
- **Use compression**: `compress=zstd:3` for VM storage partition[4][2]
- **Avoid snapshots of VM subvolume**: Snapshots slow down large file operations[3]
- **Consider qcow2 vs raw**: raw images perform better but can't be compressed[2]

### 1.6 IOMMU Group Conflict Assessment

**Check if NVIDIA GPU shares IOMMU group with critical devices**:[40][41]

```bash
# Focus on NVIDIA GPU group
for d in /sys/kernel/iommu_groups/*/devices/0000:01:00.0; do
    n=${d#*/iommu_groups/*}; n=${n%%/*}
    echo "IOMMU Group $n:"
    for dev in /sys/kernel/iommu_groups/$n/devices/*; do
        printf '  %s\n' "$(lspci -nns "${dev##*/}")"
    done
done
```

**Ideal scenario**:[21][11]
- NVIDIA GPU (01:00.0) and NVIDIA Audio (01:00.1) in same group, isolated from other devices

**If GPU shares group with other devices**:[41][40]
- May need ACS override patch (risky, reduces IOMMU security)
- AMD platforms usually have good IOMMU granularity[14]
- Lenovo IdeaPad Gaming 3 typically has acceptable grouping[10][13]

---

## PART 2: Kernel and Module Configuration

### 2.1 GRUB Bootloader Configuration

**Edit GRUB configuration**:[38][42][18]

```bash
sudo nvim /etc/default/grub
```

**Add kernel parameters to `GRUB_CMDLINE_LINUX_DEFAULT`**:[42][38]

```bash
GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet amd_iommu=on iommu=pt video=efifb:off vfio-pci.ids=10de:25a2,10de:2291"
```

**Parameter explanation**:[38][42][18]
- `amd_iommu=on` - Enables AMD IOMMU/AMD-Vi support[14][38]
- `iommu=pt` - Passthrough mode (better performance, devices only use IOMMU when passed to VM)[18][38]
- `video=efifb:off` - Prevents kernel from binding EFI framebuffer to NVIDIA GPU[42][18]
- `vfio-pci.ids=10de:25a2,10de:2291` - Binds NVIDIA GPU and audio to vfio-pci at boot[38][18]

**Alternative approach (if IDs conflict with multiple devices)**:[42]
- Use `video=vesafb:off,efifb:off` if system fails to boot
- Or use modprobe configuration instead (next section)

**Regenerate GRUB config**:[15][19]
```bash
sudo grub-mkconfig -o /boot/grub/grub.cfg

# Verify parameters will be applied
grep "amd_iommu" /boot/grub/grub.cfg
```

### 2.2 VFIO Module Configuration

**Create VFIO module configuration**:[15][18]

```bash
sudo nvim /etc/modprobe.d/vfio.conf
```

**Add the following**:[17][15][18]
```bash
# Bind NVIDIA GPU to VFIO at boot
options vfio-pci ids=10de:25a2,10de:2291

# Prevent NVIDIA drivers from loading on host
softdep nvidia pre: vfio-pci
softdep nvidia* pre: vfio-pci
softdep nouveau pre: vfio-pci

# Enable VFIO features
options vfio-pci disable_vga=1
options vfio_iommu_type1 allow_unsafe_interrupts=1
```

**Parameter explanation**:[32][18]
- `ids=10de:25a2,10de:2291` - Device IDs for RTX 3050 Mobile + audio
- `softdep` lines prevent nvidia/nouveau from claiming GPU before vfio-pci[18]
- `disable_vga=1` - Disables VGA arbitration (safe with dual GPU)[18]
- `allow_unsafe_interrupts=1` - Required for some systems (generally safe on modern hardware)[18]

### 2.3 Blacklist NVIDIA Drivers on Host

**Create blacklist configuration**:[19][15]

```bash
sudo nvim /etc/modprobe.d/blacklist-nvidia.conf
```

**Add**:[17][15]
```bash
blacklist nvidia
blacklist nvidia_drm
blacklist nvidia_modeset
blacklist nvidia_uvm
blacklist nouveau
```

**Note**: This prevents host from using NVIDIA GPU. AMD Radeon 660M will handle all host graphics.[20][21]

### 2.4 Mkinitcpio Configuration

**Edit mkinitcpio hooks**:[43][18]

```bash
sudo nvim /etc/mkinitcpio.conf
```

**Modify MODULES and HOOKS**:[43][15][18]

```bash
# Add VFIO modules (load early)
MODULES=(vfio_pci vfio vfio_iommu_type1 vfio_virqfd)

# Ensure modconf hook is present
HOOKS=(base udev autodetect modconf kms keyboard keymap consolefont block filesystems fsck)
```

**Module load order is critical**:[43][18]
1. `vfio_pci` must load before graphics drivers
2. `modconf` hook reads `/etc/modprobe.d/` configuration
3. Place VFIO modules before `kms` hook

**Regenerate initramfs**:[19][15]
```bash
sudo mkinitcpio -P

# Reboot to apply changes
sudo reboot
```

### 2.5 Verify VFIO Binding After Reboot

**Check if NVIDIA GPU is bound to vfio-pci**:[15][18]

```bash
# Should show vfio-pci as kernel driver
lspci -nnk -d 10de:25a2

# Check dmesg for VFIO messages
dmesg | grep -i vfio

# Verify IOMMU is active
dmesg | grep -i "AMD-Vi"

# Check if devices are bound
lspci -k | grep -A 3 -i nvidia
```

**Expected output**:[18]
```
01:00.0 VGA compatible controller: NVIDIA Corporation GA107M [GeForce RTX 3050 Mobile]
    Kernel driver in use: vfio-pci
    Kernel modules: nouveau, nvidia

01:00.1 Audio device: NVIDIA Corporation GA107 High Definition Audio Controller
    Kernel driver in use: vfio-pci
```

**If GPU is not bound to vfio-pci**:[42][43]
- Check GRUB parameters: `cat /proc/cmdline`
- Verify module load order: `lsmod | grep vfio`
- Check for errors: `dmesg | grep -i "vfio\|nvidia"`

***

## PART 3: KVM/QEMU Installation and Setup

### 3.1 Install Required Packages

**Install virtualization stack**:[19][15]

```bash
# Core virtualization packages
sudo pacman -S qemu-full libvirt virt-manager edk2-ovmf dnsmasq iptables-nft

# Additional tools
sudo pacman -S bridge-utils virt-viewer spice-vdagent spice-protocol

# Looking Glass dependencies (covered in Part 4)
sudo pacman -S cmake gcc libx11 nettle libxi libxinerama libxss libxcursor libxpresent libxkbcommon wayland-protocols ttf-dejavu freetype2 spice-protocol fontconfig
```

### 3.2 Configure Libvirt

**Enable and start libvirt service**:[15][19]

```bash
# Enable libvirtd
sudo systemctl enable --now libvirtd
sudo systemctl enable --now virtlogd

# Add your user to libvirt group
sudo usermod -a -G libvirt,kvm $(whoami)

# Apply group changes (or logout/login)
newgrp libvirt
```

**Configure libvirt networking**:[15]

```bash
# Start default network
sudo virsh net-start default
sudo virsh net-autostart default

# Verify network
sudo virsh net-list --all
```

### 3.3 Optimize Libvirt for Performance

**Edit libvirt QEMU configuration**:[36][37]

```bash
sudo nvim /etc/libvirt/qemu.conf
```

**Add/uncomment**:[37][15]
```bash
# User/group for QEMU processes
user = "your_username"
group = "kvm"

# Huge pages support
hugetlbfs_mount = "/dev/hugepages"

# Security driver (use if no SELinux/AppArmor)
security_driver = "none"

# Real-time scheduling (for CPU pinning)
# Leave commented for now, enable if needed
```

**Restart libvirtd**:[15]
```bash
sudo systemctl restart libvirtd
```

***

## PART 4: Hugepages Configuration

### 4.1 Calculate Hugepages Requirements

**Memory allocation plan**:[25][37]
- Total RAM: 14.81 GiB (≈15 GB)
- VM allocation: 10 GB (10240 MB)
- Hugepage size: 2 MB (default)
- Required hugepages: 10240 / 2 = **5120 pages**
- Reserve for host: 5 GB (+ IVSHMEM 256 MB for Looking Glass)

### 4.2 Configure Transparent Hugepages

**Create hugepages configuration**:[26][37]

```bash
sudo nvim /etc/sysctl.d/90-hugepages.conf
```

**Add**:[37]
```bash
# Allocate 5120 hugepages (10 GB for VM)
vm.nr_hugepages = 5120

# Hugepage allocation at boot
vm.hugetlb_shm_group = 36  # kvm group ID, check with: getent group kvm
```

**Apply configuration**:[37]
```bash
sudo sysctl -p /etc/sysctl.d/90-hugepages.conf

# Verify allocation
cat /proc/meminfo | grep -i huge

# Check /dev/hugepages mount
mount | grep huge
```

**Expected output**:
```
HugePages_Total:    5120
HugePages_Free:     5120
HugePages_Rsvd:        0
Hugepagesize:       2048 kB
```

### 4.3 Alternative: Dynamic Hugepages Allocation

**Create allocation script** (if boot-time allocation fails):[37]

```bash
sudo nvim /usr/local/bin/allocate-hugepages.sh
```

```bash
#!/bin/bash
echo 5120 | sudo tee /proc/sys/vm/nr_hugepages
```

```bash
sudo chmod +x /usr/local/bin/allocate-hugepages.sh
```

**Create systemd service**:
```bash
sudo nvim /etc/systemd/system/allocate-hugepages.service
```

```ini
[Unit]
Description=Allocate Hugepages for KVM
Before=libvirtd.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/allocate-hugepages.sh

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl enable allocate-hugepages.service
```

***

## PART 5: Looking Glass Setup

### 5.1 Calculate IVSHMEM Size

**Formula for shared memory**:[44][34][35]

$$ \text{IVSHMEM Size} = \text{Width} \times \text{Height} \times 4 \text{ bytes (RGBA)} \times 2 \text{ (double buffer)} + \text{Overhead} $$

**For 1920x1080@120Hz**:[34][44]

$$ 1920 \times 1080 \times 4 \times 2 = 16,588,800 \text{ bytes} \approx 16 \text{ MB} $$

**Recommended size with overhead**: **128 MB** or **256 MB**[44][34]

Using 128 MB is generally sufficient for 1080p; 256 MB provides headroom for higher frame rates and HDR.[35]

### 5.2 Configure IVSHMEM Device

**Create shared memory tmpfs**:[23][34]

```bash
# Add to /etc/fstab for persistence
sudo nvim /etc/fstab
```

**Add line**:[34]
```bash
tmpfs /dev/shm tmpfs defaults,size=512M 0 0
```

**Create Looking Glass shared memory file**:[23][34]

```bash
# Create shared memory file (256 MB)
sudo touch /dev/shm/looking-glass
sudo chown $USER:kvm /dev/shm/looking-glass
sudo chmod 660 /dev/shm/looking-glass
```

**Make persistent with systemd tmpfiles**:[34]
```bash
sudo nvim /etc/tmpfiles.d/looking-glass.conf
```

```bash
# Type Path                Mode UID      GID       Age
f     /dev/shm/looking-glass 0660 your_user kvm       -
```

### 5.3 Install Looking Glass Client (Host)

**Build from source**:[27][34]

```bash
# Clone Looking Glass repository
cd ~/builds
git clone --recursive https://github.com/gnif/LookingGlass.git
cd LookingGlass

# Checkout stable version
git checkout stable

# Build client
cd client
mkdir build && cd build
cmake ../
make -j$(nproc)

# Install
sudo make install
```

**Create Looking Glass configuration for Wayland**:[28][27]

```bash
mkdir -p ~/.config/looking-glass
nvim ~/.config/looking-glass/client.ini
```

**Configuration for Hyprland (Wayland)**:[27]
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

[input]
grabKeyboard=yes
grabKeyboardOnFocus=yes
releaseKeysOnFocusLoss=yes
escapeKey=KEY_SCROLLLOCK

[egl]
vsync=no
doubleBuffer=yes

[spice]
enable=yes
host=127.0.0.1
port=5900
```

### 5.4 Install Looking Glass Host (Windows VM)

**Download from Looking Glass website**:[34]
- Will be installed in Windows 10 VM after creation
- Download URL: https://looking-glass.io/downloads
- Install `looking-glass-host-setup.exe` in Windows
- Configure to start with Windows

---

## PART 6: Windows 10 VM Creation

### 6.1 Download Windows 10 ISO

```bash
# Download Windows 10 ISO
cd ~/Downloads
# Use official Microsoft Media Creation Tool or download from:
# https://www.microsoft.com/software-download/windows10

# Alternatively, use Ventoy USB (you already have one)
# Place Windows 10 ISO on Ventoy drive
```

### 6.2 Download VirtIO Drivers

```bash
# Download VirtIO drivers ISO
wget https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso -O ~/Downloads/virtio-win.iso
```

### 6.3 Create VM Storage

**Create VM disk image**:[2][15]

```bash
# Navigate to VM storage
cd /vm-images

# Create raw disk image (better performance on Btrfs with CoW disabled)
qemu-img create -f raw windows10.img 80G

# OR create qcow2 (allows snapshots, slightly slower)
# qemu-img create -f qcow2 windows10.qcow2 80G
```

### 6.4 Create Initial VM with virt-manager

**Launch virt-manager**:[19][15]

```bash
virt-manager
```

**VM Creation Steps**:[15]
1. **New VM** → "Local install media"
2. **Choose ISO**: Browse to Windows 10 ISO
3. **OS Type**: Windows 10
4. **Memory**: 10240 MB (10 GB)
5. **CPUs**: 8 (will configure pinning later)
6. **Storage**: Use existing `/vm-images/windows10.img`
7. **Network**: Default NAT
8. **Customize before install**: ✓ Check this

### 6.5 Initial VM XML Configuration

**Before starting installation, configure XML**:[36][15]

In virt-manager, go to **Overview** → **XML** tab.

**Replace with optimized configuration**:[36][37][15]

```xml
<domain xmlns:qemu="http://libvirt.org/schemas/domain/qemu/1.0" type="kvm">
  <name>win10-gaming</name>
  <uuid>GENERATE-NEW-UUID</uuid>
  <metadata>
    <libosinfo:libosinfo xmlns:libosinfo="http://libosinfo.org/xmlns/libvirt/domain/1.0">
      <libosinfo:os id="http://microsoft.com/win/10"/>
    </libosinfo:libosinfo>
  </metadata>
  
  <memory unit="KiB">10485760</memory>
  urrentntMemory unit="KiB">10485760</currentMemory>
  
  <!-- Hugepages support -->
  <memoryBacking>
    <hugepages/>
    <locked/>
  </memoryBacking>
  
  <vcpu placement="static">8</vcpu>
  
  <!-- CPU pinning for Ryzen 5 6600H (6 cores, 12 threads) -->
  <!-- Reserve threads 0-3 for host, pin 4-11 to VM -->
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
  </cputune>
  
  <iothreads>1</iothreads>
  
  <os>
    <type arch="x86_64" machine="pc-q35-9.0">hvm</type>
    <!-- OVMF UEFI firmware -->
    <loader readonly="yes" type="pflash">/usr/share/edk2/x64/OVMF_CODE.4m.fd</loader>
    <nvram template="/usr/share/edk2/x64/OVMF_VARS.4m.fd">/var/lib/libvirt/qemu/nvram/win10-gaming_VARS.fd</nvram>
    <boot dev="hd"/>
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
      <evmcs state="off"/>
    </hyperv>
    
    <!-- Hide KVM from VM (helps avoid detection) -->
    <kvm>
      <hidden state="on"/>
    </kvm>
    
    <vmport state="off"/>
    <smm state="on"/>
    <ioapic driver="kvm"/>
  </features>
  
  pu mode="host-passthrough" check="none"e" migratable="off">
    <topology sockets="1" dies="1" cores="4" threads="2"/>
    <cache mode="passthrough"/>
    <feature policy="require" name="topoext"/>
    <feature policy="require" name="invtsc"/>
  </cpu>
  
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
    
    <!-- Disk: VirtIO-SCSI with optimal performance settings -->
    <disk type="file" device="disk">
      <driver name="qemu" type="raw" cache="writeback" io="threads" discard="unmap" iothread="1"/>
      <source file="/vm-images/windows10.img"/>
      <target dev="sda" bus="scsi"/>
      <address type="drive" controller="0" bus="0" target="0" unit="0"/>
    </disk>
    
    <!-- Windows 10 ISO -->
    <disk type="file" device="cdrom">
      <driver name="qemu" type="raw"/>
      <source file="/home/your_user/Downloads/Win10_22H2_English_x64.iso"/>
      <target dev="sdb" bus="sata"/>
      <readonly/>
      <address type="drive" controller="0" bus="0" target="0" unit="1"/>
    </disk>
    
    <!-- VirtIO drivers ISO -->
    <disk type="file" device="cdrom">
      <driver name="qemu" type="raw"/>
      <source file="/home/your_user/Downloads/virtio-win.iso"/>
      <target dev="sdc" bus="sata"/>
      <readonly/>
      <address type="drive" controller="0" bus="0" target="0" unit="2"/>
    </disk>
    
    <!-- SCSI controller -->
    ontroller type="scsi" index="0"0" model="virtio-scsi">
      <driver iothread="1"/>
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
    
    ontroller type="s"sata" index="0">
      <address type="pci" domain="0x0000" bus="0x00" slot="0x1f" function="0x2"/>
    </controller>
    
    ontroller type="usb" index="0" model="qemu-xhci" ports="1515">
      <address type="pci" domain="0x0000" bus="0x02" slot="0x00" function="0x0"/>
    </controller>
    
    <!-- VirtIO network with vhost -->
    <interface type="network">
      <mac address="52:54:00:XX:XX:XX"/>
      <source network="default"/>
      <model type="virtio"/>
      <driver name="vhost" queues="8"/>
      <address type="pci" domain="0x0000" bus="0x01" slot="0x00" function="0x0"/>
    </interface>
    
    <!-- GPU Passthrough: NVIDIA RTX 3050 Mobile -->
    <hostdev mode="subsystem" type="pci" managed="yes">
      <source>
        <address domain="0x0000" bus="0x01" slot="0x00" function="0x0"/>
      </source>
      <!-- Optional: Uncomment if VBIOS is required -->
      <!--
      <rom file="/usr/share/vgabios/rtx3050_mobile_patched.rom"/>
      -->
      <address type="pci" domain="0x0000" bus="0x04" slot="0x00" function="0x0" multifunction="on"/>
    </hostdev>
    
    <!-- GPU Passthrough: NVIDIA Audio Controller -->
    <hostdev mode="subsystem" type="pci" managed="yes">
      <source>
        <address domain="0x0000" bus="0x01" slot="0x00" function="0x1"/>
      </source>
      <address type="pci" domain="0x0000" bus="0x04" slot="0x00" function="0x1"/>
    </hostdev>
    
    <!-- Spice display (for initial setup, disable after Looking Glass works) -->
    <graphics type="spice" autoport="yes">
      <listen type="address"/>
      <image compression="off"/>
      <gl enable="no"/>
    </graphics>
    
    <!-- QXL video (temporary, remove after GPU passthrough works) -->
    <video>
      <model type="qxl" ram="65536" vram="65536" vgamem="16384" heads="1" primary="yes"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x01" function="0x0"/>
    </video>
    
    <!-- VirtIO input devices -->
    <input type="keyboard" bus="virtio">
      <address type="pci" domain="0x0000" bus="0x05" slot="0x00" function="0x0"/>
    </input>
    <input type="tablet" bus="virtio">
      <address type="pci" domain="0x0000" bus="0x06" slot="0x00" function="0x0"/>
    </input>
    
    <!-- VirtIO balloon for memory management -->
    <memballoon model="virtio">
      <address type="pci" domain="0x0000" bus="0x07" slot="0x00" function="0x0"/>
    </memballoon>
    
    <!-- VirtIO RNG for entropy -->
    <rng model="virtio">
      <backend model="random">/dev/urandom</backend>
      <address type="pci" domain="0x0000" bus="0x08" slot="0x00" function="0x0"/>
    </rng>
    
    <!-- TPM 2.0 passthrough (for Windows 11 compatibility) -->
    <tpm model="tpm-crb">
      <backend type="emulator" version="2.0"/>
    </tpm>
  </devices>
  
  <!-- Looking Glass IVSHMEM device -->
  <qemu:commandline>
    <qemu:arg value="-device"/>
    <qemu:arg value="ivshmem-plain,memdev=ivshmem,bus=pcie.0"/>
    <qemu:arg value="-object"/>
    <qemu:arg value="memory-backend-file,id=ivshmem,share=on,mem-path=/dev/shm/looking-glass,size=256M"/>
  </qemu:commandline>
</domain>
```

**Critical notes**:[36][37][15]
1. **Replace UUID**: Generate new with `uuidgen`
2. **Update file paths**: Change `/home/your_user/` to your actual path
3. **Verify PCI addresses**: Match NVIDIA GPU addresses from `lspci`
4. **MAC address**: Generate random MAC or let libvirt auto-assign

### 6.6 CPU Pinning Strategy for Ryzen 5 6600H

**Ryzen 5 6600H topology**:[45][26][25]
- 6 physical cores (cores 0-5)
- 12 threads with SMT (threads 0-11)
- Single CCX configuration (no cross-CCX latency)

**Check topology**:[45][25]
```bash
lscpu -e
lstopo  # Install: sudo pacman -S hwloc
```

**Recommended pinning**:[26][25][45]
- **Host reserved**: Threads 0-3 (cores 0-1 + siblings)
- **VM allocated**: Threads 4-11 (cores 2-5 + siblings)
- **Emulator threads**: 0-3 (host-side processing)

**Rationale**:[26][45]
- Leave enough cores for host (Hyprland, system processes)
- VM gets 4 physical cores (8 threads) for gaming
- Avoid cross-CCX penalties (not applicable to 6600H, but good practice)

---

## PART 7: Windows 10 Installation

### 7.1 Initial Installation

**Start VM and install Windows**:[15]

1. **Start VM** in virt-manager
2. **Windows installation** will use Spice display initially
3. **Load VirtIO drivers** during installation:
   - When asked "Where do you want to install Windows?", click **Load driver**
   - Browse to VirtIO ISO → `amd64/w10` folder
   - Install `Red Hat VirtIO SCSI controller` driver
   - Your disk will now appear

4. **Complete Windows installation** normally
5. **After first boot**, install VirtIO drivers:
   - Open VirtIO ISO in Windows Explorer
   - Run `virtio-win-gt-x64.exe` installer
   - Install all drivers (network, balloon, serial, etc.)

### 7.2 Install NVIDIA Drivers in VM

**Download and install NVIDIA drivers**:[32]

```
1. Open Device Manager in Windows
2. Check if RTX 3050 appears (may show "Code 43" error)
3. Download latest NVIDIA GeForce Game Ready Driver
4. Install driver
5. Reboot VM
```

**If "Code 43" error persists**:[31][32]
- You need patched VBIOS (see Part 10.2)
- Verify Hyper-V enlightenments are enabled in XML
- Check `<kvm hidden="on"/>` is present

### 7.3 Install Looking Glass Host in Windows

**Download and install**:[34]

```
1. Download Looking Glass host installer from:
   https://looking-glass.io/downloads
2. Run looking-glass-host-setup.exe
3. Configure to start with Windows
4. In Services, set "Looking Glass (host)" to Automatic
```

### 7.4 Optimize Windows for VM Performance

**Disable Windows bloat**:[36][37]

```
1. Settings → Privacy → disable telemetry
2. Disable Windows Search indexing (Services → Windows Search → Disabled)
3. Disable Superfetch/SysMain (Services → SysMain → Disabled)
4. Set Windows Update to notify only
5. Disable Windows Defender real-time protection (during gaming)
6. Power Plan → High Performance
7. Visual Effects → Adjust for best performance
```

**Install MSI Afterburner / HWiNFO** (for monitoring).[37]

***

## PART 8: Looking Glass Integration

### 8.1 Configure Looking Glass in VM XML

The IVSHMEM device is already added in the XML configuration above.[23][34]

**Verify IVSHMEM in Windows**:[34]
- Device Manager → System devices → "IVSHMEM device" should appear
- If not, install IVSHMEM driver from Looking Glass host installer

### 8.2 Start Looking Glass Client on Host

**Remove QXL display from VM** (after GPU passthrough works):[34]

```xml
<!-- Remove or comment out -->
<!--
<graphics type="spice" autoport="yes">
<video>
  <model type="qxl" .../>
</video>
-->
```

**Start Looking Glass client on Hyprland**:[27]

```bash
# Run Looking Glass client
looking-glass-client

# Or with specific config
looking-glass-client -F -m KEY_SCROLLLOCK
```

**Keyboard shortcuts**:[34]
- **Scroll Lock**: Toggle input capture
- **Scroll Lock + Q**: Quit Looking Glass
- **Scroll Lock + F**: Toggle fullscreen

### 8.3 Wayland-Specific Configuration

**For Hyprland Wayland compatibility**:[28][27]

```bash
# Ensure Looking Glass client runs with Wayland backend
export SDL_VIDEODRIVER=wayland
export GDK_BACKEND=wayland
looking-glass-client
```

**Hyprland window rules** (optional):

```bash
# Add to ~/.config/hypr/hyprland.conf
windowrulev2 = float,class:(looking-glass-client)
windowrulev2 = size 1920 1080,class:(looking-glass-client)
windowrulev2 = center,class:(looking-glass-client)
```

### 8.4 Audio Passthrough

**Option 1: PulseAudio/PipeWire passthrough**:[36]

Add to VM XML:
```xml
<sound model="ich9">
  <audio id="1"/>
</sound>
<audio id="1" type="pulseaudio" serverName="/run/user/1000/pulse/native">
  <input mixingEngine="no"/>
  <output mixingEngine="no"/>
</audio>
```

**Option 2: SCREAM (network audio)**:[36]
- Install SCREAM driver in Windows
- Install scream receiver on host: `yay -S scream`
- Lower latency than PulseAudio passthrough

***

## PART 9: Dynamic GPU Rebinding (Optional)

**Note**: Since you have dual GPUs, rebinding is optional. The NVIDIA GPU remains bound to vfio-pci when VM is off.[21][23]

If you want NVIDIA available on host when VM is off, use libvirt hooks.[46][23]

### 9.1 Create Libvirt Hook Scripts

**Create hook directory**:[23]

```bash
sudo mkdir -p /etc/libvirt/hooks
sudo nvim /etc/libvirt/hooks/qemu
```

**Main hook script**:[46][23]
```bash
#!/bin/bash
#
# Libvirt hook for dynamic GPU rebinding
# Trigger on VM start/stop

GUEST_NAME="$1"
HOOK_NAME="$2"
STATE_NAME="$3"
MISC="${@:4}"

if [ "$GUEST_NAME" == "win10-gaming" ]; then
    if [ "$HOOK_NAME" == "prepare" ] && [ "$STATE_NAME" == "begin" ]; then
        # VM starting - unbind from vfio-pci (already done by default)
        /etc/libvirt/hooks/qemu.d/win10-gaming/prepare/begin/start.sh
    fi
    
    if [ "$HOOK_NAME" == "release" ] && [ "$STATE_NAME" == "end" ]; then
        # VM stopped - rebind to nvidia driver
        /etc/libvirt/hooks/qemu.d/win10-gaming/release/end/revert.sh
    fi
fi
```

```bash
sudo chmod +x /etc/libvirt/hooks/qemu
```

### 9.2 Create Start Script

```bash
sudo mkdir -p /etc/libvirt/hooks/qemu.d/win10-gaming/prepare/begin
sudo nvim /etc/libvirt/hooks/qemu.d/win10-gaming/prepare/begin/start.sh
```

```bash
#!/bin/bash
set -x

# GPU already bound to vfio-pci by kernel parameters
# This script can be used for additional prep (e.g., CPU governor)

# Set CPU governor to performance
echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

# Disable display manager (if needed)
# systemctl stop ly.service
```

```bash
sudo chmod +x /etc/libvirt/hooks/qemu.d/win10-gaming/prepare/begin/start.sh
```

### 9.3 Create Stop Script (GPU Rebinding)

```bash
sudo mkdir -p /etc/libvirt/hooks/qemu.d/win10-gaming/release/end
sudo nvim /etc/libvirt/hooks/qemu.d/win10-gaming/release/end/revert.sh
```

```bash
#!/bin/bash
set -x

# Rebind NVIDIA GPU to nvidia driver for host use
# (Only needed if you want CUDA/gaming on host after VM shutdown)

# Unload vfio-pci
modprobe -r vfio_pci
modprobe -r vfio_iommu_type1
modprobe -r vfio

# Rebind to nvidia
modprobe nvidia_drm
modprobe nvidia_modeset
modprobe nvidia_uvm
modprobe nvidia

# Bind devices
echo "0000:01:00.0" > /sys/bus/pci/drivers/nvidia/bind
echo "0000:01:00.1" > /sys/bus/pci/drivers/snd_hda_intel/bind

# Restart display manager
# systemctl start ly.service

# Set CPU governor back to powersave
echo powersave | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
```

```bash
sudo chmod +x /etc/libvirt/hooks/qemu.d/win10-gaming/release/end/revert.sh
```

**Note**: GPU rebinding is **not required** for your dual-GPU setup. The NVIDIA GPU can remain bound to vfio-pci permanently if you don't need it on the host.[21][23]

***

## PART 10: Troubleshooting and Optimization

### 10.1 Diagnostic Commands

**Check VM is using NVIDIA GPU**:[18][15]

```bash
# From host, while VM is running
sudo virsh dumpxml win10-gaming | grep -i hostdev
lspci -k | grep -A 3 "01:00.0"

# Check if GPU is in use by QEMU process
ps aux | grep qemu | grep 01:00.0
```

**Monitor VM performance**:[37]

```bash
# CPU usage
sudo virsh domstats win10-gaming --cpu-total

# Memory usage
sudo virsh domstats win10-gaming --balloon

# Disk I/O
sudo virsh domstats win10-gaming --block
```

**Check IOMMU groups**:[18][15]
```bash
for d in /sys/kernel/iommu_groups/*/devices/*; do 
    n=${d#*/iommu_groups/*}; n=${n%%/*}
    printf 'IOMMU Group %s ' "$n"
    lspci -nns "${d##*/}"
done | grep -i nvidia
```

### 10.2 NVIDIA "Code 43" Error

**Symptoms**:[31][32]
- Device Manager shows "Code 43: Windows has stopped this device"
- NVIDIA driver installs but GPU doesn't work

**Solutions**:[31][32]

**1. Verify Hyper-V enlightenments and hidden KVM**:[32][36]
```xml
<hyperv mode="custom">
  <vendor_id state="on" value="GenuineIntel"/>
  ...
</hyperv>
<kvm>
  <hidden state="on"/>
</kvm>
```

**2. Dump and patch VBIOS**:[30][31]

**From Windows (before passthrough)**:
- Download GPU-Z
- GPU-Z → Save BIOS to file → `rtx3050_mobile.rom`
- Transfer to Linux host

**Patch VBIOS**:[31]
```bash
git clone https://github.com/Matoking/NVIDIA-vBIOS-VFIO-Patcher
cd NVIDIA-vBIOS-VFIO-Patcher
python nvidia_vbios_vfio_patcher.py -i rtx3050_mobile.rom -o rtx3050_mobile_patched.rom

sudo mkdir -p /usr/share/vgabios/
sudo cp rtx3050_mobile_patched.rom /usr/share/vgabios/
```

**Add to VM XML**:[32][31]
```xml
<hostdev mode="subsystem" type="pci" managed="yes">
  <source>
    <address domain="0x0000" bus="0x01" slot="0x00" function="0x0"/>
  </source>
  <rom file="/usr/share/vgabios/rtx3050_mobile_patched.rom"/>
  ...
</hostdev>
```

**3. Update NVIDIA driver**:[32]
- Use latest Game Ready Driver from NVIDIA
- Avoid Studio drivers for passthrough

### 10.3 VM Won't Start / Black Screen

**Check VM logs**:[15]
```bash
sudo journalctl -u libvirtd -f
sudo tail -f /var/log/libvirt/qemu/win10-gaming.log
```

**Common issues**:[43][42]
1. **Hugepages not allocated**: Check `cat /proc/meminfo | grep Huge`
2. **OVMF firmware missing**: Reinstall `edk2-ovmf`
3. **PCI address conflict**: Verify addresses with `lspci`
4. **IVSHMEM file missing**: Check `/dev/shm/looking-glass` exists
5. **VFIO binding failed**: Check `dmesg | grep vfio`

### 10.4 Poor VM Performance

**Check CPU pinning is active**:[26]
```bash
# While VM is running
sudo virsh vcpuinfo win10-gaming

# Check CPU affinity
ps -eLo pid,tid,class,rtprio,ni,pri,psr,pcpu,stat,wchan:14,comm | grep qemu
```

**Verify hugepages are in use**:[37]
```bash
cat /proc/meminfo | grep -i huge
# HugePages_Rsvd should be non-zero when VM is running
```

**Check disk I/O**:[2]
```bash
# Monitor Btrfs disk usage
sudo btrfs filesystem usage /

# Check I/O scheduler
cat /sys/block/nvme0n1/queue/scheduler
# Should be [none] or [mq-deadline] for NVMe

# Monitor I/O in real-time
sudo iotop -o
```

**Optimize I/O scheduler**:[1]
```bash
# Set to none for NVMe (best performance)
echo none | sudo tee /sys/block/nvme0n1/queue/scheduler

# Make persistent
sudo nvim /etc/udev/rules.d/60-ioschedulers.rules
```

Add:
```
# NVMe: none scheduler
ACTION=="add|change", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/scheduler}="none"
```

### 10.5 Looking Glass Issues

**Black screen in Looking Glass client**:[35][34]

1. **Check IVSHMEM device in Windows**:
   - Device Manager → System devices → "IVSHMEM device"
   - If missing, reinstall Looking Glass host

2. **Verify shared memory**:
   ```bash
   ls -lh /dev/shm/looking-glass
   # Should show 256M size
   ```

3. **Check Looking Glass host logs** (in Windows):
   - `C:\ProgramData\Looking Glass (host)\looking-glass-host.txt`

4. **Test with Spice first**:
   - Ensure GPU passthrough works with Spice display
   - Then transition to Looking Glass

**Input lag or stuttering**:[35]

1. **Disable VSync in Looking Glass config**:
   ```ini
   [egl]
   vsync=no
   ```

2. **Ensure host has enough CPU**:
   - Looking Glass client needs 1-2 cores
   - Check if emulator threads are pinned correctly

3. **Wayland-specific**: Use `SDL_VIDEODRIVER=wayland`[27]

### 10.6 Audio Crackling / Desync

**PulseAudio passthrough issues**:[36]

```xml
<!-- Adjust buffer settings -->
<audio id="1" type="pulseaudio">
  <input mixingEngine="no"/>
  <output mixingEngine="no" bufferLength="256"/>
</audio>
```

**Alternative: Use SCREAM**:[36]
```bash
# Install on host
yay -S scream

# Run receiver
scream -i virbr0 -p 4010
```

In Windows VM:
- Install SCREAM driver
- Configure to use multicast or unicast to host IP

### 10.7 Thermal Throttling

**Monitor temperatures**:[5]

```bash
# CPU temperature
sensors | grep -i temp

# GPU temperature (AMD Radeon 660M)
cat /sys/class/drm/card0/device/hwmon/hwmon*/temp1_input
```

**Laptop cooling optimization**:
- Use laptop cooling pad
- Ensure vents are clean
- Run VM on AC power (not battery)
- Consider undervolting (use `ryzenadj` tool)

**Set aggressive fan curve** (if available):
```bash
# Install laptop-mode-tools
sudo pacman -S laptop-mode-tools

# Configure cooling policy
sudo nvim /etc/laptop-mode/conf.d/cpufreq.conf
```

### 10.8 High Host System Load

**Your current load average is 4.64**:[5][1]

**Investigate processes**:
```bash
# Top CPU consumers
htop

# Check btrfs-cleaner
ps aux | grep btrfs-cleaner

# Check if snapshots are being processed
sudo btrfs subvolume list / | wc -l
```

**Reduce Btrfs overhead**:[5][2]
```bash
# Remove old snapshots
sudo btrfs subvolume delete /path/to/old/snapshot

# Run balance (caution: high I/O)
sudo btrfs balance start -dusage=50 /

# Disable quotas if enabled (can cause high CPU)
sudo btrfs quota disable /
```

**Before running VM**, ensure system is idle.[1]

***

## PART 11: Performance Benchmarking

### 11.1 Expected Performance Metrics

**GPU Performance**:[35][37]
- **3DMark Time Spy**: 85-95% of native score
- **Games**: 5-10% performance hit maximum
- **Latency**: <1ms additional input lag with Looking Glass

**CPU Performance**:[26]
- VM should not impact host significantly with proper pinning
- Host retains 2 physical cores (4 threads) for Hyprland

### 11.2 Benchmarking Tools

**In Windows VM**:[37]
- 3DMark (Time Spy, Fire Strike)
- Unigine Heaven/Superposition
- Game benchmarks (built-in)
- CapFrameX (frame time analysis)
- HWiNFO64 (monitor clocks, temps, power)

**On Host**:[1]
```bash
# Monitor system during VM operation
htop

# I/O monitoring
sudo iotop

# Network monitoring (for Looking Glass)
iftop
```

### 11.3 Optimization Iteration

**If performance is suboptimal**:[26][37]

1. **Check CPU pinning**: Ensure no overlap between host and VM cores
2. **Verify hugepages**: Should show as reserved when VM runs
3. **Disk I/O**: Monitor with `iotop`, consider moving VM to raw partition
4. **Memory pressure**: Check swap usage, increase VM RAM if needed
5. **PCIe performance**: Verify GPU runs at Gen 4 x8 speeds in VM

***

## PART 12: Configuration Files Summary

### 12.1 Complete GRUB Configuration

**`/etc/default/grub`**:[38][42]
```bash
GRUB_DEFAULT=0
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR="Arch"
GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet amd_iommu=on iommu=pt video=efifb:off vfio-pci.ids=10de:25a2,10de:2291"
GRUB_CMDLINE_LINUX=""
GRUB_PRELOAD_MODULES="part_gpt part_msdos"
GRUB_GFXMODE=auto
GRUB_GFXPAYLOAD_LINUX=keep
GRUB_DISABLE_RECOVERY=true
```

### 12.2 Complete Module Configuration

**`/etc/modprobe.d/vfio.conf`**:[18][15]
```bash
options vfio-pci ids=10de:25a2,10de:2291
softdep nvidia pre: vfio-pci
softdep nvidia* pre: vfio-pci
softdep nouveau pre: vfio-pci
options vfio-pci disable_vga=1
options vfio_iommu_type1 allow_unsafe_interrupts=1
```

**`/etc/modprobe.d/blacklist-nvidia.conf`**:[15]
```bash
blacklist nvidia
blacklist nvidia_drm
blacklist nvidia_modeset
blacklist nvidia_uvm
blacklist nouveau
```

### 12.3 Complete Mkinitcpio Configuration

**`/etc/mkinitcpio.conf`**:[43][18]
```bash
MODULES=(vfio_pci vfio vfio_iommu_type1 vfio_virqfd)
BINARIES=()
FILES=()
HOOKS=(base udev autodetect modconf kms keyboard keymap consolefont block filesystems fsck)
```

### 12.4 Hugepages Configuration

**`/etc/sysctl.d/90-hugepages.conf`**:[37]
```bash
vm.nr_hugepages = 5120
vm.hugetlb_shm_group = 36
```

### 12.5 Looking Glass Shared Memory

**`/etc/tmpfiles.d/looking-glass.conf`**:[34]
```bash
f /dev/shm/looking-glass 0660 your_user kvm -
```

**`/etc/fstab` addition**:[34]
```bash
tmpfs /dev/shm tmpfs defaults,size=512M 0 0
```

### 12.6 Looking Glass Client Configuration

**`~/.config/looking-glass/client.ini`**:[27][34]
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

[input]
grabKeyboard=yes
grabKeyboardOnFocus=yes
releaseKeysOnFocusLoss=yes
escapeKey=KEY_SCROLLLOCK

[egl]
vsync=no
doubleBuffer=yes

[spice]
enable=yes
host=127.0.0.1
port=5900
```

***

## PART 13: Step-by-Step Implementation Checklist

### Phase 1: Preparation (1-2 hours)

- [ ] **Backup critical data** (VM setup can affect host stability)
- [ ] **Enter BIOS**: Enable AMD-V, IOMMU/AMD-Vi, disable CSM
- [ ] **Check IOMMU groups**: Run diagnostic commands from Part 1.1
- [ ] **Verify device IDs**: Confirm NVIDIA GPU/audio IDs
- [ ] **Clean up disk space**: Ensure 80+ GB free in `/vm-images`
- [ ] **Create Btrfs subvolume**: `/vm-images` with CoW disabled

### Phase 2: Kernel Configuration (30 minutes)

- [ ] **Edit GRUB**: Add kernel parameters
- [ ] **Create VFIO modprobe config**: `/etc/modprobe.d/vfio.conf`
- [ ] **Blacklist NVIDIA drivers**: `/etc/modprobe.d/blacklist-nvidia.conf`
- [ ] **Edit mkinitcpio**: Add VFIO modules
- [ ] **Regenerate GRUB config**: `grub-mkconfig`
- [ ] **Regenerate initramfs**: `mkinitcpio -P`
- [ ] **Reboot and verify**: Check `lspci -k` shows vfio-pci on GPU

### Phase 3: Libvirt Setup (30 minutes)

- [ ] **Install packages**: qemu-full, libvirt, virt-manager, edk2-ovmf
- [ ] **Enable libvirtd**: `systemctl enable --now libvirtd`
- [ ] **Add user to libvirt group**: `usermod -a -G libvirt,kvm`
- [ ] **Configure libvirt**: Edit `/etc/libvirt/qemu.conf`
- [ ] **Start default network**: `virsh net-start default`

### Phase 4: Hugepages (15 minutes)

- [ ] **Create sysctl config**: `/etc/sysctl.d/90-hugepages.conf`
- [ ] **Apply configuration**: `sysctl -p`
- [ ] **Verify allocation**: Check `/proc/meminfo`

### Phase 5: Looking Glass (30 minutes)

- [ ] **Create IVSHMEM file**: `/dev/shm/looking-glass`
- [ ] **Create tmpfiles config**: `/etc/tmpfiles.d/looking-glass.conf`
- [ ] **Build Looking Glass client**: Clone and compile
- [ ] **Create client config**: `~/.config/looking-glass/client.ini`
- [ ] **Download Looking Glass host**: For Windows installation

### Phase 6: VM Creation (1-2 hours)

- [ ] **Download Windows 10 ISO**: Official Microsoft download
- [ ] **Download VirtIO drivers**: `virtio-win.iso`
- [ ] **Create VM disk**: `qemu-img create` in `/vm-images`
- [ ] **Launch virt-manager**: Create new VM
- [ ] **Configure initial settings**: Memory, CPU, storage
- [ ] **Edit XML**: Replace with optimized configuration from Part 6.5
- [ ] **Verify XML syntax**: `virsh define` (done automatically by virt-manager)

### Phase 7: Windows Installation (1-2 hours)

- [ ] **Start VM**: Begin Windows installation
- [ ] **Load VirtIO SCSI driver**: During "Where to install Windows?"
- [ ] **Complete Windows setup**: User account, network
- [ ] **Install VirtIO drivers**: Run `virtio-win-gt-x64.exe`
- [ ] **Install NVIDIA drivers**: Download from NVIDIA website
- [ ] **Check Device Manager**: Verify GPU appears without Code 43
- [ ] **Install Looking Glass host**: Run installer in Windows
- [ ] **Configure Looking Glass host**: Set to start with Windows

### Phase 8: Looking Glass Integration (30 minutes)

- [ ] **Remove QXL display from XML**: Comment out Spice graphics
- [ ] **Restart VM**: Ensure it boots without QXL
- [ ] **Launch Looking Glass client**: On Hyprland host
- [ ] **Test display output**: Should show Windows desktop
- [ ] **Test input capture**: Scroll Lock to toggle
- [ ] **Configure audio**: PulseAudio passthrough or SCREAM

### Phase 9: Optimization (1 hour)

- [ ] **Verify CPU pinning**: Check `virsh vcpuinfo`
- [ ] **Monitor temperatures**: Use `sensors` during VM operation
- [ ] **Run benchmarks**: 3DMark in Windows VM
- [ ] **Tune performance**: Adjust CPU pinning, hugepages if needed
- [ ] **Test host performance**: Ensure Hyprland remains responsive

### Phase 10: Optional Enhancements

- [ ] **GPU rebinding hooks**: If you want NVIDIA on host post-VM
- [ ] **Startup scripts**: Automate Looking Glass client launch
- [ ] **Performance profiles**: Switch CPU governor for gaming
- [ ] **USB passthrough**: Pass entire USB controller for peripherals

***

## PART 14: Optimization Matrix

| Configuration Option | Performance Impact | Stability Risk | Implementation Difficulty |
|---------------------|-------------------|----------------|---------------------------|
| **CPU Pinning** | Very High (+15-25%) | Low | Medium |
| **Hugepages** | High (+10-15%) | Low | Easy |
| **IOMMU=pt** | Medium (+5-10%) | Low | Easy |
| **Hyper-V Enlightenments** | Medium (+5-10%) | Low | Easy |
| **VirtIO-SCSI** | High (+20-30% I/O) | Low | Easy |
| **Raw disk image** | Medium (+5-10% I/O) | Low | Easy |
| **Looking Glass** | Minimal (-1-2%) | Medium | Hard |
| **GPU VBIOS Patch** | None (fixes errors) | Medium | Medium |
| **ACS Override Patch** | None | High (security) | Hard |
| **CPU Governor=Performance** | Low (+2-5%) | None | Easy |
| **I/O Scheduler=none** | Medium (+5
