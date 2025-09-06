# 🏢 Proxmox VE Setup and Virtual Network Configuration

## 🎯 What You'll Learn

- How to install and configure Proxmox VE for Windows Server labs
- Creating and managing virtual networks for lab environments
- Setting up proper network isolation and security
- Configuring Proxmox VE for optimal Windows Server performance
- Best practices for Proxmox networking and VM management

## 📋 Prerequisites

Before we begin, ensure you have:

1. **Dedicated server or workstation** for Proxmox installation
   - Modern 64-bit CPU with VT-x/AMD-V support
   - At least 16GB RAM (32GB+ recommended for multiple VMs)
   - 500GB+ storage (NVMe SSD recommended)
   - Multiple network interfaces (recommended but not required)
2. **Proxmox VE ISO** downloaded from [proxmox.com](https://www.proxmox.com/en/downloads)
3. **Network configuration** planning completed
4. **Windows Server and client ISOs** ready for upload

## 🚀 Step 1: Install Proxmox VE

### Installation Process

1. **Create bootable USB** with Proxmox VE ISO
2. **Boot from USB** and start installation
3. **Accept license** and continue
4. **Select target disk** for installation
5. **Configure basic settings**:

   ```
   Country: Your country
   Timezone: Your timezone
   Keyboard Layout: Your layout
   ```

6. **Set administrator password**:

   ```
   Password: [Strong password]
   Email: admin@your-domain.com
   ```

7. **Network configuration**:

   ```
   Management Interface: Primary network interface
   Hostname: proxmox.your-domain.local
   IP Address: 192.168.1.100/24 (adjust for your network)
   Gateway: 192.168.1.1
   DNS Server: 8.8.8.8
   ```

8. **Complete installation** and reboot

### Post-Installation Configuration

```bash
# Update Proxmox (run on Proxmox host)
apt update && apt upgrade -y

# Configure Proxmox repositories (optional, for non-subscription)
# Edit /etc/apt/sources.list.d/pve-enterprise.list
# Comment out the enterprise repository if not using subscription

# Add no-subscription repository
echo "deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription" >> /etc/apt/sources.list.d/pve-no-subscription.list

# Update package lists
apt update
```

## 🌐 Step 2: Network Architecture Planning

### Recommended Network Design

```
┌─────────────────────────────────────────────────────────────────┐
│                    Physical Proxmox Host                        │
│                  (192.168.1.100/24)                            │
└─────────────────────┬───────────────────────────────────────────┘
                      │
              ┌───────▼────────┐
              │     vmbr0      │ (Physical Bridge - Internet)
              │  192.168.1.0/24 │
              └───────┬────────┘
                      │
        ┌─────────────┼─────────────────┐
        │             │                 │
┌───────▼──────┐ ┌────▼──────┐ ┌────────▼───────┐
│    vmbr1     │ │   vmbr2   │ │     vmbr3      │
│ Management   │ │Production │ │   Client Lab   │
│192.168.100.0 │ │192.168.1.0│ │ 192.168.200.0  │
│     /24      │ │    /24    │ │      /24       │
└──────────────┘ └───────────┘ └────────────────┘
```

### Network Segmentation Strategy

| Network | VLAN | Purpose | IP Range | Gateway |
|---------|------|---------|----------|---------|
| **Management** | 100 | Host access, backups | 192.168.100.0/24 | 192.168.100.1 |
| **Production** | 10 | Server lab network | 192.168.1.0/24 | 192.168.1.1 |
| **Client Lab** | 200 | Workstation testing | 192.168.200.0/24 | 192.168.200.1 |
| **DMZ** | 50 | Web servers, external | 192.168.50.0/24 | 192.168.50.1 |

## 🔧 Step 3: Create Virtual Bridges

### Via Web Interface

1. **Navigate to**: `Datacenter → [Your Node] → System → Network`
2. **Create Management Bridge** (vmbr1):

   ```
   Name: vmbr1
   IPv4/CIDR: 192.168.100.1/24
   Comment: Lab Management Network
   Autostart: Yes
   VLAN aware: Yes (for advanced setups)
   ```

3. **Create Production Bridge** (vmbr2):

   ```
   Name: vmbr2
   IPv4/CIDR: 192.168.1.1/24
   Comment: Lab Production Network
   Autostart: Yes
   VLAN aware: Yes
   ```

4. **Apply Configuration** and reboot if needed

### Via Command Line

```bash
# Edit network configuration
nano /etc/network/interfaces

# Add virtual bridges
cat >> /etc/network/interfaces << EOF

# Management Network Bridge
auto vmbr1
iface vmbr1 inet static
    address 192.168.100.1/24
    bridge-ports none
    bridge-stp off
    bridge-fd 0
    bridge-vlan-aware yes
    post-up echo 1 > /proc/sys/net/ipv4/ip_forward
    post-up iptables -t nat -A POSTROUTING -s '192.168.100.0/24' -o vmbr0 -j MASQUERADE
    post-down iptables -t nat -D POSTROUTING -s '192.168.100.0/24' -o vmbr0 -j MASQUERADE

# Production Lab Network Bridge  
auto vmbr2
iface vmbr2 inet static
    address 192.168.1.1/24
    bridge-ports none
    bridge-stp off
    bridge-fd 0
    bridge-vlan-aware yes
    post-up echo 1 > /proc/sys/net/ipv4/ip_forward
    post-up iptables -t nat -A POSTROUTING -s '192.168.1.0/24' -o vmbr0 -j MASQUERADE
    post-down iptables -t nat -D POSTROUTING -s '192.168.1.0/24' -o vmbr0 -j MASQUERADE

# Client Lab Network Bridge
auto vmbr3  
iface vmbr3 inet static
    address 192.168.200.1/24
    bridge-ports none
    bridge-stp off
    bridge-fd 0
    bridge-vlan-aware yes
    post-up echo 1 > /proc/sys/net/ipv4/ip_forward
    post-up iptables -t nat -A POSTROUTING -s '192.168.200.0/24' -o vmbr0 -j MASQUERADE
    post-down iptables -t nat -D POSTROUTING -s '192.168.200.0/24' -o vmbr0 -j MASQUERADE
EOF

# Restart networking
systemctl restart networking
```

## 🖥️ Step 4: VM Template Creation

### Create Windows Server Template

1. **Create base VM** with optimal settings
2. **Install Windows Server** with VirtIO drivers
3. **Configure basic settings** and sysprep
4. **Convert to template** for rapid deployment

### Template Configuration Script

```bash
# Create Windows Server template VM
qm create 9000 \
  --name "win-server-template" \
  --memory 4096 \
  --cores 4 \
  --net0 virtio,bridge=vmbr1 \
  --net1 virtio,bridge=vmbr2 \
  --scsi0 local-lvm:80 \
  --ide2 local:iso/WindowsServer2022.iso,media=cdrom \
  --ide0 local:iso/virtio-win.iso,media=cdrom \
  --ostype win10 \
  --agent 1 \
  --bios ovmf \
  --efidisk0 local-lvm:4 \
  --machine q35 \
  --cpu host

# After installation and configuration, convert to template
qm template 9000
```

## 💾 Step 5: Storage Configuration

### Storage Types for Lab Environment

```bash
# Check current storage
pvesm status

# Add additional storage if needed
# Directory storage for ISOs and backups
pvesm add dir backup-storage --path /backup --content backup,iso

# Configure automatic backup
# Via web interface: Datacenter → Backup → Add
```

### Optimal Storage Layout

| Storage Type | Purpose | Configuration |
|--------------|---------|---------------|
| **local-lvm** | VM disks | Thin provisioning, snapshots |
| **local** | ISOs, templates | Directory storage |
| **NFS/CIFS** | Shared storage | For live migration |
| **Backup** | VM backups | Separate disk/NAS |

## 🔒 Step 6: Security Configuration

### Firewall Configuration

```bash
# Enable Proxmox firewall
# Via web interface: Datacenter → Firewall → Options
# Enable: Yes

# Configure basic rules
# Datacenter → Firewall → Rules
# Allow SSH (22), HTTPS (8006), VNC (5900-5999)
```

### User Management

```bash
# Create lab user via web interface
# Datacenter → Permissions → Users → Add

# Example user configuration:
# User ID: labadmin@pve
# Password: [strong password]
# Groups: lab-admins
# Permissions: VM admin on specific VMs
```

### SSL Certificate

```bash
# Generate self-signed certificate for lab use
openssl req -newkey rsa:2048 -nodes -keyout /etc/pve/nodes/$(hostname)/pve-ssl.key -out /etc/pve/nodes/$(hostname)/pve-ssl.csr

# Or use Let's Encrypt for production
pvenode acme account register default mail@example.com
pvenode acme cert order
```

## 🎯 Step 7: VM Deployment Examples

### Domain Controller VM (DC1-LAB)

```bash
# Clone from template
qm clone 9000 100 --name DC1-LAB --full

# Customize configuration
qm set 100 --memory 4096 --cores 4
qm set 100 --net0 virtio,bridge=vmbr1,tag=100
qm set 100 --net1 virtio,bridge=vmbr2,tag=10
qm set 100 --description "Primary Domain Controller"

# Start VM
qm start 100
```

### File Server VM (FS1-LAB)

```bash
# Clone and configure file server
qm clone 9000 102 --name FS1-LAB --full
qm set 102 --memory 8192 --cores 4
qm set 102 --scsi1 local-lvm:200  # Additional disk for data
qm set 102 --net0 virtio,bridge=vmbr1,tag=100
qm set 102 --net1 virtio,bridge=vmbr2,tag=10
qm start 102
```

## 📊 Step 8: Monitoring and Management

### Performance Monitoring

```bash
# Check VM performance
qm monitor 100

# System resource usage
htop
iotop
free -h
df -h

# Network monitoring
iftop
nethogs
```

### Backup Configuration

```bash
# Create backup schedule via web interface
# Datacenter → Backup → Add

# Example backup job:
# Schedule: Daily at 2:00 AM
# Storage: backup-storage
# Mode: Snapshot
# Compression: ZSTD
# Retention: 7 daily, 4 weekly, 12 monthly
```

### VM Management Commands

```bash
# Essential VM commands
qm list                    # List all VMs
qm status 100             # Check VM status
qm start 100              # Start VM
qm stop 100               # Stop VM
qm restart 100            # Restart VM
qm reset 100              # Hard reset VM

# Snapshot management
qm snapshot 100 pre-update
qm listsnapshot 100
qm rollback 100 pre-update
qm delsnapshot 100 pre-update

# Live migration (if multiple nodes)
qm migrate 100 node2
```

## 🛠️ Step 9: Advanced Configuration

### High Availability Setup

```bash
# Configure HA (requires cluster)
# Datacenter → HA → Groups → Add
# Create HA group for lab VMs

# Add VMs to HA
# Datacenter → HA → Resources
# Add VMs with priority settings
```

### GPU Passthrough (if required)

```bash
# Enable IOMMU
echo "intel_iommu=on iommu=pt" >> /etc/default/grub
update-grub

# Configure GPU passthrough
# Edit VM configuration to add PCI device
qm set 100 --hostpci0 01:00,pcie=1
```

### Network VLAN Configuration

```bash
# Configure VLAN-aware bridge
# Network → vmbr1 → Edit
# VLAN aware: Yes

# Assign VLAN tags to VM interfaces
qm set 100 --net0 virtio,bridge=vmbr1,tag=100
qm set 100 --net1 virtio,bridge=vmbr2,tag=10
```

## 🔧 Best Practices for Windows Server Labs

### VM Configuration Optimization

1. **Use VirtIO drivers** for all devices (network, storage, balloon)
2. **Enable Qemu Guest Agent** for better integration
3. **Use UEFI boot** for modern Windows versions
4. **Configure appropriate CPU type** (host for best performance)
5. **Enable balloon memory** for dynamic allocation

### Network Security

1. **Implement firewall rules** at VM and host level
2. **Use VLANs** for network segmentation
3. **Restrict management access** to specific IPs
4. **Regular security updates** for Proxmox host

### Performance Tuning

1. **Use NVMe/SSD storage** for better I/O performance
2. **Configure appropriate NUMA** settings for large VMs
3. **Monitor resource usage** and adjust allocations
4. **Use thin provisioning** to optimize storage usage

### Backup Strategy

1. **Automated daily backups** with retention policies
2. **Test restore procedures** regularly
3. **Store backups** on separate storage
4. **Document recovery procedures**

## 🆘 Troubleshooting Common Issues

### VM Won't Start

```bash
# Check configuration
qm config 100

# Check logs
tail -f /var/log/pve/tasks/active

# Check resources
free -h
df -h
```

### Network Connectivity Issues

```bash
# Check bridge configuration
brctl show
ip addr show

# Test connectivity
ping 192.168.1.1
traceroute 8.8.8.8

# Check firewall rules
iptables -L -n
```

### Performance Issues

```bash
# Check system load
uptime
top
iostat -x 1

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

# Check filesystem
df -h
lsblk
```

## 📚 Next Steps

1. **Deploy VMs** using the configured environment
2. **Install Windows Server** with VirtIO drivers
3. **Configure Active Directory** following the lab guides
4. **Set up network services** (DNS, DHCP, etc.)
5. **Implement security policies** and monitoring
6. **Test backup and recovery** procedures

This comprehensive guide provides the foundation for building a professional Windows Server lab environment on Proxmox VE. The enterprise-grade virtualization platform offers scalability, reliability, and advanced features suitable for both learning and production-ready deployments.
