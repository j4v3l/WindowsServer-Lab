# 🏰 **ASGARD TECHNOLOGIES** - Manual Setup Guide

> **Legacy reference:** This hand-built `.local` topology is retained for historical users and is not the v2 production-like deployment path. It contains old bridge and IP examples. New deployments must use the canonical `ad.asgard.test` definition and the guarded [six-VM startup runbook](../../docs/SMOKE_STARTUP.md); never apply this guide's `vmbr0`/`vmbr1` examples to the current host.

## 📋 **EXECUTION CONTEXT GUIDE**

**CRITICAL:** This guide contains commands that must be run on different systems. Pay attention to the execution context for each command:

- **[PROXMOX HOST]** - Commands run on the Proxmox VE host via SSH or console
- **[SERVER VM]** - Commands run inside Windows Server VMs (domain controllers, file servers, etc.)
- **[CLIENT VM]** - Commands run inside Windows client VMs (workstations)

### **Access Methods:**

- **Proxmox Host:** SSH to Proxmox VE with root privileges
- **Server VMs:** RDP, Console, or PowerShell Direct with Administrator/Domain Admin privileges
- **Client VMs:** Local console or RDP with Local Administrator privileges

### **Prerequisites Verification:**

Before running any commands, ensure all prerequisites are met as listed in each section.

## 📋 **Overview**

This manual setup guide provides step-by-step instructions for deploying the Asgard Technologies Windows Server lab environment without using the automated deployment script. This approach gives you complete control over the installation process and allows for customization at each step.

---

## 🎯 **What You'll Build**

- **25 Virtual Machines** (5 servers + 20 workstations)
- **Norse Mythology Company**: Realistic enterprise organization
- **Complete Domain Environment**: `asgard.local`
- **4 Network Segments**: Production, Management, Client, DMZ
- **25 User Accounts**: Across 5 departments

---

## 📋 **Prerequisites**

### **Hardware Requirements**

| Component   | Minimum    | Recommended | Tested Optimal            |
| ----------- | ---------- | ----------- | ------------------------- |
| **CPU**     | 8 cores    | 12+ cores   | AMD Ryzen 7900X (12C/24T) |
| **RAM**     | 32GB       | 64GB        | 64GB DDR5                 |
| **Storage** | 500GB      | 1TB+        | 1TB NVMe SSD              |
| **GPU**     | Integrated | Dedicated   | NVIDIA RTX 5070 (12GB)    |

### **Software Requirements**

- **Proxmox VE 8.0+ Environment Ready**
- **Windows Server 2019/2022/2025 ISO**
- **Windows 10/11 Client ISO**
- **VirtIO drivers ISO for optimal Windows performance**
- **SSH access to Proxmox host (optional)**

### **Network Requirements**

- **Physical network adapter** (for external connectivity)
- **Internet access** (for updates and downloads)

---

## 🚀 **Phase 1: Environment Preparation**

### **Step 1.1: Prepare Proxmox VE Environment**

```bash
# Create VMs using Proxmox VE web interface
# Follow the Proxmox setup guides for VM creation
# Ensure adequate resources are allocated:
# - Domain Controller: 8GB RAM, 4 vCPU, 80GB disk
# - File Server: 6GB RAM, 3 vCPU, 120GB disk
# - Web Server: 6GB RAM, 3 vCPU, 80GB disk
```

### **Step 1.2: Upload ISO Files to Proxmox**

```bash
# Upload ISO files to Proxmox storage
# Method 1: Via web interface
# Navigate to: Datacenter > [Node] > local (storage) > ISO Images > Upload

# Method 2: Via command line (on Proxmox host)
cd /var/lib/vz/template/iso/
# Upload your ISO files here:
# - WindowsServer2022.iso (or your version)
# - Windows11.iso (for client VMs)
# - virtio-win.iso (VirtIO drivers)
```

### **Step 1.3: Configure Proxmox Storage**

1. **Verify Local Storage**
   - Ensure adequate space in `local-lvm` for VM disks
   - Recommended: 500GB+ free space

2. **Optional: Configure Additional Storage**

   ```bash
   # Add additional storage if needed
   # Via web interface: Datacenter > Storage > Add
   # Configure shared storage for VM migration (optional)
   ```

---

## 🌐 **Phase 2: Network Infrastructure Setup**

### **Step 2.1: Create Network Bridges in Proxmox VE**

#### **Production Network (External)**

```bash
# Use Proxmox VE web interface to create network bridges
# Navigate to: Datacenter > [Node] > System > Network
# Create bridge vmbr0 for production network with physical interface
# This provides internet access for VMs
```

#### **Management Network (Internal)**

```bash
# Create bridge vmbr1 for management network
# Configure as internal bridge without physical interface
# IP: 10.0.100.1/24 for host management access
```

#### **Client Network (Internal)**

```bash
# Create bridge vmbr2 for client network
# Configure as internal bridge
# IP: 10.0.20.1/22 for client VMs
```

#### **DMZ Network (Private)**

```bash
# Create bridge vmbr3 for DMZ
# Configure as isolated bridge for web servers
```

### **Step 2.2: Verify Network Configuration**

```bash
# Check network bridges on Proxmox host
ip link show | grep vmbr
# Verify bridge configurations
brctl show
```

---

## 🖥️ **Phase 3: Server Infrastructure Deployment**

### **Step 3.1: Create Primary Domain Controller (ODIN-DC01)**

#### **Create VM using Proxmox VE Web Interface**

1. **Navigate to**: Datacenter > [Node] > Create VM
2. **General Tab**:
   - VM ID: 100
   - Name: ODIN-DC01
   - Resource Pool: (optional)

3. **OS Tab**:
   - Use CD/DVD disc image file (iso)
   - Storage: local
   - ISO image: WindowsServer2022.iso

4. **System Tab**:
   - Machine: q35
   - BIOS: OVMF (UEFI)
   - Add EFI Disk: Yes
   - SCSI Controller: VirtIO SCSI

