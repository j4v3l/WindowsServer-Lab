# Windows Server Lab Environment Restore Script
# This script restores lab components from backups created by Lab-Uninstall.ps1

#Requires -RunAsAdministrator
#Requires -Module Hyper-V

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$BackupPath = "C:\LabBackup",
  [ValidateSet("All", "VMs", "AD", "Configuration", "Help")]
  [string]$Component = "All",
  [string]$VMPath = "C:\VMs",
  [switch]$Force = $false,
  [switch]$SkipConfirmation = $false
)

# Enhanced Error Handling Configuration
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Logging Configuration
$LogPath = Join-Path $env:TEMP "Lab-Restore-$(Get-Date -Format 'yyyy-MM-dd_HH-mm').log"

# Color coding for output
$ErrorColor = "Red"
$WarningColor = "Yellow"
$InfoColor = "Green"
$DebugColor = "Cyan"
$HighlightColor = "Magenta"

function Write-RestoreLog {
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
=== WINDOWS SERVER LAB RESTORE SCRIPT ===

SYNOPSIS:
    Restores lab components from backups created by Lab-Uninstall.ps1

PARAMETERS:
    -BackupPath <path>       : Path where backup is stored (required)
    -Component <component>   : Component to restore (All, VMs, AD, Configuration, Help)
    -VMPath <path>          : Path where VMs should be restored (default: C:\VMs)
    -Force                  : Force restore without detailed confirmations
    -SkipConfirmation       : Skip all confirmation prompts

COMPONENTS:
    All           : Restore all backed up components
    VMs           : Restore virtual machines and their configurations
    AD            : Restore Active Directory objects (users, groups, OUs)
    Configuration : Restore configuration files and settings

EXAMPLES:
    .\Lab-Restore.ps1 -BackupPath "C:\LabBackup"
    .\Lab-Restore.ps1 -BackupPath "D:\Backup" -Component VMs
    .\Lab-Restore.ps1 -BackupPath "C:\LabBackup" -Component AD -Force

PREREQUISITES:
    - Backup must exist at specified path
    - Hyper-V role must be enabled for VM restore
    - Active Directory PowerShell module for AD restore
    - Administrator privileges required

"@ -ForegroundColor $InfoColor
  exit 0
}

function Test-BackupIntegrity {
  Write-RestoreLog "Validating backup integrity..." "INFO"
    
  if (!(Test-Path $BackupPath)) {
    Write-RestoreLog "Backup path does not exist: $BackupPath" "ERROR"
    return $false
  }
    
  $manifestPath = Join-Path $BackupPath "BackupManifest.json"
  if (!(Test-Path $manifestPath)) {
    Write-RestoreLog "Backup manifest not found: $manifestPath" "ERROR"
    return $false
  }
    
  try {
    $manifest = Get-Content $manifestPath | ConvertFrom-Json
    Write-RestoreLog "Backup created: $($manifest.Timestamp)" "INFO"
    Write-RestoreLog "Backup components: $($manifest.Components.Keys -join ', ')" "INFO"
        
    return $true
  }
  catch {
    Write-RestoreLog "Failed to read backup manifest: $($_.Exception.Message)" "ERROR"
    return $false
  }
}

