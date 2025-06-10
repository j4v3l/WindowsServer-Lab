# Hyper-V Lab Management Script
# Provides ongoing management capabilities for Hyper-V lab environment

#Requires -RunAsAdministrator
#Requires -Module Hyper-V

[CmdletBinding()]
param(
    [ValidateSet("Status", "Start", "Stop", "Restart", "Backup", "Restore", "Network", "Cleanup", "Monitor", "Help")]
    [string]$Action = "Status",
    [string]$VMName = "",
    [string]$BackupPath = "C:\VMBackups",
    [switch]$All = $false,
    [switch]$Force = $false
)

# Color coding
$ErrorColor = "Red"
$WarningColor = "Yellow"
$InfoColor = "Green"
$DebugColor = "Cyan"
$HighlightColor = "Magenta"

function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

function Show-Help {
    Write-ColorOutput "=== HYPER-V LAB MANAGEMENT SCRIPT ===" $InfoColor
    Write-ColorOutput ""
    Write-ColorOutput "SYNOPSIS:" $HighlightColor
    Write-ColorOutput "  Manages Hyper-V lab environment with various operations"
    Write-ColorOutput ""
    Write-ColorOutput "PARAMETERS:" $HighlightColor
    Write-ColorOutput "  -Action <action>    : Action to perform (Status, Start, Stop, Restart, Backup, Restore, Network, Cleanup, Monitor, Help)"
    Write-ColorOutput "  -VMName <name>      : Specific VM name (optional, defaults to all lab VMs)"
    Write-ColorOutput "  -BackupPath <path>  : Path for VM backups (default: C:\VMBackups)"
    Write-ColorOutput "  -All                : Apply action to all VMs (not just lab VMs)"
    Write-ColorOutput "  -Force              : Force action without confirmation"
    Write-ColorOutput ""
    Write-ColorOutput "EXAMPLES:" $HighlightColor
    Write-ColorOutput "  .\Hyper-V_Management.ps1 -Action Status"
    Write-ColorOutput "  .\Hyper-V_Management.ps1 -Action Start -VMName DC1-LAB"
    Write-ColorOutput "  .\Hyper-V_Management.ps1 -Action Backup -All"
    Write-ColorOutput "  .\Hyper-V_Management.ps1 -Action Network"
    Write-ColorOutput "  .\Hyper-V_Management.ps1 -Action Cleanup -Force"
    Write-ColorOutput ""
    Write-ColorOutput "ACTIONS:" $HighlightColor
    Write-ColorOutput "  Status    : Show status of VMs and network configuration"
    Write-ColorOutput "  Start     : Start specified VM(s)"
    Write-ColorOutput "  Stop      : Stop specified VM(s)"
    Write-ColorOutput "  Restart   : Restart specified VM(s)"
    Write-ColorOutput "  Backup    : Create backup/checkpoint of VM(s)"
    Write-ColorOutput "  Restore   : Restore VM from latest checkpoint"
    Write-ColorOutput "  Network   : Show network configuration and diagnostics"
    Write-ColorOutput "  Cleanup   : Remove old checkpoints and optimize VHDs"
    Write-ColorOutput "  Monitor   : Show real-time performance monitoring"
}

function Get-LabVMs {
    param([string]$SpecificVM = "")
    
    if ($SpecificVM) {
        return Get-VM -Name $SpecificVM -ErrorAction SilentlyContinue
    }
    elseif ($All) {
        return Get-VM
    }
    else {
        return Get-VM | Where-Object { $_.Name -like "*LAB*" -or $_.Name -like "DC1*" -or $_.Name -like "FS1*" -or $_.Name -like "WEB1*" -or $_.Name -like "CL1*" }
    }
}

