# THE ULTIMATE GPU PASSTHROUGH SETUP GUIDE
## Complete Dual-Mode Setup: VM Gaming + Host Gaming (Wine/Lutris)
### Lenovo IdeaPad Gaming 3 15ARH7 - Arch Linux + Hyprland

**Hardware**: AMD Ryzen 5 6600H | NVIDIA RTX 3050 Mobile | AMD Radeon 660M | 16GB RAM  
**Host OS**: Arch Linux (CachyOS 6.16.8) + Hyprland Wayland  
**Guest OS**: Windows 10 with GPU Passthrough  
**Display**: Looking Glass (seamless VM switching)  
**Dual Mode**: Dynamic GPU switching for VM + Host gaming

---

## TABLE OF CONTENTS

1. [Overview & Architecture](#overview)
2. [Pre-Installation Checklist](#pre-installation)
3. [BIOS Configuration](#bios-config)
4. [Kernel & VFIO Setup (Dynamic Mode)](#kernel-setup)
5. [NVIDIA Drivers Installation](#nvidia-drivers)
6. [Libvirt & KVM Setup](#libvirt-setup)
7. [Performance Tuning](#performance-tuning)
8. [Looking Glass Installation](#looking-glass)
9. [Windows VM Creation](#windows-vm)
10. [Dynamic GPU Rebinding Scripts](#gpu-rebinding)
11. [Automation & Lifecycle Management](#automation)
12. [Hyprland Integration & Keybindings](#hyprland-config)
13. [Wine/Lutris Configuration](#wine-lutris)
14. [Troubleshooting](#troubleshooting)
15. [Complete Workflow Guide](#workflow)

**Total Setup Time**: 4-6 hours

---

<a name="overview"></a>
## 1. OVERVIEW & ARCHITECTURE

### What You'll Build

A **triple-mode gaming setup**:

| Mode | GPU Binding | Performance | Use Case |
|------|-------------|-------------|----------|
| **Windows VM** | RTX 3050 → vfio-pci | 90-95% native | AAA games, anti-cheat games |
| **Wine/Lutris** | RTX 3050 → nvidia | 80-90% native | Most Windows games on Linux |
| **Native Linux** | RTX 3050 → nvidia | 100% native | Steam Proton, native games |

### System Architecture

```
┌─────────────────────────────────────────────────────┐
│ Host: Arch Linux + Hyprland (Wayland)              │
│ Primary GPU: AMD Radeon 660M (always host display) │
└─────────────────────────────────────────────────────┘
                        │
        ┌───────────────┴───────────────┐
        │                               │
        ▼                               ▼
┌───────────────────┐         ┌───────────────────┐
│  Mode 1: VM       │         │  Mode 2: Host     │
│  RTX 3050 →       │         │  RTX 3050 →       │
│  vfio-pci         │         │  nvidia driver    │
│                   │         │                   │
│  Windows 10 VM    │         │  Wine/Lutris      │
│  Looking Glass    │         │  Steam Proton     │
│  90-95% perf      │         │  80-100% perf     │
└───────────────────┘         └───────────────────┘
```

### Key Features

✅ **Dynamic GPU switching** between VM and host  
✅ **AMD Radeon 660M** always drives host display (Hyprland)  
✅ **NVIDIA RTX 3050** switches between vfio-pci (VM) and nvidia (host)  
✅ **Looking Glass** for seamless VM display  
✅ **CPU isolation** (cores 4-11 dedicated to VM)  
✅ **Hugepages** for reduced memory latency  
✅ **One-key switching** via Hyprland keybindings  
✅ **Automated management** scripts  

---

<a name="pre-installation"></a>
## 2. PRE-INSTALLATION CHECKLIST

### Verify Hardware

```bash
# System information
sudo dmidecode -t system | grep -E "Manufacturer|Product"

# CPU check
lscpu | grep -E "Model name|Core|Thread"

# GPU detection
lspci | grep -E "VGA|3D"

# Expected output:
# 00:08.1 VGA: AMD [AMD/ATI] Rembrandt [Radeon 660M]
# 01:00.0 VGA: NVIDIA GA107M [GeForce RTX 3050 Mobile] [10de:25a2]
# 01:00.1 Audio: NVIDIA GA107 High Definition Audio [10de:2291]
```

**Write down NVIDIA device IDs**: `10de:25a2` (GPU), `10de:2291` (Audio)

### Storage Preparation

```bash
# Check disk space (need 80+ GB free)
df -h /

# Create Btrfs subvolume for VMs
sudo btrfs subvolume create /vm-images

# Disable Copy-on-Write (critical for VM performance)
sudo chattr +C /vm-images

# Verify
lsattr -d /vm-images
# Output: ---------------C------ /vm-images

# Create directory structure
sudo mkdir -p /vm-images/{iso,disks}
sudo chown -R $USER:$USER /vm-images
```

**Add to /etc/fstab**:

```bash
sudo nvim /etc/fstab
```

Add (replace UUID):
```
UUID=YOUR-BTRFS-UUID /vm-images btrfs noatime,nodiratime,compress=no,space_cache=v2,autodefrag,ssd,discard=async,subvol=vm-images 0 0
```

Find UUID:
```bash
sudo blkid | grep btrfs
```

Mount:
```bash
sudo mount -a
```

***

<a name="bios-config"></a>
## 3. BIOS CONFIGURATION

### Access BIOS

1. Restart computer
2. Press **F2** or **Fn+F2** repeatedly during boot

### Required Settings

| Setting | Value | Location |
|---------|-------|----------|
| **AMD-V / SVM** | Enabled | Configuration → Virtualization |
| **IOMMU / AMD-Vi** | Enabled | Configuration (may be hidden) |
| **Above 4G Decoding** | Enabled | Advanced → PCI |
| **Resizable BAR** | Enabled | Advanced → PCI |
| **CSM Support** | Disabled | Boot → CSM |
| **Secure Boot** | Disabled | Security |
| **Fast Boot** | Disabled | Boot |

**Save & Exit** → Reboot

### Verify IOMMU Active

```bash
dmesg | grep -i "AMD-Vi"

# Expected output:
# AMD-Vi: Found IOMMU cap 0x40
# AMD-Vi: Interrupt remapping enabled
```

### Check IOMMU Groups

```bash
for d in /sys/kernel/iommu_groups/*/devices/*; do 
    n=${d#*/iommu_groups/*}; n=${n%%/*}
    printf 'IOMMU Group %s ' "$n"
    lspci -nns "${d##*/}"
done | grep -E "01:00|NVIDIA"

# Ideal output:
# IOMMU Group X 01:00.0 VGA [0300]: NVIDIA [10de:25a2]
# IOMMU Group X 01:00.1 Audio [0403]: NVIDIA [10de:2291]
```

✓ GPU and audio in same group = Perfect isolation

***

<a name="kernel-setup"></a>
## 4. KERNEL & VFIO SETUP (DYNAMIC MODE)

### Edit GRUB Configuration

```bash
sudo nvim /etc/default/grub
```

**Modify `GRUB_CMDLINE_LINUX_DEFAULT`** (DO NOT add vfio-pci.ids here):

```bash
GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet amd_iommu=on iommu=pt iommu.strict=0 iommu.passthrough=1 video=efifb:off pci=noaer isolcpus=4-11 nohz_full=4-11 rcu_nocbs=4-11"
```

**Parameter breakdown**:
- `amd_iommu=on` - Enable AMD IOMMU
- `iommu=pt` - Passthrough mode (+5-10% performance)
- `iommu.strict=0` - Relaxed TLB flushing (+10-15% I/O)
- `video=efifb:off` - Disable EFI framebuffer on NVIDIA
- `pci=noaer` - Disable PCIe error reporting
- `isolcpus=4-11` - Isolate cores 4-11 for VM
- `nohz_full=4-11` - Disable timer ticks on VM cores
- `rcu_nocbs=4-11` - RCU callbacks offload

**Update GRUB**:

```bash
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

### VFIO Module Configuration

```bash
sudo nvim /etc/modprobe.d/vfio.conf
```

**Add** (no static IDs - we'll bind dynamically):

```bash
# VFIO options for dynamic binding
options vfio-pci disable_vga=1
options vfio_iommu_type1 allow_unsafe_interrupts=1

# Prefer vfio-pci over nvidia (but don't force)
softdep nvidia pre: vfio-pci
```

### Mkinitcpio Configuration

```bash
sudo nvim /etc/mkinitcpio.conf
```

**Modify MODULES**:

```bash
MODULES=(vfio_pci vfio vfio_iommu_type1 vfio_virqfd vendor-reset)
```

**Ensure HOOKS contains**:

```bash
HOOKS=(base udev autodetect modconf kms keyboard keymap consolefont block filesystems fsck)
```

**Install vendor-reset** (better GPU reset):

```bash
yay -S vendor-reset-dkms-git
```

**Regenerate initramfs**:

```bash
sudo mkinitcpio -P
```

***

<a name="nvidia-drivers"></a>
## 5. NVIDIA DRIVERS INSTALLATION

### Install NVIDIA Drivers (for host gaming)

```bash
sudo pacman -S nvidia-dkms nvidia-utils lib32-nvidia-utils nvidia-settings opencl-nvidia
```

### Install Vulkan Support

```bash
sudo pacman -S vulkan-icd-loader lib32-vulkan-icd-loader vulkan-tools
```

### Reboot

```bash
sudo reboot
```

### Verify NVIDIA Available on Host

```bash
# Check driver loaded
lspci -k | grep -A 3 "01:00.0"

# Expected output:
# 01:00.0 VGA compatible controller: NVIDIA Corporation GA107M
#     Kernel driver in use: nvidia
#     Kernel modules: nouveau, nvidia

# Test NVIDIA
nvidia-smi

# Test Vulkan
vkcube
```

***

<a name="libvirt-setup"></a>
## 6. LIBVIRT & KVM SETUP

### Install Packages

```bash
sudo pacman -S qemu-full libvirt virt-manager virt-viewer \
               edk2-ovmf dnsmasq iptables-nft bridge-utils \
               spice-vdagent spice-protocol dmidecode
```

### Enable Services

```bash
sudo systemctl enable --now libvirtd
sudo systemctl enable --now virtlogd
```

### Add User to Groups

```bash
sudo usermod -a -G libvirt,kvm,input $(whoami)
newgrp libvirt
```

### Configure Default Network

```bash
sudo virsh net-start default
sudo virsh net-autostart default
```

### Configure Libvirt for Performance

```bash
sudo nvim /etc/libvirt/qemu.conf
```

**Uncomment/modify** (replace `your_username`):

```bash
user = "your_username"
group = "kvm"
hugetlbfs_mount = "/dev/hugepages"
security_driver = "none"
log_level = 3
log_outputs = "3:file:/var/log/libvirt/qemu-win10.log"
```

**Restart**:

```bash
sudo systemctl restart libvirtd
```

***

<a name="performance-tuning"></a>
## 7. PERFORMANCE TUNING

### Hugepages Configuration

```bash
sudo nvim /etc/sysctl.d/90-hugepages.conf
```

**Add**:

```bash
# Allocate 5120 hugepages (10 GB for VM)
vm.nr_hugepages = 5120
vm.hugetlb_shm_group = 36

# Memory tuning
vm.swappiness = 10
vm.dirty_ratio = 10
vm.dirty_background_ratio = 5
vm.compaction_proactiveness = 0
```

**Apply**:

```bash
sudo sysctl -p /etc/sysctl.d/90-hugepages.conf
```

### Disable THP Defragmentation

```bash
sudo nvim /etc/tmpfiles.d/thp.conf
```

**Add**:

```bash
w /sys/kernel/mm/transparent_hugepage/defrag - - - - never
w /sys/kernel/mm/transparent_hugepage/khugepaged/defrag - - - - never
```

### I/O Scheduler Optimization

```bash
sudo nvim /etc/udev/rules.d/60-ioschedulers.rules
```

**Add**:

```bash
ACTION=="add|change", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/scheduler}="none"
```

### IRQ Affinity Script

```bash
sudo nvim /usr/local/bin/set-irq-affinity.sh
```

**Add**:

```bash
#!/bin/bash
# Pin all IRQs to host cores (0-3)

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

**Create systemd service**:

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

**Enable**:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now irq-affinity.service
```

***

<a name="looking-glass"></a>
## 8. LOOKING GLASS INSTALLATION

### Configure Shared Memory

```bash
sudo touch /dev/shm/looking-glass
sudo chown $USER:kvm /dev/shm/looking-glass
sudo chmod 660 /dev/shm/looking-glass
```

**Make persistent**:

```bash
sudo nvim /etc/tmpfiles.d/looking-glass.conf
```

**Add** (replace `your_username`):

```bash
f /dev/shm/looking-glass 0660 your_username kvm - -
```

**Update fstab**:

```bash
sudo nvim /etc/fstab
```

**Add**:

```bash
tmpfs /dev/shm tmpfs defaults,size=512M 0 0
```

**Remount**:

```bash
sudo mount -o remount /dev/shm
```

### Install Build Dependencies

```bash
sudo pacman -S cmake gcc git binutils pkgconf \
               libx11 nettle libxi libxinerama libxss \
               libxcursor libxpresent libxkbcommon \
               wayland-protocols ttf-dejavu freetype2 \
               spice-protocol fontconfig libsamplerate \
               libpipewire pipewire
```

### Build Looking Glass Client

```bash
mkdir -p ~/builds && cd ~/builds
git clone --recursive https://github.com/gnif/LookingGlass.git
cd LookingGlass
git checkout stable

cd client
mkdir build && cd build

cmake ../ \
    -DENABLE_WAYLAND=ON \
    -DENABLE_X11=ON \
    -DENABLE_PIPEWIRE=ON \
    -DENABLE_DMABUF=ON

make -j$(nproc)
sudo make install
```

### Configure Looking Glass Client

```bash
mkdir -p ~/.config/looking-glass
nvim ~/.config/looking-glass/client.ini
```

**Add**:

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

[spice]
enable=yes
host=127.0.0.1
port=5900

[audio]
micDefault=allow
```

***

<a name="windows-vm"></a>
## 9. WINDOWS VM CREATION

### Download ISOs

```bash
cd /vm-images/iso

# Use your existing Ventoy or download:
# Windows 10: https://www.microsoft.com/software-download/windows10

# VirtIO drivers
wget https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso
```

### Create Disk Image

```bash
cd /vm-images/disks
qemu-img create -f raw windows10.img 80G
```

### Launch Virt-Manager

```bash
virt-manager
```

**Create VM**:
1. New VM → Local install media
2. Select Windows 10 ISO
3. Memory: **10240 MB**, CPUs: **8**
4. **Uncheck** storage, click Forward
5. Name: **win10-gaming**
6. **Check** "Customize before install"
7. Finish

### Configure VM XML

**Generate UUID first**:

```bash
uuidgen
# Copy the output
```

**In virt-manager: Overview → XML tab, replace ALL with**:

```xml
<domain xmlns:qemu="http://libvirt.org/schemas/domain/qemu/1.0" type="kvm">
  <name>win10-gaming</name>
  <uuid>PASTE-YOUR-UUID-HERE</uuid>
  <metadata>
    <libosinfo:libosinfo xmlns:libosinfo="http://libosinfo.org/xmlns/libvirt/domain/1.0">
      <libosinfo:os id="http://microsoft.com/win/10"/>
    </libosinfo:libosinfo>
  </metadata>
  
  <memory unit="KiB">10485760</memory>
  urrentntMemory unit="KiB">10485760</currentMemory>
  
  <memoryBacking>
    <hugepages/>
    <locked/>
  </memoryBacking>
  
  <vcpu placement="static">8</vcpu>
  
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
    <loader readonly="yes" type="pflash">/usr/share/edk2/x64/OVMF_CODE.4m.fd</loader>
    <nvram template="/usr/share/edk2/x64/OVMF_VARS.4m.fd">/var/lib/libvirt/qemu/nvram/win10-gaming_VARS.fd</nvram>
    <boot dev="hd"/>
    <boot dev="cdrom"/>
  </os>
  
  <features>
    <acpi/>
    <apic/>
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
  
  <clock offset="localtime">
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
    
    <disk type="file" device="disk">
      <driver name="qemu" type="raw" cache="none" io="native" discard="unmap" iothread="1" queues="4"/>
      <source file="/vm-images/disks/windows10.img"/>
      <target dev="sda" bus="scsi"/>
      <address type="drive" controller="0" bus="0" target="0" unit="0"/>
    </disk>
    
    <disk type="file" device="cdrom">
      <driver name="qemu" type="raw"/>
      <source file="/vm-images/iso/windows10.iso"/>
      <target dev="sdb" bus="sata"/>
      <readonly/>
      <address type="drive" controller="0" bus="0" target="0" unit="1"/>
    </disk>
    
    <disk type="file" device="cdrom">
      <driver name="qemu" type="raw"/>
      <source file="/vm-images/iso/virtio-win.iso"/>
      <target dev="sdc" bus="sata"/>
      <readonly/>
      <address type="drive" controller="0" bus="0" target="0" unit="2"/>
    </disk>
    
    ontroller type="scsi" index="0" model="="virtio-scsi">
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
    
    ontrollerer type="sata" index="0">
      <address type="pci" domain="0x0000" bus="0x00" slot="0x1f" function="0x2"/>
    </controller>
    
    ontroller type="usb" index="0" model="q"qemu-xhci" ports="15">
      <address type="pci" domain="0x0000" bus="0x02" slot="0x00" function="0x0"/>
    </controller>
    
    <interface type="network">
      <mac address="52:54:00:AA:BB:CC"/>
      <source network="default"/>
      <model type="virtio"/>
      <driver name="vhost" queues="8"/>
      <address type="pci" domain="0x0000" bus="0x01" slot="0x00" function="0x0"/>
    </interface>
    
    <hostdev mode="subsystem" type="pci" managed="yes">
      <source>
        <address domain="0x0000" bus="0x01" slot="0x00" function="0x0"/>
      </source>
      <driver name="vfio"/>
      <address type="pci" domain="0x0000" bus="0x04" slot="0x00" function="0x0" multifunction="on"/>
    </hostdev>
    
    <hostdev mode="subsystem" type="pci" managed="yes">
      <source>
        <address domain="0x0000" bus="0x01" slot="0x00" function="0x1"/>
      </source>
      <driver name="vfio"/>
      <address type="pci" domain="0x0000" bus="0x04" slot="0x00" function="0x1"/>
    </hostdev>
    
    <graphics type="spice" autoport="yes">
      <listen type="address"/>
      <image compression="off"/>
    </graphics>
    
    <video>
      <model type="qxl" ram="65536" vram="65536" vgamem="16384" heads="1" primary="yes"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x01" function="0x0"/>
    </video>
    
    <input type="keyboard" bus="virtio">
      <address type="pci" domain="0x0000" bus="0x05" slot="0x00" function="0x0"/>
    </input>
    <input type="tablet" bus="virtio">
      <address type="pci" domain="0x0000" bus="0x06" slot="0x00" function="0x0"/>
    </input>
    
    <memballoon model="virtio">
      <address type="pci" domain="0x0000" bus="0x07" slot="0x00" function="0x0"/>
    </memballoon>
    
    <rng model="virtio">
      <backend model="random">/dev/urandom</backend>
      <address type="pci" domain="0x0000" bus="0x08" slot="0x00" function="0x0"/>
    </rng>
    
    <tpm model="tpm-crb">
      <backend type="emulator" version="2.0"/>
    </tpm>
    
    <sound model="ich9">
      <audio id="1"/>
    </sound>
    <audio id="1" type="pipewire">
      <input mixingEngine="no"/>
      <output mixingEngine="no" latency="512"/>
    </audio>
  </devices>
  
  <qemu:commandline>
    <qemu:arg value="-device"/>
    <qemu:arg value="ivshmem-plain,memdev=ivshmem,bus=pcie.0"/>
    <qemu:arg value="-object"/>
    <qemu:arg value="memory-backend-file,id=ivshmem,share=on,mem-path=/dev/shm/looking-glass,size=256M"/>
  </qemu:commandline>
</domain>
```

**Click "Apply"** → **"Begin Installation"**

### Install Windows

1. Windows Setup: Language, time, keyboard
2. **Install now**
3. **When asked "Where to install?"**: Click **"Load driver"**
4. Browse to VirtIO ISO → `amd64\w10`
5. Select **"Red Hat VirtIO SCSI controller"**
6. Disk appears → Install
7. Complete Windows setup

### Install Drivers in Windows

**After first boot**:

1. Open VirtIO CD (D:$)
2. Run **virtio-win-gt-x64.exe**
3. Install all drivers
4. Reboot VM

**Install NVIDIA drivers**:

1. Download from: https://www.nvidia.com/download/
2. Select: RTX 30 Series (Notebooks) → RTX 3050 Mobile → Windows 10
3. Install Game Ready Driver
4. Reboot

**Install Looking Glass host**:

1. Download: https://looking-glass.io/downloads
2. Run **looking-glass-host-setup.exe**
3. Install IVSHMEM driver
4. Services → Looking Glass (host) → Startup: Automatic
5. Start service

**Windows optimizations**:

1. Disable Windows Defender (during gaming)
2. Power Plan → High Performance
3. System → Advanced → Performance: "Adjust for best performance"
4. Run as admin:
   ```
   bcdedit /deletevalue useplatformclock
   bcdedit /set disabledynamictick yes
   ```

5. Registry Editor (regedit):
   ```
   HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000
   Create DWORD: DisableDynamicPstate = 1
   ```

6. Download **MSI Utility v3** → Enable MSI mode for GPU

***

<a name="gpu-rebinding"></a>
## 10. DYNAMIC GPU REBINDING SCRIPTS

### Script 1: Bind to VFIO (for VM)

```bash
sudo nvim /usr/local/bin/gpu-bind-vfio.sh
```

**Add**:

```bash
#!/bin/bash
# Bind NVIDIA GPU to vfio-pci for VM use

set -e

echo "=== Binding GPU to vfio-pci for VM use ==="

# Check if VM is running
if virsh list --state-running | grep -q "win10-gaming"; then
    echo "ERROR: VM is already running!"
    exit 1
fi

# Unload NVIDIA modules
echo "Unloading NVIDIA modules..."
sudo modprobe -r nvidia_drm nvidia_modeset nvidia_uvm nvidia 2>/dev/null || true

# Unbind from nvidia driver
echo "Unbinding from nvidia driver..."
echo "0000:01:00.0" | sudo tee /sys/bus/pci/drivers/nvidia/unbind 2>/dev/null || true
echo "0000:01:00.1" | sudo tee /sys/bus/pci/drivers/snd_hda_intel/unbind 2>/dev/null || true

sleep 1

# Load VFIO modules
echo "Loading VFIO modules..."
sudo modprobe vfio vfio_pci vfio_iommu_type1

# Bind to vfio-pci
echo "Binding to vfio-pci..."
echo "10de 25a2" | sudo tee /sys/bus/pci/drivers/vfio-pci/new_id
echo "10de 2291" | sudo tee /sys/bus/pci/drivers/vfio-pci/new_id

sleep 2

# Verify
DRIVER=$(lspci -ks 01:00.0 | grep "Kernel driver in use" | awk '{print $5}')
if [ "$DRIVER" = "vfio-pci" ]; then
    echo "✓ GPU successfully bound to vfio-pci"
    echo "✓ Ready for VM gaming!"
    exit 0
else
    echo "✗ ERROR: GPU bound to $DRIVER instead of vfio-pci"
    exit 1
fi
```

```bash
sudo chmod +x /usr/local/bin/gpu-bind-vfio.sh
```

### Script 2: Bind to NVIDIA (for host gaming)

```bash
sudo nvim /usr/local/bin/gpu-bind-nvidia.sh
```

**Add**:

```bash
#!/bin/bash
# Bind NVIDIA GPU to nvidia driver for host gaming

set -e

echo "=== Binding GPU to nvidia for host gaming ==="

# Check VM is not running
if virsh list --state-running | grep -q "win10-gaming"; then
    echo "ERROR: VM is running! Stop VM first."
    exit 1
fi

# Unbind from vfio-pci
echo "Unbinding from vfio-pci..."
echo "0000:01:00.0" | sudo tee /sys/bus/pci/drivers/vfio-pci/unbind 2>/dev/null || true
echo "0000:01:00.1" | sudo tee /sys/bus/pci/drivers/vfio-pci/unbind 2>/dev/null || true

# Remove IDs
echo "10de 25a2" | sudo tee /sys/bus/pci/drivers/vfio-pci/remove_id 2>/dev/null || true
echo "10de 2291" | sudo tee /sys/bus/pci/drivers/vfio-pci/remove_id 2>/dev/null || true

# Unload VFIO
sudo modprobe -r vfio_pci vfio_iommu_type1 vfio 2>/dev/null || true

sleep 1

# Load NVIDIA modules
echo "Loading NVIDIA modules..."
sudo modprobe nvidia_drm nvidia_modeset nvidia_uvm nvidia

# Bind to nvidia
echo "Binding to nvidia driver..."
echo "0000:01:00.0" | sudo tee /sys/bus/pci/drivers/nvidia/bind
echo "0000:01:00.1" | sudo tee /sys/bus/pci/drivers/snd_hda_intel/bind

sleep 2

# Verify
DRIVER=$(lspci -ks 01:00.0 | grep "Kernel driver in use" | awk '{print $5}')
if [ "$DRIVER" = "nvidia" ]; then
    echo "✓ GPU successfully bound to nvidia"
    echo "✓ Ready for host gaming!"
    nvidia-smi
    exit 0
else
    echo "✗ ERROR: GPU bound to $DRIVER instead of nvidia"
    exit 1
fi
```

```bash
sudo chmod +x /usr/local/bin/gpu-bind-nvidia.sh
```

### Script 3: Check GPU Status

```bash
sudo nvim /usr/local/bin/gpu-status.sh
```

**Add**:

```bash
#!/bin/bash
# Display current GPU binding status

echo "===================================="
echo "GPU Status Dashboard"
echo "===================================="
echo ""

# GPU driver
DRIVER=$(lspci -ks 01:00.0 | grep "Kernel driver in use" | awk '{print $5}')
echo "Current GPU driver: $DRIVER"

if [ "$DRIVER" = "vfio-pci" ]; then
    echo "Mode: VM GAMING (Ready for Windows VM)"
    echo ""
    if virsh list --state-running | grep -q "win10-gaming"; then
        echo "VM Status: RUNNING ✓"
    else
        echo "VM Status: STOPPED (run: vm-start)"
    fi
elif [ "$DRIVER" = "nvidia" ]; then
    echo "Mode: HOST GAMING (Ready for Wine/Lutris/Native)"
    echo ""
    nvidia-smi --query-gpu=name,temperature.gpu,utilization.gpu,utilization.memory --format=csv,noheader
else
    echo "Mode: UNKNOWN (driver: $DRIVER)"
fi

echo ""
echo "===================================="
```

```bash
sudo chmod +x /usr/local/bin/gpu-status.sh
```

***

<a name="automation"></a>
## 11. AUTOMATION & LIFECYCLE MANAGEMENT

### VM Prepare Script

```bash
sudo nvim /usr/local/bin/vm-prepare.sh
```

**Add**:

```bash
#!/bin/bash
# VM Pre-Launch Preparation

set -e

VM_NAME="win10-gaming"
LOG_FILE="/var/log/vm-launch.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "=== VM Pre-Launch Sequence ==="

# Check if VM already running
if virsh list --state-running | grep -q "$VM_NAME"; then
    log "ERROR: VM already running!"
    exit 1
fi

# Bind GPU to vfio-pci if needed
GPU_DRIVER=$(lspci -ks 01:00.0 | grep "Kernel driver in use" | awk '{print $5}')
if [ "$GPU_DRIVER" != "vfio-pci" ]; then
    log "GPU bound to $GPU_DRIVER, switching to vfio-pci..."
    /usr/local/bin/gpu-bind-vfio.sh || exit 1
fi

# Clear cache
log "Clearing cache..."
sync && echo 3 | sudo tee /proc/sys/vm/drop_caches > /dev/null

# CPU governor

log "Setting CPU to performance mode..."
echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor > /dev/null

# Verify hugepages

HUGE_FREE=$(grep HugePages_Free /proc/meminfo | awk '{print $2}')
log "Hugepages free: $HUGE_FREE"
if [ "$HUGE_FREE" -lt 5000 ]; then
    echo 5120 | sudo tee /proc/sys/vm/nr_hugepages > /dev/null
    sleep 2
fi

# IRQ affinity
/usr/local/bin/set-irq-affinity.sh

# Verify Looking Glass
[ -f /dev/shm/looking-glass ] || {
    sudo touch /dev/shm/looking-glass
    sudo chown $USER:kvm /dev/shm/looking-glass
    sudo chmod 660 /dev/shm/looking-glass
}

log "System ready - Load: $(cat /proc/loadavg | awk '{print $1}')"
log "=== Pre-Launch Complete ==="
```

```bash
sudo chmod +x /usr/local/bin/vm-prepare.sh
```

### VM Launch Script

```bash
sudo nvim /usr/local/bin/vm-launch.sh
```

**Add**:

```bash
#!/bin/bash
# VM Launch with Looking Glass

VM_NAME="win10-gaming"

echo "Preparing system..."
/usr/local/bin/vm-prepare.sh || exit 1

echo "Starting VM: $VM_NAME..."
virsh start "$VM_NAME"

echo "Waiting for Windows to boot (20s)..."
sleep 20

echo "Launching Looking Glass..."
export SDL_VIDEODRIVER=wayland
export GDK_BACKEND=wayland
looking-glass-client -F -m KEY_SCROLLLOCK &

echo "✓ VM launched! Press Scroll Lock to toggle input"
```

```bash
sudo chmod +x /usr/local/bin/vm-launch.sh
```

### VM Shutdown Script

```bash
sudo nvim /usr/local/bin/vm-shutdown.sh
```

**Add**:

```bash
#!/bin/bash
# VM Graceful Shutdown

VM_NAME="win10-gaming"

echo "Shutting down VM..."

if ! virsh list --state-running | grep -q "$VM_NAME"; then
    echo "VM is not running"
    exit 0
fi

virsh shutdown "$VM_NAME"

# Wait for shutdown (max 60s)
TIMEOUT=60
ELAPSED=0
while virsh list --state-running | grep -q "$VM_NAME"; do
    if [ $ELAPSED -ge $TIMEOUT ]; then
        echo "Timeout! Forcing shutdown..."
        virsh destroy "$VM_NAME"
        break
    fi
    sleep 2
    ELAPSED=$((ELAPSED + 2))
done

pkill -x "looking-glass-client" 2>/dev/null || true
sleep 3

echo "✓ VM stopped (${ELAPSED}s)"
```

```bash
sudo chmod +x /usr/local/bin/vm-shutdown.sh
```

### VM Cleanup Script

```bash
sudo nvim /usr/local/bin/vm-cleanup.sh
```

**Add**:

```bash
#!/bin/bash
# Post-VM Cleanup

echo "Restoring system state..."

# CPU governor
echo powersave | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor > /dev/null

# Compact memory
echo 1 | sudo tee /proc/sys/vm/compact_memory > /dev/null

echo "✓ Cleanup complete"
```

```bash
sudo chmod +x /usr/local/bin/vm-cleanup.sh
```

### Libvirt Hook

```bash
sudo nvim /etc/libvirt/hooks/qemu
```

**Add**:

```bash
#!/bin/bash

GUEST_NAME="$1"
HOOK_NAME="$2"
STATE_NAME="$3"

if [ "$GUEST_NAME" == "win10-gaming" ]; then
    if [ "$HOOK_NAME" == "release" ] && [ "$STATE_NAME" == "end" ]; then
        /usr/local/bin/vm-cleanup.sh &
    fi
fi
```

```bash
sudo chmod +x /etc/libvirt/hooks/qemu
sudo systemctl restart libvirtd
```

***

<a name="hyprland-config"></a>
## 12. HYPRLAND INTEGRATION & KEYBINDINGS

### Complete Hyprland VM Configuration

```bash
nvim ~/.config/hypr/hyprland.conf
```

**Add this section**:

```bash
# ========================================
# GPU PASSTHROUGH & GAMING KEYBINDINGS
# ========================================

# Main modifier (SUPER = Windows key)
$mainMod = SUPER

# ==================
# GPU MODE SWITCHING
# ==================

# Check GPU status
bind = $mainMod, F10, exec, kitty -e sh -c 'gpu-status.sh; read -p "Press Enter to close"'

# Switch to VM mode (bind GPU to vfio-pci)
bind = $mainMod SHIFT, F10, exec, kitty -e sh -c 'sudo gpu-bind-vfio.sh; read -p "Press Enter to close"'

# Switch to Host mode (bind GPU to nvidia)
bind = $mainMod CTRL, F10, exec, kitty -e sh -c 'sudo gpu-bind-nvidia.sh; read -p "Press Enter to close"'

# ====================
# VM MANAGEMENT
# ====================

# Launch Windows VM + Looking Glass
bind = $mainMod, F12, exec, vm-launch.sh

# Shutdown VM
bind = $mainMod SHIFT, F12, exec, vm-shutdown.sh

# VM status dashboard
bind = $mainMod CTRL, F12, exec, kitty -e sh -c 'vm-status.sh; read -p "Press Enter to close"'

# Force stop VM (emergency)
bind = $mainMod CTRL SHIFT, F12, exec, virsh destroy win10-gaming && pkill looking-glass-client

# ====================
# HOST GAMING
# ====================

# Launch Lutris
bind = $mainMod, F11, exec, lutris

# Launch Steam
bind = $mainMod SHIFT, F11, exec, steam

# ====================
# LOOKING GLASS RULES
# ====================

# Window rules for Looking Glass
windowrulev2 = workspace 9 silent, class:(looking-glass-client)
windowrulev2 = fullscreen, class:(looking-glass-client)
windowrulev2 = noanim, class:(looking-glass-client)
windowrulev2 = noinitialfocus, class:(looking-glass-client)
windowrulev2 = stayfocused, class:(looking-glass-client)

# ====================
# QUICK ACCESS
# ====================

# System monitor
bind = $mainMod, M, exec, kitty -e htop

# GPU monitor (when in nvidia mode)
bind = $mainMod SHIFT, M, exec, kitty -e nvidia-smi -l 1

# Temperature monitor
bind = $mainMod CTRL, M, exec, kitty -e watch -n 1 sensors
```

### Hyprland Workspace Setup

**Add to hyprland.conf** (if not already present):

```bash
# Workspace definitions
workspace = 1, monitor:eDP-1, default:true  # Main workspace
workspace = 2, monitor:eDP-1                # Browser
workspace = 3, monitor:eDP-1                # Code
workspace = 4, monitor:eDP-1                # Files
workspace = 9, monitor:eDP-1                # VM (Looking Glass)

# Workspace switching
bind = $mainMod, 1, workspace, 1
bind = $mainMod, 2, workspace, 2
bind = $mainMod, 3, workspace, 3
bind = $mainMod, 4, workspace, 4
bind = $mainMod, 9, workspace, 9

# Move window to workspace
bind = $mainMod SHIFT, 1, movetoworkspace, 1
bind = $mainMod SHIFT, 2, movetoworkspace, 2
bind = $mainMod SHIFT, 3, movetoworkspace, 3
bind = $mainMod SHIFT, 4, movetoworkspace, 4
bind = $mainMod SHIFT, 9, movetoworkspace, 9
```

### Reload Hyprland Config

```bash
# Method 1: Keybinding (usually SUPER + R or SUPER + SHIFT + R)
# Check your existing hyprland.conf for reload keybind

# Method 2: Command
hyprctl reload
```

***

## COMPLETE KEYBINDING REFERENCE

| Keybinding | Action |
|------------|--------|
| **GPU Management** | |
| `Super + F10` | Check GPU status (nvidia/vfio-pci) |
| `Super + Shift + F10` | Switch to VM mode (bind to vfio-pci) |
| `Super + Ctrl + F10` | Switch to Host mode (bind to nvidia) |
| **VM Control** | |
| `Super + F12` | Launch Windows VM + Looking Glass |
| `Super + Shift + F12` | Shutdown Windows VM gracefully |
| `Super + Ctrl + F12` | Show VM status dashboard |
| `Super + Ctrl + Shift + F12` | **Emergency** force stop VM |
| **Host Gaming** | |
| `Super + F11` | Launch Lutris |
| `Super + Shift + F11` | Launch Steam |
| **Monitoring** | |
| `Super + M` | System monitor (htop) |
| `Super + Shift + M` | GPU monitor (nvidia-smi) |
| `Super + Ctrl + M` | Temperature monitor (sensors) |
| **Workspaces** | |
| `Super + 1-9` | Switch to workspace 1-9 |
| `Super + Shift + 1-9` | Move window to workspace 1-9 |
| `Super + 9` | Go to Looking Glass workspace |
| **Looking Glass** | |
| `Scroll Lock` | Toggle input capture (host ↔ VM) |
| `Scroll Lock + Q` | Quit Looking Glass |
| `Scroll Lock + F` | Toggle fullscreen |

***

### Shell Aliases

**Add to ~/.zshrc**:

```bash
# ========================================
# GPU PASSTHROUGH ALIASES
# ========================================

# GPU management
alias gpu-vm='sudo gpu-bind-vfio.sh'
alias gpu-host='sudo gpu-bind-nvidia.sh'
alias gpu-stat='gpu-status.sh'

# VM shortcuts
alias vm-start='vm-launch.sh'
alias vm-stop='vm-shutdown.sh'
alias vm-stat='vm-status.sh'
alias vm-kill='virsh destroy win10-gaming && pkill looking-glass-client'

# Combined workflows
alias vm-game='gpu-vm && vm-start'
alias host-game='gpu-host && lutris'

# Monitoring
alias gpu-mon='watch -n 1 nvidia-smi'
alias temp-mon='watch -n 1 sensors'
alias vm-mon='watch -n 1 "virsh domstats win10-gaming --cpu-total --balloon"'
```

**Reload shell**:

```bash
source ~/.zshrc
```

***

<a name="wine-lutris"></a>
## 13. WINE/LUTRIS CONFIGURATION FOR NVIDIA

### Install Wine & Dependencies

```bash
sudo pacman -S wine-staging winetricks lutris \
               lib32-mesa vulkan-icd-loader lib32-vulkan-icd-loader \
               lib32-nvidia-utils lib32-opencl-nvidia
```

### Configure Lutris for NVIDIA

**Launch Lutris**:

```bash
lutris
```

**Global configuration**:

1. **☰ Menu** → **Preferences**
2. **Global options** tab
3. **System options**:
   - **Vulkan ICD loader**: `/usr/share/vulkan/icd.d/nvidia_icd.json`
   - **Enable DXVK**: ✓
   - **Enable VKD3D**: ✓

### Per-Game NVIDIA Configuration

**For each game** (Right-click → Configure):

**System options** tab → **Environment variables**:

```
__NV_PRIME_RENDER_OFFLOAD=1
__GLX_VENDOR_LIBRARY_NAME=nvidia
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/nvidia_icd.json
```

### Verify NVIDIA in Use

**Test Vulkan**:

```bash
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/nvidia_icd.json vkcube
```

**Test OpenGL**:

```bash
__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia glxinfo | grep "OpenGL renderer"

# Expected: NVIDIA GeForce RTX 3050 Mobile
```

**Monitor GPU usage**:

```bash
watch -n 1 nvidia-smi
```

### Wine Wrapper for NVIDIA

**Create wrapper script**:

```bash
nvim ~/.local/bin/wine-nvidia
```

**Add**:

```bash
#!/bin/bash
export __NV_PRIME_RENDER_OFFLOAD=1
export __GLX_VENDOR_LIBRARY_NAME=nvidia
export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/nvidia_icd.json
wine "$@"
```

```bash
chmod +x ~/.local/bin/wine-nvidia
```

**Usage**:

```bash
wine-nvidia /path/to/game.exe
```

***

<a name="troubleshooting"></a>
## 14. TROUBLESHOOTING

### Problem: GPU won't switch modes

**Check current binding**:

```bash
lspci -k | grep -A 3 "01:00.0"
```

**Force unbind and rebind**:

```bash
# To vfio-pci
sudo gpu-bind-vfio.sh

# To nvidia
sudo gpu-bind-nvidia.sh
```

### Problem: VM won't start

**Check logs**:

```bash
sudo journalctl -u libvirtd -f
sudo tail -f /var/log/libvirt/qemu/win10-gaming.log
```

**Common fixes**:

```bash
# Hugepages
cat /proc/meminfo | grep Huge
echo 5120 | sudo tee /proc/sys/vm/nr_hugepages

# VFIO binding
lspci -k | grep -A 3 nvidia

# Looking Glass
ls -lh /dev/shm/looking-glass
```

### Problem: Code 43 in Windows

**Solution 1: Check Hyper-V**:

```bash
virsh dumpxml win10-gaming | grep -E "vendor_id|hidden|evmcs"

# evmcs MUST be "off"
```

**Solution 2: VBIOS patch** (if Code 43 persists):

```bash
# Dump VBIOS in Windows with GPU-Z
# Transfer to Linux
cd ~/builds
git clone https://github.com/Matoking/NVIDIA-vBIOS-VFIO-Patcher
cd NVIDIA-vBIOS-VFIO-Patcher

python nvidia_vbios_vfio_patcher.py -i rtx3050.rom -o rtx3050_patched.rom

sudo mkdir -p /usr/share/vgabios/
sudo cp rtx3050_patched.rom /usr/share/vgabios/

# Edit VM XML
virsh edit win10-gaming

# Add to GPU hostdev:
# <rom file="/usr/share/vgabios/rtx3050_patched.rom"/>
```

### Problem: Looking Glass black screen

**Checks**:

1. IVSHMEM device in Windows Device Manager
2. Looking Glass host service running
3. Shared memory file exists: `ls /dev/shm/looking-glass`
4. Try with Spice display first

### Problem: Poor performance in Wine/Lutris

**Verify NVIDIA in use**:

```bash
# While game running
nvidia-smi

# Should show game process using GPU
```

**Check environment variables** in Lutris game config.

***

<a name="workflow"></a>
## 15. COMPLETE WORKFLOW GUIDE

### Daily Workflow

#### Morning: Boot to Host Gaming Mode

```bash
# After boot, GPU is in nvidia mode (default)
gpu-status

# Output: Mode: HOST GAMING
```

**Play native Linux games or Wine/Lutris games directly**

#### Switch to VM Gaming

```bash
# Method 1: Keybinding
Super + F12

# Method 2: Command
vm-game

# OR step-by-step:
gpu-vm      # Bind GPU to vfio-pci
vm-start    # Launch VM + Looking Glass
```

**Game in Windows VM** (90-95% performance)

**Press Scroll Lock** to toggle between host and VM input

#### Return to Host Gaming

```bash
# Method 1: Keybinding
Super + Shift + F12    # Shutdown VM

Super + Ctrl + F10     # Bind GPU to nvidia

# Method 2: Commands
vm-stop      # Stop VM
gpu-host     # Bind GPU to nvidia

# Now GPU available for Wine/Lutris again
```

### Quick Reference Workflows

| Want to... | Commands | Keybindings |
|------------|----------|-------------|
| **Check GPU mode** | `gpu-stat` | `Super + F10` |
| **Play Windows VM** | `vm-game` | `Super + F12` |
| **Stop VM** | `vm-stop` | `Super + Shift + F12` |
| **Play Wine/Lutris** | `gpu-host && lutris` | `Super + Ctrl + F10` then `Super + F11` |
| **Play Steam Proton** | `gpu-host && steam` | `Super + Ctrl + F10` then `Super + Shift + F11` |
| **Monitor GPU** | `gpu-mon` | `Super + Shift + M` |
| **Emergency stop VM** | `vm-kill` | `Super + Ctrl + Shift + F12` |

### Decision Tree

```
Want to game?
│
├─ Windows game with anti-cheat? → vm-game (Super + F12)
│
├─ Windows game (no anti-cheat)? → Choose:
│  ├─ Best performance? → vm-game (90-95%)
│  └─ Quick launch? → gpu-host + lutris (80-90%)
│
├─ Native Linux game? → gpu-host + steam
│
└─ Proton game? → gpu-host + steam
```

***

## CONGRATULATIONS! 🎉

You now have the **ultimate triple-mode gaming setup**:

✅ **Windows VM Gaming** (90-95% native performance)  
✅ **Wine/Lutris Gaming** (80-90% native performance)  
✅ **Native Linux Gaming** (100% native performance)  
✅ **One-key switching** via Hyprland keybindings  
✅ **Seamless display** via Looking Glass  
✅ **Professional automation** with management scripts

**Your gaming paradise is ready!** 🎮🚀

***

## SUMMARY OF FILES CREATED

| File | Purpose |
|------|---------|
| `/etc/default/grub` | Kernel parameters |
| `/etc/modprobe.d/vfio.conf` | VFIO configuration |
| `/etc/mkinitcpio.conf` | Early module loading |
| `/etc/sysctl.d/90-hugepages.conf` | Hugepages |
| `/etc/tmpfiles.d/looking-glass.conf` | Looking Glass memory |
| `/usr/local/bin/gpu-bind-vfio.sh` | Switch GPU to vfio-pci |
| `/usr/local/bin/gpu-bind-nvidia.sh` | Switch GPU to nvidia |
| `/usr/local/bin/gpu-status.sh` | Check GPU mode |
| `/usr/local/bin/vm-prepare.sh` | Pre-launch prep |
| `/usr/local/bin/vm-launch.sh` | Launch VM |
| `/usr/local/bin/vm-shutdown.sh` | Shutdown VM |
| `/usr/local/bin/vm-cleanup.sh` | Post-VM cleanup |
| `/usr/local/bin/set-irq-affinity.sh` | IRQ pinning |
| `/etc/libvirt/hooks/qemu` | Libvirt hooks |
| `~/.config/hypr/hyprland.conf` | Hyprland keybindings |
| `~/.config/looking-glass/client.ini` | Looking Glass config |
| `~/.zshrc` | Shell aliases |

**Total configuration files: 17**  
**Total scripts: 8**  
**Total keybindings: 16**

**Happy gaming! 🎯**

[1](https://wiki.hypr.land/Configuring/Binds/)
[2](https://www.reddit.com/r/hyprland/comments/1d0hkyq/keybind_list/)
[3](https://wayland.app/protocols/hyprland-global-shortcuts-v1)
[4](https://github.com/hyprwm/Hyprland/issues/7539)
[5](https://wiki.hypr.land/Configuring/Uncommon-tips--tricks/)
[6](https://wiki.archlinux.org/title/Hyprland)
[7](https://wiki.garudalinux.org/en/hyprland-cheatsheet)
[8](https://www.lorenzobettini.it/2023/07/hyprland-getting-started-part-1/)
[9](https://www.youtube.com/watch?v=N1pRdNp-l4U)
[10](https://forum.garudalinux.org/t/hyprland-keyboard-shortcuts-in-live-usb/41431)