5. **Hard Disk Tab**:
   - Bus/Device: SCSI 0
   - Storage: local-lvm
   - Disk size: 80 GB
   - Cache: Write back
   - Discard: Yes

6. **CPU Tab**:
   - Cores: 4
   - Type: host

7. **Memory Tab**:
   - Memory: 8192 MB

8. **Network Tab**:
   - Bridge: vmbr0 (Production)
   - Model: VirtIO (paravirtualized)

9. **Add Second Network Interface**:
   - Bridge: vmbr1 (Management)
   - Model: VirtIO

#### **Install Windows Server**

1. **Start VM**: Click Start button in Proxmox web interface
2. **Connect**: Use web console or VNC viewer
3. **Install Windows Server** with Desktop Experience
4. **Configure Basic Settings**:
   - Computer Name: `ODIN-DC01`
   - Administrator Password: (Choose secure password)
   - Network Configuration:
     - Production NIC: DHCP (temporary)
     - Management NIC: Static IP `10.0.100.10/24`

#### **Promote to Domain Controller**

```powershell
# [SERVER VM] - Run on ODIN-DC01 after initial Windows Server installation
# EXECUTION CONTEXT: PowerShell session with Administrator privileges on ODIN-DC01
# PREREQUISITES: Windows Server installed, network configured, system updated

Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

# Import AD DS module
Import-Module ADDSDeployment

# Create new forest
$DomainName = "asgard.local"
$SafeModePassword = ConvertTo-SecureString "[ADMIN_MUST_SET_SECURE_PASSWORD]" -AsPlainText -Force

Install-ADDSForest `
    -CreateDnsDelegation:$false `
    -DatabasePath "C:\Windows\NTDS" `
    -DomainMode "WinThreshold" `
    -DomainName $DomainName `
    -DomainNetbiosName "ASGARD" `
    -ForestMode "WinThreshold" `
    -InstallDns:$true `
    -LogPath "C:\Windows\NTDS" `
    -NoRebootOnCompletion:$false `
    -SysvolPath "C:\Windows\SYSVOL" `
    -SafeModeAdministratorPassword $SafeModePassword `
    -Force:$true
```

### **Step 3.2: Create Secondary Domain Controller (FRIGG-DC02)**

#### **Create VM using Proxmox VE Web Interface**

1. **Navigate to**: Datacenter > [Node] > Create VM
2. **VM Configuration**:
   - VM ID: 101
   - Name: FRIGG-DC02
   - Memory: 6144 MB
   - CPU Cores: 3
   - Disk: 60 GB
   - Network: vmbr0 (Production) + vmbr1 (Management)

#### **Install and Configure**

1. Install Windows Server
2. Configure network settings:
   - Computer Name: `FRIGG-DC02`
   - Management NIC: `10.0.100.11/24`
   - DNS: `10.0.100.10` (ODIN-DC01)
3. Join domain and promote to DC

### **Step 3.3: Create File Server (HEIMDALL-FS01)**

#### **Create VM using Proxmox VE Web Interface**

1. **Navigate to**: Datacenter > [Node] > Create VM
2. **VM Configuration**:
   - VM ID: 102
   - Name: HEIMDALL-FS01
   - Memory: 8192 MB
   - CPU Cores: 4
   - Disk: 120 GB
   - Network: vmbr0 (Production) + vmbr1 (Management)

3. **Or via Command Line**:

   ```bash
   # [PROXMOX HOST] - Create file server VM using Proxmox CLI
   # EXECUTION CONTEXT: SSH session to Proxmox VE host with root privileges
   # PREREQUISITES: ISO files uploaded, storage configured, network bridges created
   
   qm create 102 \
     --name "HEIMDALL-FS01" \
     --memory 8192 \
     --cores 4 \
     --cpu host \
     --machine q35 \
     --bios ovmf \
     --efidisk0 local-lvm:4 \
     --scsi0 local-lvm:120,cache=writeback,discard=on \
     --scsihw virtio-scsi-single \
     --net0 virtio,bridge=vmbr0 \
     --net1 virtio,bridge=vmbr1 \
     --ide2 local:iso/WindowsServer2022.iso,media=cdrom \
     --ide0 local:iso/virtio-win.iso,media=cdrom \
     --ostype win10 \
     --agent 1
   ```

#### **Configure File Server Role**

```powershell
# [SERVER VM] - Run on HEIMDALL-FS01 after domain join
# EXECUTION CONTEXT: PowerShell session with Domain Administrator privileges on HEIMDALL-FS01
# PREREQUISITES: VM joined to asgard.local domain, Windows Server installed

Install-WindowsFeature -Name File-Services -IncludeManagementTools
Install-WindowsFeature -Name FS-FileServer -IncludeManagementTools
Install-WindowsFeature -Name FS-DFS-Namespace -IncludeManagementTools
Install-WindowsFeature -Name FS-DFS-Replication -IncludeManagementTools
```

### **Step 3.4: Create Web Server (BALDER-WEB01)**

#### **Create VM using Proxmox VE Web Interface**

1. **Navigate to**: Datacenter > [Node] > Create VM
2. **VM Configuration**:
   - VM ID: 103
   - Name: BALDER-WEB01
   - Memory: 6144 MB
   - CPU Cores: 3
   - Disk: 80 GB
   - Network: vmbr0 (Production) + vmbr1 (Management) + vmbr3 (DMZ)

3. **Or via Command Line**:

   ```bash
   # [PROXMOX HOST] - Create web server VM with DMZ access
   # EXECUTION CONTEXT: SSH session to Proxmox VE host with root privileges
   # PREREQUISITES: ISO files uploaded, network bridges vmbr0, vmbr1, vmbr3 created
   
   qm create 103 \
     --name "BALDER-WEB01" \
     --memory 6144 \
     --cores 3 \
     --cpu host \
     --machine q35 \
     --bios ovmf \
     --efidisk0 local-lvm:4 \
     --scsi0 local-lvm:80,cache=writeback,discard=on \
     --scsihw virtio-scsi-single \
     --net0 virtio,bridge=vmbr0 \
     --net1 virtio,bridge=vmbr1 \
     --net2 virtio,bridge=vmbr3 \
     --ide2 local:iso/WindowsServer2022.iso,media=cdrom \
     --ide0 local:iso/virtio-win.iso,media=cdrom \
     --ostype win10 \
     --agent 1
   ```

