# 🎯 Execution Context Guide - What Runs Where?

## 📋 Overview

This guide provides a comprehensive breakdown of **execution contexts** for all scripts, commands, and procedures in the Windows Server Lab Environment. Understanding where each component runs is critical for successful deployment and management.

## 🏗️ Infrastructure Architecture

```
┌─────────────────────────────────────────────────┐
│                Proxmox VE Host                  │
│  ┌─────────────────────────────────────────────┐│
│  │           Host Commands                     ││
│  │  • qm create/start/stop/destroy             ││
│  │  • pvesh get /nodes/<node>/status           ││
│  │  • vzdump (backup commands)                 ││
│  │  • Network bridge configuration             ││
│  │  • Storage management                       ││
│  └─────────────────────────────────────────────┘│
│  ┌─────────────────┐ ┌─────────────────┐        │
│  │   Windows VM    │ │   Windows VM    │        │
│  │     DC01        │ │     FS01        │        │
│  │ ┌─────────────┐ │ │ ┌─────────────┐ │        │
│  │ │PowerShell   │ │ │ │PowerShell   │ │        │
│  │ │Scripts      │ │ │ │Scripts      │ │        │
│  │ │• AD Config  │ │ │ │• File Shares│ │        │
│  │ │• GPO Mgmt   │ │ │ │• DHCP Setup │ │        │
│  │ │• User Mgmt  │ │ │ │• Monitoring │ │        │
│  │ └─────────────┘ │ │ └─────────────┘ │        │
│  └─────────────────┘ └─────────────────┘        │
└─────────────────────────────────────────────────┘
```

---

## 🖥️ Proxmox VE Host Commands

### **Where**: Proxmox VE Host (Debian Linux)

### **Access**: SSH to Proxmox host or web interface shell

#### **VM Lifecycle Management**

```bash
# VM Creation (Run on Proxmox host)
qm create 100 \
  --name "DC1-LAB" \
  --memory 4096 \
  --cores 4 \
  --cpu host \
  --machine q35 \
  --bios ovmf \
  --efidisk0 local-lvm:4 \
  --scsi0 local-lvm:80,cache=writeback,discard=on \
  --scsihw virtio-scsi-single \
  --net0 virtio,bridge=vmbr1 \
  --net1 virtio,bridge=vmbr2 \
  --ide2 local:iso/WindowsServer2022.iso,media=cdrom \
  --ide0 local:iso/virtio-win.iso,media=cdrom \
  --ostype win10 \
  --agent 1

# VM Operations (Run on Proxmox host)
qm start 100              # Start VM
qm stop 100               # Stop VM
qm restart 100            # Restart VM
qm status 100             # Check VM status
qm list                   # List all VMs
qm destroy 100            # Delete VM (careful!)

# VM Configuration (Run on Proxmox host)
qm set 100 --memory 8192                    # Change memory
qm set 100 --cores 6                        # Change CPU cores
qm set 100 --cpu host,flags=+aes            # Optimize CPU
qm set 100 --balloon 4096                   # Enable memory ballooning
qm set 100 --hostpci0 01:00,pcie=1         # GPU passthrough

# Snapshot Management (Run on Proxmox host)
qm snapshot 100 pre-update                  # Create snapshot
qm listsnapshot 100                         # List snapshots
qm rollback 100 pre-update                  # Restore snapshot
qm delsnapshot 100 pre-update              # Delete snapshot
```

#### **Network Management**

```bash
# Network Configuration (Run on Proxmox host)
# Edit /etc/network/interfaces for bridge configuration

# Bridge Operations
brctl show                                   # Show bridge status
ip link show                                 # Show network interfaces
systemctl restart networking                # Restart networking

# Firewall Management
pve-firewall status                         # Check firewall status
# Configure via web interface: Datacenter → Firewall
```

#### **Storage Management**

```bash
# Storage Operations (Run on Proxmox host)
pvesm status                                # Show storage status
pvesm list                                  # List storage content
df -h                                       # Check disk usage
lvdisplay                                   # Show LVM volumes

# Backup Operations
vzdump 100 --storage local --compress gzip  # Backup VM
vzdump --all --storage backup               # Backup all VMs
```

