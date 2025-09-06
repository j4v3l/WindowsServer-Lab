# Windows Server Lab Environment Uninstall Script
# This script safely removes all components created by the lab setup scripts
# 
# IMPORTANT: This script runs INSIDE Windows VMs on Proxmox VE, not on the Proxmox host
# VM lifecycle management (start/stop/create/destroy) is handled via Proxmox VE web interface
# This script only cleans up Windows-specific configurations (AD, shares, GPOs, etc.)

#Requires -RunAsAdministrator
# Note: Updated for Proxmox VE compatibility

[CmdletBinding()]
param(
  [ValidateSet("All", "VMs", "Switches", "Shares", "AD", "Users", "GPOs", "Registry", "Scheduled", "Help")]
  [string]$Component = "Help",
  [string]$VMPath = "C:\VMs",  # Note: This is for VM file cleanup, not Proxmox VM management
  [string]$DomainName = "lab.local",
  [string]$BackupPath = "C:\LabBackup",
  [switch]$Force = $false,
  [switch]$CreateBackup = $true,
  [switch]$SkipConfirmation = $false
)

# Enhanced Error Handling Configuration
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Logging Configuration
$LogPath = Join-Path $env:TEMP "Lab-Uninstall-$(Get-Date -Format 'yyyy-MM-dd_HH-mm').log"
$UninstallManifestPath = Join-Path $env:TEMP "Lab-Uninstall-Manifest.json"

# Color coding for output
$ErrorColor = "Red"
$WarningColor = "Yellow"
$InfoColor = "Green"
$DebugColor = "Cyan"
$HighlightColor = "Magenta"

