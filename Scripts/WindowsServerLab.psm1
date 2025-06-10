# Windows Server Lab Environment PowerShell Module
# This module provides comprehensive lab management functionality

# Module Configuration
$ModuleRoot = $PSScriptRoot
$ModuleVersion = "1.1.0"

# Import required modules with error handling
try {
    Import-Module Hyper-V -ErrorAction Stop
    Import-Module ActiveDirectory -ErrorAction SilentlyContinue
}
catch {
    Write-Warning "Some required modules are not available. Full functionality may be limited."
}

# Common Configuration
$script:LabConfig = @{
    DefaultVMPath     = "C:\VMs"
    DefaultDomainName = "lab.local"
    LogPath           = Join-Path $env:TEMP "WindowsServerLab.log"
}

# Common Logging Function
function Write-LabLog {
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARNING", "ERROR", "SUCCESS", "DEBUG")]
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Add-Content -Path $script:LabConfig.LogPath -Value $logEntry -ErrorAction SilentlyContinue
    
    # Also write to console with color
    switch ($Level) {
        "ERROR" { Write-Host "❌ $Message" -ForegroundColor Red }
        "WARNING" { Write-Host "⚠️  $Message" -ForegroundColor Yellow }
        "SUCCESS" { Write-Host "✅ $Message" -ForegroundColor Green }
        "INFO" { Write-Host "ℹ️  $Message" -ForegroundColor Cyan }
        "DEBUG" { Write-Host "🔍 $Message" -ForegroundColor Gray }
    }
}

# Wrapper Functions for Main Scripts

function New-LabEnvironment {
    <#
    .SYNOPSIS
        Creates a complete lab environment with Hyper-V VMs and networking
    .DESCRIPTION
        This function creates a complete Windows Server lab environment including
        virtual switches, VMs, and basic configuration
    .PARAMETER VMPath
        Path where VMs will be stored
    .PARAMETER ISOPath
        Path to Windows Server ISO file
    .PARAMETER DomainName
        Domain name for the lab environment
    .PARAMETER Force
        Force recreation of existing components
    .EXAMPLE
        New-LabEnvironment -VMPath "D:\VMs" -ISOPath "C:\ISO\WindowsServer2022.iso"
    #>
    [CmdletBinding()]
    param(
        [string]$VMPath = $script:LabConfig.DefaultVMPath,
        [string]$ISOPath = "",
        [string]$DomainName = $script:LabConfig.DefaultDomainName,
        [switch]$Force
    )
    
    Write-LabLog "Starting lab environment creation..." "INFO"
    
    try {
        $scriptPath = Join-Path $ModuleRoot "Hyper-V_Lab_Setup.ps1"
        if (Test-Path $scriptPath) {
            & $scriptPath -VMPath $VMPath -ISOPath $ISOPath -DomainName $DomainName -Force:$Force
        }
        else {
            throw "Hyper-V_Lab_Setup.ps1 script not found at $scriptPath"
        }
    }
    catch {
        Write-LabLog "Failed to create lab environment: $($_.Exception.Message)" "ERROR"
        throw
    }
}

function Test-LabEnvironment {
    <#
    .SYNOPSIS
        Validates the lab environment configuration
    .DESCRIPTION
        This function performs comprehensive validation of the lab environment
        including prerequisites, Hyper-V configuration, and network setup
    .PARAMETER Detailed
        Show detailed validation information
    .EXAMPLE
        Test-LabEnvironment -Detailed
    #>
    [CmdletBinding()]
    param(
        [switch]$Detailed
    )
    
    Write-LabLog "Starting lab environment validation..." "INFO"
    
    try {
        $scriptPath = Join-Path $ModuleRoot "Test-LabEnvironment.ps1"
        if (Test-Path $scriptPath) {
            & $scriptPath -Detailed:$Detailed
        }
        else {
            throw "Test-LabEnvironment.ps1 script not found at $scriptPath"
        }
    }
    catch {
        Write-LabLog "Failed to validate lab environment: $($_.Exception.Message)" "ERROR"
        throw
    }
}

function Start-LabVMs {
    <#
    .SYNOPSIS
        Starts all lab virtual machines
    .DESCRIPTION
        This function starts all VMs in the lab environment in the correct order
    .PARAMETER VMNames
        Specific VM names to start (optional)
    .EXAMPLE
        Start-LabVMs
    .EXAMPLE
        Start-LabVMs -VMNames "DC1-LAB", "FS1-LAB"
    #>
    [CmdletBinding()]
    param(
        [string[]]$VMNames = @()
    )
    
    Write-LabLog "Starting lab VMs..." "INFO"
    
    try {
        $scriptPath = Join-Path $ModuleRoot "Hyper-V_Management.ps1"
        if (Test-Path $scriptPath) {
            if ($VMNames.Count -gt 0) {
                foreach ($vmName in $VMNames) {
                    & $scriptPath -Action Start -VMName $vmName
                }
            }
            else {
                & $scriptPath -Action Start
            }
        }
        else {
            throw "Hyper-V_Management.ps1 script not found at $scriptPath"
        }
    }
    catch {
        Write-LabLog "Failed to start lab VMs: $($_.Exception.Message)" "ERROR"
        throw
    }
}

