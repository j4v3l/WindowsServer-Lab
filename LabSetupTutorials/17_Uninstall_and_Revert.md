# 🔄 Uninstall and Revert Changes Guide

## 🎯 What You'll Learn

- How to safely uninstall lab components
- Backup and restore procedures
- Selective component removal
- Recovery from failed installations
- Best practices for lab environment cleanup

## 📋 Prerequisites

- Windows Server Lab environment installed
- Administrative access to the system
- PowerShell 5.1 or later
- Understanding of lab components

## 🛡️ Safety First

⚠️ **IMPORTANT**: Always create backups before uninstalling components. The uninstall process can permanently remove VMs, Active Directory objects, and other configurations.

### Default Safety Features

- **Automatic Backup**: Creates backup before removal (can be disabled)
- **Confirmation Prompts**: Requires user confirmation for destructive operations
- **Detailed Logging**: All operations are logged with timestamps
- **Component Validation**: Validates components before removal
- **Manifest Creation**: Creates uninstall manifest for tracking

## 🚀 Quick Start

### Using PowerShell Module

```powershell
# Import the module
Import-Module .\Scripts\WindowsServerLab.psd1

# Remove all lab components (with backup)
Remove-LabEnvironment -Component All

# Remove only VMs (with backup)
Remove-LabEnvironment -Component VMs

# Force removal without confirmations
Remove-LabEnvironment -Component All -Force

# Skip backup creation (not recommended)
Remove-LabEnvironment -Component All -CreateBackup:$false
```

### Using Direct Script

```powershell
# Remove all components
.\Scripts\Lab-Uninstall.ps1 -Component All

# Remove specific components
.\Scripts\Lab-Uninstall.ps1 -Component VMs
.\Scripts\Lab-Uninstall.ps1 -Component AD

# See all available options
.\Scripts\Lab-Uninstall.ps1 -Component Help
```

## 🔧 Available Components

### Complete Removal

```powershell
# Remove everything (VMs, switches, shares, AD, GPOs, registry, scheduled tasks)
.\Scripts\Lab-Uninstall.ps1 -Component All
```

### Selective Removal

#### Virtual Machines

```powershell
# Remove all lab VMs and their files
.\Scripts\Lab-Uninstall.ps1 -Component VMs

# Specify custom VM path
.\Scripts\Lab-Uninstall.ps1 -Component VMs -VMPath "D:\VMs"

# Force removal without confirmation
.\Scripts\Lab-Uninstall.ps1 -Component VMs -Force
```

#### Virtual Network Switches

```powershell
# Remove lab virtual switches and NAT configurations
.\Scripts\Lab-Uninstall.ps1 -Component Switches
```

#### File Shares

```powershell
# Remove SMB shares and share directories
.\Scripts\Lab-Uninstall.ps1 -Component Shares
```

#### Active Directory Objects

```powershell
# Remove all lab AD objects (OUs, users, groups)
.\Scripts\Lab-Uninstall.ps1 -Component AD

# Remove only lab user accounts
.\Scripts\Lab-Uninstall.ps1 -Component Users

# Specify custom domain
.\Scripts\Lab-Uninstall.ps1 -Component AD -DomainName "custom.local"
```

#### Group Policy Objects

```powershell
# Remove lab-related GPOs
.\Scripts\Lab-Uninstall.ps1 -Component GPOs
```

#### Registry Entries

```powershell
# Clean up lab-related registry entries
.\Scripts\Lab-Uninstall.ps1 -Component Registry
```

#### Scheduled Tasks

```powershell
# Remove lab-related scheduled tasks
.\Scripts\Lab-Uninstall.ps1 -Component Scheduled
```

## 💾 Backup and Restore

### Automatic Backup

By default, the uninstall script creates a backup before removing components:

```powershell
# Backup is created automatically
.\Scripts\Lab-Uninstall.ps1 -Component All

# Specify custom backup location
.\Scripts\Lab-Uninstall.ps1 -Component All -BackupPath "D:\LabBackup"

# Skip backup (not recommended)
.\Scripts\Lab-Uninstall.ps1 -Component All -CreateBackup:$false
```

### Manual Backup

```powershell
# Create backup without uninstalling
.\Scripts\Lab-Uninstall.ps1 -Component Help  # This won't uninstall anything
```

### Restore from Backup

#### Using PowerShell Module

