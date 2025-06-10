# Hyper-V Lab Environment Setup Script
# This script sets up a complete Hyper-V lab environment with proper networking

#Requires -RunAsAdministrator
#Requires -Module Hyper-V

[CmdletBinding()]
param(
    [string]$VMPath = "C:\VMs",
    [string]$ServerISOPath = "",
    [string]$ClientISOPath = "",
    [string]$ISOPath = "", # Legacy parameter for backward compatibility
    [string]$PhysicalAdapter = "Ethernet",
    [string]$DomainName = "lab.local",
    [switch]$CreateSwitchesOnly = $false,
    [switch]$Force = $false
)

# Enhanced Error Handling Configuration
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Handle legacy ISOPath parameter for backward compatibility
if ($ISOPath -and (-not $ServerISOPath -and -not $ClientISOPath)) {
    Write-Host "⚠️  Using legacy ISOPath for both servers and clients. Consider using -ServerISOPath and -ClientISOPath for better control." -ForegroundColor Yellow
    $ServerISOPath = $ISOPath
    $ClientISOPath = $ISOPath
}

# Validate ISO paths
if ($ServerISOPath -and !(Test-Path $ServerISOPath)) {
    Write-Log "Server ISO file not found: $ServerISOPath" "WARNING"
    Write-Log "Servers will be created without ISO attached" "INFO"
}
if ($ClientISOPath -and !(Test-Path $ClientISOPath)) {
    Write-Log "Client ISO file not found: $ClientISOPath" "WARNING"
    Write-Log "Clients will be created without ISO attached" "INFO"
}

# Logging Configuration
$LogPath = Join-Path $env:TEMP "HyperV-Lab-Setup.log"
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARNING", "ERROR", "DEBUG")]
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Add-Content -Path $LogPath -Value $logEntry -ErrorAction SilentlyContinue
    
    # Also write to console with color
    switch ($Level) {
        "ERROR" { Write-ColorOutput $Message $ErrorColor }
        "WARNING" { Write-ColorOutput $Message $WarningColor }
        "INFO" { Write-ColorOutput $Message $InfoColor }
        "DEBUG" { Write-ColorOutput $Message $DebugColor }
    }
}

# Color coding for output
$ErrorColor = "Red"
$WarningColor = "Yellow"
$InfoColor = "Green"
$DebugColor = "Cyan"

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

