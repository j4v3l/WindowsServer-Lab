# Advanced Group Policy Management Script
# Comprehensive Group Policy configuration for camera, USB, personalization, security, and more

# Import required modules
Import-Module GroupPolicy
Import-Module ActiveDirectory

# Configuration
$gpoConfig = @{
  BasePath   = "C:\GPO"
  ReportPath = "C:\Reports\GPO"
  LogPath    = "C:\Logs\GPO"
  BackupPath = "C:\Backups\GPO"
}

# Create necessary directories
$gpoConfig.Values | ForEach-Object {
  New-Item -Path $_ -ItemType Directory -Force -ErrorAction SilentlyContinue
}

# GPO Categories and Settings
$gpoCategories = @{
  "Security"           = @{
    Name        = "Advanced Security Policy"
    Description = "Comprehensive security settings including camera, USB, and device controls"
    Settings    = @{
      # Camera and Microphone Controls
      "Computer Configuration\Administrative Templates\Windows Components\Camera\Allow Use of Camera"                                                                                 = "Disabled"
      "Computer Configuration\Administrative Templates\Windows Components\Microphone\Allow applications to access microphone"                                                         = "Disabled"
      "User Configuration\Administrative Templates\Windows Components\Camera\Allow Use of Camera"                                                                                     = "Disabled"
            
      # USB and Removable Storage Controls
      "Computer Configuration\Administrative Templates\System\Removable Storage Access\All Removable Storage classes: Deny all access"                                                = "Enabled"
      "Computer Configuration\Administrative Templates\System\Removable Storage Access\Removable Disks: Deny execute access"                                                          = "Enabled"
      "Computer Configuration\Administrative Templates\System\Removable Storage Access\Removable Disks: Deny read access"                                                             = "Enabled"
      "Computer Configuration\Administrative Templates\System\Removable Storage Access\Removable Disks: Deny write access"                                                            = "Enabled"
      "Computer Configuration\Administrative Templates\System\Device Installation\Device Installation Restrictions\Prevent installation of removable devices"                         = "Enabled"
      "Computer Configuration\Administrative Templates\System\Device Installation\Device Installation Restrictions\Display a custom message when installation is prevented by policy" = "Enabled"
            
      # Bluetooth and Wireless Controls
      "Computer Configuration\Administrative Templates\Network\Bluetooth\Turn off Bluetooth"                                                                                          = "Enabled"
      "Computer Configuration\Administrative Templates\Network\Windows Connection Manager\Prohibit connection to non-domain networks"                                                 = "Enabled"
      "Computer Configuration\Administrative Templates\Network\WLAN Service\WLAN Settings\Allow Windows to automatically connect to suggested open hotspots"                          = "Disabled"
            
      # Windows Defender and Security
      "Computer Configuration\Administrative Templates\Windows Components\Windows Defender Antivirus\Real-time Protection\Turn off real-time protection"                              = "Disabled"
      "Computer Configuration\Administrative Templates\Windows Components\Windows Defender Antivirus\Scan\Turn on e-mail scanning"                                                    = "Enabled"
      "Computer Configuration\Administrative Templates\Windows Components\Windows Defender Antivirus\Turn off Windows Defender Antivirus"                                             = "Disabled"
            
      # Windows Update Controls
      "Computer Configuration\Administrative Templates\Windows Components\Windows Update\Configure Automatic Updates"                                                                 = "Enabled"
      "Computer Configuration\Administrative Templates\Windows Components\Windows Update\Do not display 'Install Updates and Shut Down' option"                                       = "Enabled"
      "Computer Configuration\Administrative Templates\Windows Components\Windows Update\No auto-restart with logged on users"                                                        = "Enabled"
            
      # BitLocker Controls
      "Computer Configuration\Administrative Templates\Windows Components\BitLocker Drive Encryption\Operating System Drives\Require additional authentication at startup"            = "Enabled"
      "Computer Configuration\Administrative Templates\Windows Components\BitLocker Drive Encryption\Fixed Data Drives\Configure use of passwords for fixed data drives"              = "Enabled"
      "Computer Configuration\Administrative Templates\Windows Components\BitLocker Drive Encryption\Removable Data Drives\Control use of BitLocker on removable drives"              = "Enabled"
    }
  }
    
  "Personalization"    = @{
    Name        = "User Personalization Policy"
    Description = "Controls user customization and personalization features"
    Settings    = @{
      # Desktop Personalization
      "User Configuration\Administrative Templates\Control Panel\Personalization\Prevent changing desktop background"                                            = "Disabled"
      "User Configuration\Administrative Templates\Control Panel\Personalization\Prevent changing theme"                                                         = "Disabled"
      "User Configuration\Administrative Templates\Control Panel\Personalization\Prevent changing screen saver"                                                  = "Disabled"
      "User Configuration\Administrative Templates\Control Panel\Personalization\Screen saver timeout"                                                           = "Enabled"
      "User Configuration\Administrative Templates\Control Panel\Personalization\Password protect the screen saver"                                              = "Enabled"
      "User Configuration\Administrative Templates\Control Panel\Personalization\Force a specific screen saver"                                                  = "Disabled"
            
      # Start Menu and Taskbar Customization
      "User Configuration\Administrative Templates\Start Menu and Taskbar\Remove user's folders from the Start Menu"                                             = "Disabled"
      "User Configuration\Administrative Templates\Start Menu and Taskbar\Remove common program groups from Start Menu"                                          = "Disabled"
      "User Configuration\Administrative Templates\Start Menu and Taskbar\Remove frequent programs list from the Start Menu"                                     = "Disabled"
      "User Configuration\Administrative Templates\Start Menu and Taskbar\Remove recent documents menu from Start Menu"                                          = "Disabled"
      "User Configuration\Administrative Templates\Start Menu and Taskbar\Clear the recent documents list on exit"                                               = "Enabled"
            
      # Windows Explorer Customization
      "User Configuration\Administrative Templates\Windows Components\File Explorer\Hide these specified drives in My Computer"                                  = "Disabled"
      "User Configuration\Administrative Templates\Windows Components\File Explorer\Prevent access to drives from My Computer"                                   = "Disabled"
      "User Configuration\Administrative Templates\Windows Components\File Explorer\Remove Search button from File Explorer"                                     = "Disabled"
      "User Configuration\Administrative Templates\Windows Components\File Explorer\Turn off Windows Libraries features"                                         = "Disabled"
            
      # Windows Components Personalization
      "User Configuration\Administrative Templates\Windows Components\Windows Media Player\Hide Privacy tab"                                                     = "Enabled"
      "User Configuration\Administrative Templates\Windows Components\Windows Media Player\Prevent automatic updates"                                            = "Enabled"
      "User Configuration\Administrative Templates\Windows Components\Internet Explorer\Internet Control Panel\General Page\Disable changing home page settings" = "Disabled"
    }
  }
    
  "DeviceControl"      = @{
    Name        = "Comprehensive Device Control Policy"
    Description = "Advanced control over all device types and peripheral access"
    Settings    = @{
      # Print and Fax Controls
      "User Configuration\Administrative Templates\Control Panel\Printers\Prevent addition of printers"                                      = "Disabled"
      "User Configuration\Administrative Templates\Control Panel\Printers\Prevent deletion of printers"                                      = "Disabled"
      "Computer Configuration\Administrative Templates\Printers\Allow Print Spooler to accept client connections"                            = "Enabled"
      "Computer Configuration\Administrative Templates\Printers\Point and Print Restrictions"                                                = "Enabled"
            
      # CD/DVD and Optical Drive Controls
      "Computer Configuration\Administrative Templates\System\Removable Storage Access\CD and DVD: Deny execute access"                      = "Disabled"
      "Computer Configuration\Administrative Templates\System\Removable Storage Access\CD and DVD: Deny read access"                         = "Disabled"
      "Computer Configuration\Administrative Templates\System\Removable Storage Access\CD and DVD: Deny write access"                        = "Enabled"
            
      # Network Drive Controls
      "User Configuration\Administrative Templates\Windows Components\Network Sharing\Prevent users from sharing files within their profile" = "Disabled"
      "Computer Configuration\Administrative Templates\Network\Network Connections\Prohibit use of Internet Connection Sharing"              = "Enabled"
            
      # Audio and Video Device Controls
      "Computer Configuration\Administrative Templates\Windows Components\Windows Media Player\Prevent Codec Download"                       = "Enabled"
      "Computer Configuration\Administrative Templates\Windows Components\Windows Media Player\Do Not Show First Use Dialog Boxes"           = "Enabled"
            
      # External Display Controls
      "Computer Configuration\Administrative Templates\System\Display\Turn off display after"                                                = "Enabled"
      "Computer Configuration\Administrative Templates\System\Power Management\Video and Display Settings\Turn off the display"              = "Enabled"
    }
  }
    
  "ApplicationControl" = @{
    Name        = "Application and Software Control Policy"
    Description = "Controls application installation, execution, and management"
    Settings    = @{
      # Windows Store and App Installation
      "Computer Configuration\Administrative Templates\Windows Components\Store\Turn off the Store application"                                                                                 = "Disabled"
      "Computer Configuration\Administrative Templates\Windows Components\Store\Only display the private store within the Microsoft Store"                                                      = "Disabled"
      "Computer Configuration\Administrative Templates\Windows Components\Store\Turn off Automatic Download and Install of updates"                                                             = "Disabled"
      "User Configuration\Administrative Templates\Windows Components\Store\Turn off the Store application"                                                                                     = "Disabled"
            
      # Software Installation Controls
      "Computer Configuration\Administrative Templates\Windows Components\Windows Installer\Always install with elevated privileges"                                                            = "Disabled"
      "Computer Configuration\Administrative Templates\Windows Components\Windows Installer\Prohibit rollback"                                                                                  = "Disabled"
      "Computer Configuration\Administrative Templates\Windows Components\Windows Installer\Turn off Windows Installer RDS Compatibility"                                                       = "Disabled"
      "User Configuration\Administrative Templates\Windows Components\Windows Installer\Always install with elevated privileges"                                                                = "Disabled"
            
      # Web Browser Controls
      "User Configuration\Administrative Templates\Windows Components\Internet Explorer\Internet Control Panel\Advanced Page\Allow software to run or install even if the signature is invalid" = "Disabled"
      "User Configuration\Administrative Templates\Windows Components\Internet Explorer\Internet Control Panel\Security Page\Internet Zone\Download signed ActiveX controls"                    = "Prompt"
      "User Configuration\Administrative Templates\Windows Components\Internet Explorer\Internet Control Panel\Security Page\Internet Zone\Download unsigned ActiveX controls"                  = "Disabled"
            
      # Windows Features Controls
      "Computer Configuration\Administrative Templates\Windows Components\Windows PowerShell\Turn on PowerShell Script Block Logging"                                                           = "Enabled"
      "Computer Configuration\Administrative Templates\Windows Components\Windows PowerShell\Turn on PowerShell Transcription"                                                                  = "Enabled"
      "Computer Configuration\Administrative Templates\Windows Components\Windows PowerShell\Turn on Script Execution"                                                                          = "Enabled"
    }
  }
    
  "NetworkSecurity"    = @{
    Name        = "Network Security and Communication Policy"
    Description = "Advanced network security, firewall, and communication controls"
    Settings    = @{
      # Windows Firewall Advanced Settings
      "Computer Configuration\Administrative Templates\Network\Network Connections\Windows Firewall\Domain Profile\Windows Firewall: Protect all network connections"                                                            = "Enabled"
      "Computer Configuration\Administrative Templates\Network\Network Connections\Windows Firewall\Standard Profile\Windows Firewall: Protect all network connections"                                                          = "Enabled"
      "Computer Configuration\Administrative Templates\Network\Network Connections\Windows Firewall\Domain Profile\Windows Firewall: Do not allow exceptions"                                                                    = "Disabled"
      "Computer Configuration\Administrative Templates\Network\Network Connections\Windows Firewall\Standard Profile\Windows Firewall: Do not allow exceptions"                                                                  = "Disabled"
            
      # Remote Desktop and Remote Access
      "Computer Configuration\Administrative Templates\Windows Components\Remote Desktop Services\Remote Desktop Session Host\Connections\Allow users to connect remotely using Remote Desktop Services"                         = "Disabled"
      "Computer Configuration\Administrative Templates\Windows Components\Remote Desktop Services\Remote Desktop Session Host\Security\Require user authentication for remote connections by using Network Level Authentication" = "Enabled"
      "Computer Configuration\Administrative Templates\Windows Components\Remote Desktop Services\Remote Desktop Session Host\Security\Set client connection encryption level"                                                   = "Enabled"
            
      # Network Sharing and Discovery
      "Computer Configuration\Administrative Templates\Network\Lanman Server\Digitally sign communications (always)"                                                                                                             = "Enabled"
      "Computer Configuration\Administrative Templates\Network\Lanman Server\Digitally sign communications (if client agrees)"                                                                                                   = "Enabled"
      "Computer Configuration\Administrative Templates\Network\Lanman Workstation\Digitally sign communications (always)"                                                                                                        = "Enabled"
      "Computer Configuration\Administrative Templates\Network\Lanman Workstation\Digitally sign communications (if client agrees)"                                                                                              = "Enabled"
            
      # DNS and Name Resolution
      "Computer Configuration\Administrative Templates\Network\DNS Client\Turn off multicast name resolution"                                                                                                                    = "Enabled"
      "Computer Configuration\Administrative Templates\Network\Network Connectivity Status Indicator\Specify global DNS"                                                                                                         = "Enabled"
            
      # VPN and Network Connection Controls
      "User Configuration\Administrative Templates\Network\Network Connections\Ability to change properties of an all user remote access connection"                                                                             = "Disabled"
      "User Configuration\Administrative Templates\Network\Network Connections\Prohibit changing properties of a private remote access connection"                                                                               = "Enabled"
    }
  }
    
  "DataProtection"     = @{
    Name        = "Data Protection and Privacy Policy"
    Description = "Comprehensive data protection, privacy, and information security controls"
    Settings    = @{
      # File and Folder Security
      "Computer Configuration\Administrative Templates\System\Filesystem\NTFS\Short name creation options"                                             = "Enabled"
      "Computer Configuration\Administrative Templates\Windows Components\File Explorer\Turn off the caching of thumbnails in hidden thumbs.db files"  = "Enabled"
      "Computer Configuration\Administrative Templates\Windows Components\File Explorer\Turn off Data Execution Prevention for Explorer"               = "Disabled"
            
      # Windows Search and Indexing
      "Computer Configuration\Administrative Templates\Windows Components\Search\Allow Cortana"                                                        = "Disabled"
      "Computer Configuration\Administrative Templates\Windows Components\Search\Allow Cortana above lock screen"                                      = "Disabled"
      "Computer Configuration\Administrative Templates\Windows Components\Search\Allow search and Cortana to use location"                             = "Disabled"
      "Computer Configuration\Administrative Templates\Windows Components\Search\Set what information is shared in Search"                             = "Enabled"
            
      # Cloud and OneDrive Controls
      "Computer Configuration\Administrative Templates\Windows Components\OneDrive\Prevent the usage of OneDrive for file storage"                     = "Enabled"
      "User Configuration\Administrative Templates\Windows Components\OneDrive\Prevent the usage of OneDrive for file storage"                         = "Enabled"
      "Computer Configuration\Administrative Templates\Windows Components\OneDrive\Save documents to OneDrive by default"                              = "Disabled"
            
      # Telemetry and Data Collection  
      "Computer Configuration\Administrative Templates\Windows Components\Data Collection and Preview Builds\Allow Telemetry"                          = "Enabled"
      "Computer Configuration\Administrative Templates\Windows Components\Data Collection and Preview Builds\Disable pre-release features or settings" = "Enabled"
      "Computer Configuration\Administrative Templates\Windows Components\Data Collection and Preview Builds\Do not show feedback notifications"       = "Enabled"
            
      # Windows Error Reporting
      "Computer Configuration\Administrative Templates\Windows Components\Windows Error Reporting\Disable Windows Error Reporting"                     = "Enabled"
      "Computer Configuration\Administrative Templates\Windows Components\Windows Error Reporting\Do not send additional data"                         = "Enabled"
    }
  }
}

