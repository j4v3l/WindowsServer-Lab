# ⚡ **OLYMPUS SYSTEMS** - Manual Setup Guide

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

This manual setup guide provides step-by-step instructions for deploying the Olympus Systems Windows Server lab environment without using the automated deployment script. This approach gives you complete control over the installation process and allows for customization at each step.

**Olympus Systems** is the advanced Windows Server lab featuring Greek mythology themes, cloud integration, AI/ML capabilities, and comprehensive security controls.

---

## 🎯 **What You'll Build**

- **25 Virtual Machines** (5 servers + 20 workstations)
- **Greek Mythology Company**: Divine enterprise organization
- **Complete Domain Environment**: `olympus.local`
- **4 Network Segments**: Production, Management, Client, DMZ
- **25 User Accounts**: Across 5 divine departments
- **Advanced Security Suite**: 100+ enterprise security controls
- **Cloud Integration**: Hybrid cloud capabilities
- **AI/ML Development Environment**: Data science workloads

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
- **Azure CLI** (optional, for cloud integration via Windows VMs)

---

## 🚀 **Phase 1: Environment Preparation**

### **Step 1.1: Prepare Proxmox VE Environment**

```bash
# Create VMs using Proxmox VE web interface
# Follow the Proxmox setup guides for VM creation
# Ensure adequate resources are allocated:
# - Domain Controller: 8GB RAM, 4 vCPU, 80GB disk
# - File Server: 8GB RAM, 4 vCPU, 120GB disk
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
# - Optional: Ubuntu Server ISO (for AI/ML container host)
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

#### **AI/ML Network (Specialized)**

```bash
# Create bridge vmbr4 for AI/ML workloads
# Configure as high-performance bridge for data science VMs
# Optional: Configure with dedicated high-speed network interface
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

### **Step 3.1: Create Primary Domain Controller (ZEUS-DC01)**

#### **Create VM using Proxmox VE Web Interface**

1. **Navigate to**: Datacenter > [Node] > Create VM
2. **General Tab**:
   - VM ID: 200
   - Name: ZEUS-DC01
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

#### **Or via Command Line**

```bash
# Create Zeus DC01 VM using Proxmox CLI
qm create 200 \
  --name "ZEUS-DC01" \
  --memory 8192 \
  --cores 4 \
  --cpu host \
  --machine q35 \
  --bios ovmf \
  --efidisk0 local-lvm:4 \
  --scsi0 local-lvm:80,cache=writeback,discard=on \
  --scsihw virtio-scsi-single \
  --net0 virtio,bridge=vmbr0 \
  --net1 virtio,bridge=vmbr1 \
  --ide2 local:iso/WindowsServer2022.iso,media=cdrom \
  --ide0 local:iso/virtio-win.iso,media=cdrom \
  --ostype win10 \
  --agent 1
```

#### **Promote to Domain Controller**

```powershell
# [SERVER VM] - Run on ZEUS-DC01 after Windows Server installation
# EXECUTION CONTEXT: PowerShell session with Administrator privileges on ZEUS-DC01
# PREREQUISITES: Windows Server installed, network configured, system updated

Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
Import-Module ADDSDeployment

$DomainName = "olympus.local"
$SafeModePassword = ConvertTo-SecureString "[ADMIN_MUST_SET_SECURE_PASSWORD]" -AsPlainText -Force

Install-ADDSForest `
    -CreateDnsDelegation:$false `
    -DatabasePath "C:\Windows\NTDS" `
    -DomainMode "WinThreshold" `
    -DomainName $DomainName `
    -DomainNetbiosName "OLYMPUS" `
    -ForestMode "WinThreshold" `
    -InstallDns:$true `
    -LogPath "C:\Windows\NTDS" `
    -NoRebootOnCompletion:$false `
    -SysvolPath "C:\Windows\SYSVOL" `
    -SafeModeAdministratorPassword $SafeModePassword `
    -Force:$true
```

### **Step 3.2: Create Secondary Domain Controller (HERA-DC02)**

#### **Create VM using Proxmox VE Web Interface**

1. **Navigate to**: Datacenter > [Node] > Create VM
2. **VM Configuration**:
   - VM ID: 201
   - Name: HERA-DC02
   - Memory: 6144 MB
   - CPU Cores: 3
   - Disk: 60 GB
   - Network: vmbr0 (Production) + vmbr1 (Management)