function Test-Prerequisites {
    Write-Log "Checking prerequisites..." "INFO"
    
    try {
        # Check if Hyper-V is enabled
        $hyperVFeature = Get-WindowsOptionalFeature -FeatureName Microsoft-Hyper-V -Online -ErrorAction Stop
        if ($hyperVFeature.State -ne "Enabled") {
            Write-Log "Hyper-V is not enabled. Please enable Hyper-V and restart." "ERROR"
            Write-Log "Run: Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -All" "WARNING"
            return $false
        }
        
        # Check if running as administrator
        if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
            Write-Log "This script must be run as Administrator." "ERROR"
            return $false
        }
        
        # Check available memory
        $totalMemory = (Get-CimInstance Win32_ComputerSystem -ErrorAction Stop).TotalPhysicalMemory / 1GB
        if ($totalMemory -lt 8) {
            Write-Log "Less than 8GB RAM detected ($([math]::Round($totalMemory, 1))GB). Lab performance may be limited." "WARNING"
        }
        Write-Log "System Memory: $([math]::Round($totalMemory, 1))GB" "DEBUG"
        
        # Check disk space
        $drive = [System.IO.Path]::GetPathRoot($VMPath)
        $diskSpace = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='$($drive.TrimEnd('\'))'" -ErrorAction Stop
        $freeSpaceGB = $diskSpace.FreeSpace / 1GB
        if ($freeSpaceGB -lt 100) {
            Write-Log "Low disk space detected ($([math]::Round($freeSpaceGB, 1))GB free). Consider freeing up space." "WARNING"
        }
        Write-Log "Available disk space: $([math]::Round($freeSpaceGB, 1))GB" "DEBUG"
        
        # Create VM directory if it doesn't exist
        if (!(Test-Path $VMPath)) {
            New-Item -Path $VMPath -ItemType Directory -Force -ErrorAction Stop | Out-Null
            Write-Log "Created VM directory: $VMPath" "INFO"
        }
        
        # Validate ISO path if provided
        if ($ISOPath -and !(Test-Path $ISOPath)) {
            Write-Log "ISO file not found: $ISOPath" "WARNING"
            Write-Log "VMs will be created without ISO attached" "INFO"
        }
        
        Write-Log "Prerequisites check completed successfully" "INFO"
        return $true
    }
    catch {
        Write-Log "Prerequisites check failed: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function New-LabVirtualSwitches {
    Write-ColorOutput "Creating virtual switches..." $InfoColor
    
    try {
        # Remove existing lab switches if Force is specified
        if ($Force) {
            $existingSwitches = @("LAB-External", "LAB-Management", "LAB-Isolated")
            foreach ($switchName in $existingSwitches) {
                $switch = Get-VMSwitch -Name $switchName -ErrorAction SilentlyContinue
                if ($switch) {
                    Write-ColorOutput "Removing existing switch: $switchName" $WarningColor
                    Remove-VMSwitch -Name $switchName -Force
                }
            }
        }
        
        # Create External Switch
        $externalSwitch = Get-VMSwitch -Name "LAB-External" -ErrorAction SilentlyContinue
        if (-not $externalSwitch) {
            # Get physical adapters
            $physicalAdapters = Get-NetAdapter -Physical | Where-Object { $_.Status -eq "Up" }
            if ($physicalAdapters.Count -eq 0) {
                Write-ColorOutput "WARNING: No active physical network adapters found." $WarningColor
            }
            else {
                $targetAdapter = $physicalAdapters | Where-Object { $_.Name -like "*$PhysicalAdapter*" } | Select-Object -First 1
                if (-not $targetAdapter) {
                    $targetAdapter = $physicalAdapters | Select-Object -First 1
                    Write-ColorOutput "Using adapter: $($targetAdapter.Name)" $InfoColor
                }
                
                New-VMSwitch -Name "LAB-External" -NetAdapterName $targetAdapter.Name -AllowManagementOS $true
                Write-ColorOutput "✓ Created External Switch: LAB-External" $InfoColor
            }
        }
        else {
            Write-ColorOutput "✓ External Switch already exists: LAB-External" $DebugColor
        }
        
        # Create Internal Switch for Management
        $internalSwitch = Get-VMSwitch -Name "LAB-Management" -ErrorAction SilentlyContinue
        if (-not $internalSwitch) {
            New-VMSwitch -Name "LAB-Management" -SwitchType Internal
            Write-ColorOutput "✓ Created Internal Switch: LAB-Management" $InfoColor
            
            # Configure IP for management network
            Start-Sleep -Seconds 3  # Wait for adapter to be created
            $mgmtAdapter = Get-NetAdapter -Name "vEthernet (LAB-Management)" -ErrorAction SilentlyContinue
            if ($mgmtAdapter) {
                # Remove existing IP if present
                Remove-NetIPAddress -InterfaceIndex $mgmtAdapter.ifIndex -Confirm:$false -ErrorAction SilentlyContinue
                # Set new IP
                New-NetIPAddress -IPAddress 192.168.100.1 -PrefixLength 24 -InterfaceIndex $mgmtAdapter.ifIndex -ErrorAction SilentlyContinue
                Write-ColorOutput "✓ Configured Management Network: 192.168.100.1/24" $InfoColor
            }
        }
        else {
            Write-ColorOutput "✓ Internal Switch already exists: LAB-Management" $DebugColor
        }
        
        # Create Private Switch for Isolated Testing
        $privateSwitch = Get-VMSwitch -Name "LAB-Isolated" -ErrorAction SilentlyContinue
        if (-not $privateSwitch) {
            New-VMSwitch -Name "LAB-Isolated" -SwitchType Private
            Write-ColorOutput "✓ Created Private Switch: LAB-Isolated" $InfoColor
        }
        else {
            Write-ColorOutput "✓ Private Switch already exists: LAB-Isolated" $DebugColor
        }
        
        # Configure NAT for internal network
        $existingNAT = Get-NetNat -Name "LAB-ManagementNAT" -ErrorAction SilentlyContinue
        if (-not $existingNAT) {
            New-NetNat -Name "LAB-ManagementNAT" -InternalIPInterfaceAddressPrefix 192.168.100.0/24 -ErrorAction SilentlyContinue
            Write-ColorOutput "✓ Configured NAT for Management Network" $InfoColor
        }
        
        return $true
    }
    catch {
        Write-ColorOutput "ERROR: Failed to create virtual switches: $($_.Exception.Message)" $ErrorColor
        return $false
    }
}