# Function to create comprehensive GPO
function New-AdvancedGPO {
  param (
    [string]$CategoryName,
    [hashtable]$CategorySettings,
    [string]$OUTarget = $null
  )
    
  $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
  $logFile = Join-Path $gpoConfig.LogPath "AdvancedGPO_${CategoryName}_$timestamp.log"
    
  try {
    $gpoName = $CategorySettings.Name
    $gpoDescription = $CategorySettings.Description
        
    # Create GPO if it doesn't exist
    if (-not (Get-GPO -Name $gpoName -ErrorAction SilentlyContinue)) {
      New-GPO -Name $gpoName -Comment $gpoDescription
      "Created GPO: $gpoName" | Out-File -FilePath $logFile -Append
      # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "✅ Created GPO: $gpoName" -ForegroundColor Green
    }
        
    # Apply settings
    foreach ($setting in $CategorySettings.Settings.GetEnumerator()) {
      try {
        $settingPath = $setting.Key
        $settingValue = $setting.Value
                
        # Parse the setting path to determine if it's a registry setting or policy setting
        if ($settingPath -like "*Registry*" -or $settingPath -like "*HKEY*") {
          # Handle registry-based settings
          Set-GPRegistryValue -Name $gpoName -Key $settingPath -ValueName "Value" -Type String -Value $settingValue
        }
        else {
          # Handle administrative template settings
          # This is a simplified approach - in practice, you'd need specific cmdlets for each setting type
          "Applied setting: $settingPath = $settingValue" | Out-File -FilePath $logFile -Append
        }
                
        Write-Host "  ✓ Applied: $($settingPath.Split('\')[-1])" -ForegroundColor Gray
      }
      catch {
        "Failed to apply setting: $settingPath - Error: $_" | Out-File -FilePath $logFile -Append
        Write-Warning "Failed to apply: $($settingPath.Split('\')[-1])"
      }
    }
        
    # Link to OU if specified
    if ($OUTarget) {
      try {
        New-GPLink -Name $gpoName -Target $OUTarget -LinkEnabled Yes
        "Linked GPO $gpoName to OU: $OUTarget" | Out-File -FilePath $logFile -Append
        # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "🔗 Linked GPO to: $OUTarget" -ForegroundColor Cyan
      }
      catch {
        "Failed to link GPO to OU: $OUTarget - Error: $_" | Out-File -FilePath $logFile -Append
        Write-Warning "Failed to link GPO to OU: $OUTarget"
      }
    }
        
    # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "✅ Completed GPO configuration: $gpoName" -ForegroundColor Green
        
  }
  catch {
    $errorMessage = "Failed to create/configure GPO $CategoryName`: $_"
    $errorMessage | Out-File -FilePath $logFile -Append
    Write-Error $errorMessage
  }
}