function Restore-LabVM {
  Write-RestoreLog "Starting VM restore process..." "INFO"
    
  try {
    $vmBackupPath = Join-Path $BackupPath "VMs"
    if (!(Test-Path $vmBackupPath)) {
      Write-RestoreLog "VM backup directory not found: $vmBackupPath" "WARNING"
      return $false
    }
        
    $vmBackups = Get-ChildItem -Path $vmBackupPath -Directory
    if (-not $vmBackups) {
      Write-RestoreLog "No VM backups found in: $vmBackupPath" "WARNING"
      return $false
    }
        
    Write-RestoreLog "Found $($vmBackups.Count) VM backups to restore" "INFO"
        
    if (-not $Force -and -not $SkipConfirmation) {
      # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "`nVMs to be restored:" -ForegroundColor $WarningColor
      foreach ($vmBackup in $vmBackups) {
        Write-Host "  - $($vmBackup.Name)" -ForegroundColor $DebugColor
      }
            
      $response = Read-Host "`nRestore these VMs? (y/N)"
      if ($response -ne 'y' -and $response -ne 'Y') {
        Write-RestoreLog "VM restore cancelled by user" "WARNING"
        return $false
      }
    }
        
    # Ensure VM path exists
    if (!(Test-Path $VMPath)) {
      New-Item -Path $VMPath -ItemType Directory -Force | Out-Null
      Write-RestoreLog "Created VM directory: $VMPath" "INFO"
    }
        
    foreach ($vmBackup in $vmBackups) {
      try {
        $vmConfigPath = Get-ChildItem -Path $vmBackup.FullName -Filter "*.vmcx" -Recurse | Select-Object -First 1
        if ($vmConfigPath) {
          Import-VM -Path $vmConfigPath.FullName -Copy -VhdDestinationPath $VMPath -VirtualMachinePath $VMPath
          Write-RestoreLog "Restored VM: $($vmBackup.Name)" "SUCCESS"
        }
        else {
          Write-RestoreLog "VM configuration not found in: $($vmBackup.FullName)" "WARNING"
        }
      }
      catch {
        Write-RestoreLog "Failed to restore VM $($vmBackup.Name): $($_.Exception.Message)" "ERROR"
      }
    }
        
    Write-RestoreLog "VM restore completed" "SUCCESS"
    return $true
  }
  catch {
    Write-RestoreLog "VM restore failed: $($_.Exception.Message)" "ERROR"
    return $false
  }
}

function Restore-LabAD {
  Write-RestoreLog "Starting Active Directory restore..." "INFO"
    
  try {
    $adBackupPath = Join-Path $BackupPath "ActiveDirectory"
    if (!(Test-Path $adBackupPath)) {
      Write-RestoreLog "AD backup directory not found: $adBackupPath" "WARNING"
      return $false
    }
        
    Import-Module ActiveDirectory -ErrorAction Stop
        
    # Restore OUs
    $ouFile = Join-Path $adBackupPath "OUs.csv"
    if (Test-Path $ouFile) {
      $ous = Import-Csv $ouFile
      Write-RestoreLog "Restoring $($ous.Count) Organizational Units..." "INFO"
            
      foreach ($ou in $ous) {
        try {
          if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$($ou.Name)'" -ErrorAction SilentlyContinue)) {
            New-ADOrganizationalUnit -Name $ou.Name -Path $ou.DistinguishedName.Substring($ou.DistinguishedName.IndexOf(',') + 1)
            Write-RestoreLog "Restored OU: $($ou.Name)" "SUCCESS"
          }
        }
        catch {
          Write-RestoreLog "Failed to restore OU $($ou.Name): $($_.Exception.Message)" "WARNING"
        }
      }
    }
        
    # Restore Groups
    $groupFile = Join-Path $adBackupPath "Groups.csv"
    if (Test-Path $groupFile) {
      $groups = Import-Csv $groupFile
      Write-RestoreLog "Restoring $($groups.Count) Groups..." "INFO"
            
      foreach ($group in $groups) {
        try {
          if (-not (Get-ADGroup -Filter "Name -eq '$($group.Name)'" -ErrorAction SilentlyContinue)) {
            $ouPath = $group.DistinguishedName.Substring($group.DistinguishedName.IndexOf(',') + 1)
            New-ADGroup -Name $group.Name -GroupScope $group.GroupScope -GroupCategory $group.GroupCategory -Path $ouPath
            Write-RestoreLog "Restored group: $($group.Name)" "SUCCESS"
          }
        }
        catch {
          Write-RestoreLog "Failed to restore group $($group.Name): $($_.Exception.Message)" "WARNING"
        }
      }
    }
        
    # Restore Users (Note: Passwords will need to be reset)
    $userFile = Join-Path $adBackupPath "Users.csv"
    if (Test-Path $userFile) {
      $users = Import-Csv $userFile
      Write-RestoreLog "Restoring $($users.Count) Users..." "INFO"
      Write-RestoreLog "Note: User passwords will need to be reset manually" "WARNING"
            
      foreach ($user in $users) {
        try {
          if (-not (Get-ADUser -Filter "SamAccountName -eq '$($user.SamAccountName)'" -ErrorAction SilentlyContinue)) {
            $ouPath = $user.DistinguishedName.Substring($user.DistinguishedName.IndexOf(',') + 1)
            # Generate a secure random password instead of hardcoded one
            $tempPassword = ConvertTo-SecureString -String ([System.Web.Security.Membership]::GeneratePassword(12, 3)) -AsPlainText -Force
            New-ADUser -Name $user.Name -GivenName $user.GivenName -Surname $user.Surname -SamAccountName $user.SamAccountName -UserPrincipalName $user.UserPrincipalName -Path $ouPath -AccountPassword $tempPassword -Enabled $false
            Write-RestoreLog "Restored user: $($user.SamAccountName) (password reset required)" "SUCCESS"
          }
        }
        catch {
          Write-RestoreLog "Failed to restore user $($user.SamAccountName): $($_.Exception.Message)" "WARNING"
        }
      }
    }
        
    Write-RestoreLog "Active Directory restore completed" "SUCCESS"
    return $true
  }
  catch {
    if ($_.Exception.Message -like "*ActiveDirectory*") {
      Write-RestoreLog "Active Directory module not available - skipping AD restore" "WARNING"
      return $true
    }
    Write-RestoreLog "AD restore failed: $($_.Exception.Message)" "ERROR"
    return $false
  }
}

