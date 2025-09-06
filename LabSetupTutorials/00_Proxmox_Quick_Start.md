# 🚀 Proxmox VE Lab Quick Start Guide

## 🎯 Overview

This guide helps you quickly set up a complete Windows Server lab environment using Proxmox Virtual Environment (Proxmox VE). This provides enterprise-grade virtualization with powerful management capabilities for your Windows Server lab infrastructure.

## ⚡ Prerequisites Checklist

- [ ] Proxmox VE 8.0+ installed and running
- [ ] 16GB+ RAM (32GB recommended for multiple VMs)
- [ ] 500GB+ storage (1TB recommended)
- [ ] Network connectivity configured
- [ ] Windows Server ISO files downloaded
- [ ] Windows 10/11 client ISO files (optional)

## 🏃‍♂️ 5-Minute Setup (Automated VM Creation)

### Step 1: Access Proxmox Web Interface

1. Open your web browser
2. Navigate to `https://your-proxmox-ip:8006`
3. Login with your Proxmox credentials
4. Accept the SSL certificate (for lab environments)

### Step 2: Upload ISO Images

```bash
# Upload via web interface: Datacenter → local → ISO Images → Upload
# Or via command line on Proxmox host:
cd /var/lib/vz/template/iso/
wget https://path-to-your-windows-server.iso
# Ensure ISOs are in the correct location
```

### Step 3: Create Virtual Networks

1. **Navigate to**: `Datacenter → System → Network`
2. **Create Management Bridge** (vmbr1):

   ```
   Bridge Name: vmbr1
   IPv4/CIDR: 192.168.100.1/24
   Comment: Lab Management Network
   ```

3. **Create Lab Network Bridge** (vmbr2):

   ```
   Bridge Name: vmbr2
   IPv4/CIDR: 192.168.1.1/24
   Comment: Lab Production Network
   ```

## 🛠️ Manual VM Creation (Step-by-Step)

### Create Domain Controller VM (DC1-LAB)

1. **Click "Create VM"** in the Proxmox interface
2. **General Settings**:

   ```
   VM ID: 100
   Name: DC1-LAB
   Resource Pool: (optional)
   ```

3. **OS Settings**:

   ```
   Use CD/DVD disc image file (iso): ✓
   Storage: local
   ISO image: WindowsServer2022.iso
   Type: Microsoft Windows
   Version: 10/2016/2019/2022 (win10)
   ```

4. **System Settings**:

   ```
   Graphic card: Default
   Machine: q35
   BIOS: OVMF (UEFI)
   EFI Storage: local-lvm
   Pre-Enroll keys: ✓
   SCSI Controller: VirtIO SCSI single
   Qemu Agent: ✓
   ```

5. **Hard Disk**:

   ```
   Storage: local-lvm
   Disk size (GB): 80
   Cache: Write back
   Discard: ✓
   SSD emulation: ✓ (if using SSD storage)
   ```

6. **CPU**:

   ```
   Sockets: 1
   Cores: 4
   Type: host
   ```

7. **Memory**:

   ```
   Memory (MB): 4096
   Ballooning: ✓
   ```

8. **Network**:

   ```
   Bridge: vmbr1 (Management)
   Model: VirtIO (paravirtualized)
   ```

9. **Confirm and Create**

### Add Additional Network Interface for Production

1. **Select DC1-LAB VM** → **Hardware**
2. **Add → Network Device**:

   ```
   Bridge: vmbr2 (Production)
   Model: VirtIO
   ```

## 🌐 Network Configuration Reference

### Recommended Network Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Proxmox Host                             │
│                 (Your Proxmox Server)                      │
└─────────────────────┬───────────────────────────────────────┘
                      │
            ┌─────────▼──────────┐
            │     vmbr0          │ (Default - Internet)
            │  Physical Bridge   │
            └─────────┬──────────┘
                      │
        ┌─────────────┼─────────────┐
        │             │             │
┌───────▼──────┐ ┌────▼──────┐ ┌───▼───────┐
│    vmbr1     │ │   vmbr2   │ │   vmbr3   │
│ Management   │ │Production │ │  Client   │
│192.168.100.0 │ │192.168.1.0│ │192.168.2.0│
└──────────────┘ └───────────┘ └───────────┘
```

### VM Network Configuration

#### DC1-LAB (Domain Controller)

- **Management Interface (vmbr1)**:
  - IP: `192.168.100.10/24`
  - Gateway: `192.168.100.1`
  - DNS: `192.168.100.10` (itself after AD installation)
  
- **Production Interface (vmbr2)**:
  - IP: `192.168.1.10/24`
  - Gateway: `192.168.1.1`
  - DNS: `192.168.1.10` (itself after AD installation)

#### FS1-LAB (File Server)

- **Management Interface**: `192.168.100.20/24`
- **Production Interface**: `192.168.1.20/24`
- **DNS**: `192.168.1.10` (DC1-LAB)

## 🔧 Essential Proxmox Commands

### VM Management

```bash
# List all VMs
qm list