function New-LabVirtualMachine {
    param(
        [string]$VMName,
        [int64]$Memory = 4GB,
        [int64]$VHDSize = 80GB,
        [int]$CPUCount = 2,
        [string[]]$NetworkSwitches = @("LAB-External", "LAB-Management"),
        [string]$Description = "",
        [string]$ISOPath = ""
    )
    
    Write-ColorOutput "Creating VM: $VMName" $InfoColor
    
    try {
        # Check if VM already exists
        $existingVM = Get-VM -Name $VMName -ErrorAction SilentlyContinue
        if ($existingVM -and -not $Force) {
            Write-ColorOutput "VM $VMName already exists. Use -Force to recreate." $WarningColor
            return $false
        }
        elseif ($existingVM -and $Force) {
            Write-ColorOutput "Removing existing VM: $VMName" $WarningColor
            Stop-VM -Name $VMName -Force -ErrorAction SilentlyContinue
            Remove-VM -Name $VMName -Force
        }
        
        # Create VM
        $vmPath = Join-Path $VMPath $VMName
        New-VM -Name $VMName -Path $VMPath -MemoryStartupBytes $Memory -Generation 2
        
        # Configure VM settings
        Set-VM -Name $VMName -ProcessorCount $CPUCount
        Set-VM -Name $VMName -DynamicMemory -MemoryMinimumBytes ([Math]::Max(512MB, $Memory / 2)) -MemoryMaximumBytes ($Memory * 2)
        Set-VM -Name $VMName -Notes $Description
        
        # Create and attach VHD
        $vhdPath = Join-Path $vmPath "$VMName.vhdx"
        New-VHD -Path $vhdPath -SizeBytes $VHDSize -Dynamic
        Add-VMHardDiskDrive -VMName $VMName -Path $vhdPath
        
        # Add DVD drive for OS installation
        Add-VMDvdDrive -VMName $VMName
        
        # Configure network adapters
        # Remove default network adapter first
        $defaultAdapter = Get-VMNetworkAdapter -VMName $VMName
        if ($defaultAdapter) {
            Remove-VMNetworkAdapter -VMName $VMName -VMNetworkAdapter $defaultAdapter
        }
        
        # Add specified network adapters
        foreach ($switchName in $NetworkSwitches) {
            $adapterName = $switchName.Replace("LAB-", "")
            Add-VMNetworkAdapter -VMName $VMName -SwitchName $switchName -Name $adapterName
            Write-ColorOutput "  ✓ Added network adapter: $adapterName ($switchName)" $DebugColor
        }
        
        # Configure firmware for Generation 2 VMs
        Set-VMFirmware -VMName $VMName -EnableSecureBoot On -SecureBootTemplate "MicrosoftWindows"
        $dvdDrive = Get-VMDvdDrive -VMName $VMName
        if ($dvdDrive) {
            Set-VMFirmware -VMName $VMName -FirstBootDevice $dvdDrive
        }
        
        # Enable integration services
        $integrationServices = @(
            "Guest Service Interface",
            "Heartbeat",
            "Key-Value Pair Exchange",
            "Shutdown",
            "Time Synchronization",
            "VSS"
        )
        
        foreach ($service in $integrationServices) {
            Enable-VMIntegrationService -VMName $VMName -Name $service -ErrorAction SilentlyContinue
        }
        
        # Configure automatic checkpoints (disable for lab environment)
        Set-VM -Name $VMName -AutomaticCheckpointsEnabled $false
        
        # Attach ISO if provided
        if ($ISOPath -and (Test-Path $ISOPath)) {
            Set-VMDvdDrive -VMName $VMName -Path $ISOPath
            Write-ColorOutput "✓ ISO attached to $VMName`: $(Split-Path $ISOPath -Leaf)" $InfoColor
        }
        
        Write-ColorOutput "✓ VM Created: $VMName" $InfoColor
        Write-ColorOutput "  Memory: $($Memory/1GB)GB (Dynamic: $([Math]::Max(512MB, $Memory / 2)/1GB)GB - $($Memory * 2/1GB)GB)" $DebugColor
        Write-ColorOutput "  CPUs: $CPUCount" $DebugColor
        Write-ColorOutput "  VHD: $VHDSize GB" $DebugColor
        Write-ColorOutput "  Networks: $($NetworkSwitches -join ', ')" $DebugColor
        
        return $true
    }
    catch {
        Write-ColorOutput "ERROR: Failed to create VM $VMName`: $($_.Exception.Message)" $ErrorColor
        return $false
    }
}