#### **Configure IIS and Web Services**

```powershell
# [SERVER VM] - Run on BALDER-WEB01 after domain join
# EXECUTION CONTEXT: PowerShell session with Domain Administrator privileges on BALDER-WEB01
# PREREQUISITES: VM joined to asgard.local domain, Windows Server installed

Install-WindowsFeature -Name Web-Server -IncludeManagementTools
Install-WindowsFeature -Name Web-Asp-Net45 -IncludeManagementTools
Install-WindowsFeature -Name Web-Net-Ext45 -IncludeManagementTools
```

### **Step 3.5: Create Security Server (VIDAR-SEC01)**

#### **Create VM using Proxmox VE Web Interface**

1. **Navigate to**: Datacenter > [Node] > Create VM
2. **VM Configuration**:
   - VM ID: 104
   - Name: VIDAR-SEC01
   - Memory: 8192 MB
   - CPU Cores: 4
   - Disk: 100 GB
   - Network: vmbr0 (Production) + vmbr1 (Management)

3. **Or via Command Line**:

   ```bash
   # [PROXMOX HOST] - Create security server VM
   # EXECUTION CONTEXT: SSH session to Proxmox VE host with root privileges
   # PREREQUISITES: ISO files uploaded, network bridges vmbr0, vmbr1 created
   
   qm create 104 \
     --name "VIDAR-SEC01" \
     --memory 8192 \
     --cores 4 \
     --cpu host \
     --machine q35 \
     --bios ovmf \
     --efidisk0 local-lvm:4 \
     --scsi0 local-lvm:100,cache=writeback,discard=on \
     --scsihw virtio-scsi-single \
     --net0 virtio,bridge=vmbr0 \
     --net1 virtio,bridge=vmbr1 \
     --ide2 local:iso/WindowsServer2022.iso,media=cdrom \
     --ide0 local:iso/virtio-win.iso,media=cdrom \
     --ostype win10 \
     --agent 1
   ```

#### **Configure WSUS and Security Features**

```powershell
# [SERVER VM] - Run on VIDAR-SEC01 after domain join
# EXECUTION CONTEXT: PowerShell session with Domain Administrator privileges on VIDAR-SEC01
# PREREQUISITES: VM joined to asgard.local domain, Windows Server installed

Install-WindowsFeature -Name UpdateServices -IncludeManagementTools
Install-WindowsFeature -Name RSAT-AD-Tools -IncludeManagementTools
```

---

## 💻 **Phase 4: Workstation Deployment**

### **Step 4.1: Create Workstation Template**

#### **Workstation VM Template (via Proxmox VE)**

All workstations will follow this template configuration:

```bash
# [PROXMOX HOST] - Template for creating Asgard workstations
# EXECUTION CONTEXT: SSH session to Proxmox VE host with root privileges
# VM IDs: 110-129 (20 workstations)
# Standard configuration:
# - Memory: 4096 MB (adjustable per workstation)
# - CPU: 2 cores (adjustable per workstation)
# - Disk: 60 GB (adjustable per workstation)
# - Network: vmbr2 (Client network)
# - OS: Windows 10/11

# Example template command:
qm create [VMID] \
  --name "[VM_NAME]" \
  --memory 4096 \
  --cores 2 \
  --cpu host \
  --machine q35 \
  --bios ovmf \
  --efidisk0 local-lvm:4 \
  --scsi0 local-lvm:60,cache=writeback,discard=on \
  --scsihw virtio-scsi-single \
  --net0 virtio,bridge=vmbr2 \
  --ide2 local:iso/Windows11.iso,media=cdrom \
  --ide0 local:iso/virtio-win.iso,media=cdrom \
  --ostype win10 \
  --agent 1
```

### **Step 4.2: Create All Workstations**

#### **IT Operations Department (Odin's Realm)**

```bash
# Create IT Operations workstations via Proxmox VE

# ODIN-WS01 (Command Center)
qm create 110 \
  --name "ODIN-WS01" \
  --memory 6144 \
  --cores 2 \
  --cpu host \
  --machine q35 \
  --bios ovmf \
  --efidisk0 local-lvm:4 \
  --scsi0 local-lvm:80,cache=writeback,discard=on \
  --scsihw virtio-scsi-single \
  --net0 virtio,bridge=vmbr2 \
  --ide2 local:iso/Windows11.iso,media=cdrom \
  --ide0 local:iso/virtio-win.iso,media=cdrom \
  --ostype win10 \
  --agent 1

# THOR-WS01 (Thunder Station)
qm create 111 \
  --name "THOR-WS01" \
  --memory 4096 \
  --cores 2 \
  --cpu host \
  --machine q35 \
  --bios ovmf \
  --efidisk0 local-lvm:4 \
  --scsi0 local-lvm:60,cache=writeback,discard=on \
  --scsihw virtio-scsi-single \
  --net0 virtio,bridge=vmbr2 \
  --ide2 local:iso/Windows11.iso,media=cdrom \
  --ide0 local:iso/virtio-win.iso,media=cdrom \
  --ostype win10 \
  --agent 1

# LOKI-WS01 (Mischief Machine)
qm create 112 \
  --name "LOKI-WS01" \
  --memory 3072 \
  --cores 2 \
  --cpu host \
  --machine q35 \
  --bios ovmf \
  --efidisk0 local-lvm:4 \
  --scsi0 local-lvm:60,cache=writeback,discard=on \
  --scsihw virtio-scsi-single \
  --net0 virtio,bridge=vmbr2 \
  --ide2 local:iso/Windows11.iso,media=cdrom \
  --ide0 local:iso/virtio-win.iso,media=cdrom \
  --ostype win10 \
  --agent 1

# HERMOD-WS01 (Messenger Terminal)
qm create 113 \
  --name "HERMOD-WS01" \
  --memory 3072 \
  --cores 2 \
  --cpu host \
  --machine q35 \
  --bios ovmf \
  --efidisk0 local-lvm:4 \
  --scsi0 local-lvm:60,cache=writeback,discard=on \
  --scsihw virtio-scsi-single \
  --net0 virtio,bridge=vmbr2 \
  --ide2 local:iso/Windows11.iso,media=cdrom \
  --ide0 local:iso/virtio-win.iso,media=cdrom \
  --ostype win10 \
  --agent 1

# TYR-WS01 (Brave Station)
qm create 114 \
  --name "TYR-WS01" \
  --memory 3072 \
  --cores 2 \
  --cpu host \
  --machine q35 \
  --bios ovmf \
  --efidisk0 local-lvm:4 \
  --scsi0 local-lvm:60,cache=writeback,discard=on \
  --scsihw virtio-scsi-single \
  --net0 virtio,bridge=vmbr2 \
  --ide2 local:iso/Windows11.iso,media=cdrom \
  --ide0 local:iso/virtio-win.iso,media=cdrom \
  --ostype win10 \
  --agent 1
```