```powershell
# Restore all components from backup
Restore-LabEnvironment -BackupPath "C:\LabBackup"

# Restore specific components
Restore-LabEnvironment -BackupPath "C:\LabBackup" -Component VMs
Restore-LabEnvironment -BackupPath "C:\LabBackup" -Component AD

# Specify custom VM path for restore
Restore-LabEnvironment -BackupPath "C:\LabBackup" -Component VMs -VMPath "D:\VMs"
```

#### Using Direct Script

```powershell
# Restore all components
.\Scripts\Lab-Restore.ps1 -BackupPath "C:\LabBackup"

# Restore specific components
.\Scripts\Lab-Restore.ps1 -BackupPath "C:\LabBackup" -Component VMs
.\Scripts\Lab-Restore.ps1 -BackupPath "C:\LabBackup" -Component AD

# Force restore without confirmations
.\Scripts\Lab-Restore.ps1 -BackupPath "C:\LabBackup" -Force
```

## 📊 Backup Contents

### What Gets Backed Up

1. **Virtual Machines**

   - VM configurations and settings
   - Virtual hard disk files
   - Checkpoints and snapshots
   - Network adapter configurations

2. **Active Directory**

   - Organizational Units (exported to CSV)
   - User accounts (exported to CSV)
   - Security groups (exported to CSV)
   - _Note: Passwords are not backed up_

3. **Configuration Files**
   - Module settings
   - Custom configurations

### Backup Structure

```
C:\LabBackup\
├── BackupManifest.json          # Backup metadata
├── VMs\                         # VM exports
│   ├── DC1-LAB\
│   ├── FS1-LAB\
│   └── CL1-LAB\
└── ActiveDirectory\             # AD exports
    ├── OUs.csv
    ├── Users.csv
    └── Groups.csv
```

## 🔍 Logs and Monitoring

### Log Files

All operations are logged with detailed information:

```powershell
# Default log location
$LogPath = "$env:TEMP\Lab-Uninstall-$(Get-Date -Format 'yyyy-MM-dd_HH-mm').log"

# View log file
Get-Content $LogPath | Select-Object -Last 20
```

### Uninstall Manifest

Each uninstall operation creates a manifest file:

```powershell
# Manifest location
$ManifestPath = "$env:TEMP\Lab-Uninstall-Manifest.json"

# View manifest
Get-Content $ManifestPath | ConvertFrom-Json
```

Example manifest:

```json
{
  "UninstallDate": "2025-01-27 14:30:00",
  "Component": "All",
  "Results": {
    "VMs": true,
    "Switches": true,
    "Shares": true,
    "AD": true,
    "GPOs": true,
    "Registry": true,
    "ScheduledTasks": true
  },
  "LogPath": "C:\\Users\\Admin\\AppData\\Local\\Temp\\Lab-Uninstall-2025-01-27_14-30.log",
  "BackupPath": "C:\\LabBackup"
}
```

## 🔧 Troubleshooting

### Common Issues

#### 1. Permission Denied

```powershell
# Ensure running as Administrator
# Right-click PowerShell -> "Run as Administrator"

# Verify privileges
([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
```

#### 2. Module Not Found

```powershell
# Check if ActiveDirectory module is available
Get-Module -ListAvailable ActiveDirectory

# Install if missing (on Windows 10/11)
Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0
```

#### 3. VMs Still Running

```powershell
# Stop all lab VMs first
Get-VM | Where-Object { $_.Name -like "*LAB*" } | Stop-VM -Force

# Then proceed with uninstall
.\Scripts\Lab-Uninstall.ps1 -Component VMs
```

#### 4. Backup Failed

```powershell
# Check disk space
Get-WmiObject -Class Win32_LogicalDisk | Select-Object DeviceID, FreeSpace

# Use custom backup location
.\Scripts\Lab-Uninstall.ps1 -Component All -BackupPath "D:\LabBackup"

# Skip backup if necessary (not recommended)
.\Scripts\Lab-Uninstall.ps1 -Component All -CreateBackup:$false
```

### Recovery Scenarios

#### 1. Partial Uninstall Failure

```powershell
# Check the uninstall manifest for failed components
$manifest = Get-Content "$env:TEMP\Lab-Uninstall-Manifest.json" | ConvertFrom-Json
$manifest.Results

# Retry failed components individually
.\Scripts\Lab-Uninstall.ps1 -Component VMs -Force
```

#### 2. Restore After Accidental Removal

```powershell
# Restore from most recent backup
$backupPath = "C:\LabBackup"
.\Scripts\Lab-Restore.ps1 -BackupPath $backupPath -Component All
```

#### 3. Corrupted Backup