# Start VM
qm start 100

# Stop VM
qm stop 100

# Get VM status
qm status 100

# Access VM console
qm monitor 100

# Snapshot management
qm snapshot 100 before-ad-install
qm rollback 100 before-ad-install
```

### Network Management

```bash
# Show network configuration
cat /etc/network/interfaces

# Restart networking
systemctl restart networking

# Check bridge status
brctl show
```

### Storage Management

```bash
# List storage
pvesm list

# Check disk usage
df -h

# LVM commands
lvdisplay
vgdisplay
```

## 💻 Windows VM Optimization

### Install VirtIO Drivers

1. **Download VirtIO ISO** from Proxmox or Fedora project
2. **Attach as CD-ROM** to VM
3. **During Windows installation**:
   - Load VirtIO SCSI driver for disk
   - Load VirtIO Network driver for network
4. **Post-installation**:
   - Install remaining VirtIO drivers
   - Install Qemu Guest Agent

### Performance Optimization

```bash
# Enable CPU flags for better performance
# Edit VM configuration
qm set 100 --cpu host,flags=+aes

# Enable balloon driver
qm set 100 --balloon 2048

# Set machine type for better compatibility
qm set 100 --machine q35

# Enable NUMA if multiple CPU sockets
qm set 100 --numa 1
```

## 🛡️ Security Configuration

### VM Security

```bash
# Enable firewall for VM
qm set 100 --firewall 1

# Disable USB redirection
qm set 100 --usb0 none
```

### Network Security

```bash
# Configure firewall rules at datacenter level
# Via web interface: Datacenter → Firewall → Rules
```

## 🎯 Quick VM Creation Templates

### Standard Windows Server VM

```bash
# Create VM via command line
qm create 100 \
  --name "DC1-LAB" \
  --memory 4096 \
  --cores 4 \
  --net0 virtio,bridge=vmbr1 \
  --net1 virtio,bridge=vmbr2 \
  --scsi0 local-lvm:80 \
  --ide2 local:iso/WindowsServer2022.iso,media=cdrom \
  --ostype win10 \
  --agent 1
```

### Windows Client VM

```bash
# Create Windows 10/11 client
qm create 101 \
  --name "CLIENT1-LAB" \
  --memory 4096 \
  --cores 2 \
  --net0 virtio,bridge=vmbr1 \
  --scsi0 local-lvm:60 \
  --ide2 local:iso/Windows11.iso,media=cdrom \
  --ostype win10 \
  --agent 1
```

## 🏗️ Lab Architecture Deployment

### Typical Lab Setup

1. **DC1-LAB** (100) - Primary Domain Controller
2. **DC2-LAB** (101) - Secondary Domain Controller
3. **FS1-LAB** (102) - File Server
4. **WEB1-LAB** (103) - Web Server
5. **CLIENT1-LAB** (110) - Windows Client
6. **CLIENT2-LAB** (111) - Additional Client

### Deployment Order

1. Create network bridges
2. Deploy Domain Controller first
3. Install and configure Active Directory
4. Deploy additional servers
5. Join servers to domain
6. Deploy and join client machines

## 🆘 Troubleshooting Quick Fixes

### VM Won't Start

```bash
# Check VM configuration
qm config 100

# Check available resources
free -h
df -h

# Check logs
tail -f /var/log/pve/tasks/active
```

### Network Issues

```bash
# Check bridge configuration
ip addr show
brctl show

# Test network connectivity
ping 192.168.1.1
```

### Performance Issues

```bash
# Check system resources
htop
iotop

# Check VM resources
qm info 100
```

### Storage Issues

```bash
# Check storage status
pvesm status

# Check LVM
lvs
vgs
pvs
```

## 📚 Next Steps

1. **Complete Windows Installation** on your VMs
2. **Install VirtIO Drivers** for optimal performance
3. **Configure Active Directory** - Follow [Lab Environment Setup](01_Setup_Lab_Environment.md)
4. **Set up Additional VMs** using the templates above
5. **Configure Lab Services** - DNS, DHCP, File Shares, etc.
6. **Implement Security** - Follow Windows Server security guides

## 🎓 Advanced Features

### High Availability

- Configure HA groups for automatic failover
- Set up shared storage for VM migration
- Configure fencing for split-brain protection

### Backup and Recovery

- Set up automated VM backups
- Configure backup retention policies
- Test restore procedures

### Monitoring

- Enable Proxmox monitoring
- Set up email notifications
- Configure log forwarding

This guide provides the foundation for building a robust Windows Server lab environment on Proxmox VE. The modular approach allows you to start simple and expand as your requirements grow.