#### **System Monitoring**

```bash
# Host Monitoring (Run on Proxmox host)
pvesh get /nodes/$(hostname)/status        # Node status
pvesh get /cluster/resources               # Cluster resources
htop                                       # System performance
iotop                                      # I/O monitoring
```

---

## 💻 Windows VM Commands

### **Where**: Inside Windows Server VMs

### **Access**: RDP, Console, or PowerShell Direct

#### **Active Directory Configuration**

```powershell
# Domain Controller Setup (Run inside Windows Server VM)
# Location: Domain Controller VM (DC01, ODIN-DC01, ZEUS-DC01)

Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

# Promote to Domain Controller
Install-ADDSForest `
  -DomainName "lab.local" `
  -DomainNetbiosName "LAB" `
  -ForestMode "WinThreshold" `
  -DomainMode "WinThreshold" `
  -DatabasePath "C:\Windows\NTDS" `
  -LogPath "C:\Windows\NTDS" `
  -SysvolPath "C:\Windows\SYSVOL" `
  -InstallDns:$true `
  -CreateDnsDelegation:$false `
  -NoRebootOnCompletion:$false `
  -Force:$true
```

#### **User and Group Management**

```powershell
# User Creation (Run inside Domain Controller VM)
Import-Module ActiveDirectory

New-ADUser -Name "John Smith" `
  -GivenName "John" `
  -Surname "Smith" `
  -SamAccountName "john.smith" `
  -UserPrincipalName "john.smith@lab.local" `
  -Path "OU=Users,DC=lab,DC=local" `
  -AccountPassword (ConvertTo-SecureString "P@ssw0rd123!" -AsPlainText -Force) `
  -Enabled $true `
  -ChangePasswordAtLogon $true
```

#### **Group Policy Management**

```powershell
# GPO Creation and Management (Run inside Domain Controller VM)
Import-Module GroupPolicy

New-GPO -Name "Security Policy" -Comment "Lab security settings"
Set-GPRegistryValue -Name "Security Policy" `
  -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" `
  -ValueName "NoAutoUpdate" `
  -Type DWord `
  -Value 1

New-GPLink -Name "Security Policy" -Target "OU=Computers,DC=lab,DC=local"
```

#### **File Server Configuration**

```powershell
# File Server Setup (Run inside File Server VM)
# Location: File Server VM (FS01, HEIMDALL-FS01, HERMES-FS01)

Install-WindowsFeature -Name File-Services -IncludeManagementTools
Install-WindowsFeature -Name FS-FileServer -IncludeManagementTools
Install-WindowsFeature -Name FS-DFS-Namespace -IncludeManagementTools
Install-WindowsFeature -Name FS-DFS-Replication -IncludeManagementTools

# Create File Shares
New-Item -Path "C:\Shares\IT" -ItemType Directory -Force
New-SmbShare -Name "IT" -Path "C:\Shares\IT" -FullAccess "LAB\Domain Admins"
```

#### **DHCP Server Configuration**

```powershell
# DHCP Setup (Run inside DHCP Server VM or Domain Controller)
Install-WindowsFeature -Name DHCP -IncludeManagementTools

Add-DhcpServerv4Scope `
  -Name "Lab Network" `
  -StartRange "192.168.1.100" `
  -EndRange "192.168.1.200" `
  -SubnetMask "255.255.255.0" `
  -LeaseDuration "8.00:00:00"

Set-DhcpServerv4OptionValue `
  -ScopeId "192.168.1.0" `
  -Router "192.168.1.1" `
  -DnsServer "192.168.1.10"
