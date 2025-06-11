# Group Policy Management Script
# This script configures various Group Policy settings for security and standardization

# Import required modules
Import-Module GroupPolicy
Import-Module ActiveDirectory

# Configuration
$gpoConfig = @{
    GpoName = "Standard Security Settings"
    Description = "Standard security and user experience settings for all computers"
    ReportPath = "C:\Reports\GPO"
    LogPath = "C:\Logs\GPO"
}

# Create necessary directories
New-Item -Path $gpoConfig.ReportPath -ItemType Directory -Force -ErrorAction SilentlyContinue
New-Item -Path $gpoConfig.LogPath -ItemType Directory -Force -ErrorAction SilentlyContinue

# Function to create and configure GPO
function Set-StandardGPO {
    param (
        [string]$GpoName = $gpoConfig.GpoName
    )
    
    $logFile = Join-Path $gpoConfig.LogPath "gpo_config_$(Get-Date -Format 'yyyy-MM-dd_HH-mm').log"
    
    try {
        # Create new GPO if it doesn't exist
        if (-not (Get-GPO -Name $GpoName -ErrorAction SilentlyContinue)) {
            New-GPO -Name $GpoName -Comment $gpoConfig.Description
            # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "Created new GPO: $GpoName" -ForegroundColor Green
        }

        # Computer Configuration Settings
        $computerSettings = @{
            # Security Settings
            "Computer Configuration\Windows Settings\Security Settings\Account Policies\Password Policy\Minimum password length" = 12
            "Computer Configuration\Windows Settings\Security Settings\Account Policies\Password Policy\Password must meet complexity requirements" = "Enabled"
            "Computer Configuration\Windows Settings\Security Settings\Account Policies\Account Lockout Policy\Account lockout threshold" = 5
            "Computer Configuration\Windows Settings\Security Settings\Account Policies\Account Lockout Policy\Account lockout duration" = 30
            
            # Windows Components
            "Computer Configuration\Administrative Templates\Windows Components\Windows Update\Configure Automatic Updates" = "Enabled"
            "Computer Configuration\Administrative Templates\Windows Components\Windows Update\No auto-restart with logged on users for scheduled automatic updates installations" = "Disabled"
            
            # System
            "Computer Configuration\Administrative Templates\System\Power Management\Button Settings\Turn off the display (on battery)" = "Enabled"
            "Computer Configuration\Administrative Templates\System\Power Management\Button Settings\Turn off the display (plugged in)" = "Enabled"
            
            # Network
            "Computer Configuration\Administrative Templates\Network\Windows Connection Manager\Prohibit connection to non-domain networks when connected to domain authenticated network" = "Enabled"
            
            # Bluetooth
            "Computer Configuration\Administrative Templates\Windows Components\Bluetooth\Turn off Bluetooth" = "Enabled"
            
            # Windows Store
            "Computer Configuration\Administrative Templates\Windows Components\Store\Turn off the Store application" = "Enabled"
            
            # Remote Desktop
            "Computer Configuration\Administrative Templates\Windows Components\Remote Desktop Services\Remote Desktop Session Host\Connections\Allow users to connect remotely using Remote Desktop Services" = "Disabled"
        }

        # User Configuration Settings
        $userSettings = @{
            # Control Panel
            "User Configuration\Administrative Templates\Control Panel\Personalization\Prevent changing desktop background" = "Enabled"
            "User Configuration\Administrative Templates\Control Panel\Personalization\Prevent changing theme" = "Enabled"
            "User Configuration\Administrative Templates\Control Panel\Personalization\Prevent changing screen saver" = "Enabled"
            
            # Start Menu and Taskbar
            "User Configuration\Administrative Templates\Start Menu and Taskbar\Remove user's folders from the Start Menu" = "Enabled"
            "User Configuration\Administrative Templates\Start Menu and Taskbar\Remove common program groups from Start Menu" = "Enabled"
            
            # Windows Components
            "User Configuration\Administrative Templates\Windows Components\Windows Media Player\Prevent automatic updates" = "Enabled"
            "User Configuration\Administrative Templates\Windows Components\Windows Store\Turn off the Store application" = "Enabled"
            
            # System
            "User Configuration\Administrative Templates\System\Ctrl+Alt+Del Options\Remove Change Password" = "Enabled"
            "User Configuration\Administrative Templates\System\Ctrl+Alt+Del Options\Remove Lock Computer" = "Enabled"
            "User Configuration\Administrative Templates\System\Ctrl+Alt+Del Options\Remove Task Manager" = "Enabled"
            
            # Desktop
            "User Configuration\Administrative Templates\Desktop\Desktop\Remove Recycle Bin icon from desktop" = "Enabled"
            "User Configuration\Administrative Templates\Desktop\Desktop\Remove Computer icon from desktop" = "Enabled"
            "User Configuration\Administrative Templates\Desktop\Desktop\Remove Network icon from desktop" = "Enabled"
        }

        # Apply Computer Configuration Settings
        foreach ($setting in $computerSettings.GetEnumerator()) {
            Set-GPRegistryValue -Name $GpoName -Key $setting.Key -ValueName "Value" -Type DWord -Value $setting.Value
            "Set computer setting: $($setting.Key)" | Out-File -FilePath $logFile -Append
        }

        # Apply User Configuration Settings
        foreach ($setting in $userSettings.GetEnumerator()) {
            Set-GPRegistryValue -Name $GpoName -Key $setting.Key -ValueName "Value" -Type DWord -Value $setting.Value
            "Set user setting: $($setting.Key)" | Out-File -FilePath $logFile -Append
        }

        # Configure Software Installation
        $softwarePaths = @{
            "Adobe Reader" = "\\server\software\AdobeReader.msi"
            "Microsoft Office" = "\\server\software\Office.msi"
            "Antivirus" = "\\server\software\Antivirus.msi"
        }

        foreach ($software in $softwarePaths.GetEnumerator()) {
            if (Test-Path $software.Value) {
                New-GPO -Name "$GpoName - $($software.Key) Installation"
                Set-GPRegistryValue -Name "$GpoName - $($software.Key) Installation" `
                    -Key "Software\Policies\Microsoft\Windows\Installer" `
                    -ValueName "EnableAdminTSRemote" `
                    -Type DWord `
                    -Value 1
                "Configured software installation: $($software.Key)" | Out-File -FilePath $logFile -Append
            }
        }

        # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "GPO configuration completed successfully!" -ForegroundColor Green
    }
    catch {
        $errorMessage = "GPO configuration failed: $_"
        $errorMessage | Out-File -FilePath $logFile -Append
        # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host $errorMessage -ForegroundColor Red
    }
}