function Set-VMISOImage {
    param(
        [string]$VMName,
        [string]$ISOPath
    )
    
    if ($ISOPath -and (Test-Path $ISOPath)) {
        $dvdDrive = Get-VMDvdDrive -VMName $VMName
        if ($dvdDrive) {
            Set-VMDvdDrive -VMName $VMName -Path $ISOPath
            Write-ColorOutput "✓ ISO attached to $VMName`: $ISOPath" $InfoColor
        }
    }
}

function New-CompleteLabEnvironment {
    Write-ColorOutput "Creating complete lab environment..." $InfoColor
    
    # Define VMs to create with their types for ISO assignment
    $labVMs = @(
        @{
            Name        = "DC1-LAB"
            Memory      = 4GB
            VHDSize     = 80GB
            CPUCount    = 2
            Networks    = @("LAB-External", "LAB-Management")
            Description = "Primary Domain Controller for $DomainName"
            Type        = "Server"
        },
        @{
            Name        = "FS1-LAB"
            Memory      = 2GB
            VHDSize     = 100GB
            CPUCount    = 2
            Networks    = @("LAB-External", "LAB-Management")
            Description = "File Server for lab environment"
            Type        = "Server"
        },
        @{
            Name        = "WEB1-LAB"
            Memory      = 2GB
            VHDSize     = 60GB
            CPUCount    = 2
            Networks    = @("LAB-External", "LAB-Management")
            Description = "Web Server for lab applications"
            Type        = "Server"
        },
        @{
            Name        = "CL1-LAB"
            Memory      = 2GB
            VHDSize     = 60GB
            CPUCount    = 2
            Networks    = @("LAB-External")
            Description = "Windows 10/11 Client for testing"
            Type        = "Client"
        }
    )
    
    foreach ($vm in $labVMs) {
        # Determine which ISO to use based on VM type
        $isoToUse = ""
        if ($vm.Type -eq "Server" -and $ServerISOPath) {
            $isoToUse = $ServerISOPath
        }
        elseif ($vm.Type -eq "Client" -and $ClientISOPath) {
            $isoToUse = $ClientISOPath
        }
        
        $success = New-LabVirtualMachine -VMName $vm.Name -Memory $vm.Memory -VHDSize $vm.VHDSize -CPUCount $vm.CPUCount -NetworkSwitches $vm.Networks -Description $vm.Description -ISOPath $isoToUse
    }
}