3. **Or via Command Line**:

   ```bash
   # [PROXMOX HOST] - Create Hera DC02 VM using Proxmox CLI
   # EXECUTION CONTEXT: SSH session to Proxmox VE host with root privileges
   # PREREQUISITES: ISO files uploaded, storage configured, network bridges created
   
   qm create 201 \
     --name "HERA-DC02" \
     --memory 6144 \
     --cores 3 \
     --cpu host \
     --machine q35 \
     --bios ovmf \
     --efidisk0 local-lvm:4 \
     --scsi0 local-lvm:60,cache=writeback,discard=on \
     --scsihw virtio-scsi-single \
     --net0 virtio,bridge=vmbr0 \
     --net1 virtio,bridge=vmbr1 \
     --ide2 local:iso/WindowsServer2022.iso,media=cdrom \
     --ide0 local:iso/virtio-win.iso,media=cdrom \
     --ostype win10 \
     --agent 1
   ```

### **Step 3.3: Create File Server (HERMES-FS01)**

#### **Create VM using Proxmox VE Web Interface**

1. **Navigate to**: Datacenter > [Node] > Create VM
2. **VM Configuration**:
   - VM ID: 202
   - Name: HERMES-FS01
   - Memory: 8192 MB
   - CPU Cores: 4
   - Disk: 120 GB
   - Network: vmbr0 (Production) + vmbr1 (Management)

3. **Or via Command Line**:

   ```bash
   # [PROXMOX HOST] - Create file server VM using Proxmox CLI  
   # EXECUTION CONTEXT: SSH session to Proxmox VE host with root privileges
   # PREREQUISITES: ISO files uploaded, storage configured, network bridges created
   
   qm create 202 \
     --name "HERMES-FS01" \
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

### **Step 3.4: Create Web Server (APOLLO-WEB01)**

#### **Create VM using Proxmox VE Web Interface**

1. **Navigate to**: Datacenter > [Node] > Create VM
2. **VM Configuration**:
   - VM ID: 203
   - Name: APOLLO-WEB01
   - Memory: 6144 MB
   - CPU Cores: 3
   - Disk: 80 GB
   - Network: vmbr0 (Production) + vmbr1 (Management) + vmbr3 (DMZ)

3. **Or via Command Line**:

   ```bash
   # [PROXMOX HOST] - Create web server VM with DMZ access
   # EXECUTION CONTEXT: SSH session to Proxmox VE host with root privileges  
   # PREREQUISITES: ISO files uploaded, network bridges vmbr0, vmbr1, vmbr3 created
   
   qm create 203 \
     --name "APOLLO-WEB01" \
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

### **Step 3.5: Create Security Server (ATHENA-SEC01)**

#### **Create VM using Proxmox VE Web Interface**

1. **Navigate to**: Datacenter > [Node] > Create VM
2. **VM Configuration**:
   - VM ID: 204
   - Name: ATHENA-SEC01
   - Memory: 8192 MB
   - CPU Cores: 4
   - Disk: 100 GB
   - Network: vmbr0 (Production) + vmbr1 (Management)

3. **Or via Command Line**:

   ```bash
   # [PROXMOX HOST] - Create security server VM
   # EXECUTION CONTEXT: SSH session to Proxmox VE host with root privileges
   # PREREQUISITES: ISO files uploaded, network bridges vmbr0, vmbr1 created
   
   qm create 204 \
     --name "ATHENA-SEC01" \
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

---

## 💻 **Phase 4: Workstation Deployment**

### **Step 4.1: Create Workstation Template**

#### **Workstation VM Template (via Proxmox VE)**

All workstations will follow this template configuration:

```bash
# [PROXMOX HOST] - Template for creating Olympus workstations  
# EXECUTION CONTEXT: SSH session to Proxmox VE host with root privileges
# VM IDs: 210-229 (20 workstations)
# Standard configuration:
# - Memory: 4096 MB (adjustable per workstation)
# - CPU: 2 cores (adjustable per workstation)
# - Disk: 60 GB (adjustable per workstation)
# - Network: vmbr2 (Client network) or vmbr4 (AI/ML network for R&D)
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