#### **Cybersecurity Department (Heimdall's Watch)**

```bash
# Create Cybersecurity workstations via Proxmox VE

# HEIMDALL-WS01 (Watchtower)
qm create 115 \
  --name "HEIMDALL-WS01" \
  --memory 6144 \
  --cores 2 \
  --cpu host \
  --machine q35 \
  --bios ovmf \
  --efidisk0 local-lvm:4 \
  --scsi0 local-lvm:80,cache=writeback,discard=on \
  --scsihw virtio-scsi-single \
  --net0 virtio,bridge=vmbr2 \
  --ide2 local:iso/Windows11.iso,media=cdrom \
  --ide0 local:iso/virtio-win.iso,media=cdrom \
  --ostype win10 \
  --agent 1

# MIMIR-WS01 (Wisdom Terminal)
qm create 116 \
  --name "MIMIR-WS01" \
  --memory 4096 \
  --cores 2 \
  --cpu host \
  --machine q35 \
  --bios ovmf \
  --efidisk0 local-lvm:4 \
  --scsi0 local-lvm:60,cache=writeback,discard=on \
  --scsihw virtio-scsi-single \
  --net0 virtio,bridge=vmbr2 \
  --ide2 local:iso/Windows11.iso,media=cdrom \
  --ide0 local:iso/virtio-win.iso,media=cdrom \
  --ostype win10 \
  --agent 1

# HUGINN-WS01 (Surveillance Station)
qm create 117 \
  --name "HUGINN-WS01" \
  --memory 3072 \
  --cores 2 \
  --cpu host \
  --machine q35 \
  --bios ovmf \
  --efidisk0 local-lvm:4 \
  --scsi0 local-lvm:60,cache=writeback,discard=on \
  --scsihw virtio-scsi-single \
  --net0 virtio,bridge=vmbr2 \
  --ide2 local:iso/Windows11.iso,media=cdrom \
  --ide0 local:iso/virtio-win.iso,media=cdrom \
  --ostype win10 \
  --agent 1

# MUNINN-WS01 (Memory Bank)
qm create 118 \
  --name "MUNINN-WS01" \
  --memory 3072 \
  --cores 2 \
  --cpu host \
  --machine q35 \
  --bios ovmf \
  --efidisk0 local-lvm:4 \
  --scsi0 local-lvm:60,cache=writeback,discard=on \
  --scsihw virtio-scsi-single \
  --net0 virtio,bridge=vmbr2 \
  --ide2 local:iso/Windows11.iso,media=cdrom \
  --ide0 local:iso/virtio-win.iso,media=cdrom \
  --ostype win10 \
  --agent 1

# FENRIR-WS01 (Attack Lab)
qm create 119 \
  --name "FENRIR-WS01" \
  --memory 4096 \
  --cores 2 \
  --cpu host \
  --machine q35 \
  --bios ovmf \
  --efidisk0 local-lvm:4 \
  --scsi0 local-lvm:60,cache=writeback,discard=on \
  --scsihw virtio-scsi-single \
  --net0 virtio,bridge=vmbr2 \
  --ide2 local:iso/Windows11.iso,media=cdrom \
  --ide0 local:iso/virtio-win.iso,media=cdrom \
  --ostype win10 \
  --agent 1
```

#### **Research & Development (Freya's Workshop)**