function Show-VMStatus {
    Write-ColorOutput "=== VM STATUS REPORT ===" $InfoColor
    
    $vms = Get-LabVMs -SpecificVM $VMName
    if (-not $vms) {
        Write-ColorOutput "No VMs found matching criteria." $WarningColor
        return
    }
    
    # VM Status Table
    Write-ColorOutput "`nVirtual Machines:" $InfoColor
    $vmData = @()
    foreach ($vm in $vms) {
        $memory = "{0:N1} GB" -f ($vm.MemoryAssigned / 1GB)
        $uptime = if ($vm.Uptime) { 
            "{0:dd}d {0:hh}h {0:mm}m" -f $vm.Uptime 
        }
        else { 
            "N/A" 
        }
        
        $vmData += [PSCustomObject]@{
            Name   = $vm.Name
            State  = $vm.State
            CPUs   = $vm.ProcessorCount
            Memory = $memory
            Uptime = $uptime
            Status = $vm.Status
        }
    }
    $vmData | Format-Table -AutoSize
    
    # Network Adapters
    Write-ColorOutput "Network Configuration:" $InfoColor
    foreach ($vm in $vms) {
        $adapters = Get-VMNetworkAdapter -VMName $vm.Name
        if ($adapters) {
            Write-ColorOutput "  $($vm.Name):" $DebugColor
            foreach ($adapter in $adapters) {
                $status = if ($adapter.Connected) { "Connected" } else { "Disconnected" }
                Write-ColorOutput "    ├─ $($adapter.Name): $($adapter.SwitchName) [$status]" $DebugColor
            }
        }
    }
    
    # Resource Usage Summary
    Write-ColorOutput "`nResource Usage:" $InfoColor
    $totalMemory = ($vms | Where-Object { $_.State -eq "Running" } | Measure-Object MemoryAssigned -Sum).Sum / 1GB
    $totalCPUs = ($vms | Where-Object { $_.State -eq "Running" } | Measure-Object ProcessorCount -Sum).Sum
    $runningVMs = ($vms | Where-Object { $_.State -eq "Running" }).Count
    
    Write-ColorOutput "  Running VMs: $runningVMs" $DebugColor
    Write-ColorOutput "  Total Memory Assigned: $($totalMemory.ToString('N1')) GB" $DebugColor
    Write-ColorOutput "  Total vCPUs: $totalCPUs" $DebugColor
}

function Start-LabVMs {
    $vms = Get-LabVMs -SpecificVM $VMName
    if (-not $vms) {
        Write-ColorOutput "No VMs found to start." $WarningColor
        return
    }
    
    Write-ColorOutput "Starting VMs..." $InfoColor
    foreach ($vm in $vms) {
        if ($vm.State -eq "Off") {
            try {
                Start-VM -Name $vm.Name
                Write-ColorOutput "✓ Started: $($vm.Name)" $InfoColor
            }
            catch {
                Write-ColorOutput "✗ Failed to start $($vm.Name): $($_.Exception.Message)" $ErrorColor
            }
        }
        else {
            Write-ColorOutput "⚠ $($vm.Name) is already $($vm.State)" $WarningColor
        }
    }
}

function Stop-LabVMs {
    $vms = Get-LabVMs -SpecificVM $VMName
    if (-not $vms) {
        Write-ColorOutput "No VMs found to stop." $WarningColor
        return
    }
    
    if (-not $Force) {
        $response = Read-Host "Are you sure you want to stop the VMs? (y/N)"
        if ($response -ne 'y' -and $response -ne 'Y') {
            Write-ColorOutput "Operation cancelled." $WarningColor
            return
        }
    }
    
    Write-ColorOutput "Stopping VMs..." $InfoColor
    foreach ($vm in $vms) {
        if ($vm.State -eq "Running") {
            try {
                # Try graceful shutdown first
                Stop-VM -Name $vm.Name -Save
                Write-ColorOutput "✓ Stopped: $($vm.Name)" $InfoColor
            }
            catch {
                try {
                    # Force stop if graceful fails
                    Stop-VM -Name $vm.Name -Force
                    Write-ColorOutput "✓ Force stopped: $($vm.Name)" $WarningColor
                }
                catch {
                    Write-ColorOutput "✗ Failed to stop $($vm.Name): $($_.Exception.Message)" $ErrorColor
                }
            }
        }
        else {
            Write-ColorOutput "⚠ $($vm.Name) is already $($vm.State)" $WarningColor
        }
    }
}