### **Step 4.2: Create Divine Council Workstations (IT Operations)**

```bash
# Create IT Operations workstations via Proxmox VE

# ZEUS-WS01 (Supreme Command Center)
qm create 210 \
  --name "ZEUS-WS01" \
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

# POSEIDON-WS01 (Ocean Terminal)
qm create 211 \
  --name "POSEIDON-WS01" \
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

# HADES-WS01 (Underworld Station)
qm create 212 \
  --name "HADES-WS01" \
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

# HERMES-WS01 (Swift Messenger)
qm create 213 \
  --name "HERMES-WS01" \
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

# DIONYSUS-WS01 (Creative Studio)
qm create 214 \
  --name "DIONYSUS-WS01" \
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

### **Step 4.3: Create War Strategists Workstations (Cybersecurity)**

```bash
# Create Cybersecurity workstations via Proxmox VE

# ATHENA-WS01 (Wisdom Tower)
qm create 215 \
  --name "ATHENA-WS01" \
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

# ARES-WS01 (War Room)
qm create 216 \
  --name "ARES-WS01" \
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

# NIKE-WS01 (Victory Terminal)
qm create 217 \
  --name "NIKE-WS01" \
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

# KRATOS-WS01 (Strength Station)
qm create 218 \
  --name "KRATOS-WS01" \
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

# BIA-WS01 (Force Platform)
qm create 219 \
  --name "BIA-WS01" \
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

### **Step 4.4: Create Innovation Forge Workstations (R&D)**

```bash
# Create R&D workstations via Proxmox VE with AI/ML network access

# APOLLO-WS01 (Light Laboratory)
qm create 220 \
  --name "APOLLO-WS01" \
  --memory 6144 \
  --cores 4 \
  --cpu host \
  --machine q35 \
  --bios ovmf \
  --efidisk0 local-lvm:4 \
  --scsi0 local-lvm:100,cache=writeback,discard=on \
  --scsihw virtio-scsi-single \
  --net0 virtio,bridge=vmbr4 \
  --ide2 local:iso/Windows11.iso,media=cdrom \
  --ide0 local:iso/virtio-win.iso,media=cdrom \
  --ostype win10 \
  --agent 1

# ARTEMIS-WS01 (Hunt Station)
qm create 221 \
  --name "ARTEMIS-WS01" \
  --memory 4096 \
  --cores 2 \
  --cpu host \
  --machine q35 \
  --bios ovmf \
  --efidisk0 local-lvm:4 \
  --scsi0 local-lvm:80,cache=writeback,discard=on \
  --scsihw virtio-scsi-single \
  --net0 virtio,bridge=vmbr4 \
  --ide2 local:iso/Windows11.iso,media=cdrom \
  --ide0 local:iso/virtio-win.iso,media=cdrom \
  --ostype win10 \
  --agent 1

# HEPHAESTUS-WS01 (Forge)
qm create 222 \
  --name "HEPHAESTUS-WS01" \
  --memory 4096 \
  --cores 2 \
  --cpu host \
  --machine q35 \
  --bios ovmf \
  --efidisk0 local-lvm:4 \
  --scsi0 local-lvm:80,cache=writeback,discard=on \
  --scsihw virtio-scsi-single \
  --net0 virtio,bridge=vmbr4 \
  --ide2 local:iso/Windows11.iso,media=cdrom \
  --ide0 local:iso/virtio-win.iso,media=cdrom \
  --ostype win10 \
  --agent 1
# PROMETHEUS-WS01 (Fire Terminal)
qm create 223 \
  --name "PROMETHEUS-WS01" \
  --memory 4096 \
  --cores 2 \
  --cpu host \
  --machine q35 \
  --bios ovmf \
  --efidisk0 local-lvm:4 \
  --scsi0 local-lvm:80,cache=writeback,discard=on \
  --scsihw virtio-scsi-single \
  --net0 virtio,bridge=vmbr4 \
  --ide2 local:iso/Windows11.iso,media=cdrom \
  --ide0 local:iso/virtio-win.iso,media=cdrom \
  --ostype win10 \
  --agent 1

# DAEDALUS-WS01 (Craft Studio)
qm create 224 \
  --name "DAEDALUS-WS01" \
  --memory 4096 \
  --cores 2 \
  --cpu host \
  --machine q35 \
  --bios ovmf \
  --efidisk0 local-lvm:4 \
  --scsi0 local-lvm:80,cache=writeback,discard=on \
  --scsihw virtio-scsi-single \
  --net0 virtio,bridge=vmbr4 \
  --ide2 local:iso/Windows11.iso,media=cdrom \
  --ide0 local:iso/virtio-win.iso,media=cdrom \
  --ostype win10 \
  --agent 1
```