function Show-LabSummary {
    Write-ColorOutput "`n=== LAB ENVIRONMENT SUMMARY ===" $InfoColor
    
    # Show virtual switches
    Write-ColorOutput "`nVirtual Switches:" $InfoColor
    $switches = Get-VMSwitch | Where-Object { $_.Name -like "LAB-*" }
    foreach ($switch in $switches) {
        Write-ColorOutput "  ✓ $($switch.Name) ($($switch.SwitchType))" $DebugColor
    }
    
    # Show management network configuration
    $mgmtAdapter = Get-NetAdapter -Name "vEthernet (LAB-Management)" -ErrorAction SilentlyContinue
    if ($mgmtAdapter) {
        $mgmtIP = Get-NetIPAddress -InterfaceIndex $mgmtAdapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
        if ($mgmtIP) {
            Write-ColorOutput "  Management Network: $($mgmtIP.IPAddress)/$($mgmtIP.PrefixLength)" $DebugColor
        }
    }
    
    # Show NAT configuration
    $nat = Get-NetNat -Name "LAB-ManagementNAT" -ErrorAction SilentlyContinue
    if ($nat) {
        Write-ColorOutput "  NAT Network: $($nat.InternalIPInterfaceAddressPrefix)" $DebugColor
    }
    
    # Show VMs
    Write-ColorOutput "`nVirtual Machines:" $InfoColor
    $labVMs = Get-VM | Where-Object { $_.Name -like "*LAB*" }
    if ($labVMs) {
        foreach ($vm in $labVMs) {
            $vmNetworks = (Get-VMNetworkAdapter -VMName $vm.Name | ForEach-Object { $_.SwitchName }) -join ", "
            Write-ColorOutput "  ✓ $($vm.Name) - $($vm.State) - Networks: $vmNetworks" $DebugColor
        }
    }
    else {
        Write-ColorOutput "  No lab VMs found." $WarningColor
    }
    
    Write-ColorOutput "`nNext Steps:" $InfoColor
    Write-ColorOutput "1. Start VMs and install operating systems" $DebugColor
    Write-ColorOutput "2. Configure DC1-LAB as domain controller" $DebugColor
    Write-ColorOutput "3. Join other servers to the domain" $DebugColor
    Write-ColorOutput "4. Configure services (DNS, DHCP, File Shares)" $DebugColor
    Write-ColorOutput "5. Add client machines and test connectivity" $DebugColor
}

# Main execution
try {
    Write-ColorOutput "=== HYPER-V LAB SETUP SCRIPT ===" $InfoColor
    Write-ColorOutput "VM Path: $VMPath" $DebugColor
    Write-ColorOutput "Domain: $DomainName" $DebugColor
    Write-ColorOutput "Physical Adapter: $PhysicalAdapter" $DebugColor
    
    if (-not (Test-Prerequisites)) {
        exit 1
    }
    
    # Create virtual switches
    if (-not (New-LabVirtualSwitches)) {
        Write-ColorOutput "Failed to create virtual switches. Exiting." $ErrorColor
        exit 1
    }
    
    # Create VMs unless only switches requested
    if (-not $CreateSwitchesOnly) {
        New-CompleteLabEnvironment
    }
    
    # Show summary
    Show-LabSummary
    
    Write-ColorOutput "`n✓ Lab setup completed successfully!" $InfoColor
}
catch {
    Write-ColorOutput "ERROR: Script execution failed: $($_.Exception.Message)" $ErrorColor
    Write-ColorOutput "Stack Trace: $($_.ScriptStackTrace)" $DebugColor
    exit 1
} 