function Restart-LabVMs {
    $vms = Get-LabVMs -SpecificVM $VMName
    if (-not $vms) {
        Write-ColorOutput "No VMs found to restart." $WarningColor
        return
    }
    
    Write-ColorOutput "Restarting VMs..." $InfoColor
    foreach ($vm in $vms) {
        if ($vm.State -eq "Running") {
            try {
                Restart-VM -Name $vm.Name -Force
                Write-ColorOutput "✓ Restarted: $($vm.Name)" $InfoColor
            }
            catch {
                Write-ColorOutput "✗ Failed to restart $($vm.Name): $($_.Exception.Message)" $ErrorColor
            }
        }
        else {
            Write-ColorOutput "⚠ $($vm.Name) is not running (State: $($vm.State))" $WarningColor
        }
    }
}

function Backup-LabVMs {
    $vms = Get-LabVMs -SpecificVM $VMName
    if (-not $vms) {
        Write-ColorOutput "No VMs found to backup." $WarningColor
        return
    }
    
    # Create backup directory
    if (!(Test-Path $BackupPath)) {
        New-Item -Path $BackupPath -ItemType Directory -Force
        Write-ColorOutput "Created backup directory: $BackupPath" $InfoColor
    }
    
    Write-ColorOutput "Creating VM checkpoints..." $InfoColor
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    
    foreach ($vm in $vms) {
        try {
            $checkpointName = "$($vm.Name)-Backup-$timestamp"
            Checkpoint-VM -Name $vm.Name -SnapshotName $checkpointName
            Write-ColorOutput "✓ Created checkpoint: $checkpointName" $InfoColor
        }
        catch {
            Write-ColorOutput "✗ Failed to create checkpoint for $($vm.Name): $($_.Exception.Message)" $ErrorColor
        }
    }
}

function Restore-LabVMs {
    $vms = Get-LabVMs -SpecificVM $VMName
    if (-not $vms) {
        Write-ColorOutput "No VMs found to restore." $WarningColor
        return
    }
    
    Write-ColorOutput "Available checkpoints for restoration:" $InfoColor
    foreach ($vm in $vms) {
        $checkpoints = Get-VMSnapshot -VMName $vm.Name | Sort-Object CreationTime -Descending
        if ($checkpoints) {
            Write-ColorOutput "`n$($vm.Name):" $DebugColor
            for ($i = 0; $i -lt [Math]::Min(5, $checkpoints.Count); $i++) {
                $cp = $checkpoints[$i]
                Write-ColorOutput "  [$i] $($cp.Name) - $($cp.CreationTime)" $DebugColor
            }
        }
        else {
            Write-ColorOutput "$($vm.Name): No checkpoints available" $WarningColor
        }
    }
    
    if (-not $Force) {
        Write-ColorOutput "`nRestore will revert VMs to their latest checkpoint state." $WarningColor
        $response = Read-Host "Continue with restore? (y/N)"
        if ($response -ne 'y' -and $response -ne 'Y') {
            Write-ColorOutput "Restore cancelled." $WarningColor
            return
        }
    }
    
    foreach ($vm in $vms) {
        $latestCheckpoint = Get-VMSnapshot -VMName $vm.Name | Sort-Object CreationTime -Descending | Select-Object -First 1
        if ($latestCheckpoint) {
            try {
                Restore-VMSnapshot -VMName $vm.Name -Name $latestCheckpoint.Name -Confirm:$false
                Write-ColorOutput "✓ Restored $($vm.Name) to checkpoint: $($latestCheckpoint.Name)" $InfoColor
            }
            catch {
                Write-ColorOutput "✗ Failed to restore $($vm.Name): $($_.Exception.Message)" $ErrorColor
            }
        }
    }
}

