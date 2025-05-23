# Security Audit Script
# This script performs a comprehensive security audit of Windows Server

# Import required modules
Import-Module ActiveDirectory
Import-Module SecurityPolicy

# Configuration
$auditConfig = @{
    ReportPath = "C:\Reports\Security"
    LogPath = "C:\Logs\Security"
}

# Create necessary directories
New-Item -Path $auditConfig.ReportPath -ItemType Directory -Force -ErrorAction SilentlyContinue
New-Item -Path $auditConfig.LogPath -ItemType Directory -Force -ErrorAction SilentlyContinue

# Function to check password policy
function Get-PasswordPolicyAudit {
    $policy = Get-ADDefaultDomainPasswordPolicy
    $report = @{
        MinPasswordLength = $policy.MinPasswordLength
        ComplexityEnabled = $policy.ComplexityEnabled
        MaxPasswordAge = $policy.MaxPasswordAge
        MinPasswordAge = $policy.MinPasswordAge
        PasswordHistoryCount = $policy.PasswordHistoryCount
        LockoutThreshold = $policy.LockoutThreshold
        LockoutDuration = $policy.LockoutDuration
        Recommendations = @()
    }
    
    # Add recommendations based on best practices
    if ($policy.MinPasswordLength -lt 12) {
        $report.Recommendations += "Increase minimum password length to at least 12 characters"
    }
    if (-not $policy.ComplexityEnabled) {
        $report.Recommendations += "Enable password complexity requirements"
    }
    if ($policy.MaxPasswordAge -gt 90) {
        $report.Recommendations += "Reduce maximum password age to 90 days or less"
    }
    if ($policy.LockoutThreshold -gt 5) {
        $report.Recommendations += "Reduce account lockout threshold to 5 attempts"
    }
    
    return $report
}

# Function to check user account security
function Get-UserAccountAudit {
    $users = Get-ADUser -Filter * -Properties PasswordNeverExpires, PasswordLastSet, LastLogonDate, Enabled
    $report = @{
        TotalUsers = $users.Count
        DisabledAccounts = ($users | Where-Object { -not $_.Enabled }).Count
        PasswordNeverExpires = ($users | Where-Object { $_.PasswordNeverExpires }).Count
        NeverLoggedOn = ($users | Where-Object { -not $_.LastLogonDate }).Count
        Recommendations = @()
    }
    
    # Add recommendations
    if ($report.PasswordNeverExpires -gt 0) {
        $report.Recommendations += "Review accounts with non-expiring passwords"
    }
    if ($report.NeverLoggedOn -gt 0) {
        $report.Recommendations += "Review accounts that have never logged on"
    }
    
    return $report
}

# Function to check service security
function Get-ServiceSecurityAudit {
    $services = Get-Service
    $report = @{
        TotalServices = $services.Count
        AutomaticServices = ($services | Where-Object { $_.StartType -eq "Automatic" }).Count
        RunningServices = ($services | Where-Object { $_.Status -eq "Running" }).Count
        Recommendations = @()
    }
    
    # Check for unnecessary services
    $unnecessaryServices = $services | Where-Object {
        $_.Name -in @("RemoteRegistry", "TelnetServer", "TFTP")
    }
    
    if ($unnecessaryServices) {
        $report.Recommendations += "Review and disable unnecessary services: $($unnecessaryServices.Name -join ', ')"
    }
    
    return $report
}

# Function to check firewall rules
function Get-FirewallAudit {
    $firewall = Get-NetFirewallProfile
    $report = @{
        DomainProfile = ($firewall | Where-Object { $_.Name -eq "Domain" }).Enabled
        PrivateProfile = ($firewall | Where-Object { $_.Name -eq "Private" }).Enabled
        PublicProfile = ($firewall | Where-Object { $_.Name -eq "Public" }).Enabled
        Recommendations = @()
    }
    
    # Add recommendations
    if (-not $report.DomainProfile) {
        $report.Recommendations += "Enable Domain Profile firewall"
    }
    if (-not $report.PrivateProfile) {
        $report.Recommendations += "Enable Private Profile firewall"
    }
    if (-not $report.PublicProfile) {
        $report.Recommendations += "Enable Public Profile firewall"
    }
    
    return $report
}

# Function to check Windows Defender status
function Get-WindowsDefenderAudit {
    $defender = Get-MpComputerStatus
    $report = @{
        RealTimeProtection = $defender.RealTimeProtectionEnabled
        AntivirusEnabled = $defender.AntivirusEnabled
        AntispywareEnabled = $defender.AntispywareEnabled
        Recommendations = @()
    }
    
    # Add recommendations
    if (-not $report.RealTimeProtection) {
        $report.Recommendations += "Enable Windows Defender Real-Time Protection"
    }
    if (-not $report.AntivirusEnabled) {
        $report.Recommendations += "Enable Windows Defender Antivirus"
    }
    if (-not $report.AntispywareEnabled) {
        $report.Recommendations += "Enable Windows Defender Antispyware"
    }
    
    return $report
}

# Generate comprehensive report
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm"
$reportPath = Join-Path $auditConfig.ReportPath "SecurityAudit_$timestamp.html"

$html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Security Audit Report - $timestamp</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        table { border-collapse: collapse; width: 100%; margin-bottom: 20px; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .recommendation { color: red; }
    </style>
</head>
<body>
    <h1>Security Audit Report</h1>
    <h2>Generated on: $timestamp</h2>
    
    <h3>Password Policy Audit</h3>
    $(Get-PasswordPolicyAudit | ConvertTo-Html -Fragment)
    
    <h3>User Account Security Audit</h3>
    $(Get-UserAccountAudit | ConvertTo-Html -Fragment)
    
    <h3>Service Security Audit</h3>
    $(Get-ServiceSecurityAudit | ConvertTo-Html -Fragment)
    
    <h3>Firewall Configuration Audit</h3>
    $(Get-FirewallAudit | ConvertTo-Html -Fragment)
    
    <h3>Windows Defender Status</h3>
    $(Get-WindowsDefenderAudit | ConvertTo-Html -Fragment)
</body>
</html>
"@

# Save the report
$html | Out-File -FilePath $reportPath -Encoding UTF8

Write-Host "Security audit report generated at: $reportPath" -ForegroundColor Green 