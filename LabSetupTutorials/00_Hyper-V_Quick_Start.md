# 🚀 Hyper-V Lab Quick Start Guide

## 🎯 Overview

This guide helps you quickly set up a complete Windows Server lab environment using Hyper-V. If you want detailed explanations, see the [complete Hyper-V setup guide](16_Hyper-V_Setup_and_Configuration.md).

## ⚡ Prerequisites Checklist

- [ ] Windows 10/11 Pro, Enterprise, or Education
- [ ] 8GB+ RAM (16GB recommended)
- [ ] 100GB+ free disk space
- [ ] Virtualization enabled in BIOS/UEFI
- [ ] Windows Server ISO file downloaded

## 🏃‍♂️ 5-Minute Setup (Automated)

### Step 1: Enable Hyper-V (Run as Administrator)

```powershell
# Enable Hyper-V and restart
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -All
# Restart required after this command
```

### Step 2: Run Automated Lab Setup

```powershell
# Download and run the Hyper-V lab setup script
# Navigate to the Scripts directory first
cd "C:\path\to\WindowsServer\Scripts"

# Create virtual switches only (first run)
.\Hyper-V_Lab_Setup.ps1 -CreateSwitchesOnly

# Create complete lab environment
.\Hyper-V_Lab_Setup.ps1 -VMPath "C:\VMs" -ISOPath "C:\path\to\WindowsServer.iso"
```

### Step 3: Start Your Lab

```powershell
# Start all lab VMs
.\Hyper-V_Management.ps1 -Action Start

# Check status
.\Hyper-V_Management.ps1 -Action Status
```

## 🛠️ Manual Setup (Step-by-Step)

### 1. Create Virtual Switches

```powershell
# External switch (internet access)
New-VMSwitch -Name "LAB-External" -NetAdapterName "Ethernet" -AllowManagementOS $true

# Internal switch (management)
New-VMSwitch -Name "LAB-Management" -SwitchType Internal

# Configure management IP
$adapter = Get-NetAdapter -Name "vEthernet (LAB-Management)"
New-NetIPAddress -IPAddress 192.168.100.1 -PrefixLength 24 -InterfaceIndex $adapter.ifIndex

# Private switch (isolated testing)
New-VMSwitch -Name "LAB-Isolated" -SwitchType Private
```

### 2. Create Domain Controller VM

```powershell
# Create DC1-LAB VM
New-VM -Name "DC1-LAB" -Path "C:\VMs" -MemoryStartupBytes 4GB -Generation 2

# Configure VM
Set-VM -Name "DC1-LAB" -ProcessorCount 2
Set-VM -Name "DC1-LAB" -DynamicMemory -MemoryMinimumBytes 2GB -MemoryMaximumBytes 8GB

# Create and attach VHD
New-VHD -Path "C:\VMs\DC1-LAB\DC1-LAB.vhdx" -SizeBytes 80GB -Dynamic
Add-VMHardDiskDrive -VMName "DC1-LAB" -Path "C:\VMs\DC1-LAB\DC1-LAB.vhdx"

# Add DVD drive
Add-VMDvdDrive -VMName "DC1-LAB"

# Configure network (remove default, add specific adapters)
Remove-VMNetworkAdapter -VMName "DC1-LAB" -Name "Network Adapter"
Add-VMNetworkAdapter -VMName "DC1-LAB" -SwitchName "LAB-External" -Name "External"
Add-VMNetworkAdapter -VMName "DC1-LAB" -SwitchName "LAB-Management" -Name "Management"

# Configure boot and security
Set-VMFirmware -VMName "DC1-LAB" -EnableSecureBoot On
Set-VMFirmware -VMName "DC1-LAB" -FirstBootDevice (Get-VMDvdDrive -VMName "DC1-LAB")

# Attach ISO and start
Set-VMDvdDrive -VMName "DC1-LAB" -Path "C:\path\to\WindowsServer.iso"
Start-VM -Name "DC1-LAB"
```

## 🌐 Network Configuration Reference

### Recommended IP Scheme

| Network | Range | Purpose |
|---------|-------|---------|
| External | 192.168.1.0/24 | Internet access, production services |
| Management | 192.168.100.0/24 | Lab management, host access |
| Isolated | 192.168.200.0/24 | Isolated testing, DMZ |