### **Step 4.5: Create Abundance Treasury Workstations (Finance)**

```bash
# Create Finance & Administration workstations via Proxmox VE

# HERA-WS01 (Queen Station)
qm create 225 \
  --name "HERA-WS01" \
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

# DEMETER-WS01 (Harvest Terminal)
qm create 226 \
  --name "DEMETER-WS01" \
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

# PLUTUS-WS01 (Wealth Engine)
qm create 227 \
  --name "PLUTUS-WS01" \
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

# TYCHE-WS01 (Fortune Analyzer)
qm create 228 \
  --name "TYCHE-WS01" \
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

# NEMESIS-WS01 (Balance Scale)
qm create 229 \
  --name "NEMESIS-WS01" \
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

### **Step 4.6: Create Harmony Relations Workstations (HR)**

```bash
# Create Human Resources workstations via Proxmox VE

# APHRODITE-WS01 (Harmony Hub)
qm create 230 \
  --name "APHRODITE-WS01" \
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

# EROS-WS01 (Love Portal)
qm create 231 \
  --name "EROS-WS01" \
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

# PSYCHE-WS01 (Soul Station)
qm create 232 \
  --name "PSYCHE-WS01" \
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

# HARMONIA-WS01 (Peace Terminal)
qm create 233 \
  --name "HARMONIA-WS01" \
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

# IRIS-WS01 (Rainbow Bridge)
qm create 234 \
  --name "IRIS-WS01" \
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

### **Step 5.1: Create Organizational Structure**

Run on ZEUS-DC01:

```powershell
Import-Module ActiveDirectory

# Create main OU structure
New-ADOrganizationalUnit -Name "Olympus Systems" -Path "DC=olympus,DC=local"
$OlympusOU = "OU=Olympus Systems,DC=olympus,DC=local"

# Create department OUs
New-ADOrganizationalUnit -Name "Divine Council" -Path $OlympusOU
New-ADOrganizationalUnit -Name "War Strategists" -Path $OlympusOU
New-ADOrganizationalUnit -Name "Innovation Forge" -Path $OlympusOU
New-ADOrganizationalUnit -Name "Abundance Treasury" -Path $OlympusOU
New-ADOrganizationalUnit -Name "Harmony Relations" -Path $OlympusOU

# Create computer OUs
New-ADOrganizationalUnit -Name "Servers" -Path $OlympusOU
New-ADOrganizationalUnit -Name "Workstations" -Path $OlympusOU

# Create server computer accounts in Servers OU
$servers = @("ZEUS-DC01", "HERA-DC02", "HERMES-FS01", "APOLLO-WEB01", "ATHENA-SEC01")
foreach ($server in $servers) {
    New-ADComputer -Name $server -Path "OU=Servers,$OlympusOU" -Description "Olympus Systems Server" -Enabled $true
}

# Create sample workstation computer accounts in Workstations OU
$workstations = @(
    @{Name="ZEUS-WS01"; Dept="Divine Council"; Description="Zeus Supreme Command Center"},
    @{Name="POSEIDON-WS01"; Dept="Divine Council"; Description="Poseidon's Ocean Terminal"},
    @{Name="ATHENA-WS01"; Dept="War Strategists"; Description="Athena's Wisdom Tower"},
    @{Name="ARES-WS01"; Dept="War Strategists"; Description="Ares' War Room"},
    @{Name="APOLLO-WS01"; Dept="Innovation Forge"; Description="Apollo's Light Laboratory"},
    @{Name="ARTEMIS-WS01"; Dept="Innovation Forge"; Description="Artemis' Hunt Station"},
    @{Name="HERA-WS01"; Dept="Abundance Treasury"; Description="Hera's Queen Station"},
    @{Name="DEMETER-WS01"; Dept="Abundance Treasury"; Description="Demeter's Harvest Terminal"},
    @{Name="APHRODITE-WS01"; Dept="Harmony Relations"; Description="Aphrodite's Harmony Hub"},
    @{Name="EROS-WS01"; Dept="Harmony Relations"; Description="Eros' Love Portal"}
)
foreach ($ws in $workstations) {
    New-ADComputer -Name $ws.Name -Path "OU=$($ws.Dept),$OlympusOU" -Description $ws.Description -Enabled $true
}
```

