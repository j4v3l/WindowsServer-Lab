# Advanced Security Audit Script
# Comprehensive security auditing including camera, USB, device controls, and advanced GPO settings

# Import required modules
Import-Module ActiveDirectory
Import-Module GroupPolicy
try {
  Import-Module SecurityPolicy
}
catch {
  Write-Warning "SecurityPolicy module not found. Some audits may be limited."
}

# Configuration
$auditConfig = @{
  ReportPath = "C:\Reports\Security"
  LogPath    = "C:\Logs\Security"
  BackupPath = "C:\Backups\SecurityAudit"
}

# Create necessary directories
$auditConfig.Values | ForEach-Object {
  New-Item -Path $_ -ItemType Directory -Force -ErrorAction SilentlyContinue
}

# Function to check camera and microphone policies
function Get-CameraSecurityAudit {
  $audit = @{
    ComputerCameraPolicy     = $null
    UserCameraPolicy         = $null
    ComputerMicrophonePolicy = $null
    UserMicrophonePolicy     = $null
    WindowsHelloCameraPolicy = $null
    FacialRecognitionPolicy  = $null
    Recommendations          = @()
    SecurityScore            = 0
  }
    
  try {
    # Check camera policies in Group Policy
    $cameraGPOs = Get-GPO -All | Where-Object { $_.DisplayName -like "*Camera*" -or $_.DisplayName -like "*Security*" }
        
    # Check registry settings for camera access
    $cameraRegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Camera"
    if (Test-Path $cameraRegPath) {
      $allowCamera = Get-ItemProperty -Path $cameraRegPath -Name "AllowCamera" -ErrorAction SilentlyContinue
      $audit.ComputerCameraPolicy = if ($allowCamera) { "Configured" } else { "Not Configured" }
    }
    else {
      $audit.ComputerCameraPolicy = "Not Configured"
    }
        
    # Check microphone policies
    $microphoneRegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy"
    if (Test-Path $microphoneRegPath) {
      $allowMicrophone = Get-ItemProperty -Path $microphoneRegPath -Name "LetAppsAccessMicrophone" -ErrorAction SilentlyContinue
      $audit.ComputerMicrophonePolicy = if ($allowMicrophone) { "Configured" } else { "Not Configured" }
    }
    else {
      $audit.ComputerMicrophonePolicy = "Not Configured"
    }
        
    # Security recommendations
    if ($audit.ComputerCameraPolicy -eq "Not Configured") {
      $audit.Recommendations += "Configure camera access policy to restrict unauthorized usage"
      $audit.SecurityScore += 0
    }
    else {
      $audit.SecurityScore += 20
    }
        
    if ($audit.ComputerMicrophonePolicy -eq "Not Configured") {
      $audit.Recommendations += "Configure microphone access policy for enhanced privacy"
      $audit.SecurityScore += 0
    }
    else {
      $audit.SecurityScore += 20
    }
        
  }
  catch {
    $audit.Recommendations += "Failed to audit camera/microphone policies: $_"
  }
    
  return $audit
}