```bash
# Create R&D workstations via Proxmox VE

# FREYA-WS01 (Innovation Lab)
qm create 120 \
  --name "FREYA-WS01" \
  --memory 6144 \
  --cores 2 \
  --cpu host \
  --machine q35 \
  --bios ovmf \
  --efidisk0 local-lvm:4 \
  --scsi0 local-lvm:100,cache=writeback,discard=on \
  --scsihw virtio-scsi-single \
  --net0 virtio,bridge=vmbr2 \
  --ide2 local:iso/Windows11.iso,media=cdrom \
  --ide0 local:iso/virtio-win.iso,media=cdrom \
  --ostype win10 \
  --agent 1

# NJORD-WS01 (Wind Tunnel)
qm create 121 \
  --name "NJORD-WS01" \
  --memory 4096 \
  --cores 2 \
  --cpu host \
  --machine q35 \
  --bios ovmf \
  --efidisk0 local-lvm:4 \
  --scsi0 local-lvm:80,cache=writeback,discard=on \
  --scsihw virtio-scsi-single \
  --net0 virtio,bridge=vmbr2 \
  --ide2 local:iso/Windows11.iso,media=cdrom \
  --ide0 local:iso/virtio-win.iso,media=cdrom \
  --ostype win10 \
  --agent 1

# FREY-WS01 (Prosperity Engine)
qm create 122 \
  --name "FREY-WS01" \
  --memory 4096 \
  --cores 2 \
  --cpu host \
  --machine q35 \
  --bios ovmf \
  --efidisk0 local-lvm:4 \
  --scsi0 local-lvm:80,cache=writeback,discard=on \
  --scsihw virtio-scsi-single \
  --net0 virtio,bridge=vmbr2 \
  --ide2 local:iso/Windows11.iso,media=cdrom \
  --ide0 local:iso/virtio-win.iso,media=cdrom \
  --ostype win10 \
  --agent 1

# JORMUNG-WS01 (Data Lake)
qm create 123 \
  --name "JORMUNG-WS01" \
  --memory 4096 \
  --cores 2 \
  --cpu host \
  --machine q35 \
  --bios ovmf \
  --efidisk0 local-lvm:4 \
  --scsi0 local-lvm:80,cache=writeback,discard=on \
  --scsihw virtio-scsi-single \
  --net0 virtio,bridge=vmbr2 \
  --ide2 local:iso/Windows11.iso,media=cdrom \
  --ide0 local:iso/virtio-win.iso,media=cdrom \
  --ostype win10 \
  --agent 1

# SLEIPNIR-WS01 (Speed Demon)
qm create 124 \
  --name "SLEIPNIR-WS01" \
  --memory 4096 \
  --cores 2 \
  --cpu host \
  --machine q35 \
  --bios ovmf \
  --efidisk0 local-lvm:4 \
  --scsi0 local-lvm:80,cache=writeback,discard=on \
  --scsihw virtio-scsi-single \
  --net0 virtio,bridge=vmbr2 \
  --ide2 local:iso/Windows11.iso,media=cdrom \
  --ide0 local:iso/virtio-win.iso,media=cdrom \
  --ostype win10 \
  --agent 1
```

#### **Finance & Administration (Frigg's Treasury)**

```bash
# Create Finance & Administration workstations via Proxmox VE

# FRIGG-WS01 (Treasury Terminal)
qm create 125 \
  --name "FRIGG-WS01" \
  --memory 4096 \
  --cores 2 \
  --cpu host \
  --machine q35 \
  --bios ovmf \
  --efidisk0 local-lvm:4 \
  --scsi0 local-lvm:60,cache=writeback,discard=on \
  --scsihw virtio-scsi-single \
  --net0 virtio,bridge=vmbr2 \
  --ide2 local:iso/Windows11.iso,media=cdrom \
  --ide0 local:iso/virtio-win.iso,media=cdrom \
  --ostype win10 \
  --agent 1

# EIR-WS01 (Healing Touch)
qm create 126 \
  --name "EIR-WS01" \
  --memory 3072 \
  --cores 2 \
  --cpu host \
  --machine q35 \
  --bios ovmf \
  --efidisk0 local-lvm:4 \
  --scsi0 local-lvm:60,cache=writeback,discard=on \
  --scsihw virtio-scsi-single \
  --net0 virtio,bridge=vmbr2 \
  --ide2 local:iso/Windows11.iso,media=cdrom \
  --ide0 local:iso/virtio-win.iso,media=cdrom \
  --ostype win10 \
  --agent 1

# SAGA-WS01 (Story Keeper)
qm create 127 \
  --name "SAGA-WS01" \
  --memory 3072 \
  --cores 2 \
  --cpu host \
  --machine q35 \
  --bios ovmf \
  --efidisk0 local-lvm:4 \
  --scsi0 local-lvm:60,cache=writeback,discard=on \
  --scsihw virtio-scsi-single \
  --net0 virtio,bridge=vmbr2 \
  --ide2 local:iso/Windows11.iso,media=cdrom \
  --ide0 local:iso/virtio-win.iso,media=cdrom \
  --ostype win10 \
  --agent 1

# VAR-WS01 (Oath Guardian)
qm create 128 \
  --name "VAR-WS01" \
  --memory 3072 \
  --cores 2 \
  --cpu host \
  --machine q35 \
  --bios ovmf \
  --efidisk0 local-lvm:4 \
  --scsi0 local-lvm:60,cache=writeback,discard=on \
  --scsihw virtio-scsi-single \
  --net0 virtio,bridge=vmbr2 \
  --ide2 local:iso/Windows11.iso,media=cdrom \
  --ide0 local:iso/virtio-win.iso,media=cdrom \
  --ostype win10 \
  --agent 1

# FORSETI-WS01 (Justice Scale)
qm create 129 \
  --name "FORSETI-WS01" \
  --memory 3072 \
  --cores 2 \
  --cpu host \
  --machine q35 \
  --bios ovmf \
  --efidisk0 local-lvm:4 \
  --scsi0 local-lvm:60,cache=writeback,discard=on \
  --scsihw virtio-scsi-single \
  --net0 virtio,bridge=vmbr2 \
  --ide2 local:iso/Windows11.iso,media=cdrom \
  --ide0 local:iso/virtio-win.iso,media=cdrom \
  --ostype win10 \
  --agent 1
```

#### **Human Resources (Sif's Domain)**

