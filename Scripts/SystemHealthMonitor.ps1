# System Health Monitoring Script
# This script monitors various aspects of server health and generates a report

# Import required modules
Import-Module ActiveDirectory
Import-Module ServerManager

# Create timestamp for the report
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm"
$reportPath = "C:\Reports\SystemHealth_$timestamp.html"

# Create reports directory if it doesn't exist
New-Item -Path "C:\Reports" -ItemType Directory -Force -ErrorAction SilentlyContinue

# Function to get disk space information
function Get-DiskSpaceInfo {
    $disks = Get-WmiObject Win32_LogicalDisk -Filter "DriveType=3"
    $diskInfo = @()
    
    foreach ($disk in $disks) {
        $freeSpace = [math]::Round($disk.FreeSpace / 1GB, 2)
        $totalSpace = [math]::Round($disk.Size / 1GB, 2)
        $usedSpace = $totalSpace - $freeSpace
        $usedPercentage = [math]::Round(($usedSpace / $totalSpace) * 100, 2)
        
        $diskInfo += [PSCustomObject]@{
            Drive = $disk.DeviceID
            TotalSpace = "$totalSpace GB"
            FreeSpace = "$freeSpace GB"
            UsedSpace = "$usedSpace GB"
            UsedPercentage = "$usedPercentage%"
            Status = if ($usedPercentage -gt 90) { "Critical" } elseif ($usedPercentage -gt 75) { "Warning" } else { "Normal" }
        }
    }
    return $diskInfo
}

# Function to get service status
function Get-ServiceStatus {
    $services = Get-Service | Where-Object { $_.Status -ne "Running" -and $_.StartType -eq "Automatic" }
    return $services | Select-Object Name, Status, StartType
}

# Function to get event log errors
function Get-EventLogErrors {
    $errors = Get-EventLog -LogName System -EntryType Error -Newest 10
    return $errors | Select-Object TimeGenerated, Source, Message
}

# Function to get AD replication status
function Get-ADReplicationStatus {
    $replicationStatus = repadmin /showrepl
    return $replicationStatus
}

# Function to get performance metrics
function Get-PerformanceMetrics {
    $cpu = Get-WmiObject Win32_Processor | Measure-Object -Property LoadPercentage -Average
    $memory = Get-WmiObject Win32_OperatingSystem
    $totalMemory = [math]::Round($memory.TotalVisibleMemorySize / 1MB, 2)
    $freeMemory = [math]::Round($memory.FreePhysicalMemory / 1MB, 2)
    $usedMemory = $totalMemory - $freeMemory
    $memoryPercentage = [math]::Round(($usedMemory / $totalMemory) * 100, 2)

    return [PSCustomObject]@{
        CPUUsage = "$($cpu.Average)%"
        TotalMemory = "$totalMemory GB"
        FreeMemory = "$freeMemory GB"
        UsedMemory = "$usedMemory GB"
        MemoryUsage = "$memoryPercentage%"
    }
}

# Generate HTML report
$html = @"
<!DOCTYPE html>
<html>
<head>
    <title>System Health Report - $timestamp</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        table { border-collapse: collapse; width: 100%; margin-bottom: 20px; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .critical { color: red; }
        .warning { color: orange; }
        .normal { color: green; }
    </style>
</head>
<body>
    <h1>System Health Report</h1>
    <h2>Generated on: $timestamp</h2>
    
    <h3>Disk Space Information</h3>
    $(Get-DiskSpaceInfo | ConvertTo-Html -Fragment)
    
    <h3>Stopped Automatic Services</h3>
    $(Get-ServiceStatus | ConvertTo-Html -Fragment)
    
    <h3>Recent System Errors</h3>
    $(Get-EventLogErrors | ConvertTo-Html -Fragment)
    
    <h3>Performance Metrics</h3>
    $(Get-PerformanceMetrics | ConvertTo-Html -Fragment)
    
    <h3>AD Replication Status</h3>
    <pre>$(Get-ADReplicationStatus)</pre>
</body>
</html>
"@

# Save the report
$html | Out-File -FilePath $reportPath -Encoding UTF8

Write-Host "System health report generated at: $reportPath" -ForegroundColor Green 