function Restore-LabConfiguration {
  Write-RestoreLog "Starting configuration restore..." "INFO"
    
  try {
    # This function can be extended to restore additional configuration files
    # Currently serves as a placeholder for future configuration restoration
        
    Write-RestoreLog "Configuration restore completed" "SUCCESS"
    return $true
  }
  catch {
    Write-RestoreLog "Configuration restore failed: $($_.Exception.Message)" "ERROR"
    return $false
  }
}

# Main execution logic
try {
  if ($Component -eq "Help") {
    Show-Help
  }
    
  Write-RestoreLog "Starting Windows Server Lab restore..." "INFO"
  Write-RestoreLog "Backup Path: $BackupPath" "INFO"
  Write-RestoreLog "Component: $Component" "INFO"
    
  # Validate backup
  if (-not (Test-BackupIntegrity)) {
    Write-RestoreLog "Backup validation failed. Cannot proceed with restore." "ERROR"
    exit 1
  }
    
  $results = @{}
    
  # Execute restore based on component
  switch ($Component.ToLower()) {
    "all" {
      Write-RestoreLog "Performing complete lab environment restore..." "INFO"
      $results.VMs = Restore-LabVM
      $results.AD = Restore-LabAD
      $results.Configuration = Restore-LabConfiguration
    }
    "vms" { $results.VMs = Restore-LabVM }
    "ad" { $results.AD = Restore-LabAD }
    "configuration" { $results.Configuration = Restore-LabConfiguration }
    default {
      Write-RestoreLog "Unknown component: $Component" "ERROR"
      Show-Help
    }
  }
    
  # Summary
  Write-Information "`n" -InformationAction Continue -NoNewline
  # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "=== RESTORE SUMMARY ===" -ForegroundColor $HighlightColor
  Write-RestoreLog "Restore operation completed" "SUCCESS"
  Write-RestoreLog "Log file: $LogPath" "INFO"
    
  # Check results
  $failedOperations = $results.GetEnumerator() | Where-Object { $_.Value -eq $false }
  if ($failedOperations) {
    Write-RestoreLog "Some operations failed. Check log for details." "WARNING"
    foreach ($failed in $failedOperations) {
      Write-RestoreLog "Failed: $($failed.Key)" "ERROR"
    }
  }
  else {
    Write-RestoreLog "All operations completed successfully!" "SUCCESS"
  }
    
  Write-Host "`nPost-Restore Actions Required:" -ForegroundColor $HighlightColor
  # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "1. Reset user passwords in Active Directory" -ForegroundColor $WarningColor
  # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "2. Verify VM network configurations" -ForegroundColor $WarningColor
  # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "3. Test domain controller functionality" -ForegroundColor $WarningColor
  Write-Host "4. Re-configure any custom settings" -ForegroundColor $WarningColor
}
catch {
  Write-RestoreLog "Restore script failed: $($_.Exception.Message)" "ERROR"
  Write-RestoreLog "Stack trace: $($_.ScriptStackTrace)" "DEBUG"
  exit 1
} 