### **Step 5.2: Create Security Groups**

```powershell
# Department groups
New-ADGroup -Name "Divine-Council" -GroupScope Global -GroupCategory Security -Path "OU=Divine Council,$OlympusOU"
New-ADGroup -Name "War-Strategists" -GroupScope Global -GroupCategory Security -Path "OU=War Strategists,$OlympusOU"
New-ADGroup -Name "Innovation-Forge" -GroupScope Global -GroupCategory Security -Path "OU=Innovation Forge,$OlympusOU"
New-ADGroup -Name "Abundance-Treasury" -GroupScope Global -GroupCategory Security -Path "OU=Abundance Treasury,$OlympusOU"
New-ADGroup -Name "Harmony-Relations" -GroupScope Global -GroupCategory Security -Path "OU=Harmony Relations,$OlympusOU"

# Advanced security groups
New-ADGroup -Name "AI-ML-Developers" -GroupScope Global -GroupCategory Security -Path $OlympusOU
New-ADGroup -Name "Cloud-Administrators" -GroupScope Global -GroupCategory Security -Path $OlympusOU
New-ADGroup -Name "Security-Auditors" -GroupScope Global -GroupCategory Security -Path $OlympusOU
```

### **Step 5.3: Create Divine User Accounts**

#### **Divine Council (IT Operations)**

```powershell
$DivineCouncilOU = "OU=Divine Council,$OlympusOU"
$SecurePassword = ConvertTo-SecureString "[ADMIN_MUST_SET_SECURE_PASSWORD]" -AsPlainText -Force

# Create divine users
New-ADUser -Name "Zeus Supreme" -SamAccountName "zeus.supreme" -UserPrincipalName "zeus.supreme@olympus.local" -Path $DivineCouncilOU -AccountPassword $SecurePassword -Enabled $true -ChangePasswordAtLogon $true -Title "CEO & Domain Admin" -Department "Divine Council"

New-ADUser -Name "Poseidon Seas" -SamAccountName "poseidon.seas" -UserPrincipalName "poseidon.seas@olympus.local" -Path $DivineCouncilOU -AccountPassword $SecurePassword -Enabled $true -ChangePasswordAtLogon $true -Title "Senior Systems Engineer" -Department "Divine Council"

New-ADUser -Name "Hades Underworld" -SamAccountName "hades.underworld" -UserPrincipalName "hades.underworld@olympus.local" -Path $DivineCouncilOU -AccountPassword $SecurePassword -Enabled $true -ChangePasswordAtLogon $true -Title "Database Administrator" -Department "Divine Council"

New-ADUser -Name "Hermes Messenger" -SamAccountName "hermes.messenger" -UserPrincipalName "hermes.messenger@olympus.local" -Path $DivineCouncilOU -AccountPassword $SecurePassword -Enabled $true -ChangePasswordAtLogon $true -Title "Network Administrator" -Department "Divine Council"

New-ADUser -Name "Dionysus Wine" -SamAccountName "dionysus.wine" -UserPrincipalName "dionysus.wine@olympus.local" -Path $DivineCouncilOU -AccountPassword $SecurePassword -Enabled $true -ChangePasswordAtLogon $true -Title "Junior Developer" -Department "Divine Council"

# Add to groups
Add-ADGroupMember -Identity "Divine-Council" -Members "zeus.supreme", "poseidon.seas", "hades.underworld", "hermes.messenger", "dionysus.wine"
Add-ADGroupMember -Identity "Domain Admins" -Members "zeus.supreme"
```

---

## 🛡️ **Phase 6: Advanced Security Configuration**

### **Step 6.1: Advanced Group Policy Objects**