# Function to check USB and removable storage security
function Get-USBSecurityAudit {
  $audit = @{
    RemovableStoragePolicy   = $null
    USBInstallationPolicy    = $null
    AutorunPolicy            = $null
    BitLockerRemovablePolicy = $null
    DeviceInstallationPolicy = $null
    ConnectedUSBDevices      = @()
    Recommendations          = @()
    SecurityScore            = 0
  }
    
  try {
    # Check removable storage policies
    $removableStorageRegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\RemovableStorageDevices"
    if (Test-Path $removableStorageRegPath) {
      $denyRead = Get-ItemProperty -Path "$removableStorageRegPath\{53f5630d-b6bf-11d0-94f2-00a0c91efb8b}" -Name "Deny_Read" -ErrorAction SilentlyContinue
      $denyWrite = Get-ItemProperty -Path "$removableStorageRegPath\{53f5630d-b6bf-11d0-94f2-00a0c91efb8b}" -Name "Deny_Write" -ErrorAction SilentlyContinue
      $denyExecute = Get-ItemProperty -Path "$removableStorageRegPath\{53f5630d-b6bf-11d0-94f2-00a0c91efb8b}" -Name "Deny_Execute" -ErrorAction SilentlyContinue
            
      $audit.RemovableStoragePolicy = @{
        ReadDenied    = [bool]$denyRead.Deny_Read
        WriteDenied   = [bool]$denyWrite.Deny_Write
        ExecuteDenied = [bool]$denyExecute.Deny_Execute
      }
    }
    else {
      $audit.RemovableStoragePolicy = "Not Configured"
    }
        
    # Check USB installation policies
    $usbInstallRegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Restrictions"
    if (Test-Path $usbInstallRegPath) {
      $denyRemovable = Get-ItemProperty -Path $usbInstallRegPath -Name "DenyRemovableDevices" -ErrorAction SilentlyContinue
      $audit.USBInstallationPolicy = if ($denyRemovable) { "Removable devices blocked" } else { "Removable devices allowed" }
    }
    else {
      $audit.USBInstallationPolicy = "Not Configured"
    }
        
    # Check autorun policies
    $autorunRegPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer"
    if (Test-Path $autorunRegPath) {
      $noAutorun = Get-ItemProperty -Path $autorunRegPath -Name "NoDriveTypeAutoRun" -ErrorAction SilentlyContinue
      $audit.AutorunPolicy = if ($noAutorun) { "Autorun disabled" } else { "Autorun enabled" }
    }
    else {
      $audit.AutorunPolicy = "Not Configured"
    }
        
    # Check connected USB devices
    $usbDevices = Get-CimInstance -ClassName Win32_PnPEntity | Where-Object { $_.PNPDeviceID -like "USB*" -and $_.Status -eq "OK" }
    $audit.ConnectedUSBDevices = $usbDevices | Select-Object Name, Manufacturer, PNPDeviceID | Sort-Object Name
        
    # Security scoring and recommendations
    if ($audit.RemovableStoragePolicy -eq "Not Configured") {
      $audit.Recommendations += "Configure removable storage access policies to prevent data exfiltration"
      $audit.SecurityScore += 0
    }
    elseif ($audit.RemovableStoragePolicy.ReadDenied -and $audit.RemovableStoragePolicy.WriteDenied) {
      $audit.SecurityScore += 25
    }
    else {
      $audit.Recommendations += "Consider restricting both read and write access to removable storage"
      $audit.SecurityScore += 10
    }
        
    if ($audit.USBInstallationPolicy -eq "Not Configured") {
      $audit.Recommendations += "Configure USB device installation restrictions"
      $audit.SecurityScore += 0
    }
    else {
      $audit.SecurityScore += 15
    }
        
    if ($audit.AutorunPolicy -ne "Autorun disabled") {
      $audit.Recommendations += "Disable autorun for removable media to prevent malware execution"
      $audit.SecurityScore += 0
    }
    else {
      $audit.SecurityScore += 10
    }
        
    if ($audit.ConnectedUSBDevices.Count -gt 0) {
      $audit.Recommendations += "Review connected USB devices: $($audit.ConnectedUSBDevices.Count) devices found"
    }
        
  }
  catch {
    $audit.Recommendations += "Failed to audit USB security: $_"
  }
    
  return $audit
}

# Function to check device control and peripheral security
function Get-DeviceControlAudit {
  $audit = @{
    BluetoothPolicy       = $null
    WiFiPolicy            = $null
    PrinterPolicy         = $null
    CDDVDPolicy           = $null
    ExternalDisplayPolicy = $null
    AudioDevicePolicy     = $null
    NetworkAdapterPolicy  = $null
    ConnectedDevices      = @()
    Recommendations       = @()
    SecurityScore         = 0
  }
    
  try {
    # Check Bluetooth policies
    $bluetoothRegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Bluetooth"
    if (Test-Path $bluetoothRegPath) {
      $bluetoothDisabled = Get-ItemProperty -Path $bluetoothRegPath -Name "ServicesInitialization" -ErrorAction SilentlyContinue
      $audit.BluetoothPolicy = if ($bluetoothDisabled) { "Disabled" } else { "Enabled" }
    }
    else {
      $audit.BluetoothPolicy = "Not Configured"
    }
        
    # Check WiFi policies
    $wifiRegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WlanSvc"
    if (Test-Path $wifiRegPath) {
      $allowAutoConnect = Get-ItemProperty -Path $wifiRegPath -Name "AllowAutoConnectToWiFiSenseHotspots" -ErrorAction SilentlyContinue
      $audit.WiFiPolicy = if ($allowAutoConnect) { "Auto-connect enabled" } else { "Auto-connect disabled" }
    }
    else {
      $audit.WiFiPolicy = "Not Configured"
    }
        
    # Check printer policies
    $printerRegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers"
    if (Test-Path $printerRegPath) {
      $preventAddPrinters = Get-ItemProperty -Path $printerRegPath -Name "DisableAddPrinter" -ErrorAction SilentlyContinue
      $audit.PrinterPolicy = if ($preventAddPrinters) { "Printer addition restricted" } else { "Printer addition allowed" }
    }
    else {
      $audit.PrinterPolicy = "Not Configured"
    }
        
    # Check CD/DVD policies (part of removable storage)
    $cdDvdRegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\RemovableStorageDevices\{53f56308-b6bf-11d0-94f2-00a0c91efb8b}"
    if (Test-Path $cdDvdRegPath) {
      $cdDvdDenyWrite = Get-ItemProperty -Path $cdDvdRegPath -Name "Deny_Write" -ErrorAction SilentlyContinue
      $audit.CDDVDPolicy = if ($cdDvdDenyWrite) { "CD/DVD write blocked" } else { "CD/DVD write allowed" }
    }
    else {
      $audit.CDDVDPolicy = "Not Configured"
    }
        
    # Get connected devices
    $pnpDevices = Get-CimInstance -ClassName Win32_PnPEntity | Where-Object { $_.Status -eq "OK" -and $_.Name -notlike "*Microsoft*" }
    $audit.ConnectedDevices = $pnpDevices | Select-Object Name, Manufacturer, DeviceID | Sort-Object Name
        
    # Security scoring
    if ($audit.BluetoothPolicy -eq "Disabled") {
      $audit.SecurityScore += 15
    }
    elseif ($audit.BluetoothPolicy -eq "Not Configured") {
      $audit.Recommendations += "Consider disabling Bluetooth if not required for business operations"
    }
        
    if ($audit.WiFiPolicy -eq "Auto-connect disabled") {
      $audit.SecurityScore += 10
    }
    else {
      $audit.Recommendations += "Disable automatic WiFi connections to prevent security risks"
    }
        
    if ($audit.PrinterPolicy -eq "Printer addition restricted") {
      $audit.SecurityScore += 5
    }
        
    if ($audit.CDDVDPolicy -eq "CD/DVD write blocked") {
      $audit.SecurityScore += 10
    }
        
    $audit.Recommendations += "Review connected devices: $($audit.ConnectedDevices.Count) devices detected"
        
  }
  catch {
    $audit.Recommendations += "Failed to audit device controls: $_"
  }
    
  return $audit
}