### VM Network Configuration

#### DC1-LAB (Domain Controller)

- **External Adapter**: 192.168.1.10/24, GW: 192.168.1.1, DNS: 192.168.1.10
- **Management Adapter**: 192.168.100.10/24, GW: 192.168.100.1, DNS: 192.168.100.10

#### FS1-LAB (File Server)

- **External Adapter**: 192.168.1.20/24, GW: 192.168.1.1, DNS: 192.168.1.10
- **Management Adapter**: 192.168.100.20/24, GW: 192.168.100.1, DNS: 192.168.100.10

## 🔧 Common Management Tasks

### Start/Stop VMs

```powershell
# Start all lab VMs
.\Hyper-V_Management.ps1 -Action Start

# Stop specific VM
.\Hyper-V_Management.ps1 -Action Stop -VMName "DC1-LAB"

# Restart all VMs
.\Hyper-V_Management.ps1 -Action Restart
```

### Backup and Restore

```powershell
# Create checkpoints
.\Hyper-V_Management.ps1 -Action Backup

# Restore from checkpoint
.\Hyper-V_Management.ps1 -Action Restore -VMName "DC1-LAB"
```

### Network Diagnostics

```powershell
# Check network configuration
.\Hyper-V_Management.ps1 -Action Network

# Test connectivity
Test-NetConnection -ComputerName "192.168.1.10" -Port 3389
```

### Performance Monitoring

```powershell
# Real-time monitoring (Ctrl+C to stop)
.\Hyper-V_Management.ps1 -Action Monitor

# Resource cleanup
.\Hyper-V_Management.ps1 -Action Cleanup
```

## 🏗️ Lab Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Physical Host                             │
│                 (Your Windows Machine)                      │
└─────────────────────┬───────────────────────────────────────┘
                      │
              ┌───────▼────────┐
              │  LAB-External  │ (Internet Access)
              │     Switch     │
              └───────┬────────┘
                      │
        ┌─────────────┼─────────────┐
        │             │             │
    ┌───▼───┐     ┌───▼───┐     ┌───▼───┐
    │ DC1   │     │ FS1   │     │ WEB1  │
    │ .1.10 │     │ .1.20 │     │ .1.30 │
    └───┬───┘     └───┬───┘     └───┬───┘
        │             │             │
        └─────────────┼─────────────┘
                      │
              ┌───────▼────────┐
              │ LAB-Management │ (Host Access)
              │     Switch     │
              └────────────────┘
```

## 🎓 Next Steps

1. **Install Windows Server** on DC1-LAB
2. **Configure Active Directory** - Follow [Lab Environment Setup](01_Setup_Lab_Environment.md)
3. **Create Additional VMs** - Use the scripts or manual commands above
4. **Join VMs to Domain** - Configure domain membership
5. **Set up Lab Services** - DNS, DHCP, File Shares, etc.

## 🆘 Troubleshooting Quick Fixes

### Issue: Hyper-V Not Available

```powershell
# Check Windows edition
Get-WindowsEdition -Online

# Enable Hyper-V
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -All
```

### Issue: VM Won't Start

```powershell
# Check VM configuration
Get-VM -Name "DC1-LAB" | Format-List *

# Check switch availability
Get-VMSwitch
```

### Issue: No Internet in VM

```powershell
# Check external switch
Get-VMSwitch -Name "LAB-External" | Format-List *

# Check VM network adapter
Get-VMNetworkAdapter -VMName "DC1-LAB"
```

### Issue: Can't Connect to VM

```powershell
# Enable Enhanced Session Mode
Set-VMHost -EnableEnhancedSessionMode $true

# Use RDP instead
mstsc /v:192.168.1.10
```

## 📚 Related Documentation

- [Detailed Hyper-V Setup](16_Hyper-V_Setup_and_Configuration.md)
- [Lab Environment Setup](01_Setup_Lab_Environment.md)
- [Troubleshooting Guide](05_Troubleshooting.md)
- [Network Configuration](02_Manage_Users_Computers_AD.md)

---

**💡 Pro Tips:**

- Always create checkpoints before major changes
- Use Dynamic Memory to optimize RAM usage  
- Keep ISO files on fast storage (SSD)
- Monitor resource usage with the management script
- Document your IP allocations for reference