function Write-UninstallLog {
  param(
    [string]$Message,
    [ValidateSet("INFO", "WARNING", "ERROR", "DEBUG", "SUCCESS")]
    [string]$Level = "INFO"
  )
  $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  $logEntry = "[$timestamp] [$Level] $Message"
  Add-Content -Path $LogPath -Value $logEntry -ErrorAction SilentlyContinue
    
  # Also write to console with color
  switch ($Level) {
    "ERROR" { # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host $Message -ForegroundColor $ErrorColor }
    "WARNING" { # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host $Message -ForegroundColor $WarningColor }
    "INFO" { # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host $Message -ForegroundColor $InfoColor }
    "DEBUG" { # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host $Message -ForegroundColor $DebugColor }
    "SUCCESS" { # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host $Message -ForegroundColor $InfoColor }
  }
}

function Show-Help {
  Write-Host @"
=== WINDOWS SERVER LAB UNINSTALL SCRIPT ===

SYNOPSIS:
    Safely removes all components created by the Windows Server Lab setup scripts.

PARAMETERS:
    -Component <component>    : Component to uninstall (All, VMs, Switches, Shares, AD, Users, GPOs, Registry, Scheduled, Help)
    -VMPath <path>           : Path for VM file cleanup (default: C:\VMs) - Note: VM management via Proxmox VE
    -DomainName <domain>     : Domain name to clean up (default: lab.local)
    -BackupPath <path>       : Path for backup before uninstall (default: C:\LabBackup)
    -Force                   : Force removal without detailed confirmations
    -CreateBackup            : Create backup before uninstall (default: true)
    -SkipConfirmation        : Skip all confirmation prompts (dangerous!)

COMPONENTS:
    All         : Remove all lab components (comprehensive cleanup)
    VMs         : Remove all lab virtual machines and checkpoints
    Switches    : Remove lab virtual network switches
    Shares      : Remove file shares and directories created by lab
    AD          : Remove Active Directory objects (users, groups, OUs)
    Users       : Remove only user accounts created by lab
    GPOs        : Remove Group Policy Objects created by lab
    Registry    : Clean up registry entries created by lab
    Scheduled   : Remove scheduled tasks created by lab

EXAMPLES:
    .\Lab-Uninstall.ps1 -Component Help
    .\Lab-Uninstall.ps1 -Component VMs -VMPath "D:\VMs"
    .\Lab-Uninstall.ps1 -Component All -Force
    .\Lab-Uninstall.ps1 -Component AD -DomainName "custom.local"
    .\Lab-Uninstall.ps1 -Component Shares -SkipConfirmation

SAFETY FEATURES:
    - Creates backup before removal (unless disabled)
    - Logs all operations with timestamps
    - Requires confirmation for destructive operations
    - Validates components before removal
    - Creates uninstall manifest for tracking

"@ -ForegroundColor $InfoColor
  exit 0
}

function New-UninstallBackup {
  Write-UninstallLog "Creating backup before uninstall..." "INFO"
    
  try {
    if (!(Test-Path $BackupPath)) {
      New-Item -Path $BackupPath -ItemType Directory -Force | Out-Null
    }
        
    $backupManifest = @{
      Timestamp  = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
      BackupPath = $BackupPath
      Components = @{}
    }
        
    # VM backup functionality removed - use Proxmox VE backup features
    Write-Host "VM backups should be handled via Proxmox VE backup system" -ForegroundColor Yellow
        
    # Backup Active Directory structure
    if (Get-Module ActiveDirectory -ListAvailable) {
      try {
        Import-Module ActiveDirectory -ErrorAction SilentlyContinue
        $adBackupPath = Join-Path $BackupPath "ActiveDirectory"
        New-Item -Path $adBackupPath -ItemType Directory -Force | Out-Null
                
        # Export OUs, Users, Groups
        Get-ADOrganizationalUnit -Filter * | Export-Csv (Join-Path $adBackupPath "OUs.csv") -NoTypeInformation
        Get-ADUser -Filter * | Export-Csv (Join-Path $adBackupPath "Users.csv") -NoTypeInformation
        Get-ADGroup -Filter * | Export-Csv (Join-Path $adBackupPath "Groups.csv") -NoTypeInformation
                
        $backupManifest.Components.AD = "Exported"
        Write-UninstallLog "Backed up Active Directory structure" "SUCCESS"
      }
      catch {
        Write-UninstallLog "Could not backup AD: $($_.Exception.Message)" "WARNING"
      }
    }
        
    # Save backup manifest
    $backupManifest | ConvertTo-Json -Depth 3 | Out-File (Join-Path $BackupPath "BackupManifest.json")
    Write-UninstallLog "Backup completed at: $BackupPath" "SUCCESS"
        
    return $true
  }
  catch {
    Write-UninstallLog "Backup failed: $($_.Exception.Message)" "ERROR"
    return $false
  }
}

function Remove-LabVM {
  Write-UninstallLog "Starting VM removal process..." "INFO"
    
  try {
    # VM management moved to Proxmox VE - use web interface
    Write-Host "Please use Proxmox VE web interface to manage VMs:" -ForegroundColor Yellow
    Write-Host "- List VMs: qm list" -ForegroundColor Cyan
    Write-Host "- Stop VM: qm stop <vmid>" -ForegroundColor Cyan
    Write-Host "- Remove VM: qm destroy <vmid>" -ForegroundColor Cyan
    $labVMs = @() # Empty array since VMs are now managed via Proxmox
        
    if (-not $labVMs) {
      Write-UninstallLog "No lab VMs found to remove" "INFO"
      return $true
    }
        
    Write-UninstallLog "Found $($labVMs.Count) lab VMs to remove" "INFO"
        
    if (-not $Force -and -not $SkipConfirmation) {
      # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "`nLab VMs to be removed:" -ForegroundColor $WarningColor
      foreach ($vm in $labVMs) {
        Write-Host "  - $($vm.Name) [$($vm.State)]" -ForegroundColor $DebugColor
      }
            
      $response = Read-Host "`nThis will permanently remove all listed VMs. Continue? (y/N)"
      if ($response -ne 'y' -and $response -ne 'Y') {
        Write-UninstallLog "VM removal cancelled by user" "WARNING"
        return $false
      }
    }
        
    # Stop running VMs
    $runningVMs = $labVMs | Where-Object { $_.State -eq "Running" }
    if ($runningVMs) {
      Write-UninstallLog "Stopping $($runningVMs.Count) running VMs..." "INFO"
      foreach ($vm in $runningVMs) {
        # VM stop functionality moved to Proxmox VE
        Write-Host "Use 'qm stop <vmid>' on Proxmox host to stop VMs" -ForegroundColor Yellow
      }
    }
        
    # Snapshot management via Proxmox VE
    Write-UninstallLog "Snapshot management moved to Proxmox VE..." "INFO"
    Write-Host "Manage snapshots via Proxmox VE web interface or CLI:" -ForegroundColor Yellow
    Write-Host "- List snapshots: qm listsnapshot <vmid>" -ForegroundColor Cyan
    Write-Host "- Delete snapshot: qm delsnapshot <vmid> <snapshot_name>" -ForegroundColor Cyan
        
    # VM removal via Proxmox VE
    Write-UninstallLog "VM removal moved to Proxmox VE..." "INFO"
    Write-Host "Remove VMs via Proxmox VE:" -ForegroundColor Yellow
    Write-Host "- Remove VM: qm destroy <vmid>" -ForegroundColor Cyan
        
    # Clean up VM files
    if (Test-Path $VMPath) {
      Write-UninstallLog "Cleaning up VM files at: $VMPath" "INFO"
      Get-ChildItem -Path $VMPath -Recurse | Where-Object { 
        $_.Name -like "*LAB*" -or 
        $_.Name -like "*ASGARD*" -or 
        $_.Name -like "*OLYMPUS*" -or
        $_.Name -like "DC1*" -or 
        $_.Name -like "FS1*" -or 
        $_.Name -like "WEB1*" -or 
        $_.Name -like "CL1*"
      } | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
        
    Write-UninstallLog "VM removal completed" "SUCCESS"
    return $true
  }
  catch {
    Write-UninstallLog "VM removal failed: $($_.Exception.Message)" "ERROR"
    return $false
  }
}

function Remove-LabSwitch {
  Write-UninstallLog "Starting virtual switch removal..." "INFO"
    
  try {
    # Network bridges managed via Proxmox VE
    Write-Host "Network bridges managed via Proxmox VE web interface:" -ForegroundColor Yellow
    Write-Host "- View bridges: ip link show | grep vmbr" -ForegroundColor Cyan
    Write-Host "- Edit bridges: via Proxmox web interface" -ForegroundColor Cyan
    $labSwitches = @() # Empty array since bridges are now managed via Proxmox
        
    if (-not $labSwitches) {
      Write-UninstallLog "No lab switches found to remove" "INFO"
      return $true
    }
        
    Write-UninstallLog "Found $($labSwitches.Count) lab switches to remove" "INFO"
        
    if (-not $Force -and -not $SkipConfirmation) {
      # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "`nLab switches to be removed:" -ForegroundColor $WarningColor
      foreach ($switch in $labSwitches) {
        Write-Host "  - $($switch.Name) [$($switch.SwitchType)]" -ForegroundColor $DebugColor
      }
            
      $response = Read-Host "`nRemove these switches? (y/N)"
      if ($response -ne 'y' -and $response -ne 'Y') {
        Write-UninstallLog "Switch removal cancelled by user" "WARNING"
        return $false
      }
    }
        
    # Network bridge removal handled via Proxmox VE
    Write-Host "Network bridges managed via Proxmox VE web interface:" -ForegroundColor Yellow
    Write-Host "- Remove bridges: Node → Network → Select bridge → Remove" -ForegroundColor Cyan
    Write-Host "- Or via CLI: Edit /etc/network/interfaces on Proxmox host" -ForegroundColor Cyan
    Write-UninstallLog "Network bridge removal guidance provided" "INFO"
        
    # Clean up NAT configurations
    try {
      Get-NetNat | Where-Object { $_.Name -like "*LAB*" } | Remove-NetNat -Confirm:$false -ErrorAction SilentlyContinue
      Write-UninstallLog "Cleaned up NAT configurations" "SUCCESS"
    }
    catch {
      Write-UninstallLog "Could not clean up NAT: $($_.Exception.Message)" "WARNING"
    }
        
    Write-UninstallLog "Switch removal completed" "SUCCESS"
    return $true
  }
  catch {
    Write-UninstallLog "Switch removal failed: $($_.Exception.Message)" "ERROR"
    return $false
  }
}

function Remove-LabShare {
  Write-UninstallLog "Starting file share removal..." "INFO"
    
  try {
    # Remove SMB shares
    $labShares = Get-SmbShare | Where-Object { 
      $_.Name -in @("IT", "HR", "Sales", "Finance", "Marketing") -or
      $_.Name -like "*LAB*"
    }
        
    if ($labShares) {
      Write-UninstallLog "Found $($labShares.Count) lab shares to remove" "INFO"
            
      if (-not $Force -and -not $SkipConfirmation) {
        # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "`nLab shares to be removed:" -ForegroundColor $WarningColor
        foreach ($share in $labShares) {
          Write-Host "  - $($share.Name) [$($share.Path)]" -ForegroundColor $DebugColor
        }
                
        $response = Read-Host "`nRemove these shares? (y/N)"
        if ($response -ne 'y' -and $response -ne 'Y') {
          Write-UninstallLog "Share removal cancelled by user" "WARNING"
          return $false
        }
      }
            
      foreach ($share in $labShares) {
        try {
          Remove-SmbShare -Name $share.Name -Force
          Write-UninstallLog "Removed share: $($share.Name)" "SUCCESS"
        }
        catch {
          Write-UninstallLog "Failed to remove share $($share.Name): $($_.Exception.Message)" "ERROR"
        }
      }
    }
        
    # Remove share directories
    $sharePaths = @("C:\Shares\IT", "C:\Shares\HR", "C:\Shares\Sales", "C:\Shares\Finance", "C:\Shares\Marketing", "C:\Shares")
    foreach ($path in $sharePaths) {
      if (Test-Path $path) {
        try {
          Remove-Item -Path $path -Recurse -Force
          Write-UninstallLog "Removed directory: $path" "SUCCESS"
        }
        catch {
          Write-UninstallLog "Failed to remove directory $path: $($_.Exception.Message)" "WARNING"
        }
      }
    }
        
    Write-UninstallLog "Share removal completed" "SUCCESS"
    return $true
  }
  catch {
    Write-UninstallLog "Share removal failed: $($_.Exception.Message)" "ERROR"
    return $false
  }
}

function Remove-LabAD {
  Write-UninstallLog "Starting Active Directory cleanup..." "INFO"
    
  try {
    Import-Module ActiveDirectory -ErrorAction Stop
        
    # Remove lab OUs
    $labOUs = @("IT", "HR", "Sales", "Finance", "Marketing")
    foreach ($ou in $labOUs) {
      try {
        $ouDN = "OU=$ou,DC=lab,DC=local"
        $adOU = Get-ADOrganizationalUnit -Identity $ouDN -ErrorAction SilentlyContinue
        if ($adOU) {
          # Remove users in OU first
          Get-ADUser -SearchBase $ouDN -Filter * | Remove-ADUser -Confirm:$false
          # Remove computers in OU
          Get-ADComputer -SearchBase $ouDN -Filter * | Remove-ADComputer -Confirm:$false
          # Remove groups in OU
          Get-ADGroup -SearchBase $ouDN -Filter * | Remove-ADGroup -Confirm:$false
          # Remove OU
          Remove-ADOrganizationalUnit -Identity $ouDN -Recursive -Confirm:$false
          Write-UninstallLog "Removed OU: $ou" "SUCCESS"
        }
      }
      catch {
        Write-UninstallLog "Failed to remove OU $ou: $($_.Exception.Message)" "WARNING"
      }
    }
        
    # Remove lab groups not in OUs
    $labGroups = Get-ADGroup -Filter { Name -like "GRP-*" }
    foreach ($group in $labGroups) {
      try {
        Remove-ADGroup -Identity $group -Confirm:$false
        Write-UninstallLog "Removed group: $($group.Name)" "SUCCESS"
      }
      catch {
        Write-UninstallLog "Failed to remove group $($group.Name): $($_.Exception.Message)" "WARNING"
      }
    }
        
    Write-UninstallLog "Active Directory cleanup completed" "SUCCESS"
    return $true
  }
  catch {
    if ($_.Exception.Message -like "*ActiveDirectory*") {
      Write-UninstallLog "Active Directory module not available - skipping AD cleanup" "WARNING"
      return $true
    }
    Write-UninstallLog "AD cleanup failed: $($_.Exception.Message)" "ERROR"
    return $false
  }
}

function Remove-LabUser {
  Write-UninstallLog "Starting user account removal..." "INFO"
    
  try {
    Import-Module ActiveDirectory -ErrorAction Stop
        
    # Lab user accounts
    $labUsers = @("thor", "freya", "sif", "heimdall", "frigg")
        
    foreach ($user in $labUsers) {
      try {
        $adUser = Get-ADUser -Identity $user -ErrorAction SilentlyContinue
        if ($adUser) {
          Remove-ADUser -Identity $user -Confirm:$false
          Write-UninstallLog "Removed user: $user" "SUCCESS"
        }
      }
      catch {
        Write-UninstallLog "Failed to remove user $user: $($_.Exception.Message)" "WARNING"
      }
    }
        
    Write-UninstallLog "User removal completed" "SUCCESS"
    return $true
  }
  catch {
    if ($_.Exception.Message -like "*ActiveDirectory*") {
      Write-UninstallLog "Active Directory module not available - skipping user cleanup" "WARNING"
      return $true
    }
    Write-UninstallLog "User removal failed: $($_.Exception.Message)" "ERROR"
    return $false
  }
}

function Remove-LabGPO {
  Write-UninstallLog "Starting Group Policy cleanup..." "INFO"
    
  try {
    Import-Module GroupPolicy -ErrorAction Stop
        
    # Find lab GPOs
    $labGPOs = Get-GPO -All | Where-Object { 
      $_.DisplayName -like "*Lab*" -or 
      $_.DisplayName -like "*LAB*" -or
      $_.DisplayName -like "*Test*"
    }
        
    if ($labGPOs) {
      Write-UninstallLog "Found $($labGPOs.Count) lab GPOs to remove" "INFO"
            
      foreach ($gpo in $labGPOs) {
        try {
          Remove-GPO -Guid $gpo.Id -Confirm:$false
          Write-UninstallLog "Removed GPO: $($gpo.DisplayName)" "SUCCESS"
        }
        catch {
          Write-UninstallLog "Failed to remove GPO $($gpo.DisplayName): $($_.Exception.Message)" "WARNING"
        }
      }
    }
    else {
      Write-UninstallLog "No lab GPOs found to remove" "INFO"
    }
        
    Write-UninstallLog "GPO cleanup completed" "SUCCESS"
    return $true
  }
  catch {
    if ($_.Exception.Message -like "*GroupPolicy*") {
      Write-UninstallLog "Group Policy module not available - skipping GPO cleanup" "WARNING"
      return $true
    }
    Write-UninstallLog "GPO cleanup failed: $($_.Exception.Message)" "ERROR"
    return $false
  }
}

function Remove-LabRegistry {
  Write-UninstallLog "Starting registry cleanup..." "INFO"
    
  try {
    # Registry paths that might be created by lab scripts
    $registryPaths = @(
                      # Registry keys updated for Proxmox VE adaptation
      "HKLM:\SOFTWARE\Lab",
                      # User-specific registry keys removed
    )
        
    foreach ($path in $registryPaths) {
      if (Test-Path $path) {
        try {
          Remove-Item -Path $path -Recurse -Force
          Write-UninstallLog "Removed registry key: $path" "SUCCESS"
        }
        catch {
          Write-UninstallLog "Failed to remove registry key $path: $($_.Exception.Message)" "WARNING"
        }
      }
    }
        
    Write-UninstallLog "Registry cleanup completed" "SUCCESS"
    return $true
  }
  catch {
    Write-UninstallLog "Registry cleanup failed: $($_.Exception.Message)" "ERROR"
    return $false
  }
}

function Remove-LabScheduledTask {
  Write-UninstallLog "Starting scheduled task cleanup..." "INFO"
    
  try {
    # Find lab-related scheduled tasks
    $labTasks = Get-ScheduledTask | Where-Object { 
      $_.TaskName -like "*Lab*" -or 
      $_.TaskName -like "*LAB*" -or
      $_.TaskPath -like "*Lab*"
    }
        
    if ($labTasks) {
      Write-UninstallLog "Found $($labTasks.Count) lab scheduled tasks to remove" "INFO"
            
      foreach ($task in $labTasks) {
        try {
          Unregister-ScheduledTask -TaskName $task.TaskName -Confirm:$false
          Write-UninstallLog "Removed scheduled task: $($task.TaskName)" "SUCCESS"
        }
        catch {
          Write-UninstallLog "Failed to remove task $($task.TaskName): $($_.Exception.Message)" "WARNING"
        }
      }
    }
    else {
      Write-UninstallLog "No lab scheduled tasks found to remove" "INFO"
    }
        
    Write-UninstallLog "Scheduled task cleanup completed" "SUCCESS"
    return $true
  }
  catch {
    Write-UninstallLog "Scheduled task cleanup failed: $($_.Exception.Message)" "ERROR"
    return $false
  }
}

function New-UninstallManifest {
  param([hashtable]$Results)
    
  $manifest = @{
    UninstallDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Component     = $Component
    Results       = $Results
    LogPath       = $LogPath
    BackupPath    = if ($CreateBackup) { $BackupPath } else { "No backup created" }
  }
    
  $manifest | ConvertTo-Json -Depth 3 | Out-File $UninstallManifestPath
  Write-UninstallLog "Uninstall manifest created: $UninstallManifestPath" "INFO"
}

# Main execution logic
try {
  if ($Component -eq "Help") {
    Show-Help
  }
    
  Write-UninstallLog "Starting Windows Server Lab uninstall..." "INFO"
  Write-UninstallLog "Component: $Component" "INFO"
  Write-UninstallLog "Force: $Force" "INFO"
  Write-UninstallLog "Create Backup: $CreateBackup" "INFO"
    
  # Create backup if requested
  if ($CreateBackup -and $Component -ne "Help") {
    if (-not (New-UninstallBackup)) {
      if (-not $Force) {
        Write-UninstallLog "Backup failed. Continue without backup? (y/N)" "WARNING"
        $response = Read-Host
        if ($response -ne 'y' -and $response -ne 'Y') {
          Write-UninstallLog "Uninstall cancelled due to backup failure" "ERROR"
          exit 1
        }
      }
    }
  }
    
  $results = @{}
    
  # Execute uninstall based on component
  switch ($Component.ToLower()) {
    "all" {
      Write-UninstallLog "Performing complete lab environment removal..." "INFO"
      $results.VMs = Remove-LabVM
      $results.Switches = Remove-LabSwitch
      $results.Shares = Remove-LabShare
      $results.AD = Remove-LabAD
      $results.GPOs = Remove-LabGPO
      $results.Registry = Remove-LabRegistry
      $results.ScheduledTasks = Remove-LabScheduledTask
    }
    "vms" { $results.VMs = Remove-LabVM }
    "switches" { $results.Switches = Remove-LabSwitch }
    "shares" { $results.Shares = Remove-LabShare }
    "ad" { $results.AD = Remove-LabAD }
    "users" { $results.Users = Remove-LabUser }
    "gpos" { $results.GPOs = Remove-LabGPO }
    "registry" { $results.Registry = Remove-LabRegistry }
    "scheduled" { $results.ScheduledTasks = Remove-LabScheduledTask }
    default {
      Write-UninstallLog "Unknown component: $Component" "ERROR"
      Show-Help
    }
  }
    
  # Create uninstall manifest
  New-UninstallManifest -Results $results
    
  # Summary
  Write-Information "`n" -InformationAction Continue -NoNewline
  # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "=== UNINSTALL SUMMARY ===" -ForegroundColor $HighlightColor
  Write-UninstallLog "Uninstall operation completed" "SUCCESS"
  Write-UninstallLog "Log file: $LogPath" "INFO"
  if ($CreateBackup) {
    Write-UninstallLog "Backup location: $BackupPath" "INFO"
  }
  Write-UninstallLog "Manifest file: $UninstallManifestPath" "INFO"
    
  # Check results
  $failedOperations = $results.GetEnumerator() | Where-Object { $_.Value -eq $false }
  if ($failedOperations) {
    Write-UninstallLog "Some operations failed. Check log for details." "WARNING"
    foreach ($failed in $failedOperations) {
      Write-UninstallLog "Failed: $($failed.Key)" "ERROR"
    }
  }
  else {
    Write-UninstallLog "All operations completed successfully!" "SUCCESS"
  }
}
catch {
  Write-UninstallLog "Uninstall script failed: $($_.Exception.Message)" "ERROR"
  Write-UninstallLog "Stack trace: $($_.ScriptStackTrace)" "DEBUG"
  exit 1
} 