function Show-NetworkDiagnostics {
    Write-ColorOutput "=== NETWORK DIAGNOSTICS ===" $InfoColor
    
    # Virtual Switches
    Write-ColorOutput "`nVirtual Switches:" $InfoColor
    $switches = Get-VMSwitch
    foreach ($switch in $switches) {
        $vmCount = (Get-VM | Get-VMNetworkAdapter | Where-Object { $_.SwitchName -eq $switch.Name }).Count
        Write-ColorOutput "  $($switch.Name) [$($switch.SwitchType)] - $vmCount VMs connected" $DebugColor
        
        if ($switch.SwitchType -eq "External") {
            $adapter = Get-NetAdapter -Name $switch.NetAdapterInterfaceDescription -ErrorAction SilentlyContinue
            if ($adapter) {
                Write-ColorOutput "    └─ Physical: $($adapter.Name) [$($adapter.LinkSpeed)] - $($adapter.Status)" $DebugColor
            }
        }
    }
    
    # Network Adapters with IP Configuration
    Write-ColorOutput "`nHost Network Adapters:" $InfoColor
    $adapters = Get-NetAdapter | Where-Object { $_.Name -like "*vEthernet*" }
    foreach ($adapter in $adapters) {
        $ipConfig = Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
        $status = "$($adapter.Status)"
        if ($ipConfig) {
            $status += " - $($ipConfig.IPAddress)/$($ipConfig.PrefixLength)"
        }
        Write-ColorOutput "  $($adapter.Name): $status" $DebugColor
    }
    
    # NAT Configuration
    Write-ColorOutput "`nNAT Configuration:" $InfoColor
    $nats = Get-NetNat
    if ($nats) {
        foreach ($nat in $nats) {
            Write-ColorOutput "  $($nat.Name): $($nat.InternalIPInterfaceAddressPrefix)" $DebugColor
        }
    }
    else {
        Write-ColorOutput "  No NAT configurations found" $WarningColor
    }
    
    # VM Network Status
    Write-ColorOutput "`nVM Network Status:" $InfoColor
    $vms = Get-LabVMs
    foreach ($vm in $vms) {
        if ($vm.State -eq "Running") {
            $adapters = Get-VMNetworkAdapter -VMName $vm.Name
            Write-ColorOutput "  $($vm.Name):" $DebugColor
            foreach ($adapter in $adapters) {
                $status = if ($adapter.Connected) { "Connected" } else { "Disconnected" }
                $traffic = "Rx: $($adapter.BytesReceived) | Tx: $($adapter.BytesSent)"
                Write-ColorOutput "    └─ $($adapter.Name) -> $($adapter.SwitchName) [$status] ($traffic)" $DebugColor
            }
        }
    }
    
    # Connectivity Tests
    Write-ColorOutput "`nConnectivity Tests:" $InfoColor
    $testHosts = @("8.8.8.8", "1.1.1.1", "google.com")
    foreach ($testHost in $testHosts) {
        $result = Test-NetConnection -ComputerName $testHost -InformationLevel Quiet -WarningAction SilentlyContinue
        $status = if ($result) { "✓ Success" } else { "✗ Failed" }
        $color = if ($result) { $InfoColor } else { $ErrorColor }
        Write-ColorOutput "  $testHost`: $status" $color
    }
}

function Invoke-Cleanup {
    Write-ColorOutput "=== CLEANUP OPERATIONS ===" $InfoColor
    
    if (-not $Force) {
        Write-ColorOutput "This will remove old checkpoints and optimize VHDs." $WarningColor
        $response = Read-Host "Continue with cleanup? (y/N)"
        if ($response -ne 'y' -and $response -ne 'Y') {
            Write-ColorOutput "Cleanup cancelled." $WarningColor
            return
        }
    }
    
    $vms = Get-LabVMs -SpecificVM $VMName
    
    # Remove old checkpoints (keep latest 3)
    Write-ColorOutput "`nCleaning up old checkpoints..." $InfoColor
    foreach ($vm in $vms) {
        $checkpoints = Get-VMSnapshot -VMName $vm.Name | Sort-Object CreationTime -Descending
        if ($checkpoints.Count -gt 3) {
            $toRemove = $checkpoints | Select-Object -Skip 3
            foreach ($checkpoint in $toRemove) {
                try {
                    Remove-VMSnapshot -VMName $vm.Name -Name $checkpoint.Name -Confirm:$false
                    Write-ColorOutput "✓ Removed checkpoint: $($checkpoint.Name)" $InfoColor
                }
                catch {
                    Write-ColorOutput "✗ Failed to remove checkpoint $($checkpoint.Name): $($_.Exception.Message)" $ErrorColor
                }
            }
        }
    }
    
    # Optimize VHDs
    Write-ColorOutput "`nOptimizing VHDs..." $InfoColor
    foreach ($vm in $vms) {
        if ($vm.State -eq "Off") {
            $vhds = Get-VMHardDiskDrive -VMName $vm.Name
            foreach ($vhd in $vhds) {
                try {
                    Optimize-VHD -Path $vhd.Path -Mode Full
                    Write-ColorOutput "✓ Optimized VHD: $($vhd.Path)" $InfoColor
                }
                catch {
                    Write-ColorOutput "✗ Failed to optimize VHD $($vhd.Path): $($_.Exception.Message)" $ErrorColor
                }
            }
        }
        else {
            Write-ColorOutput "⚠ Skipping $($vm.Name) - VM must be turned off for VHD optimization" $WarningColor
        }
    }
}