```

---

## 📁 Script Execution Matrix

| Script Name | Execution Location | Purpose | Prerequisites |
|-------------|-------------------|---------|---------------|
| **Proxmox VE Commands** | | | |
| `qm create/start/stop` | Proxmox Host | VM lifecycle management | SSH access to Proxmox |
| `pvesh get` | Proxmox Host | System monitoring | Proxmox CLI access |
| `vzdump` | Proxmox Host | VM backup operations | Storage configuration |
| **Windows VM Scripts** | | | |
| `Lab-FinishSetup.ps1` | Domain Controller VM | Complete lab setup | Domain Admin rights |
| `Create-LabUsers.ps1` | Domain Controller VM | User account creation | AD PowerShell module |
| `GroupPolicyManager.ps1` | Domain Controller VM | GPO management | Group Policy module |
| `AdvancedSecurityAudit.ps1` | Any Windows VM | Security assessment | Local Admin rights |
| `SystemHealthMonitor.ps1` | Any Windows VM | Health monitoring | Performance counters |
| `BackupRestoreManager.ps1` | File Server VM | Backup operations | Backup feature installed |
| `DHCP_Setup.ps1` | DHCP Server VM | DHCP configuration | DHCP feature installed |
| `Lab-Uninstall.ps1` | Any Windows VM | Windows cleanup only | Local Admin rights |

---

## 🎭 Demo Environment Execution Contexts

### **Asgard Technologies Demo**

#### **Proxmox VE Host Commands**

```bash
# Create all Asgard VMs (Run on Proxmox host)
# Server VMs (VM IDs 100-104)
qm create 100 --name "ODIN-DC01" --memory 8192 --cores 6 # Primary DC
qm create 101 --name "FRIGG-DC02" --memory 6144 --cores 4 # Secondary DC
qm create 102 --name "HEIMDALL-FS01" --memory 8192 --cores 4 # File Server
qm create 103 --name "BALDER-WEB01" --memory 6144 --cores 4 # Web Server
qm create 104 --name "VIDAR-SEC01" --memory 8192 --cores 4 # Security Server

# Workstation VMs (VM IDs 110-134)
# IT Operations (110-114)
qm create 110 --name "LOKI-WS01" --memory 4096 --cores 2
qm create 111 --name "THOR-WS02" --memory 3072 --cores 2
# ... (continue for all 25 workstations)

# Start all Asgard VMs
for vm in {100..104} {110..134}; do qm start $vm; done
```

#### **Windows VM Configuration**

```powershell
# Run inside ODIN-DC01 (Primary Domain Controller)
# Domain Setup
Install-ADDSForest -DomainName "asgard.local" -DomainNetbiosName "ASGARD"

# Run inside each server VM after domain join
# HEIMDALL-FS01: File server configuration
Install-WindowsFeature -Name File-Services -IncludeManagementTools

# BALDER-WEB01: Web server configuration  
Install-WindowsFeature -Name Web-Server -IncludeManagementTools

# VIDAR-SEC01: Security tools installation
Install-WindowsFeature -Name UpdateServices -IncludeManagementTools
```

### **Olympus Systems Demo**

#### **Proxmox VE Host Commands**

```bash
# Create all Olympus VMs (Run on Proxmox host)
# Server VMs (VM IDs 200-204)
qm create 200 --name "ZEUS-DC01" --memory 8192 --cores 8 # Primary DC
qm create 201 --name "HERA-DC02" --memory 6144 --cores 6 # Secondary DC
qm create 202 --name "HERMES-FS01" --memory 8192 --cores 6 # File Server
qm create 203 --name "APOLLO-WEB01" --memory 6144 --cores 6 # Web/AI Server
qm create 204 --name "ATHENA-SEC01" --memory 8192 --cores 6 # Security Server

# Enhanced AI/ML Workstations (higher specs)
qm create 215 --name "PROMETHEUS-WS01" --memory 8192 --cores 4 # AI Development
qm create 216 --name "DAEDALUS-WS01" --memory 6144 --cores 4 # ML Engineering

# Start all Olympus VMs
for vm in {200..204} {210..234}; do qm start $vm; done
```

#### **Windows VM Configuration**

```powershell
# Run inside ZEUS-DC01 (Primary Domain Controller)
# Advanced Domain Setup
Install-ADDSForest -DomainName "olympus.local" -DomainNetbiosName "OLYMPUS"

# Run inside APOLLO-WEB01 (AI/Web Server)
Install-WindowsFeature -Name "Machine-Learning-Services"
Install-WindowsFeature -Name "Web-Server" -IncludeManagementTools

