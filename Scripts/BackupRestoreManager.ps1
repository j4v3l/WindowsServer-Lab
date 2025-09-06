# Backup and Restore Management Script
# EXECUTION CONTEXT: Run INSIDE Windows Server VMs (Domain Controllers or File Servers)
# ACCESS METHOD: RDP, Console, or PowerShell Direct to Windows VMs
# PREREQUISITES: Local Administrator rights, sufficient storage space

# This script provides automated backup and restore functionality for Windows Server

# Import required modules
Import-Module ActiveDirectory
Import-Module ServerManager

# Configuration
$backupConfig = @{
    BackupPath = "D:\Backups"
    RetentionDays = 30
    LogPath = "C:\Logs\Backup"
    BackupTypes = @("SystemState", "AD", "Files")
}

# Create necessary directories
New-Item -Path $backupConfig.BackupPath -ItemType Directory -Force -ErrorAction SilentlyContinue
New-Item -Path $backupConfig.LogPath -ItemType Directory -Force -ErrorAction SilentlyContinue

# Function to create backup
function Start-Backup {
    param (
        [string]$BackupType
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm"
    $logFile = Join-Path $backupConfig.LogPath "backup_${BackupType}_${timestamp}.log"
    
    try {
        switch ($BackupType) {
            "SystemState" {
                # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "Starting System State backup..." -ForegroundColor Yellow
                $backupPath = Join-Path $backupConfig.BackupPath "SystemState_$timestamp"
                wbadmin start systemstatebackup -backupTarget:$backupPath -quiet
            }
            "AD" {
                # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "Starting Active Directory backup..." -ForegroundColor Yellow
                $backupPath = Join-Path $backupConfig.BackupPath "AD_$timestamp"
                ntdsutil "activate instance ntds" "ifm" "create full $backupPath" "quit" "quit"
            }
            "Files" {
                # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "Starting File System backup..." -ForegroundColor Yellow
                $backupPath = Join-Path $backupConfig.BackupPath "Files_$timestamp"
                $sourcePaths = @(
                    "C:\Shares",
                    "C:\ImportantData"
                )
                
                foreach ($source in $sourcePaths) {
                    if (Test-Path $source) {
                        $destination = Join-Path $backupPath (Split-Path $source -Leaf)
                        Copy-Item -Path $source -Destination $destination -Recurse -Force
                    }
                }
            }
        }
        
        "Backup completed successfully at $(Get-Date)" | Out-File -FilePath $logFile -Append
        # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "Backup completed successfully!" -ForegroundColor Green
    }
    catch {
        $errorMessage = "Backup failed: $_"
        $errorMessage | Out-File -FilePath $logFile -Append
        # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host $errorMessage -ForegroundColor Red
    }
}

# Function to restore from backup
function Start-Restore {
    param (
        [string]$BackupType,
        [string]$BackupDate
    )
    
    $logFile = Join-Path $backupConfig.LogPath "restore_${BackupType}_$(Get-Date -Format 'yyyy-MM-dd_HH-mm').log"
    
    try {
        switch ($BackupType) {
            "SystemState" {
                # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "Starting System State restore..." -ForegroundColor Yellow
                $backupPath = Get-ChildItem -Path $backupConfig.BackupPath -Filter "SystemState_$BackupDate*" | Select-Object -First 1
                if ($backupPath) {
                    wbadmin start systemstaterecovery -backupTarget:$backupPath.FullName -quiet
                }
            }
            "AD" {
                # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "Starting Active Directory restore..." -ForegroundColor Yellow
                $backupPath = Get-ChildItem -Path $backupConfig.BackupPath -Filter "AD_$BackupDate*" | Select-Object -First 1
                if ($backupPath) {
                    ntdsutil "activate instance ntds" "ifm" "restore full $($backupPath.FullName)" "quit" "quit"
                }
            }
            "Files" {
                # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "Starting File System restore..." -ForegroundColor Yellow
                $backupPath = Get-ChildItem -Path $backupConfig.BackupPath -Filter "Files_$BackupDate*" | Select-Object -First 1
                if ($backupPath) {
                    $sourcePaths = @(
                        "C:\Shares",
                        "C:\ImportantData"
                    )
                    
                    foreach ($source in $sourcePaths) {
                        $backupSource = Join-Path $backupPath.FullName (Split-Path $source -Leaf)
                        if (Test-Path $backupSource) {
                            Copy-Item -Path $backupSource -Destination $source -Recurse -Force
                        }
                    }
                }
            }
        }
        
        "Restore completed successfully at $(Get-Date)" | Out-File -FilePath $logFile -Append
        # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "Restore completed successfully!" -ForegroundColor Green
    }
    catch {
        $errorMessage = "Restore failed: $_"
        $errorMessage | Out-File -FilePath $logFile -Append
        # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host $errorMessage -ForegroundColor Red
    }
}

# Function to clean up old backups
function Remove-OldBackup {
    $cutoffDate = (Get-Date).AddDays(-$backupConfig.RetentionDays)
    
    Get-ChildItem -Path $backupConfig.BackupPath -Recurse | Where-Object {
        $_.LastWriteTime -lt $cutoffDate
    } | Remove-Item -Recurse -Force
    
    # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "Cleaned up backups older than $($backupConfig.RetentionDays) days" -ForegroundColor Yellow
}

# Function to list available backups
function Get-BackupList {
    $backups = Get-ChildItem -Path $backupConfig.BackupPath -Recurse | Group-Object {
        if ($_.Name -match "SystemState_") { "SystemState" }
        elseif ($_.Name -match "AD_") { "AD" }
        elseif ($_.Name -match "Files_") { "Files" }
    }
    
    foreach ($group in $backups) {
        # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "`n$($group.Name) Backups:" -ForegroundColor Cyan
        $group.Group | Sort-Object LastWriteTime -Descending | ForEach-Object {
            Write-Information "  $($_.Name) - $($_.LastWriteTime)" -InformationAction Continue
        }
    }
}

# Example usage:
# Start-Backup -BackupType "SystemState"
# Start-Backup -BackupType "AD"
# Start-Backup -BackupType "Files"
# Start-Restore -BackupType "SystemState" -BackupDate "2024-03-20"
# Remove-OldBackup
# Get-BackupList 