```bash
# Create Human Resources workstations via Proxmox VE

# SIF-WS01 (Golden Gateway)
qm create 130 \
  --name "SIF-WS01" \
  --memory 4096 \
  --cores 2 \
  --cpu host \
  --machine q35 \
  --bios ovmf \
  --efidisk0 local-lvm:4 \
  --scsi0 local-lvm:60,cache=writeback,discard=on \
  --scsihw virtio-scsi-single \
  --net0 virtio,bridge=vmbr2 \
  --ide2 local:iso/Windows11.iso,media=cdrom \
  --ide0 local:iso/virtio-win.iso,media=cdrom \
  --ostype win10 \
  --agent 1

# IDUN-WS01 (Eternal Garden)
qm create 131 \
  --name "IDUN-WS01" \
  --memory 3072 \
  --cores 2 \
  --cpu host \
  --machine q35 \
  --bios ovmf \
  --efidisk0 local-lvm:4 \
  --scsi0 local-lvm:60,cache=writeback,discard=on \
  --scsihw virtio-scsi-single \
  --net0 virtio,bridge=vmbr2 \
  --ide2 local:iso/Windows11.iso,media=cdrom \
  --ide0 local:iso/virtio-win.iso,media=cdrom \
  --ostype win10 \
  --agent 1

# BRAGI-WS01 (Poetic Portal)
qm create 132 \
  --name "BRAGI-WS01" \
  --memory 3072 \
  --cores 2 \
  --cpu host \
  --machine q35 \
  --bios ovmf \
  --efidisk0 local-lvm:4 \
  --scsi0 local-lvm:60,cache=writeback,discard=on \
  --scsihw virtio-scsi-single \
  --net0 virtio,bridge=vmbr2 \
  --ide2 local:iso/Windows11.iso,media=cdrom \
  --ide0 local:iso/virtio-win.iso,media=cdrom \
  --ostype win10 \
  --agent 1

# HEL-WS01 (Dual Nature)
qm create 133 \
  --name "HEL-WS01" \
  --memory 3072 \
  --cores 2 \
  --cpu host \
  --machine q35 \
  --bios ovmf \
  --efidisk0 local-lvm:4 \
  --scsi0 local-lvm:60,cache=writeback,discard=on \
  --scsihw virtio-scsi-single \
  --net0 virtio,bridge=vmbr2 \
  --ide2 local:iso/Windows11.iso,media=cdrom \
  --ide0 local:iso/virtio-win.iso,media=cdrom \
  --ostype win10 \
  --agent 1

# SIGYN-WS01 (Faithful Watch)
qm create 134 \
  --name "SIGYN-WS01" \
  --memory 3072 \
  --cores 2 \
  --cpu host \
  --machine q35 \
  --bios ovmf \
  --efidisk0 local-lvm:4 \
  --scsi0 local-lvm:60,cache=writeback,discard=on \
  --scsihw virtio-scsi-single \
  --net0 virtio,bridge=vmbr2 \
  --ide2 local:iso/Windows11.iso,media=cdrom \
  --ide0 local:iso/virtio-win.iso,media=cdrom \
  --ostype win10 \
  --agent 1
```

---

## 👥 **Phase 5: Active Directory Configuration**

### **Step 5.1: Create Organizational Units**

Run on ODIN-DC01:

```powershell
# Import AD module
Import-Module ActiveDirectory

# Create main OU structure
New-ADOrganizationalUnit -Name "Asgard Technologies" -Path "DC=asgard,DC=local"
$AsgardOU = "OU=Asgard Technologies,DC=asgard,DC=local"

# Create department OUs
New-ADOrganizationalUnit -Name "IT Operations" -Path $AsgardOU
New-ADOrganizationalUnit -Name "Cybersecurity" -Path $AsgardOU
New-ADOrganizationalUnit -Name "Research & Development" -Path $AsgardOU
New-ADOrganizationalUnit -Name "Finance & Administration" -Path $AsgardOU
New-ADOrganizationalUnit -Name "Human Resources" -Path $AsgardOU

# Create computer OUs
New-ADOrganizationalUnit -Name "Servers" -Path $AsgardOU
New-ADOrganizationalUnit -Name "Workstations" -Path $AsgardOU

# Create server computer accounts in Servers OU
$servers = @("ODIN-DC01", "FRIGG-DC02", "HEIMDALL-FS01", "BALDER-WEB01", "VIDAR-SEC01")
foreach ($server in $servers) {
    New-ADComputer -Name $server -Path "OU=Servers,$AsgardOU" -Description "Asgard Technologies Server" -Enabled $true
}

# Create sample workstation computer accounts in Workstations OU
$workstations = @(
    @{Name="ODIN-WS01"; Dept="IT Operations"; Description="Odin's Command Center"},
    @{Name="THOR-WS01"; Dept="IT Operations"; Description="Thor's Thunder Station"},
    @{Name="HEIMDALL-WS01"; Dept="Cybersecurity"; Description="Heimdall's Watchtower"},
    @{Name="MIMIR-WS01"; Dept="Cybersecurity"; Description="Mimir's Wisdom Terminal"},
    @{Name="FREYA-WS01"; Dept="Research & Development"; Description="Freya's Innovation Lab"},
    @{Name="NJORD-WS01"; Dept="Research & Development"; Description="Njord's Wind Tunnel"},
    @{Name="FRIGG-WS01"; Dept="Finance & Administration"; Description="Frigg's Treasury Terminal"},
    @{Name="EIR-WS01"; Dept="Finance & Administration"; Description="Eir's Healing Touch"},
    @{Name="SIF-WS01"; Dept="Human Resources"; Description="Sif's Golden Gateway"},
    @{Name="IDUN-WS01"; Dept="Human Resources"; Description="Idun's Eternal Garden"}
)
foreach ($ws in $workstations) {
    New-ADComputer -Name $ws.Name -Path "OU=$($ws.Dept),$AsgardOU" -Description $ws.Description -Enabled $true
}
```

### **Step 5.2: Create Security Groups**

```powershell
# [SERVER VM] - Run on ODIN-DC01 (Primary Domain Controller)
# EXECUTION CONTEXT: PowerShell session with Domain Administrator privileges on ODIN-DC01
# PREREQUISITES: Active Directory Domain Services installed and configured

# Department groups
New-ADGroup -Name "IT-Operations" -GroupScope Global -GroupCategory Security -Path "OU=IT Operations,$AsgardOU"
New-ADGroup -Name "Cybersecurity" -GroupScope Global -GroupCategory Security -Path "OU=Cybersecurity,$AsgardOU"
New-ADGroup -Name "Research-Development" -GroupScope Global -GroupCategory Security -Path "OU=Research & Development,$AsgardOU"
New-ADGroup -Name "Finance-Administration" -GroupScope Global -GroupCategory Security -Path "OU=Finance & Administration,$AsgardOU"
New-ADGroup -Name "Human-Resources" -GroupScope Global -GroupCategory Security -Path "OU=Human Resources,$AsgardOU"

# Functional groups
New-ADGroup -Name "Domain Admins - Asgard" -GroupScope Global -GroupCategory Security -Path $AsgardOU
New-ADGroup -Name "Server Administrators" -GroupScope Global -GroupCategory Security -Path $AsgardOU
New-ADGroup -Name "Workstation Users" -GroupScope Global -GroupCategory Security -Path $AsgardOU
```