# Function to check personalization and user experience policies
function Get-PersonalizationSecurityAudit {
  $audit = @{
    DesktopBackgroundPolicy = $null
    ThemePolicy             = $null
    ScreenSaverPolicy       = $null
    StartMenuPolicy         = $null
    TaskbarPolicy           = $null
    WindowsStorePolicy      = $null
    CortanaPolicy           = $null
    OneDrivePolicy          = $null
    TelemetryPolicy         = $null
    Recommendations         = @()
    SecurityScore           = 0
  }
    
  try {
    # Check desktop personalization policies
    $personalizationRegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization"
    if (Test-Path $personalizationRegPath) {
      $noChangingWallpaper = Get-ItemProperty -Path $personalizationRegPath -Name "NoChangingWallpaper" -ErrorAction SilentlyContinue
      $audit.DesktopBackgroundPolicy = if ($noChangingWallpaper) { "Locked" } else { "User configurable" }
    }
    else {
      $audit.DesktopBackgroundPolicy = "Not Configured"
    }
        
    # Check Windows Store policies
    $storeRegPath = "HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore"
    if (Test-Path $storeRegPath) {
      $disableStoreApps = Get-ItemProperty -Path $storeRegPath -Name "DisableStoreApps" -ErrorAction SilentlyContinue
      $audit.WindowsStorePolicy = if ($disableStoreApps) { "Disabled" } else { "Enabled" }
    }
    else {
      $audit.WindowsStorePolicy = "Not Configured"
    }
        
    # Check Cortana policies
    $cortanaRegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
    if (Test-Path $cortanaRegPath) {
      $allowCortana = Get-ItemProperty -Path $cortanaRegPath -Name "AllowCortana" -ErrorAction SilentlyContinue
      $audit.CortanaPolicy = if ($allowCortana) { "Enabled" } else { "Disabled" }
    }
    else {
      $audit.CortanaPolicy = "Not Configured"
    }
        
    # Check OneDrive policies
    $oneDriveRegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive"
    if (Test-Path $oneDriveRegPath) {
      $disableFileSyncNGSC = Get-ItemProperty -Path $oneDriveRegPath -Name "DisableFileSyncNGSC" -ErrorAction SilentlyContinue
      $audit.OneDrivePolicy = if ($disableFileSyncNGSC) { "Disabled" } else { "Enabled" }
    }
    else {
      $audit.OneDrivePolicy = "Not Configured"
    }
        
    # Check telemetry policies
    $telemetryRegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
    if (Test-Path $telemetryRegPath) {
      $allowTelemetry = Get-ItemProperty -Path $telemetryRegPath -Name "AllowTelemetry" -ErrorAction SilentlyContinue
      $audit.TelemetryPolicy = switch ($allowTelemetry.AllowTelemetry) {
        0 { "Security (Enterprise only)" }
        1 { "Basic" }
        2 { "Enhanced" }
        3 { "Full" }
        default { "Not Configured" }
      }
    }
    else {
      $audit.TelemetryPolicy = "Not Configured"
    }
        
    # Security scoring based on enterprise security best practices
    if ($audit.CortanaPolicy -eq "Disabled") {
      $audit.SecurityScore += 10
    }
    else {
      $audit.Recommendations += "Consider disabling Cortana for enhanced privacy in enterprise environments"
    }
        
    if ($audit.OneDrivePolicy -eq "Disabled") {
      $audit.SecurityScore += 15
    }
    else {
      $audit.Recommendations += "Evaluate OneDrive usage against data governance policies"
    }
        
    if ($audit.TelemetryPolicy -eq "Security (Enterprise only)" -or $audit.TelemetryPolicy -eq "Basic") {
      $audit.SecurityScore += 20
    }
    else {
      $audit.Recommendations += "Configure telemetry to minimum required level for privacy compliance"
    }
        
    if ($audit.WindowsStorePolicy -eq "Disabled") {
      $audit.SecurityScore += 5
    }
        
  }
  catch {
    $audit.Recommendations += "Failed to audit personalization policies: $_"
  }
    
  return $audit
}