# Run inside AI workstations (PROMETHEUS-WS01, etc.)
# Install AI/ML development tools and frameworks
```

---

## 🔧 Network Configuration Context

### **Proxmox VE Bridge Configuration**

```bash
# Network Bridge Setup (Run on Proxmox host)
# Edit /etc/network/interfaces

# Management Bridge (vmbr1)
auto vmbr1
iface vmbr1 inet static
    address 192.168.100.1/24
    bridge-ports none
    bridge-stp off
    bridge-fd 0

# Production Bridge (vmbr2)  
auto vmbr2
iface vmbr2 inet static
    address 192.168.1.1/24
    bridge-ports none
    bridge-stp off
    bridge-fd 0

# Restart networking
systemctl restart networking
```

### **Windows VM Network Configuration**

```powershell
# Network Configuration (Run inside each Windows VM)
# Configure network adapters after Windows installation

# Management Interface (connected to vmbr1)
New-NetIPAddress -InterfaceAlias "Ethernet" -IPAddress "192.168.100.10" -PrefixLength 24
Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses "192.168.100.10"

# Production Interface (connected to vmbr2)
New-NetIPAddress -InterfaceAlias "Ethernet 2" -IPAddress "192.168.1.10" -PrefixLength 24
Set-DnsClientServerAddress -InterfaceAlias "Ethernet 2" -ServerAddresses "192.168.1.10"
```

---

## 🚨 Common Execution Mistakes

### **❌ Wrong Execution Context**

```bash
# WRONG: Running Windows PowerShell commands on Proxmox host
New-ADUser -Name "Test User"  # This will fail on Linux

# WRONG: Running Proxmox commands inside Windows VM
qm start 100  # This command doesn't exist in Windows
```

### **✅ Correct Execution Context**

```bash
# CORRECT: Proxmox commands on Proxmox host
ssh root@proxmox-host
qm start 100

# CORRECT: Windows commands inside Windows VM
Enter-PSSession -ComputerName DC01
New-ADUser -Name "Test User"
```

---

## 📋 Pre-Execution Checklist

### **Before Running Proxmox Commands**

- [ ] SSH access to Proxmox host established
- [ ] Sufficient storage space available
- [ ] Network bridges configured
- [ ] ISO files uploaded to storage
- [ ] VM ID numbers planned and available

### **Before Running Windows VM Scripts**

- [ ] Windows VM is running and accessible
- [ ] PowerShell execution policy set appropriately
- [ ] Required Windows features installed
- [ ] Domain connectivity established (if needed)
- [ ] Administrative privileges confirmed

### **Before Running Demo Scripts**

- [ ] All VMs created via Proxmox VE
- [ ] VirtIO drivers installed in Windows VMs
- [ ] Network connectivity between VMs verified
- [ ] Active Directory domain established
- [ ] DNS resolution working properly

---

## 🎯 Quick Reference Commands

### **Check Execution Context**

```bash
# On Proxmox host
hostname  # Should show Proxmox hostname
qm list   # Should show VM list

# In Windows VM
$env:COMPUTERNAME  # Should show Windows VM name
Get-ADDomain       # Should show domain info (if DC)
```

### **Access Methods**

| System | Access Method | Command/URL |
|--------|---------------|-------------|
| **Proxmox Host** | SSH | `ssh root@proxmox-ip` |
| **Proxmox Host** | Web Interface | `https://proxmox-ip:8006` |
| **Windows VM** | RDP | `mstsc /v:vm-ip` |
| **Windows VM** | Console | Via Proxmox web interface |
| **Windows VM** | PowerShell Direct | `Enter-PSSession -VMName VM-NAME` |

---

## 🎊 Summary

- **Proxmox VE Host**: VM lifecycle, network bridges, storage, monitoring
- **Windows VMs**: Active Directory, file shares, applications, Windows features
- **Scripts**: Clearly documented execution location in headers
- **Demos**: Two-tier approach (Proxmox creates VMs, Windows configures services)
- **Network**: Bridges on Proxmox, IP configuration in Windows VMs

**Remember**: When in doubt, check the script header comments for execution context! 🎯