```powershell
# Create advanced security GPOs
New-GPO -Name "Olympus Advanced Security Policy" -Domain "olympus.local"
New-GPO -Name "Olympus Camera and Microphone Controls" -Domain "olympus.local"
New-GPO -Name "Olympus USB and Storage Security" -Domain "olympus.local"
New-GPO -Name "Olympus Application Control" -Domain "olympus.local"
New-GPO -Name "Olympus Network Security" -Domain "olympus.local"

# Link to workstations OU
New-GPLink -Name "Olympus Advanced Security Policy" -Target "OU=Workstations,$OlympusOU"
```

### **Step 6.2: Camera and Microphone Security**

```powershell
# Configure camera access restrictions
$GPO = Get-GPO -Name "Olympus Camera and Microphone Controls"
# Configure through Group Policy Management Console or PowerShell DSC
```

### **Step 6.3: USB and Storage Device Controls**

```powershell
# Create USB restriction policies
# Configure through Group Policy or PowerShell DSC for granular device control
```

---

## ☁️ **Phase 7: Cloud Integration Setup**

### **Step 7.1: Azure Hybrid Configuration**

```powershell
# Install Azure AD Connect prerequisites
# This would be configured on ZEUS-DC01 for hybrid cloud integration
Install-WindowsFeature -Name NET-Framework-45-Features
```

### **Step 7.2: AI/ML Development Environment**

```powershell
# Create AI/ML development shares
New-SmbShare -Name "AI-DataSets" -Path "C:\AI-ML\DataSets" -FullAccess "Innovation-Forge"
New-SmbShare -Name "ML-Models" -Path "C:\AI-ML\Models" -FullAccess "Innovation-Forge"

# For comprehensive network share setup instructions, see:
# Olympus/Guides/OLYMPUS_NETWORK_SHARE_SETUP.md
```

---

## 🔧 **Phase 8: Services Configuration**

### **Step 8.1: Configure DNS with Advanced Zones**

```powershell
# Create DNS zones for cloud services
Add-DnsServerPrimaryZone -Name "cloud.olympus.local" -ZoneFile "cloud.olympus.local.dns" -DynamicUpdate Secure
Add-DnsServerPrimaryZone -Name "ai.olympus.local" -ZoneFile "ai.olympus.local.dns" -DynamicUpdate Secure

# Add service records
Add-DnsServerResourceRecordA -ZoneName "olympus.local" -Name "fs01" -IPv4Address "10.0.10.20"
Add-DnsServerResourceRecordA -ZoneName "olympus.local" -Name "web01" -IPv4Address "10.0.10.30"
Add-DnsServerResourceRecordA -ZoneName "olympus.local" -Name "sec01" -IPv4Address "10.0.10.40"
```

### **Step 8.2: Configure Enhanced DHCP**

```powershell
# Install and configure DHCP with advanced options
Install-WindowsFeature -Name DHCP -IncludeManagementTools

# Configure scopes with advanced options
Add-DhcpServerV4Scope -Name "Divine Client Network" -StartRange 10.0.20.100 -EndRange 10.0.23.200 -SubnetMask 255.255.252.0

# Set advanced DHCP options
Set-DhcpServerV4OptionValue -ScopeId 10.0.20.0 -OptionId 3 -Value 10.0.20.1  # Gateway
Set-DhcpServerV4OptionValue -ScopeId 10.0.20.0 -OptionId 6 -Value 10.0.10.10  # DNS
Set-DhcpServerV4OptionValue -ScopeId 10.0.20.0 -OptionId 15 -Value "olympus.local"  # Domain
Set-DhcpServerV4OptionValue -ScopeId 10.0.20.0 -OptionId 44 -Value 10.0.10.10  # WINS

# Authorize DHCP server
Add-DhcpServerInDC -DnsName "zeus-dc01.olympus.local"
```

---

## 📊 **Phase 9: Monitoring and Security Auditing**

### **Step 9.1: Advanced Audit Configuration**

```powershell
# Enable comprehensive auditing
auditpol /set /category:"Logon/Logoff" /success:enable /failure:enable
auditpol /set /category:"Account Logon" /success:enable /failure:enable
auditpol /set /category:"Object Access" /success:enable /failure:enable
auditpol /set /category:"Privilege Use" /success:enable /failure:enable
auditpol /set /category:"Detailed Tracking" /success:enable /failure:enable
auditpol /set /category:"Policy Change" /success:enable /failure:enable
auditpol /set /category:"Account Management" /success:enable /failure:enable
auditpol /set /category:"DS Access" /success:enable /failure:enable
auditpol /set /category:"System" /success:enable /failure:enable
```