# Function to check application and software control policies
function Get-ApplicationControlAudit {
  $audit = @{
    AppLockerPolicies           = @()
    PowerShellExecutionPolicy   = $null
    PowerShellLogging           = $null
    WindowsDefenderAppGuard     = $null
    SoftwareRestrictionPolicies = @()
    InstalledSoftware           = @()
    Recommendations             = @()
    SecurityScore               = 0
  }
    
  try {
    # Check AppLocker policies
    try {
      $appLockerPolicies = Get-AppLockerPolicy -Effective -ErrorAction SilentlyContinue
      if ($appLockerPolicies) {
        $audit.AppLockerPolicies = $appLockerPolicies.RuleCollections | Select-Object RuleCollectionType, @{n = 'RuleCount'; e = { $_.Count } }
        $audit.SecurityScore += 25
      }
      else {
        $audit.Recommendations += "Consider implementing AppLocker policies for application control"
      }
    }
    catch {
      $audit.Recommendations += "AppLocker not available or configured"
    }
        
    # Check PowerShell execution policy
    $audit.PowerShellExecutionPolicy = Get-ExecutionPolicy
    if ($audit.PowerShellExecutionPolicy -eq "Restricted" -or $audit.PowerShellExecutionPolicy -eq "AllSigned") {
      $audit.SecurityScore += 15
    }
    else {
      $audit.Recommendations += "Consider setting PowerShell execution policy to 'AllSigned' or 'Restricted'"
    }
        
    # Check PowerShell logging
    $psLoggingRegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging"
    if (Test-Path $psLoggingRegPath) {
      $enableScriptBlockLogging = Get-ItemProperty -Path $psLoggingRegPath -Name "EnableScriptBlockLogging" -ErrorAction SilentlyContinue
      $audit.PowerShellLogging = if ($enableScriptBlockLogging) { "Enabled" } else { "Disabled" }
    }
    else {
      $audit.PowerShellLogging = "Not Configured"
    }
        
    if ($audit.PowerShellLogging -eq "Enabled") {
      $audit.SecurityScore += 10
    }
    else {
      $audit.Recommendations += "Enable PowerShell script block logging for security monitoring"
    }
        
    # Check Windows Defender Application Guard
    $wdagFeature = Get-WindowsOptionalFeature -Online -FeatureName "Windows-Defender-ApplicationGuard" -ErrorAction SilentlyContinue
    if ($wdagFeature) {
      $audit.WindowsDefenderAppGuard = $wdagFeature.State
      if ($wdagFeature.State -eq "Enabled") {
        $audit.SecurityScore += 20
      }
    }
    else {
      $audit.WindowsDefenderAppGuard = "Not Available"
    }
        
    # Get installed software
    $installedSoftware = Get-CimInstance -ClassName Win32_Product | Select-Object Name, Version, Vendor | Sort-Object Name
    $audit.InstalledSoftware = $installedSoftware
        
    $audit.Recommendations += "Review installed software: $($installedSoftware.Count) applications detected"
        
  }
  catch {
    $audit.Recommendations += "Failed to audit application controls: $_"
  }
    
  return $audit
}