function Stop-LabVMs {
    <#
    .SYNOPSIS
        Stops all lab virtual machines
    .DESCRIPTION
        This function safely stops all VMs in the lab environment
    .PARAMETER VMNames
        Specific VM names to stop (optional)
    .PARAMETER Force
        Force shutdown of VMs
    .EXAMPLE
        Stop-LabVMs
    .EXAMPLE
        Stop-LabVMs -VMNames "CL1-LAB" -Force
    #>
    [CmdletBinding()]
    param(
        [string[]]$VMNames = @(),
        [switch]$Force
    )
    
    Write-LabLog "Stopping lab VMs..." "INFO"
    
    try {
        $scriptPath = Join-Path $ModuleRoot "Hyper-V_Management.ps1"
        if (Test-Path $scriptPath) {
            if ($VMNames.Count -gt 0) {
                foreach ($vmName in $VMNames) {
                    if ($Force) {
                        & $scriptPath -Action Stop -VMName $vmName -Force
                    }
                    else {
                        & $scriptPath -Action Stop -VMName $vmName
                    }
                }
            }
            else {
                if ($Force) {
                    & $scriptPath -Action Stop -Force
                }
                else {
                    & $scriptPath -Action Stop
                }
            }
        }
        else {
            throw "Hyper-V_Management.ps1 script not found at $scriptPath"
        }
    }
    catch {
        Write-LabLog "Failed to stop lab VMs: $($_.Exception.Message)" "ERROR"
        throw
    }
}

function Get-LabStatus {
    <#
    .SYNOPSIS
        Gets the current status of the lab environment
    .DESCRIPTION
        This function returns detailed status information about the lab environment
        including VM states, network configuration, and resource usage
    .EXAMPLE
        Get-LabStatus
    #>
    [CmdletBinding()]
    param()
    
    Write-LabLog "Getting lab status..." "INFO"
    
    try {
        $scriptPath = Join-Path $ModuleRoot "Hyper-V_Management.ps1"
        if (Test-Path $scriptPath) {
            & $scriptPath -Action Status
        }
        else {
            throw "Hyper-V_Management.ps1 script not found at $scriptPath"
        }
    }
    catch {
        Write-LabLog "Failed to get lab status: $($_.Exception.Message)" "ERROR"
        throw
    }
}

function New-LabUsers {
    <#
    .SYNOPSIS
        Creates lab users and organizational structure
    .DESCRIPTION
        This function creates users, groups, and organizational units for the lab environment
    .EXAMPLE
        New-LabUsers
    #>
    [CmdletBinding()]
    param()
    
    Write-LabLog "Creating lab users..." "INFO"
    
    try {
        $scriptPath = Join-Path $ModuleRoot "Create-LabUsers.ps1"
        if (Test-Path $scriptPath) {
            & $scriptPath
        }
        else {
            throw "Create-LabUsers.ps1 script not found at $scriptPath"
        }
    }
    catch {
        Write-LabLog "Failed to create lab users: $($_.Exception.Message)" "ERROR"
        throw
    }
}

function Invoke-LabSecurityAudit {
    <#
    .SYNOPSIS
        Performs a security audit of the lab environment
    .DESCRIPTION
        This function runs a comprehensive security audit and generates a report
    .EXAMPLE
        Invoke-LabSecurityAudit
    #>
    [CmdletBinding()]
    param()
    
    Write-LabLog "Starting security audit..." "INFO"
    
    try {
        $scriptPath = Join-Path $ModuleRoot "SecurityAudit.ps1"
        if (Test-Path $scriptPath) {
            & $scriptPath
        }
        else {
            throw "SecurityAudit.ps1 script not found at $scriptPath"
        }
    }
    catch {
        Write-LabLog "Failed to perform security audit: $($_.Exception.Message)" "ERROR"
        throw
    }
}

function Set-LabGroupPolicy {
    <#
    .SYNOPSIS
        Configures Group Policy for the lab environment
    .DESCRIPTION
        This function sets up standard Group Policy Objects for the lab
    .EXAMPLE
        Set-LabGroupPolicy
    #>
    [CmdletBinding()]
    param()
    
    Write-LabLog "Configuring Group Policy..." "INFO"
    
    try {
        $scriptPath = Join-Path $ModuleRoot "GroupPolicyManager.ps1"
        if (Test-Path $scriptPath) {
            & $scriptPath
        }
        else {
            throw "GroupPolicyManager.ps1 script not found at $scriptPath"
        }
    }
    catch {
        Write-LabLog "Failed to configure Group Policy: $($_.Exception.Message)" "ERROR"
        throw
    }
}