# Function to link GPO to OUs
function Set-GPOLink {
    param (
        [string]$GpoName = $gpoConfig.GpoName,
        [string[]]$OUs = @("Computers", "Users")
    )
    
    try {
        foreach ($ou in $OUs) {
            $ouPath = "OU=$ou,DC=lab,DC=local"
            New-GPLink -Name $GpoName -Target $ouPath
            # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "Linked GPO to OU: $ou" -ForegroundColor Green
        }
    }
    catch {
        # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "Failed to link GPO: $_" -ForegroundColor Red
    }
}

# Function to generate GPO report
function Get-GPOReport {
    param (
        [string]$GpoName = $gpoConfig.GpoName
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm"
    $reportPath = Join-Path $gpoConfig.ReportPath "GPO_Report_${GpoName}_$timestamp.html"
    
    Get-GPOReport -Name $GpoName -ReportType HTML -Path $reportPath
    # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "GPO report generated at: $reportPath" -ForegroundColor Green
}

# Function to backup GPOs
function Backup-GPO {
    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm"
    $backupPath = Join-Path $gpoConfig.ReportPath "GPO_Backup_$timestamp"
    
    New-Item -Path $backupPath -ItemType Directory -Force | Out-Null
    
    Get-GPO -All | ForEach-Object {
        Backup-GPO -Guid $_.Id -Path $backupPath
    }
    
    # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "GPOs backed up to: $backupPath" -ForegroundColor Green
}

# Example usage:
# Set-StandardGPO
# Set-GPOLink
# Get-GPOReport
# Backup-GPO 