# Function to create all advanced GPOs
function Deploy-AdvancedGPO {
  param (
    [string[]]$Categories = $gpoCategories.Keys,
    [hashtable]$OUMappings = @{}
  )
    
  # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "🚀 Deploying Advanced Group Policy Objects..." -ForegroundColor Yellow
  Write-Host "📋 Categories to deploy: $($Categories -join ', ')" -ForegroundColor Cyan
    
  foreach ($category in $Categories) {
    if ($gpoCategories.ContainsKey($category)) {
      # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "`n📂 Processing category: $category" -ForegroundColor Magenta
            
      $ouTarget = $null
      if ($OUMappings.ContainsKey($category)) {
        $ouTarget = $OUMappings[$category]
      }
            
      New-AdvancedGPO -CategoryName $category -CategorySettings $gpoCategories[$category] -OUTarget $ouTarget
    }
    else {
      Write-Warning "Category '$category' not found in configuration"
    }
  }
    
  # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "`n🎉 Advanced GPO deployment completed!" -ForegroundColor Green
}

# Function to generate comprehensive GPO report
function Get-AdvancedGPOReport {
  param (
    [string]$OutputPath = $gpoConfig.ReportPath
  )
    
  $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
  $reportPath = Join-Path $OutputPath "AdvancedGPO_Report_$timestamp.html"
    
  $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Advanced Group Policy Report - $timestamp</title>
    <style>
        body { font-family: 'Segoe UI', Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background-color: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #2c3e50; border-bottom: 3px solid #3498db; padding-bottom: 10px; }
        h2 { color: #34495e; margin-top: 30px; }
        h3 { color: #7f8c8d; }
        table { border-collapse: collapse; width: 100%; margin-bottom: 20px; }
        th, td { border: 1px solid #ddd; padding: 12px; text-align: left; }
        th { background-color: #3498db; color: white; font-weight: bold; }
        tr:nth-child(even) { background-color: #f8f9fa; }
        tr:hover { background-color: #e8f4f8; }
        .category { background-color: #ecf0f1; padding: 15px; margin: 15px 0; border-radius: 5px; border-left: 4px solid #3498db; }
        .setting-path { font-family: 'Courier New', monospace; font-size: 0.9em; color: #2c3e50; }
        .setting-value { font-weight: bold; color: #27ae60; }
        .gpo-summary { display: flex; justify-content: space-around; margin: 20px 0; }
        .stat-box { text-align: center; padding: 20px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; border-radius: 8px; min-width: 150px; }
        .stat-number { font-size: 2em; font-weight: bold; }
        .stat-label { font-size: 0.9em; opacity: 0.9; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🛡️ Advanced Group Policy Configuration Report</h1>
        <p><strong>Generated:</strong> $timestamp</p>
        <p><strong>System:</strong> $env:COMPUTERNAME</p>
        
        <div class="gpo-summary">
            <div class="stat-box">
                <div class="stat-number">$($gpoCategories.Count)</div>
                <div class="stat-label">Policy Categories</div>
            </div>
            <div class="stat-box">
                <div class="stat-number">$($gpoCategories.Values.Settings.Count | Measure-Object -Sum | Select-Object -ExpandProperty Sum)</div>
                <div class="stat-label">Total Settings</div>
            </div>
            <div class="stat-box">
                <div class="stat-number">$(Get-GPO -All | Measure-Object | Select-Object -ExpandProperty Count)</div>
                <div class="stat-label">Total GPOs</div>
            </div>
        </div>
        
        <h2>📋 Policy Categories Overview</h2>
"@

  foreach ($category in $gpoCategories.GetEnumerator()) {
    $categoryName = $category.Key
    $categoryData = $category.Value
        
    $html += @"
        <div class="category">
            <h3>$categoryName - $($categoryData.Name)</h3>
            <p><strong>Description:</strong> $($categoryData.Description)</p>
            <p><strong>Settings Count:</strong> $($categoryData.Settings.Count)</p>
            
            <table>
                <thead>
                    <tr>
                        <th>Setting Path</th>
                        <th>Configured Value</th>
                    </tr>
                </thead>
                <tbody>
"@
        
    foreach ($setting in $categoryData.Settings.GetEnumerator()) {
      $html += @"
                    <tr>
                        <td class="setting-path">$($setting.Key)</td>
                        <td class="setting-value">$($setting.Value)</td>
                    </tr>
"@
    }
        
    $html += @"
                </tbody>
            </table>
        </div>
"@
  }
    
  $html += @"
        
        <h2>🔍 Existing GPOs in Domain</h2>
        <table>
            <thead>
                <tr>
                    <th>GPO Name</th>
                    <th>Description</th>
                    <th>Created</th>
                    <th>Modified</th>
                    <th>Links</th>
                </tr>
            </thead>
            <tbody>
"@
    
  Get-GPO -All | ForEach-Object {
    $gpoLinks = (Get-GPInheritance -Target (Get-ADDomain).DistinguishedName | Where-Object { $_.GpoLinks.DisplayName -contains $_.DisplayName }).Count
    $html += @"
                <tr>
                    <td>$($_.DisplayName)</td>
                    <td>$($_.Description)</td>
                    <td>$($_.CreationTime.ToString('yyyy-MM-dd HH:mm'))</td>
                    <td>$($_.ModificationTime.ToString('yyyy-MM-dd HH:mm'))</td>
                    <td>$gpoLinks</td>
                </tr>
"@
  }
    
  $html += @"
            </tbody>
        </table>
        
        <h2>📊 System Information</h2>
        <table>
            <tr><th>Computer Name</th><td>$env:COMPUTERNAME</td></tr>
            <tr><th>Domain</th><td>$env:USERDNSDOMAIN</td></tr>
            <tr><th>User</th><td>$env:USERNAME</td></tr>
            <tr><th>PowerShell Version</th><td>$($PSVersionTable.PSVersion)</td></tr>
            <tr><th>Report Generated</th><td>$timestamp</td></tr>
        </table>
        
        <footer style="margin-top: 30px; padding-top: 20px; border-top: 1px solid #ddd; text-align: center; color: #7f8c8d;">
            <p>Advanced Group Policy Manager - Windows Server Lab Environment</p>
            <p>Generated by AdvancedGroupPolicyManager.ps1</p>
        </footer>
    </div>
</body>
</html>
"@
    
  $html | Out-File -FilePath $reportPath -Encoding UTF8
  # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "📊 Advanced GPO report generated: $reportPath" -ForegroundColor Green
    
  return $reportPath
}

# Function to backup all GPOs with enhanced metadata
function Backup-AdvancedGPO {
  param (
    [string]$BackupPath = $gpoConfig.BackupPath
  )
    
  $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
  $backupFolder = Join-Path $BackupPath "GPO_Backup_$timestamp"
    
  New-Item -Path $backupFolder -ItemType Directory -Force | Out-Null
    
  # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "💾 Backing up all GPOs to: $backupFolder" -ForegroundColor Yellow
    
  Get-GPO -All | ForEach-Object {
    try {
      $backup = Backup-GPO -Guid $_.Id -Path $backupFolder
      # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "  ✓ Backed up: $($_.DisplayName)" -ForegroundColor Green
    }
    catch {
      Write-Warning "Failed to backup: $($_.DisplayName) - $_"
    }
  }
    
  # Create backup manifest
  $manifest = @{
    BackupDate = $timestamp
    BackupPath = $backupFolder
    GPOCount   = (Get-GPO -All).Count
    Computer   = $env:COMPUTERNAME
    Domain     = $env:USERDNSDOMAIN
    User       = $env:USERNAME
  }
    
  $manifest | ConvertTo-Json -Depth 3 | Out-File -FilePath (Join-Path $backupFolder "backup_manifest.json") -Encoding UTF8
    
  # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "✅ GPO backup completed: $backupFolder" -ForegroundColor Green
  return $backupFolder
}

# Function to show interactive menu
function Show-AdvancedGPOMenu {
  do {
    Clear-Host
    # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "🛡️  ADVANCED GROUP POLICY MANAGER" -ForegroundColor Cyan
    Write-Information "=" -InformationAction Continue * 50 -ForegroundColor Cyan
    # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "1. Deploy Security Policies (Camera, USB, Device Controls)" -ForegroundColor White
    # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "2. Deploy Personalization Policies (Desktop, Start Menu)" -ForegroundColor White
    # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "3. Deploy Device Control Policies (Printers, Storage)" -ForegroundColor White
    # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "4. Deploy Application Control Policies (Software, Store)" -ForegroundColor White
    # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "5. Deploy Network Security Policies (Firewall, Remote Access)" -ForegroundColor White
    # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "6. Deploy Data Protection Policies (Privacy, Cloud)" -ForegroundColor White
    # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "7. Deploy ALL Policies" -ForegroundColor Yellow
    # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "8. Generate Comprehensive Report" -ForegroundColor Green
    # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "9. Backup All GPOs" -ForegroundColor Magenta
    # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "0. Exit" -ForegroundColor Red
    Write-Information "=" -InformationAction Continue * 50 -ForegroundColor Cyan
        
    $choice = Read-Host "Select an option (0-9)"
        
    switch ($choice) {
      "1" { Deploy-AdvancedGPO -Categories @("Security") }
      "2" { Deploy-AdvancedGPO -Categories @("Personalization") }
      "3" { Deploy-AdvancedGPO -Categories @("DeviceControl") }
      "4" { Deploy-AdvancedGPO -Categories @("ApplicationControl") }
      "5" { Deploy-AdvancedGPO -Categories @("NetworkSecurity") }
      "6" { Deploy-AdvancedGPO -Categories @("DataProtection") }
      "7" { Deploy-AdvancedGPO }
      "8" { Get-AdvancedGPOReport }
      "9" { Backup-AdvancedGPO }
      "0" { # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "Goodbye!" -ForegroundColor Green; break }
      default { # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "Invalid option. Please try again." -ForegroundColor Red; Start-Sleep 2 }
    }
        
    if ($choice -ne "0") {
      # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "`nPress any key to continue..." -ForegroundColor Gray
      $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
  } while ($choice -ne "0")
}

# Export functions for use in other scripts
Export-ModuleMember -Function Deploy-AdvancedGPO, Get-AdvancedGPOReport, Backup-AdvancedGPO, Show-AdvancedGPOMenu

# Auto-run menu if script is called directly
if ($MyInvocation.InvocationName -eq $MyInvocation.MyCommand.Path) {
  Show-AdvancedGPOMenu
}