```powershell
# Validate backup integrity
.\Scripts\Lab-Restore.ps1 -BackupPath "C:\LabBackup" -Component Help

# If backup is corrupted, redeploy from scratch
Import-Module .\Scripts\WindowsServerLab.psd1
New-LabEnvironment -VMPath "C:\VMs" -ISOPath "C:\path\to\WindowsServer.iso"
```

## 🎯 Best Practices

### Before Uninstalling

1. **Document Current State**

   ```powershell
   # Export current VM list
   Get-VM | Export-Csv "VM-List-Backup.csv"

   # Export AD structure
   Get-ADOrganizationalUnit -Filter * | Export-Csv "OU-List-Backup.csv"
   ```

2. **Stop All Services**

   ```powershell
   # Stop all lab VMs
   Get-VM | Where-Object { $_.Name -like "*LAB*" } | Stop-VM

   # Wait for VMs to fully stop
   Start-Sleep -Seconds 30
   ```

3. **Verify Backup Location**
   ```powershell
   # Ensure backup drive has enough space
   $freeSpace = (Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='C:'").FreeSpace / 1GB
   Write-Host "Free space: $([math]::Round($freeSpace, 2)) GB"
   ```

### During Uninstall

1. **Use Staged Approach**

   ```powershell
   # Remove components in order
   .\Scripts\Lab-Uninstall.ps1 -Component VMs
   .\Scripts\Lab-Uninstall.ps1 -Component Switches
   .\Scripts\Lab-Uninstall.ps1 -Component AD
   ```

2. **Monitor Progress**
   ```powershell
   # Check logs in real-time
   Get-Content $LogPath -Wait
   ```

### After Uninstall

1. **Verify Removal**

   ```powershell
   # Check for remaining VMs
   Get-VM | Where-Object { $_.Name -like "*LAB*" }

   # Check for remaining switches
   Get-VMSwitch | Where-Object { $_.Name -like "*LAB*" }
   ```

2. **Clean Up Logs**
   ```powershell
   # Archive logs for future reference
   $archivePath = "C:\LabLogs\Archive"
   New-Item -Path $archivePath -ItemType Directory -Force
   Move-Item -Path "$env:TEMP\Lab-*.log" -Destination $archivePath
   ```

## 📚 Advanced Scenarios

### 1. Demo Environment Cleanup

```powershell
# Remove Asgard demo environment
.\Scripts\Lab-Uninstall.ps1 -Component All -VMPath "C:\VMs\Asgard"

# Remove Olympus demo environment
.\Scripts\Lab-Uninstall.ps1 -Component All -VMPath "C:\VMs\Olympus"
```

### 2. Multi-Domain Environment

```powershell
# Clean up multiple domains
.\Scripts\Lab-Uninstall.ps1 -Component AD -DomainName "lab.local"
.\Scripts\Lab-Uninstall.ps1 -Component AD -DomainName "test.local"
```

### 3. Automated Cleanup

```powershell
# Create scheduled cleanup task
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-File C:\Scripts\Lab-Uninstall.ps1 -Component All -Force -SkipConfirmation"
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 2AM
Register-ScheduledTask -TaskName "WeeklyLabCleanup" -Action $action -Trigger $trigger
```

## 🔒 Security Considerations

### 1. Data Protection

- Always backup before removal
- Encrypt sensitive backups
- Store backups on separate drives
- Document access controls

### 2. Audit Trail

- Review log files regularly
- Monitor uninstall operations
- Track who performs cleanup
- Document reasons for removal

### 3. Recovery Planning

- Test restore procedures
- Maintain offline backups
- Document recovery steps
- Train team members

## 📝 Summary

The Windows Server Lab environment now includes comprehensive uninstall and revert capabilities:

✅ **Safe Removal**: Automatic backups and confirmation prompts  
✅ **Selective Cleanup**: Remove individual components as needed  
✅ **Full Restoration**: Restore from backups when needed  
✅ **Detailed Logging**: Track all operations with timestamps  
✅ **PowerShell Integration**: Use module functions or direct scripts  
✅ **Demo Support**: Clean up Asgard and Olympus environments

For questions or issues, refer to the troubleshooting section or check the log files for detailed error information.

## 🔄 Related Topics

- [Lab Environment Setup](01_Setup_Lab_Environment.md)
- [Troubleshooting Guide](05_Troubleshooting.md)
- [Disaster Recovery](12_Disaster_Recovery.md)
- [Monitoring and Maintenance](06_Monitoring_and_Maintenance.md)
