# 🛠️ Scripts Directory - Windows Server Lab Environment

## 📋 Overview

This directory contains PowerShell scripts for configuring and managing Windows Server environments **running as VMs on Proxmox VE**. These scripts are designed to run **inside the Windows VMs**, not on the Proxmox host.

## 🎯 Execution Context

- **Where to run**: Inside Windows Server VMs (Domain Controllers, Member Servers)
- **Requirements**: Windows PowerShell 5.1+ with appropriate modules (ActiveDirectory, GroupPolicy, etc.)
- **Privileges**: Most scripts require Domain Administrator or local Administrator privileges
- **Platform**: Windows Server 2019/2022/2025 running on Proxmox VE

## 📁 Script Categories

### 🏗️ **Environment Setup**

- `Lab-FinishSetup.ps1` - Complete lab environment configuration
- `Create-LabUsers.ps1` - Create user accounts and organizational units
- `DHCP_Setup.ps1` - Configure DHCP server role

### 🛡️ **Security & Policy Management**

- `Deploy-AdvancedSecurityDemo.ps1` - Deploy comprehensive security policies
- `AdvancedGroupPolicyManager.ps1` - Advanced GPO configuration (100+ policies)
- `AdvancedSecurityAudit.ps1` - Comprehensive security assessment
- `GroupPolicyManager.ps1` - Basic GPO management
- `SecurityAudit.ps1` - Basic security auditing

### 🔧 **System Management**

- `SystemHealthMonitor.ps1` - Monitor server health and generate reports
- `BackupRestoreManager.ps1` - Backup and restore operations
- `Lab-Uninstall.ps1` - Clean up lab components (Windows-side only)

### 🎨 **User Experience**

- `Setup-OhMyPosh.ps1` - Configure enhanced PowerShell prompt
- `Quick-InstallOhMyPosh.ps1` - Quick Oh My Posh installation

## ⚠️ **Important Notes**

### **Execution Context - Critical!**

**These scripts run INSIDE Windows VMs, NOT on the Proxmox host!**

- **Access Method**: RDP, Console, or PowerShell Direct to Windows VMs
- **Prerequisites**: Windows PowerShell 5.1+, appropriate Windows modules
- **Privileges**: Domain Admin or Local Admin rights within Windows VMs

### **Proxmox VE Integration**

- **VM Management**: Use Proxmox VE web interface or CLI (`qm` commands) for VM lifecycle operations
- **Network Management**: Configure bridges via Proxmox VE, not Windows PowerShell  
- **Storage Management**: VM disk operations handled by Proxmox VE
- **Performance Monitoring**: Use Proxmox VE dashboard for VM resource monitoring

### **Two-Tier Architecture**

1. **Proxmox VE Host**: Creates, starts, stops, configures VMs
2. **Windows VMs**: Run these PowerShell scripts for Windows-specific configuration

### **Windows-Specific Operations**

These scripts handle Windows-specific configurations:

- Active Directory Domain Services
- Group Policy Objects (GPOs)
- Windows file shares and permissions
- Windows security policies
- Windows service configuration
- Windows user and computer management

## 🚀 **Getting Started**

1. **Deploy VMs** using Proxmox VE (see lab setup guides)
2. **Install Windows Server** on the VMs with VirtIO drivers
3. **Configure Active Directory** on the primary domain controller
4. **Run scripts** from within the Windows VMs as needed

## 📖 **Related Documentation**

- [Proxmox VE Setup Guide](../LabSetupTutorials/16_Proxmox_Setup_and_Configuration.md)
- [Windows Server Optimization](../LabSetupTutorials/Windows_Server_on_Proxmox_Optimization.md)
- [Lab Environment Setup](../LabSetupTutorials/01_Setup_Lab_Environment.md)

---

**Remember**: These scripts configure Windows Server features within VMs, while Proxmox VE manages the virtualization infrastructure. The two layers work together to provide a complete lab environment.