### **Step 5.3: Create User Accounts**

#### **IT Operations Department**

```powershell
# [SERVER VM] - Run on ODIN-DC01 (Primary Domain Controller)  
# EXECUTION CONTEXT: PowerShell session with Domain Administrator privileges on ODIN-DC01
# PREREQUISITES: Active Directory OUs and groups created

$ITOperationsOU = "OU=IT Operations,$AsgardOU"
$SecurePassword = ConvertTo-SecureString "[ADMIN_MUST_SET_SECURE_PASSWORD]" -AsPlainText -Force

# Create users
New-ADUser -Name "Odin Allfather" -SamAccountName "odin.allfather" -UserPrincipalName "odin.allfather@asgard.local" -Path $ITOperationsOU -AccountPassword $SecurePassword -Enabled $true -ChangePasswordAtLogon $true -Title "CTO & Domain Admin" -Department "IT Operations"

New-ADUser -Name "Thor Thunderer" -SamAccountName "thor.thunderer" -UserPrincipalName "thor.thunderer@asgard.local" -Path $ITOperationsOU -AccountPassword $SecurePassword -Enabled $true -ChangePasswordAtLogon $true -Title "Senior Systems Engineer" -Department "IT Operations"

New-ADUser -Name "Loki Trickster" -SamAccountName "loki.trickster" -UserPrincipalName "loki.trickster@asgard.local" -Path $ITOperationsOU -AccountPassword $SecurePassword -Enabled $true -ChangePasswordAtLogon $true -Title "Junior Developer (Intern)" -Department "IT Operations"

New-ADUser -Name "Hermod Messenger" -SamAccountName "hermod.messenger" -UserPrincipalName "hermod.messenger@asgard.local" -Path $ITOperationsOU -AccountPassword $SecurePassword -Enabled $true -ChangePasswordAtLogon $true -Title "Network Administrator" -Department "IT Operations"

New-ADUser -Name "Tyr Brave" -SamAccountName "tyr.brave" -UserPrincipalName "tyr.brave@asgard.local" -Path $ITOperationsOU -AccountPassword $SecurePassword -Enabled $true -ChangePasswordAtLogon $true -Title "Security Analyst" -Department "IT Operations"

# Add to groups
Add-ADGroupMember -Identity "IT-Operations" -Members "odin.allfather", "thor.thunderer", "loki.trickster", "hermod.messenger", "tyr.brave"
Add-ADGroupMember -Identity "Domain Admins" -Members "odin.allfather"
```

#### **Continue for all departments...**

_Note: Due to space constraints, the full user creation script would continue with all 25 users across the 5 departments. The pattern remains consistent for each department._

---

## 🔧 **Phase 6: Services Configuration**

### **Step 6.1: Configure DNS**

On ODIN-DC01:

```powershell
# [SERVER VM] - Run on ODIN-DC01 (Primary Domain Controller)
# EXECUTION CONTEXT: PowerShell session with Domain Administrator privileges on ODIN-DC01  
# PREREQUISITES: DNS Server role installed, domain functional

# Create DNS zones for internal services
Add-DnsServerPrimaryZone -Name "services.asgard.local" -ZoneFile "services.asgard.local.dns" -DynamicUpdate Secure

# Add service records
Add-DnsServerResourceRecordA -ZoneName "asgard.local" -Name "fs01" -IPv4Address "10.0.10.20"
Add-DnsServerResourceRecordA -ZoneName "asgard.local" -Name "web01" -IPv4Address "10.0.10.30"
Add-DnsServerResourceRecordA -ZoneName "asgard.local" -Name "sec01" -IPv4Address "10.0.10.40"

# Create CNAME records
Add-DnsServerResourceRecordCName -ZoneName "asgard.local" -Name "fileserver" -HostNameAlias "fs01.asgard.local"
Add-DnsServerResourceRecordCName -ZoneName "asgard.local" -Name "webserver" -HostNameAlias "web01.asgard.local"
```

### **Step 6.2: Configure DHCP**

On ODIN-DC01:

```powershell
# [SERVER VM] - Run on ODIN-DC01 (Primary Domain Controller)
# EXECUTION CONTEXT: PowerShell session with Domain Administrator privileges on ODIN-DC01
# PREREQUISITES: Domain controller functional, network configured

# Install DHCP role
Install-WindowsFeature -Name DHCP -IncludeManagementTools

# Configure DHCP scopes
Add-DhcpServerV4Scope -Name "Client Network" -StartRange 10.0.20.100 -EndRange 10.0.23.200 -SubnetMask 255.255.252.0

# Set DHCP options
Set-DhcpServerV4OptionValue -ScopeId 10.0.20.0 -OptionId 3 -Value 10.0.20.1  # Default Gateway
Set-DhcpServerV4OptionValue -ScopeId 10.0.20.0 -OptionId 6 -Value 10.0.10.10  # DNS Server
Set-DhcpServerV4OptionValue -ScopeId 10.0.20.0 -OptionId 15 -Value "asgard.local"  # Domain Name

# Authorize DHCP server
Add-DhcpServerInDC -DnsName "odin-dc01.asgard.local"
```

---

## 📝 **Phase 7: Group Policy Configuration**

### **Step 7.1: Create Group Policy Objects**

```powershell
# Create GPOs for different purposes
New-GPO -Name "Asgard Workstation Policy" -Domain "asgard.local"
New-GPO -Name "Asgard Server Policy" -Domain "asgard.local"
New-GPO -Name "Asgard Security Policy" -Domain "asgard.local"

# Link GPOs to OUs
New-GPLink -Name "Asgard Workstation Policy" -Target "OU=Workstations,OU=Asgard Technologies,DC=asgard,DC=local"
New-GPLink -Name "Asgard Server Policy" -Target "OU=Servers,OU=Asgard Technologies,DC=asgard,DC=local"
```

