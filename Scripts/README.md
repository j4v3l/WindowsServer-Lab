# 🛠️ Scripts Directory - Windows Server Lab Environment

## 📋 Overview

This directory contains PowerShell scripts for configuring and managing Windows Server/client VMs **running on Proxmox VE**. Proxmox is Linux; do not run these PowerShell scripts on the Proxmox host. Run them inside the Windows VMs only.

## 🎯 Execution Context

- **Where to run**: Inside Windows Server VMs (Domain Controllers, Member Servers)
- **Requirements**: Windows PowerShell 5.1+ with appropriate modules (ActiveDirectory, GroupPolicy, etc.)
- **Privileges**: Most scripts require Domain Administrator or local Administrator privileges
- **Platform**: Windows Server 2019/2022/2025 running on Proxmox VE

## 📁 Script Categories

### 🏗️ **Environment Setup (Server)**

- `Lab-FinishSetup.ps1` - Complete lab environment configuration
- `Create-LabUsers.ps1` - Create user accounts and organizational units
- `Server/DHCP_Setup.ps1` - Configure DHCP server role

### 🛡️ **Security & Policy Management (Server)**

- `Deploy-AdvancedSecurityDemo.ps1` - Deploy comprehensive security policies
- `Server/AdvancedGroupPolicyManager.ps1` - Advanced GPO configuration (100+ policies)
- `Server/AdvancedSecurityAudit.ps1` - Comprehensive security assessment
- `Server/GroupPolicyManager.ps1` - Basic GPO management
- `SecurityAudit.ps1` - Basic security auditing

### 🔧 **System Management (Server)**

- `Server/SystemHealthMonitor.ps1` - Monitor server health and generate reports
- `BackupRestoreManager.ps1` - Backup and restore operations
- `Lab-Uninstall.ps1` - Clean up lab components (Windows-side only)

### 🖥️ **Client Onboarding & Baseline (Client)**

- `Client/Client-Onboarding.ps1` - Join domain, optional rename, set DNS, and reboot
- `Client/Client-Baseline.ps1` - Apply safe baseline: firewall, SMB signing, PS logging, policies
- `Client/Client-HealthCheck.ps1` - Generate client HTML health report (AV, firewall, disks, updates)

### 🔒 **Server Hardening & Updates (Server)**

### 📂 File Shares & Drives

- `Server/Create-FileShares.ps1` - Create standard SMB shares with proper NTFS/share permissions
- `Client/Map-NetworkDrives.ps1` - Map T: (Tools) and D: (Departments) from the file server

### 🔧 Common Utilities

- `Common/Lab-ConnectivityTest.ps1` - Quick DNS/DC/LDAP/SMB/time checks from any VM

- `Server/Server-Hardening.ps1` - Enforce NLA for RDP, SMB signing, LSA protection, NTLM, auditpol
- `Server/WindowsUpdate-Configure.ps1` - Configure AU mode/deferrals and optionally scan/download/install

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

Quick use examples (inside the VM PowerShell):

-- Client join domain:
	$sec = Read-Host 'Password' -AsSecureString
	.\Client\Client-Onboarding.ps1 -DomainName lab.local -ComputerName PC01 -OUPath "OU=Workstations,DC=lab,DC=local" -DomainJoinUser "LAB\\Administrator" -DomainJoinPassword $sec -DNSServer 192.168.1.10 -Reboot

-- Apply client baseline:
	.\Client\Client-Baseline.ps1

-- Server hardening:
	.\Server\Server-Hardening.ps1

-- Configure Windows Update and scan (server):
	.\Server\WindowsUpdate-Configure.ps1 -Mode AutoInstall -ScanNow -DownloadNow -InstallNow -RestartIfNeeded

- Create standard shares on file server:
	.\Server\Create-FileShares.ps1 -RootPath D:\Shares -CreateExampleFolders

- Map standard drives on a client:
	.\Client\Map-NetworkDrives.ps1 -FileServer FILE1

- Test lab connectivity from any VM:
	.\Common\Lab-ConnectivityTest.ps1 -Domain lab.local -FileServer FILE1

## 📖 **Related Documentation**

- [Proxmox VE Setup Guide](../LabSetupTutorials/16_Proxmox_Setup_and_Configuration.md)
- [Windows Server Optimization](../LabSetupTutorials/Windows_Server_on_Proxmox_Optimization.md)
- [Lab Environment Setup](../LabSetupTutorials/01_Setup_Lab_Environment.md)

---

**Remember**: These scripts configure Windows Server features within VMs, while Proxmox VE manages the virtualization infrastructure. The two layers work together to provide a complete lab environment.