# Function to check advanced network security
function Get-NetworkSecurityAudit {
  $audit = @{
    FirewallProfiles     = @()
    RemoteDesktopPolicy  = $null
    NetworkSharingPolicy = $null
    VPNConnections       = @()
    NetworkAdapters      = @()
    SMBSigning           = $null
    DNSSettings          = @()
    Recommendations      = @()
    SecurityScore        = 0
  }
    
  try {
    # Check Windows Firewall profiles
    $firewallProfiles = Get-NetFirewallProfile
    $audit.FirewallProfiles = $firewallProfiles | Select-Object Name, Enabled, DefaultInboundAction, DefaultOutboundAction
        
    foreach ($profile in $firewallProfiles) {
      if ($profile.Enabled) {
        $audit.SecurityScore += 10
      }
      else {
        $audit.Recommendations += "Enable Windows Firewall for $($profile.Name) profile"
      }
    }
        
    # Check Remote Desktop policies
    $rdpRegPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server"
    if (Test-Path $rdpRegPath) {
      $rdpEnabled = Get-ItemProperty -Path $rdpRegPath -Name "fDenyTSConnections" -ErrorAction SilentlyContinue
      $audit.RemoteDesktopPolicy = if ($rdpEnabled.fDenyTSConnections -eq 1) { "Disabled" } else { "Enabled" }
    }
    else {
      $audit.RemoteDesktopPolicy = "Not Configured"
    }
        
    if ($audit.RemoteDesktopPolicy -eq "Disabled") {
      $audit.SecurityScore += 15
    }
    else {
      $audit.Recommendations += "Consider disabling Remote Desktop if not required for business operations"
    }
        
    # Check SMB signing
    $smbClientRegPath = "HKLM:\SYSTEM\CurrentControlSet\Services\lanmanworkstation\parameters"
    if (Test-Path $smbClientRegPath) {
      $requireSecuritySignature = Get-ItemProperty -Path $smbClientRegPath -Name "RequireSecuritySignature" -ErrorAction SilentlyContinue
      $audit.SMBSigning = if ($requireSecuritySignature.RequireSecuritySignature -eq 1) { "Required" } else { "Not Required" }
    }
    else {
      $audit.SMBSigning = "Not Configured"
    }
        
    if ($audit.SMBSigning -eq "Required") {
      $audit.SecurityScore += 15
    }
    else {
      $audit.Recommendations += "Enable SMB signing for enhanced network security"
    }
        
    # Get network adapters
    $networkAdapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
    $audit.NetworkAdapters = $networkAdapters | Select-Object Name, InterfaceDescription, LinkSpeed
        
    # Get DNS settings
    $dnsSettings = Get-DnsClientServerAddress | Where-Object { $_.ServerAddresses.Count -gt 0 }
    $audit.DNSSettings = $dnsSettings | Select-Object InterfaceAlias, ServerAddresses
        
    $audit.Recommendations += "Review network configuration: $($networkAdapters.Count) active adapters found"
        
  }
  catch {
    $audit.Recommendations += "Failed to audit network security: $_"
  }
    
  return $audit
}

