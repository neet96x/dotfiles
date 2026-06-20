---
name: proxmox-automation
description: Manage Proxmox VE VMs, containers, and deployments using community-scripts
---

# Proxmox VE Automation Skill

Automate VM/container creation, management, and deployment on this Proxmox VE host using the [community-scripts/ProxmoxVE](https://github.com/community-scripts/ProxmoxVE) repository.

## Prerequisites

- Running on Proxmox VE host (this machine)
- Root shell access
- Internet connection
- Proxmox VE 8.x or 9.x

## Quick Commands

### View VMs and Containers

```bash
# List all VMs
qm list

# List all containers (LXC)
pct list

# Show host resources
pvesm status
free -h
nproc
cat /proc/cpuinfo | grep "model name" | head -1
```

### Create a Debian VM (via community-scripts)

The repo provides `vm/debian-vm.sh` (Debian 12) and `vm/debian-13-vm.sh` (Debian 13).

These scripts are **interactive** (use `whiptail` dialogs). Since we're headless, use the **manual approach** instead:

#### Manual Debian VM Creation (Non-Interactive)

```bash
# Step 1: Create VM
VMID=102
qm create $VMID \
  --name debian-server \
  --memory 4096 \
  --cores 2 \
  --net0 virtio,bridge=vmbr0 \
  --ostype l26 \
  --scsihw virtio-scsi-pci \
  --agent 1 \
  --onboot 1

# Step 2: Create disks
qm set $VMID \
  --efidisk0 local-lvm:vm-$VMID-disk-0,size=4M,efitype=4m \
  --scsi0 local-lvm:vm-$VMID-disk-1,size=30G,discard=on,ssd=1

# Step 3: Attach ISO and boot
qm set $VMID --ide2 local:iso/debian-12-amd64-netinst.iso,media=cdrom

# Step 4: Start VM
qm start $VMID

# Step 5: Watch boot progress (check VNC console)
qm terminal $VMID
```

### Create a Debian LXC Container (Fast & Lightweight)

```bash
# Download Debian template (if not already present)
pct download local debian-12-standard_12.7-1_amd64.tar.zst

# Create container
CTID=102
pct create $CTID \
  local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst \
  --hostname debian-server \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp,gateway=192.168.50.1 \
  --rootfs local-lvm:vm-$CTID-disk-0,size=30G \
  --unprivileged 1 \
  --cores 2 \
  --memory 4096 \
  --swap 1024 \
  --startup startup=1,out=start

# Start container
pct start $CTID

# Get IP address
pct exec $CTID -- ip addr show eth0 | grep inet

# Access shell
pct exec $CTID -- bash
```

### Using community-scripts Officially

```bash
# For LXC containers (recommended - fast, lightweight)
bash <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/debian.sh)

# For VMs (interactive - requires VNC/TTY)
bash <script-url-from-community-scripts.org>
```

### Install Claude Code Inside Created VM/Container

Once you have SSH access to the new VM/container:

```bash
# Inside the Debian VM/container:
# Install Node.js (LTS)
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

# Install Claude Code (if available)
npm install -g @anthropic-ai/claude-code

# Or use the standalone binary
curl -o claude-code.zip -L https://github.com/anthropics/claude-code/releases/latest/download/claude-code-linux-x64.zip
unzip claude-code.zip
chmod +x claude-code
mv claude-code /usr/local/bin/
```

### Copy Claude Config

```bash
# Copy from this host to the new VM/container
scp /root/.claude-9arm.json root@<IP>:~/.claude-9arm.json

# Or inside the VM/container:
curl -fsSL <config-url> -o ~/.claude-9arm.json
```

## Available Scripts in /root/ProxmoxVE/

### VM Scripts (`vm/`)
| Script | Description |
|--------|-------------|
| `debian-vm.sh` | Debian 12 VM (cloud image, ~2GB disk) |
| `debian-13-vm.sh` | Debian 13 VM (cloud image) |
| `ubuntu2404-vm.sh` | Ubuntu 24.04 VM |
| `ubuntu2504-vm.sh` | Ubuntu 25.04 VM |
| `truenas-vm.sh` | TrueNAS VM |
| `openwrt-vm.sh` | OpenWrt router VM |
| `opnsense-vm.sh` | OPNsense firewall VM |
| `nextcloud-vm.sh` | Nextcloud VM |
| `docker-vm.sh` | Docker-focused VM |

### LXC Container Scripts (`ct/`)
Full list: `ls /root/ProxmoxVE/ct/*.sh | wc -l` (400+ scripts available)

Key ones:
| Script | Description |
|--------|-------------|
| `debian.sh` | Base Debian container |
| `ubuntu.sh` | Base Ubuntu container |
| `alpine.sh` | Alpine Linux container |
| `docker.sh` | Docker container |
| `nextcloud.sh` | Nextcloud |
| `pihole.sh` | Pi-hole DNS |
| `traefik.sh` | Traefik reverse proxy |
| `vaultwarden.sh` | Bitwarden RS |
| `plex.sh` | Plex media server |

## Common Operations

### Resize Disk
```bash
qm resize 102 scsi0 +10G    # Add 10GB to VM
pct resize 102 rootfs 10G   # Resize LXC rootfs to 10GB
```

### Clone Existing VM
```bash
qm clone 101 103 --name debian-copy
```

### Snapshot
```bash
qm snapshot 102 backup-before-update
qm rollback 102 backup-before-update
```

### Network Configuration
Current network: `vmbr0` on `nic0` — IP `192.168.50.64/24`, gateway `192.168.50.1`

### Storage
- `local` (dir): ~65GB total, ~53GB free
- `local-lvm` (lvmthin): ~130GB total, ~125GB free ← **recommended for new VMs**

## Tips

1. **LXC > VM** when possible — uses far fewer resources (no hypervisor overhead)
2. **Cloud images** (`debian-*-genericcloud` / `debian-*-nocloud`) are faster than netinst ISO
3. Use `--onboot 1` to auto-start on reboot
4. Enable `--agent 1` for better guest communication (filesystem sync, IP reporting)
5. For headless installs, prefer cloud-init + cloud images over ISOs
6. The `misc/api.func` provides telemetry helpers — set `DIAGNOSTICS=no` to disable
7. The `misc/build.func` is the core builder for LXC containers
8. The `misc/install.func` handles post-install setup inside containers