### **Step 7.2: Configure Security Policies**

Example security settings:

```powershell
# Password policy
Set-ADDefaultDomainPasswordPolicy -Identity "asgard.local" -MinPasswordLength 8 -MaxPasswordAge 90 -MinPasswordAge 1 -PasswordHistoryCount 12

# Account lockout policy
Set-ADDefaultDomainPasswordPolicy -Identity "asgard.local" -LockoutDuration 30 -LockoutObservationWindow 30 -LockoutThreshold 5
```

---

## ✅ **Phase 8: Verification and Testing**

### **Step 8.1: Network Connectivity Tests**

```powershell
# Test from external machine or Proxmox VE host
Test-NetConnection -ComputerName "10.0.10.10" -Port 53  # DNS to ODIN-DC01
Test-NetConnection -ComputerName "10.0.10.20" -Port 445  # SMB to HEIMDALL-FS01
Test-NetConnection -ComputerName "10.0.10.30" -Port 80   # HTTP to BALDER-WEB01
```

### **Step 8.2: Active Directory Verification**

```powershell
# Verify AD structure
Get-ADOrganizationalUnit -Filter * | Select-Object Name, DistinguishedName
Get-ADUser -Filter * | Select-Object Name, SamAccountName, Department
Get-ADGroup -Filter * | Select-Object Name, GroupScope, GroupCategory
```

### **Step 8.3: Service Validation**

```powershell
# Check domain controller services
Get-Service -Name "ADWS", "DNS", "DHCP", "Netlogon", "KDC" | Select-Object Name, Status
```

---

## 🚀 **Phase 9: Client Configuration**

### **Step 9.1: Install and Configure Workstations**

For each workstation:

1. **Install Windows 10/11**
2. **Join to Domain**:

   ```powershell
   # [CLIENT VM] - Run on each workstation as Local Administrator
   # EXECUTION CONTEXT: PowerShell session with Local Administrator privileges on client workstation
   # PREREQUISITES: Windows 10/11 installed, network connectivity to domain controller
   
   Add-Computer -DomainName "asgard.local" -Credential (Get-Credential -UserName "odin.allfather" -Message "Enter domain credentials") -Restart
   ```

3. **Configure Network Settings**:
   - Use DHCP for IP configuration
   - Verify DNS resolution to `asgard.local`

### **Step 9.2: User Logon Testing**

Test user accounts:

- Log on to various workstations with created user accounts
- Verify group membership and permissions
- Test file share access ([Asgard Network Share Setup](Guides/ASGARD_NETWORK_SHARE_SETUP.md))
- Confirm Group Policy application

---

## 📊 **Phase 10: Monitoring and Maintenance**

### **Step 10.1: Set Up Basic Monitoring**

```powershell
# Enable audit policies
auditpol /set /category:"Logon/Logoff" /success:enable /failure:enable
auditpol /set /category:"Account Logon" /success:enable /failure:enable
auditpol /set /category:"Object Access" /success:enable /failure:enable
```

### **Step 10.2: Create Maintenance Scripts**

Create PowerShell scripts for regular maintenance:

- **Health checks** for all VMs
- **Backup verification**
- **Performance monitoring**
- **Event log analysis**

---

## 🎯 **Expected Results**

After completing this manual setup, you will have:

### **Infrastructure**

- ✅ **5 Servers**: Fully configured and domain-joined
- ✅ **20 Workstations**: Ready for user logon
- ✅ **4 Network Segments**: Properly isolated and configured
- ✅ **NAT Configuration**: Internet access for internal networks

### **Active Directory**

- ✅ **25 User Accounts**: Across 5 departments with realistic roles
- ✅ **Security Groups**: Department and functional groups
- ✅ **Organizational Units**: Logical AD structure
- ✅ **Group Policies**: Basic security and configuration policies

### **Services**

- ✅ **DNS**: Name resolution for internal services
- ✅ **DHCP**: Automatic IP configuration for clients
- ✅ **File Services**: Central file storage and sharing
- ✅ **Web Services**: IIS with basic websites
- ✅ **Security Services**: WSUS and monitoring

### **Network Architecture**

```
Production:  10.0.10.0/24  (Servers)
Management:  10.0.100.0/24 (Admin Access)
Clients:     10.0.20.0/22  (Workstations - 1022 addresses)
DMZ:         10.0.50.0/24  (External Services)
```

### **Key Server IPs**

```
ODIN-DC01:     10.0.10.10  (Primary DC)
FRIGG-DC02:    10.0.10.11  (Secondary DC)
HEIMDALL-FS01: 10.0.10.20  (File Server)
BALDER-WEB01:  10.0.10.30  (Web Server)
VIDAR-SEC01:   10.0.10.40  (Security Server)
```

---

## 🛠️ **Troubleshooting**

### **Common Issues and Solutions**

#### **Network Connectivity**

- **Issue**: VMs cannot reach internet
- **Solution**: Verify NAT configuration and external switch setup

#### **Domain Join Failures**

- **Issue**: Workstations cannot join domain
- **Solution**: Check DNS configuration and domain controller availability

#### **Performance Issues**

- **Issue**: Slow VM performance
- **Solution**: Adjust memory allocation, check host resources, use SSD storage

#### **Authentication Problems**

- **Issue**: Users cannot log on
- **Solution**: Verify user account status, check domain controller services

---

## 📚 **Next Steps**

After completing the basic setup:

1. **Implement advanced security policies**
2. **Configure backup and disaster recovery**
3. **Set up monitoring and alerting**
4. **Create custom applications and services**
5. **Implement certificate services**
6. **Configure VPN access**
7. **Set up additional sites and replication**

---

## 🏆 **Congratulations!**

You have successfully deployed the Asgard Technologies Windows Server lab environment manually. This setup provides a solid foundation for learning Windows Server administration, Active Directory management, and enterprise networking concepts.

The Norse mythology theme makes the learning experience engaging while providing realistic enterprise scenarios for hands-on practice.

**May the Allfather guide your Windows Server journey!** 🏰⚡