function Get-LabConfiguration {
    <#
    .SYNOPSIS
        Gets the current lab configuration
    .DESCRIPTION
        This function returns the current lab configuration settings
    .EXAMPLE
        Get-LabConfiguration
    #>
    [CmdletBinding()]
    param()
    
    return $script:LabConfig
}

function Set-LabConfiguration {
    <#
    .SYNOPSIS
        Sets lab configuration options
    .DESCRIPTION
        This function allows you to modify lab configuration settings
    .PARAMETER VMPath
        Default path for VMs
    .PARAMETER DomainName
        Default domain name
    .PARAMETER LogPath
        Path for log files
    .EXAMPLE
        Set-LabConfiguration -VMPath "D:\VMs" -DomainName "mylab.local"
    #>
    [CmdletBinding()]
    param(
        [string]$VMPath,
        [string]$DomainName,
        [string]$LogPath
    )
    
    if ($VMPath) { $script:LabConfig.DefaultVMPath = $VMPath }
    if ($DomainName) { $script:LabConfig.DefaultDomainName = $DomainName }
    if ($LogPath) { $script:LabConfig.LogPath = $LogPath }
    
    Write-LabLog "Lab configuration updated" "SUCCESS"
}

function Remove-LabEnvironment {
    <#
    .SYNOPSIS
        Safely removes all lab environment components
    .DESCRIPTION
        This function provides a comprehensive uninstall of all lab components including
        VMs, virtual switches, Active Directory objects, file shares, and configurations
    .PARAMETER Component
        Specific component to remove (All, VMs, Switches, Shares, AD, Users, GPOs, Registry, Scheduled)
    .PARAMETER BackupPath
        Path where backup will be created before removal
    .PARAMETER Force
        Force removal without detailed confirmations
    .PARAMETER CreateBackup
        Create backup before removal (default: true)
    .EXAMPLE
        Remove-LabEnvironment -Component All
    .EXAMPLE
        Remove-LabEnvironment -Component VMs -Force
    #>
    [CmdletBinding()]
    param(
        [ValidateSet("All", "VMs", "Switches", "Shares", "AD", "Users", "GPOs", "Registry", "Scheduled")]
        [string]$Component = "All",
        [string]$BackupPath = "C:\LabBackup",
        [switch]$Force = $false,
        [switch]$CreateBackup = $true
    )
    
    Write-LabLog "Starting lab environment removal..." "INFO"
    
    try {
        $scriptPath = Join-Path $ModuleRoot "Lab-Uninstall.ps1"
        if (Test-Path $scriptPath) {
            & $scriptPath -Component $Component -BackupPath $BackupPath -Force:$Force -CreateBackup:$CreateBackup
        }
        else {
            throw "Lab-Uninstall.ps1 script not found at $scriptPath"
        }
    }
    catch {
        Write-LabLog "Failed to remove lab environment: $($_.Exception.Message)" "ERROR"
        throw
    }
}

function Restore-LabEnvironment {
    <#
    .SYNOPSIS
        Restores lab environment from backup
    .DESCRIPTION
        This function restores lab components from backups created by Remove-LabEnvironment
    .PARAMETER BackupPath
        Path where backup is stored
    .PARAMETER Component
        Component to restore (All, VMs, AD, Configuration)
    .PARAMETER VMPath
        Path where VMs should be restored
    .PARAMETER Force
        Force restore without detailed confirmations
    .EXAMPLE
        Restore-LabEnvironment -BackupPath "C:\LabBackup"
    .EXAMPLE
        Restore-LabEnvironment -BackupPath "D:\Backup" -Component VMs
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BackupPath,
        [ValidateSet("All", "VMs", "AD", "Configuration")]
        [string]$Component = "All",
        [string]$VMPath = $script:LabConfig.DefaultVMPath,
        [switch]$Force = $false
    )
    
    Write-LabLog "Starting lab environment restore..." "INFO"
    
    try {
        $scriptPath = Join-Path $ModuleRoot "Lab-Restore.ps1"
        if (Test-Path $scriptPath) {
            & $scriptPath -BackupPath $BackupPath -Component $Component -VMPath $VMPath -Force:$Force
        }
        else {
            throw "Lab-Restore.ps1 script not found at $scriptPath"
        }
    }
    catch {
        Write-LabLog "Failed to restore lab environment: $($_.Exception.Message)" "ERROR"
        throw
    }
}

# Module initialization
Write-LabLog "Windows Server Lab Module v$ModuleVersion loaded" "SUCCESS"
Write-LabLog "Use Get-Command -Module WindowsServerLab to see available commands" "INFO"

# Export only public functions (handled by manifest)
Export-ModuleMember -Function @(
    'New-LabEnvironment',
    'Test-LabEnvironment', 
    'Start-LabVMs',
    'Stop-LabVMs',
    'Get-LabStatus',
    'Set-LabConfiguration',
    'Get-LabConfiguration',
    'Invoke-LabSecurityAudit',
    'New-LabUsers',
    'Set-LabGroupPolicy',
    'Remove-LabEnvironment',
    'Restore-LabEnvironment'
) 