### **Step 9.2: Security Scoring System**

```powershell
# Create security assessment script
$SecurityScore = @{
    "Password Policy" = 0
    "Account Lockout" = 0
    "Audit Policy" = 0
    "User Rights" = 0
    "Security Options" = 0
    "File Permissions" = 0
    "Network Security" = 0
    "Device Control" = 0
}

# Implement scoring logic for 100+ security controls
```

---

## ✅ **Phase 10: Verification and Testing**

### **Step 10.1: Comprehensive Testing Suite**

```powershell
# Network connectivity tests
Test-NetConnection -ComputerName "10.0.10.10" -Port 53   # DNS
Test-NetConnection -ComputerName "10.0.10.20" -Port 445  # SMB
Test-NetConnection -ComputerName "10.0.10.30" -Port 80   # HTTP
Test-NetConnection -ComputerName "10.0.10.40" -Port 443  # HTTPS

# Domain services verification
Get-Service -Name "ADWS", "DNS", "DHCP", "Netlogon", "KDC" | Select-Object Name, Status

# Advanced security testing
# Test camera access controls
# Test USB device restrictions
# Test application controls
# Test network security policies
```

---

## 🎯 **Expected Results**

After completing this manual setup, you will have:

### **Divine Infrastructure**

- ✅ **5 Servers**: ZEUS-DC01, HERA-DC02, HERMES-FS01, APOLLO-WEB01, ATHENA-SEC01
- ✅ **20 Workstations**: Divine workstations across 5 departments
- ✅ **4 Network Segments**: Production, Management, Client, DMZ
- ✅ **Advanced Security**: 100+ enterprise security controls

### **Greek Mythology Organization**

- ✅ **25 Divine Users**: Zeus, Athena, Apollo, Hermes, and more
- ✅ **5 Divine Departments**: Each with specialized roles
- ✅ **Security Groups**: Advanced permission management
- ✅ **Organizational Units**: Logical divine structure

### **Advanced Features**

- ✅ **Cloud Integration**: Hybrid cloud capabilities
- ✅ **AI/ML Environment**: Data science and machine learning workloads
- ✅ **Advanced Security Suite**: Camera, USB, application controls
- ✅ **Comprehensive Auditing**: 100+ security controls with scoring

### **Network Architecture**

```
Production:  10.0.10.0/24  (Divine Servers)
Management:  10.0.100.0/24 (Divine Admin Access)
Clients:     10.0.20.0/22  (Divine Workstations)
DMZ:         10.0.50.0/24  (External Divine Services)
```

---

## 🏆 **Congratulations!**

You have successfully deployed the Olympus Systems Windows Server lab environment manually. This divine setup provides:

- **Advanced Windows Server capabilities** with cloud integration
- **Comprehensive security controls** with auditing and scoring
- **AI/ML development environment** for modern workloads
- **Greek mythology theme** making learning engaging and memorable

**May the Gods of Olympus guide your divine Windows Server journey!** ⚡🏛️

---

## 🛠️ **Advanced Troubleshooting**

### **Cloud Integration Issues**

- Verify Azure AD Connect prerequisites
- Check hybrid cloud network connectivity
- Validate certificates and authentication

### **AI/ML Environment Problems**

- Verify GPU drivers and CUDA installation
- Check data science tool compatibility
- Validate ML model deployment pipelines

### **Advanced Security Controls**

- Test camera and microphone policies
- Verify USB device restrictions
- Check application control policies
- Validate network security settings

---

## 📚 **Advanced Next Steps**

1. **Implement Azure Arc** for hybrid cloud management
2. **Deploy machine learning pipelines** with Azure ML
3. **Configure advanced threat protection** with Windows Defender ATP
4. **Set up zero-trust networking** with conditional access
5. **Implement DevOps pipelines** with Azure DevOps
6. **Configure advanced analytics** with Power BI integration
7. **Deploy containerized applications** with Docker and Kubernetes