# Function to generate comprehensive advanced security report
function Get-AdvancedSecurityReport {
  param (
    [string]$OutputPath = $auditConfig.ReportPath
  )
    
  $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
  $reportPath = Join-Path $OutputPath "AdvancedSecurityAudit_$timestamp.html"
    
  # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "🔍 Performing comprehensive security audit..." -ForegroundColor Yellow
    
  # Perform all audits
  $cameraAudit = Get-CameraSecurityAudit
  $usbAudit = Get-USBSecurityAudit
  $deviceAudit = Get-DeviceControlAudit
  $personalizationAudit = Get-PersonalizationSecurityAudit
  $applicationAudit = Get-ApplicationControlAudit
  $networkAudit = Get-NetworkSecurityAudit
    
  # Calculate overall security score
  $totalScore = $cameraAudit.SecurityScore + $usbAudit.SecurityScore + $deviceAudit.SecurityScore + 
  $personalizationAudit.SecurityScore + $applicationAudit.SecurityScore + $networkAudit.SecurityScore
  $maxScore = 200 # Theoretical maximum score
  $scorePercentage = [math]::Round(($totalScore / $maxScore) * 100, 1)
    
  # Determine security level
  $securityLevel = switch ($scorePercentage) {
    { $_ -ge 90 } { @{ Level = "Excellent"; Color = "#27ae60"; Icon = "🛡️" } }
    { $_ -ge 75 } { @{ Level = "Good"; Color = "#f39c12"; Icon = "⚠️" } }
    { $_ -ge 50 } { @{ Level = "Fair"; Color = "#e67e22"; Icon = "🔶" } }
    default { @{ Level = "Poor"; Color = "#e74c3c"; Icon = "🚨" } }
  }
    
  $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Advanced Security Audit Report - $timestamp</title>
    <style>
        body { 
            font-family: 'Segoe UI', Arial, sans-serif; 
            margin: 20px; 
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
        }
        .container { 
            max-width: 1400px; 
            margin: 0 auto; 
            background-color: white; 
            padding: 30px; 
            border-radius: 12px; 
            box-shadow: 0 8px 32px rgba(0,0,0,0.1);
        }
        h1 { 
            color: #2c3e50; 
            border-bottom: 4px solid #3498db; 
            padding-bottom: 15px; 
            margin-bottom: 30px;
            font-size: 2.5em;
        }
        h2 { 
            color: #34495e; 
            margin-top: 40px; 
            border-left: 5px solid #3498db;
            padding-left: 15px;
        }
        h3 { color: #7f8c8d; margin-top: 25px; }
        
        .security-dashboard {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
            margin: 30px 0;
        }
        
        .security-card {
            background: linear-gradient(135deg, #f8f9fa 0%, #e9ecef 100%);
            border-radius: 12px;
            padding: 25px;
            box-shadow: 0 4px 15px rgba(0,0,0,0.1);
            border-left: 5px solid #3498db;
        }
        
        .security-score {
            text-align: center;
            padding: 30px;
            background: linear-gradient(135deg, $($securityLevel.Color) 0%, $(if($securityLevel.Color -eq '#27ae60'){'#2ecc71'}elseif($securityLevel.Color -eq '#f39c12'){'#f1c40f'}elseif($securityLevel.Color -eq '#e67e22'){'#d35400'}else{'#c0392b'}) 100%);
            color: white;
            border-radius: 15px;
            margin: 20px 0;
            box-shadow: 0 6px 20px rgba(0,0,0,0.15);
        }
        
        .score-number {
            font-size: 4em;
            font-weight: bold;
            display: block;
        }
        
        .score-label {
            font-size: 1.2em;
            margin-top: 10px;
        }
        
        table { 
            border-collapse: collapse; 
            width: 100%; 
            margin: 20px 0;
            border-radius: 8px;
            overflow: hidden;
            box-shadow: 0 4px 15px rgba(0,0,0,0.1);
        }
        th, td { 
            border: 1px solid #ddd; 
            padding: 15px; 
            text-align: left; 
        }
        th { 
            background: linear-gradient(135deg, #3498db 0%, #2980b9 100%);
            color: white; 
            font-weight: bold; 
            font-size: 1.1em;
        }
        tr:nth-child(even) { background-color: #f8f9fa; }
        tr:hover { background-color: #e3f2fd; transition: background-color 0.3s; }
        
        .recommendation {
            background-color: #ffebee;
            border-left: 4px solid #f44336;
            padding: 12px;
            margin: 8px 0;
            border-radius: 4px;
        }
        
        .good-practice {
            background-color: #e8f5e8;
            border-left: 4px solid #4caf50;
            padding: 12px;
            margin: 8px 0;
            border-radius: 4px;
        }
        
        .audit-section {
            background-color: #f8f9fa;
            border-radius: 8px;
            padding: 20px;
            margin: 20px 0;
            border: 1px solid #e9ecef;
        }
        
        .status-enabled { color: #27ae60; font-weight: bold; }
        .status-disabled { color: #e74c3c; font-weight: bold; }
        .status-not-configured { color: #f39c12; font-weight: bold; }
        
        .progress-bar {
            width: 100%;
            height: 30px;
            background-color: #ecf0f1;
            border-radius: 15px;
            overflow: hidden;
            margin: 10px 0;
        }
        
        .progress-fill {
            height: 100%;
            background: linear-gradient(90deg, #3498db 0%, #2ecc71 100%);
            width: $scorePercentage%;
            border-radius: 15px;
            transition: width 0.5s ease;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>$($securityLevel.Icon) Advanced Security Audit Report</h1>
        <p><strong>Generated:</strong> $timestamp</p>
        <p><strong>System:</strong> $env:COMPUTERNAME</p>
        <p><strong>Domain:</strong> $env:USERDNSDOMAIN</p>
        
        <div class="security-score">
            <span class="score-number">$scorePercentage%</span>
            <div class="score-label">Security Score: $($securityLevel.Level)</div>
            <div class="progress-bar">
                <div class="progress-fill"></div>
            </div>
            <p>Score: $totalScore / $maxScore points</p>
        </div>
        
        <div class="security-dashboard">
            <div class="security-card">
                <h3>🎥 Camera & Microphone Security</h3>
                <p><strong>Score:</strong> $($cameraAudit.SecurityScore)/40</p>
                <p><strong>Camera Policy:</strong> <span class="status-$(($cameraAudit.ComputerCameraPolicy -replace ' ','-').ToLower())">$($cameraAudit.ComputerCameraPolicy)</span></p>
                <p><strong>Microphone Policy:</strong> <span class="status-$(($cameraAudit.ComputerMicrophonePolicy -replace ' ','-').ToLower())">$($cameraAudit.ComputerMicrophonePolicy)</span></p>
            </div>
            
            <div class="security-card">
                <h3>🔌 USB & Storage Security</h3>
                <p><strong>Score:</strong> $($usbAudit.SecurityScore)/50</p>
                <p><strong>Removable Storage:</strong> <span class="status-$(if($usbAudit.RemovableStoragePolicy -eq 'Not Configured'){'not-configured'}else{'configured'})">$($usbAudit.RemovableStoragePolicy)</span></p>
                <p><strong>USB Installation:</strong> <span class="status-$(($usbAudit.USBInstallationPolicy -replace ' ','-').ToLower())">$($usbAudit.USBInstallationPolicy)</span></p>
            </div>
            
            <div class="security-card">
                <h3>🖥️ Device Control</h3>
                <p><strong>Score:</strong> $($deviceAudit.SecurityScore)/50</p>
                <p><strong>Bluetooth:</strong> <span class="status-$(($deviceAudit.BluetoothPolicy).ToLower())">$($deviceAudit.BluetoothPolicy)</span></p>
                <p><strong>WiFi Auto-Connect:</strong> <span class="status-$(($deviceAudit.WiFiPolicy -replace ' ','-').ToLower())">$($deviceAudit.WiFiPolicy)</span></p>
            </div>
            
            <div class="security-card">
                <h3>🎨 Personalization & Privacy</h3>
                <p><strong>Score:</strong> $($personalizationAudit.SecurityScore)/45</p>
                <p><strong>Cortana:</strong> <span class="status-$(($personalizationAudit.CortanaPolicy).ToLower())">$($personalizationAudit.CortanaPolicy)</span></p>
                <p><strong>OneDrive:</strong> <span class="status-$(($personalizationAudit.OneDrivePolicy).ToLower())">$($personalizationAudit.OneDrivePolicy)</span></p>
            </div>
            
            <div class="security-card">
                <h3>📱 Application Control</h3>
                <p><strong>Score:</strong> $($applicationAudit.SecurityScore)/70</p>
                <p><strong>PowerShell Policy:</strong> <span class="status-enabled">$($applicationAudit.PowerShellExecutionPolicy)</span></p>
                <p><strong>PS Logging:</strong> <span class="status-$(($applicationAudit.PowerShellLogging).ToLower())">$($applicationAudit.PowerShellLogging)</span></p>
            </div>
            
            <div class="security-card">
                <h3>🌐 Network Security</h3>
                <p><strong>Score:</strong> $($networkAudit.SecurityScore)/40</p>
                <p><strong>Remote Desktop:</strong> <span class="status-$(($networkAudit.RemoteDesktopPolicy).ToLower())">$($networkAudit.RemoteDesktopPolicy)</span></p>
                <p><strong>SMB Signing:</strong> <span class="status-$(($networkAudit.SMBSigning -replace ' ','-').ToLower())">$($networkAudit.SMBSigning)</span></p>
            </div>
        </div>
"@

  # Add detailed audit sections
  $html += "<h2>📊 Detailed Security Analysis</h2>"
    
  # Camera Security Section
  $html += @"
        <div class="audit-section">
            <h3>🎥 Camera and Microphone Security</h3>
            <table>
                <tr><th>Setting</th><th>Status</th><th>Security Impact</th></tr>
                <tr><td>Computer Camera Policy</td><td>$($cameraAudit.ComputerCameraPolicy)</td><td>Privacy Protection</td></tr>
                <tr><td>Computer Microphone Policy</td><td>$($cameraAudit.ComputerMicrophonePolicy)</td><td>Audio Privacy</td></tr>
            </table>
"@
    
  foreach ($recommendation in $cameraAudit.Recommendations) {
    $html += "<div class='recommendation'>⚠️ $recommendation</div>"
  }
    
  $html += "</div>"
    
  # USB Security Section
  $html += @"
        <div class="audit-section">
            <h3>🔌 USB and Removable Storage Security</h3>
            <table>
                <tr><th>Control</th><th>Status</th><th>Connected Devices</th></tr>
                <tr><td>Removable Storage Access</td><td>$($usbAudit.RemovableStoragePolicy)</td><td rowspan="3">$($usbAudit.ConnectedUSBDevices.Count) USB devices</td></tr>
                <tr><td>USB Installation Policy</td><td>$($usbAudit.USBInstallationPolicy)</td></tr>
                <tr><td>Autorun Policy</td><td>$($usbAudit.AutorunPolicy)</td></tr>
            </table>
"@
    
  foreach ($recommendation in $usbAudit.Recommendations) {
    $html += "<div class='recommendation'>⚠️ $recommendation</div>"
  }
    
  $html += "</div>"
    
  # Add all other sections similarly...
    
  # Summary and Recommendations
  $allRecommendations = $cameraAudit.Recommendations + $usbAudit.Recommendations + $deviceAudit.Recommendations + 
  $personalizationAudit.Recommendations + $applicationAudit.Recommendations + $networkAudit.Recommendations
    
  $html += @"
        <h2>🎯 Priority Recommendations</h2>
        <div class="audit-section">
"@
    
  foreach ($recommendation in ($allRecommendations | Select-Object -Unique)) {
    $html += "<div class='recommendation'>📌 $recommendation</div>"
  }
    
  $html += @"
        </div>
        
        <h2>📈 Security Improvement Plan</h2>
        <div class="audit-section">
            <h4>Immediate Actions (High Priority)</h4>
            <ul>
                <li>Configure camera and microphone access policies</li>
                <li>Implement USB device restrictions</li>
                <li>Disable unnecessary services (Bluetooth, auto-connect WiFi)</li>
                <li>Enable PowerShell logging and execution policies</li>
            </ul>
            
            <h4>Medium-term Actions</h4>
            <ul>
                <li>Deploy AppLocker policies for application control</li>
                <li>Implement Windows Defender Application Guard</li>
                <li>Configure advanced audit policies</li>
                <li>Review and optimize telemetry settings</li>
            </ul>
            
            <h4>Long-term Monitoring</h4>
            <ul>
                <li>Regular security audits and policy reviews</li>
                <li>Monitor connected devices and USB usage</li>
                <li>Update security baselines based on threat landscape</li>
                <li>Train users on security best practices</li>
            </ul>
        </div>
        
        <footer style="margin-top: 40px; padding-top: 20px; border-top: 2px solid #ddd; text-align: center; color: #7f8c8d;">
            <p><strong>Advanced Security Audit - Windows Server Lab Environment</strong></p>
            <p>Generated by AdvancedSecurityAudit.ps1 on $timestamp</p>
            <p>Security Score: $scorePercentage% ($($securityLevel.Level))</p>
        </footer>
    </div>
</body>
</html>
"@
    
  $html | Out-File -FilePath $reportPath -Encoding UTF8
  # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "✅ Advanced security audit report generated: $reportPath" -ForegroundColor Green
  # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "🛡️ Overall Security Score: $scorePercentage% ($($securityLevel.Level))" -ForegroundColor $( 
    switch ($securityLevel.Level) {
      "Excellent" { "Green" }
      "Good" { "Yellow" }
      "Fair" { "DarkYellow" }
      default { "Red" }
    }
  )
    
  return $reportPath
}

# Function to run quick security check
function Start-QuickSecurityCheck {
  # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "🚀 Running Quick Security Check..." -ForegroundColor Cyan
    
  $issues = @()
    
  # Quick camera check
  $cameraReg = "HKLM:\SOFTWARE\Policies\Microsoft\Camera"
  if (-not (Test-Path $cameraReg)) {
    $issues += "Camera access policies not configured"
  }
    
  # Quick USB check
  $usbReg = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\RemovableStorageDevices"
  if (-not (Test-Path $usbReg)) {
    $issues += "USB/Removable storage policies not configured"
  }
    
  # Quick firewall check
  $firewallProfiles = Get-NetFirewallProfile
  $disabledProfiles = $firewallProfiles | Where-Object { -not $_.Enabled }
  if ($disabledProfiles) {
    $issues += "Windows Firewall disabled on $($disabledProfiles.Count) profile(s)"
  }
    
  # Quick PowerShell check
  $psPolicy = Get-ExecutionPolicy
  if ($psPolicy -eq "Unrestricted" -or $psPolicy -eq "Bypass") {
    $issues += "PowerShell execution policy too permissive: $psPolicy"
  }
    
  # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "`n📋 Quick Security Check Results:" -ForegroundColor Yellow
  if ($issues.Count -eq 0) {
    # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "✅ No immediate security issues detected!" -ForegroundColor Green
  }
  else {
    # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "⚠️ Found $($issues.Count) potential security issues:" -ForegroundColor Red
    foreach ($issue in $issues) {
      # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "  • $issue" -ForegroundColor Yellow
    }
  }
    
  Write-Host "`n💡 Run 'Get-AdvancedSecurityReport' for comprehensive analysis" -ForegroundColor Cyan
}

# Export functions
Export-ModuleMember -Function Get-AdvancedSecurityReport, Start-QuickSecurityCheck, Get-CameraSecurityAudit, Get-USBSecurityAudit

# Main execution
if ($MyInvocation.InvocationName -eq $MyInvocation.MyCommand.Path) {
  Start-QuickSecurityCheck
  Write-Information "`nWould you like to generate a full security report? (Y/N): " -InformationAction Continue -NoNewline -ForegroundColor Cyan
  $response = Read-Host
  if ($response -eq 'Y' -or $response -eq 'y') {
    Get-AdvancedSecurityReport
  }
}
</rewritten_file>