function Show-PerformanceMonitor {
    Write-ColorOutput "=== PERFORMANCE MONITOR ===" $InfoColor
    Write-ColorOutput "Press Ctrl+C to stop monitoring" $WarningColor
    
    try {
        while ($true) {
            Clear-Host
            Write-ColorOutput "=== HYPER-V LAB PERFORMANCE MONITOR ===" $InfoColor
            Write-ColorOutput "Updated: $(Get-Date)" $DebugColor
            Write-ColorOutput ""
            
            # Host Performance
            $cpu = Get-Counter "\Processor(_Total)\% Processor Time" -SampleInterval 1 -MaxSamples 1
            $memory = Get-CimInstance Win32_OperatingSystem
            $memoryUsed = (($memory.TotalVisibleMemorySize - $memory.FreePhysicalMemory) / $memory.TotalVisibleMemorySize) * 100
            
            Write-ColorOutput "Host Performance:" $InfoColor
            Write-ColorOutput "  CPU Usage: $([math]::Round($cpu.CounterSamples[0].CookedValue, 1))%" $DebugColor
            Write-ColorOutput "  Memory Usage: $([math]::Round($memoryUsed, 1))%" $DebugColor
            
            # VM Performance
            Write-ColorOutput "`nVM Performance:" $InfoColor
            $vms = Get-LabVMs | Where-Object { $_.State -eq "Running" }
            foreach ($vm in $vms) {
                $vmCpu = Get-Counter "\Hyper-V Hypervisor Virtual Processor($($vm.Name):Hv VP *)\% Guest Run Time" -SampleInterval 1 -MaxSamples 1 -ErrorAction SilentlyContinue
                if ($vmCpu) {
                    $avgCpu = ($vmCpu.CounterSamples | Measure-Object CookedValue -Average).Average
                    Write-ColorOutput "  $($vm.Name): CPU $([math]::Round($avgCpu, 1))% | Memory $([math]::Round($vm.MemoryAssigned/1GB, 1))GB" $DebugColor
                }
            }
            
            Start-Sleep -Seconds 5
        }
    }
    catch {
        Write-ColorOutput "`nMonitoring stopped." $InfoColor
    }
}

# Main execution
try {
    switch ($Action.ToLower()) {
        "status" { Show-VMStatus }
        "start" { Start-LabVMs }
        "stop" { Stop-LabVMs }
        "restart" { Restart-LabVMs }
        "backup" { Backup-LabVMs }
        "restore" { Restore-LabVMs }
        "network" { Show-NetworkDiagnostics }
        "cleanup" { Invoke-Cleanup }
        "monitor" { Show-PerformanceMonitor }
        "help" { Show-Help }
        default { 
            Write-ColorOutput "Unknown action: $Action" $ErrorColor
            Show-Help
        }
    }
}
catch {
    Write-ColorOutput "ERROR: $($_.Exception.Message)" $ErrorColor
    Write-ColorOutput "Stack trace: $($_.ScriptStackTrace)" $DebugColor
} 