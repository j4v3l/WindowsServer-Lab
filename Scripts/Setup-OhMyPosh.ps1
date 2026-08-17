# Oh My Posh Setup Script for Windows
# EXECUTION CONTEXT: Run INSIDE Windows VMs (Any Windows VM - Workstations or Servers)
# ACCESS METHOD: RDP, Console, or PowerShell Direct to Windows VMs
# PREREQUISITES: Internet access, Local Administrator rights (optional)

# This script automates the installation and configuration of Oh My Posh
# https://ohmyposh.dev/docs/installation/windows

<#
.SYNOPSIS
    Automated setup script for Oh My Posh on Windows.
.DESCRIPTION
    This script automates the installation and configuration of Oh My Posh on Windows,
    including installing Oh My Posh, the required fonts, and configuring PowerShell to use it.
    It can be used as a standalone script for Proxmox VE environments.
.PARAMETER Theme
    The Oh My Posh theme to use. If not specified, the default theme 'jandedobbeleer' will be used.
.PARAMETER FontName
    The Nerd Font library to install. Default is 'MesloLGM' (normalized to the
    current Oh My Posh library name 'meslo').
.PARAMETER SkipFontInstall
    Skip the font installation step. Use this if you already have a Nerd Font installed.
.PARAMETER ConfigureWindowsTerminal
    Configure Windows Terminal to use the installed Nerd Font.
.PARAMETER ConfigureVSCode
    Configure VS Code integrated terminal to use the installed Nerd Font.
.PARAMETER LogPath
    The path where log files will be stored. Default is "C:\Logs\OhMyPosh".
.PARAMETER ShowThemes
    Display the available themes after setup completes.
.EXAMPLE
    .\Setup-OhMyPosh.ps1
    # Install Oh My Posh with default settings
.EXAMPLE
    .\Setup-OhMyPosh.ps1 -Theme "paradox"
    # Install Oh My Posh with the paradox theme
.EXAMPLE
    .\Setup-OhMyPosh.ps1 -FontName "FiraCode"
    # Install Oh My Posh with the FiraCode Nerd Font
.EXAMPLE
    .\Setup-OhMyPosh.ps1 -SkipFontInstall
    # Install Oh My Posh without installing a Nerd Font
.EXAMPLE
    .\Setup-OhMyPosh.ps1 -ConfigureWindowsTerminal -ConfigureVSCode
    # Install Oh My Posh and configure both Windows Terminal and VS Code
.NOTES
    Author: Windows Server Lab Environment (Proxmox VE Edition)
    Date: June 12, 2025
    Version: 1.1
.LINK
    https://ohmyposh.dev/
    https://github.com/j4v3l/WindowsServer-Lab
#>

param (
    [string]$Theme = "jandedobbeleer",
    [string]$FontName = "MesloLGM",
    [switch]$SkipFontInstall = $false,
    [switch]$ConfigureWindowsTerminal = $false,
    [switch]$ConfigureVSCode = $false,
    [string]$LogPath = "C:\Logs\OhMyPosh",
    [switch]$ShowThemes = $false
)

# Set error action preference
$ErrorActionPreference = "Stop"

# This script uses Windows-only package, registry, and terminal APIs. Fail early
# with a useful message instead of producing confusing cross-platform errors.
$isWindows = ($env:OS -eq 'Windows_NT') -or ($PSVersionTable.PSVersion.Major -lt 6)
if (-not $isWindows) {
    throw 'Setup-OhMyPosh.ps1 must be run inside Windows PowerShell or PowerShell 7 on Windows.'
}

# Color settings for output
$InfoColor = "Cyan"
$SuccessColor = "Green"
$WarningColor = "Yellow"
$ErrorColor = "Red"

# Create log directory if it doesn't exist. C:\Logs normally requires elevation;
# fall back to the current user's local application data when the default path is
# not writable so administrator rights remain optional.
$logPathWasExplicit = $PSBoundParameters.ContainsKey('LogPath')
try {
    if (-not (Test-Path -LiteralPath $LogPath -PathType Container)) {
        New-Item -Path $LogPath -ItemType Directory -Force -ErrorAction Stop | Out-Null
    }
}
catch {
    if ($logPathWasExplicit) {
        throw "Unable to create the requested log directory '$LogPath': $($_.Exception.Message)"
    }

    $LogPath = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'OhMyPosh\Logs'
    New-Item -Path $LogPath -ItemType Directory -Force -ErrorAction Stop | Out-Null
}

$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm"
$logFile = Join-Path $LogPath "OhMyPosh_Setup_$timestamp.log"

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
    # Also log to file
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message" | Out-File -FilePath $logFile -Append
}

function Write-Log {
    param(
        [string]$Message
    )
    # Only log to file, don't display in console
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message" | Out-File -FilePath $logFile -Append
}

function Test-AdminRights {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-CommandExists {
    param (
        [string]$command
    )
    $exists = $false
    try {
        if (Get-Command $command -ErrorAction Stop) {
            $exists = $true
        }
    }
    catch {
        $exists = $false
    }
    return $exists
}

function Get-FontInstallName {
    param(
        [Parameter(Mandatory)][string]$Name
    )

    # The current Oh My Posh CLI installs the Meslo family with the library name
    # "meslo". Keep accepting the older MesloLGM value used by this script.
    if ($Name -match '^meslolgm$' -or $Name -match '^meslo$') {
        return 'meslo'
    }

    return $Name
}

function Get-FontFaceName {
    param(
        [Parameter(Mandatory)][string]$Name
    )

    if ($Name -match '^meslolgm$' -or $Name -match '^meslo$') {
        return 'MesloLGM Nerd Font'
    }

    if ($Name -match 'nerd\s*font$') {
        return $Name
    }

    return "$Name Nerd Font"
}

function Test-WindowsTerminalVersion {
    try {
        # Try to get Windows Terminal version
        $wtApp = Get-AppxPackage -Name Microsoft.WindowsTerminal -ErrorAction Ignore
        if ($wtApp) {
            return $wtApp.Version
        }
        
        # Try preview version
        $wtPreviewApp = Get-AppxPackage -Name Microsoft.WindowsTerminalPreview -ErrorAction Ignore
        if ($wtPreviewApp) {
            return $wtPreviewApp.Version
        }
        
        return $null
    }
    catch {
        Write-Log "Error checking Windows Terminal version: $_"
        return $null
    }
}

function Test-FontInstalled {
    param (
        [string]$FontName
    )
    
    try {
        $fontFace = Get-FontFaceName -Name $FontName
        $patterns = @($FontName, $fontFace, "$FontName NF") | Where-Object { $_ } | Select-Object -Unique
        $fontKeys = @(
            'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts',
            'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
        )

        foreach ($fontKey in $fontKeys) {
            if (-not (Test-Path -LiteralPath $fontKey)) { continue }
            $installedFonts = Get-ItemProperty -LiteralPath $fontKey
            foreach ($font in $installedFonts.PSObject.Properties) {
                foreach ($pattern in $patterns) {
                    if ($font.Name -like "*$pattern*" -or $font.Value -like "*$pattern*") {
                        return $true
                    }
                }
            }
        }
        
        return $false
    }
    catch {
        Write-Log "Error checking font installation: $_"
        return $false
    }
}

function Install-OhMyPosh {
    Write-ColorOutput "Installing Oh My Posh..." $InfoColor
    
    # Check if Oh My Posh is already installed
    if (Test-CommandExists "oh-my-posh") {
        Write-ColorOutput "Oh My Posh is already installed. Checking for updates..." $WarningColor
        if (-not (Test-CommandExists 'winget')) {
            Write-ColorOutput "winget is not available; continuing with the existing Oh My Posh installation." $WarningColor
            Write-Log "winget was not found while checking for an update"
            return
        }

        try {
            # Update Oh My Posh using winget. Native commands do not reliably
            # throw terminating PowerShell errors, so check LASTEXITCODE.
            & winget upgrade JanDeDobbeleer.OhMyPosh --source winget --accept-source-agreements --accept-package-agreements
            $upgradeExitCode = $LASTEXITCODE
            if ($upgradeExitCode -ne 0) {
                Write-ColorOutput "Oh My Posh update returned exit code $upgradeExitCode; continuing with the existing installation." $WarningColor
                Write-Log "Oh My Posh update returned exit code $upgradeExitCode"
                return
            }
            Write-ColorOutput "Oh My Posh has been updated successfully." $SuccessColor
        }
        catch {
            Write-ColorOutput "Failed to update Oh My Posh: $_" $ErrorColor
            Write-Log "Update error details: $($_.Exception.Message)"
            Write-ColorOutput "Continuing with existing installation..." $WarningColor
        }
        return
    }
    
    # Install Oh My Posh using winget when available.
    if (Test-CommandExists 'winget') {
        try {
        Write-ColorOutput "Installing Oh My Posh via winget..." $InfoColor
        Write-Log "Attempting winget installation..."
        & winget install JanDeDobbeleer.OhMyPosh --source winget --accept-source-agreements --accept-package-agreements
        $installExitCode = $LASTEXITCODE
        if ($installExitCode -ne 0) {
            throw "winget returned exit code $installExitCode."
        }
        
        # Reload PATH environment variable
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
        Write-Log "Environment PATH refreshed"
        
        if (-not (Test-CommandExists "oh-my-posh")) {
            Write-ColorOutput "Oh My Posh was installed but cannot be found in PATH. You may need to restart your terminal." $WarningColor
            Write-Log "Oh My Posh not found in PATH after installation"
        }
        else {
            Write-ColorOutput "Oh My Posh has been installed successfully." $SuccessColor
            Write-Log "Oh My Posh successfully installed via winget"
        }
        }
        catch {
        Write-ColorOutput "Failed to install Oh My Posh using winget: $_" $ErrorColor
        Write-Log "Winget installation failed: $($_.Exception.Message)"
        }
    }

    if (-not (Test-CommandExists 'oh-my-posh')) {
        # Fallback to the official installer when winget is unavailable or failed.
        Write-ColorOutput "Trying alternative installation method..." $WarningColor
        try {
            Write-ColorOutput "Installing Oh My Posh via installer script..." $InfoColor
            Write-Log "Attempting installer script installation..."
            Set-ExecutionPolicy Bypass -Scope Process -Force
            Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://ohmyposh.dev/install.ps1'))
            if (-not (Test-CommandExists 'oh-my-posh')) {
                throw 'The installer completed but oh-my-posh is still not available in PATH. Restart PowerShell and run the script again.'
            }
            Write-ColorOutput "Oh My Posh has been installed successfully using the installer script." $SuccessColor
            Write-Log "Oh My Posh successfully installed via installer script"
        }
        catch {
            Write-ColorOutput "Failed to install Oh My Posh: $_" $ErrorColor
            Write-Log "Installation failed: $($_.Exception.Message)"
            throw 'Oh My Posh installation failed. Install it from https://ohmyposh.dev/docs/installation/windows and rerun this script.'
        }
    }
}

function Install-NerdFont {
    param (
        [string]$Font = "MesloLGM"
    )
    
    if ($SkipFontInstall) {
        Write-ColorOutput "Skipping font installation as requested." $WarningColor
        Write-Log "Font installation skipped by user request"
        return
    }
    
    $fontInstallName = Get-FontInstallName -Name $Font
    $fontFace = Get-FontFaceName -Name $Font

    # Check if the font is already installed
    if (Test-FontInstalled -FontName $Font) {
        Write-ColorOutput "$fontFace is already installed." $WarningColor
        Write-Log "Font $Font already installed, skipping installation"
        return
    }
    
    Write-ColorOutput "Installing $fontFace..." $InfoColor
    Write-Log "Starting font installation for $fontInstallName"
    
    try {
        # Use Oh My Posh to install the font
        if (-not (Test-CommandExists 'oh-my-posh')) {
            throw 'oh-my-posh is not available in PATH after installation.'
        }
        & oh-my-posh font install $fontInstallName
        
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "$fontFace has been installed successfully." $SuccessColor
            Write-Log "Font installation successful"
        }
        else {
            throw "Font installation returned exit code $LASTEXITCODE."
        }
    }
    catch {
        Write-ColorOutput "Failed to install $Font Nerd Font: $_" $ErrorColor
        Write-Log "Font installation exception: $($_.Exception.Message)"
        throw "Nerd Font installation failed. Install '$fontInstallName' manually and rerun the script."
    }
}

function Configure-PowerShellProfile {
    param (
        [string]$ThemeName = "jandedobbeleer"
    )
    
    Write-ColorOutput "Configuring PowerShell profile to use Oh My Posh..." $InfoColor
    Write-Log "Starting PowerShell profile configuration"
    
    # Check if PowerShell profile exists, create if it doesn't
    if (-not (Test-Path -Path $PROFILE)) {
        Write-ColorOutput "Creating PowerShell profile at $PROFILE..." $InfoColor
        Write-Log "Creating new PowerShell profile"
        try {
            $profileDirectory = Split-Path -Path $PROFILE -Parent
            if (-not (Test-Path -LiteralPath $profileDirectory -PathType Container)) {
                New-Item -Path $profileDirectory -ItemType Directory -Force -ErrorAction Stop | Out-Null
            }
            New-Item -Path $PROFILE -Type File -Force | Out-Null
            Write-ColorOutput "PowerShell profile created successfully." $SuccessColor
            Write-Log "Profile created successfully"
        }
        catch {
            Write-ColorOutput "Failed to create PowerShell profile: $_" $ErrorColor
            Write-Log "Failed to create profile: $($_.Exception.Message)"
            return
        }
    }
    
    # Get the content of the profile
    $profileContent = Get-Content -Path $PROFILE -Raw -ErrorAction Ignore
    
    # Replace any previous Oh My Posh initialization without prompting. This
    # makes repeated runs safe for provisioning and avoids duplicate prompts.
    if ($profileContent -and $profileContent -match '(?im)^\s*oh-my-posh\s+(?:init|--init)\s+') {
        Write-ColorOutput "Updating the existing Oh My Posh configuration in your PowerShell profile." $WarningColor
        Write-Log "Found existing Oh My Posh configuration in profile; replacing it"
        $profileContent = $profileContent -replace '(?im)^\s*oh-my-posh\s+(?:init|--init)\s+.*(?:\r?\n|$)', ''
    }
    
    # Resolve a custom theme path when POSH_THEMES_PATH is available. For
    # built-in themes, use the theme name directly so the profile does not
    # depend on a deprecated environment variable or Invoke-Expression.
    $themeConfig = ''
    if ($ThemeName -match '\.omp\.json$') {
        # If it's a full path or custom theme
        if (Test-Path -LiteralPath $ThemeName -PathType Leaf) {
            $themeConfig = (Resolve-Path -LiteralPath $ThemeName).Path
            Write-Log "Using custom theme at path: $ThemeName"
        } else {
            throw "Theme file '$ThemeName' was not found. Provide a valid .omp.json path or a built-in theme name."
        }
    } else {
        # Built-in names are accepted directly by current Oh My Posh versions.
        $themeConfig = $ThemeName
        if ($env:POSH_THEMES_PATH) {
            $candidateTheme = Join-Path $env:POSH_THEMES_PATH "$ThemeName.omp.json"
            if (Test-Path -LiteralPath $candidateTheme -PathType Leaf) {
                $themeConfig = $candidateTheme
            }
        }
        Write-Log "Using standard theme: $ThemeName"
    }

    # Validate the resolved configuration before changing the user's profile.
    # The init command emits the generated prompt script; capture it so setup
    # remains quiet and use its native exit code as the validation result.
    $themeProbe = @(& oh-my-posh init pwsh --config $themeConfig 2>&1)
    if ($LASTEXITCODE -ne 0) {
        $probeMessage = ($themeProbe -join ' ').Trim()
        throw "Oh My Posh theme '$ThemeName' could not be loaded. $probeMessage"
    }
    
    # Add the init line
    $ohMyPoshInit = "oh-my-posh init pwsh --config `"$themeConfig`" | Invoke-Expression"
    Write-Log "Setting init command: $ohMyPoshInit"
    
    if ($profileContent) {
        $newContent = $profileContent.TrimEnd() + "`n`n# Oh My Posh Initialization`n$ohMyPoshInit`n"
        $newContent | Set-Content -Path $PROFILE -Encoding UTF8
    } else {
        $newContent = "# PowerShell Profile`n`n# Oh My Posh Initialization`n$ohMyPoshInit`n"
        $newContent | Set-Content -Path $PROFILE -Encoding UTF8
    }
    
    Write-ColorOutput "Oh My Posh has been configured in your PowerShell profile with theme: $ThemeName" $SuccessColor
    Write-Log "Profile successfully configured with theme: $ThemeName"
}

function Configure-WindowsTerminal {
    if (-not $ConfigureWindowsTerminal) {
        return
    }
    
    Write-ColorOutput "Configuring Windows Terminal to use Nerd Font..." $InfoColor
    Write-Log "Starting Windows Terminal configuration"
    
    # Check if Windows Terminal is installed
    $terminalVersion = Test-WindowsTerminalVersion
    if (-not $terminalVersion) {
        Write-ColorOutput "Windows Terminal does not appear to be installed." $WarningColor
        Write-Log "Windows Terminal not detected"
        Write-ColorOutput "Please install Windows Terminal from the Microsoft Store and configure it manually." $WarningColor
        return
    }
    Write-Log "Detected Windows Terminal version: $terminalVersion"
    
    # Attempt to find the Windows Terminal settings file
    $settingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    if (-not (Test-Path $settingsPath)) {
        $settingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json"
    }
    
    if (-not (Test-Path $settingsPath)) {
        Write-ColorOutput "Windows Terminal settings file not found. Please configure it manually." $WarningColor
        Write-Log "Windows Terminal settings file not found"
        Write-ColorOutput "Set your font to '$(Get-FontFaceName -Name $FontName)' in the Windows Terminal settings." $WarningColor
        return
    }
    
    try {
        # Backup the settings file
        Copy-Item $settingsPath "${settingsPath}.backup"
        Write-ColorOutput "Windows Terminal settings backed up to ${settingsPath}.backup" $SuccessColor
        Write-Log "Settings file backed up"
        
        # Load the settings JSON
        $terminalSettings = Get-Content $settingsPath -Raw | ConvertFrom-Json
        
        # Check if profiles.defaults exists, create it if it doesn't
        if (-not $terminalSettings.profiles.defaults) {
            if (-not $terminalSettings.profiles) {
                $terminalSettings | Add-Member -Type NoteProperty -Name "profiles" -Value (New-Object PSObject)
                Write-Log "Created profiles object"
            }
            $terminalSettings.profiles | Add-Member -Type NoteProperty -Name "defaults" -Value (New-Object PSObject)
            Write-Log "Created profiles.defaults object"
        }
        
        # Check if profiles.defaults.font exists, create it if it doesn't
        if (-not $terminalSettings.profiles.defaults.font) {
            $terminalSettings.profiles.defaults | Add-Member -Type NoteProperty -Name "font" -Value (New-Object PSObject)
            Write-Log "Created font object"
        }
        
        # Update the font face
        $fontFace = Get-FontFaceName -Name $FontName
        $terminalSettings.profiles.defaults.font | Add-Member -Type NoteProperty -Name "face" -Value $fontFace -Force
        Write-Log "Set font face to: $fontFace"
        
        # Save the updated settings
        $terminalSettings | ConvertTo-Json -Depth 10 | Set-Content $settingsPath -Encoding UTF8
        
        Write-ColorOutput "Windows Terminal has been configured to use '$fontFace' font." $SuccessColor
        Write-Log "Windows Terminal configuration successful"
    }
    catch {
        Write-ColorOutput "Failed to configure Windows Terminal: $_" $ErrorColor
        Write-Log "Windows Terminal configuration failed: $($_.Exception.Message)"
        Write-ColorOutput "Please configure it manually by setting your font to '$(Get-FontFaceName -Name $FontName)'." $WarningColor
    }
}

function Configure-VSCode {
    if (-not $ConfigureVSCode) {
        return
    }
    
    Write-ColorOutput "Configuring VS Code to use Nerd Font..." $InfoColor
    Write-Log "Starting VS Code configuration"
    
    # Check if VS Code is installed
    $vsCodePath = "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe"
    $vsCodeUserPath = "$HOME\AppData\Local\Programs\Microsoft VS Code\Code.exe"
    
    if (-not ((Test-Path $vsCodePath) -or (Test-Path $vsCodeUserPath))) {
        Write-ColorOutput "VS Code does not appear to be installed in the standard location." $WarningColor
        Write-Log "VS Code executable not found in standard locations"
        if (-not (Test-CommandExists "code")) {
            Write-ColorOutput "VS Code command not found in PATH. Please install VS Code and configure it manually." $WarningColor
            Write-Log "VS Code command not found in PATH"
            return
        }
    }
    
    # Find the VS Code settings file
    $settingsPath = "$env:APPDATA\Code\User\settings.json"
    if (-not (Test-Path $settingsPath)) {
        $settingsPath = "$HOME\AppData\Roaming\Code\User\settings.json"
    }
    
    if (-not (Test-Path $settingsPath)) {
        Write-ColorOutput "VS Code settings file not found." $WarningColor
        Write-Log "VS Code settings file not found"
        
        # Try to create the settings file
        try {
            $settingsDir = Split-Path $settingsPath -Parent
            if (-not (Test-Path $settingsDir)) {
                New-Item -Path $settingsDir -ItemType Directory -Force | Out-Null
                Write-Log "Created VS Code settings directory"
            }
            
            $initialSettings = @{
                "terminal.integrated.fontFamily" = (Get-FontFaceName -Name $FontName)
            }
            
            $initialSettings | ConvertTo-Json | Set-Content $settingsPath -Encoding UTF8
            Write-ColorOutput "Created VS Code settings file with Nerd Font configuration." $SuccessColor
            Write-Log "Created new VS Code settings file"
            return
        }
        catch {
            Write-ColorOutput "Failed to create VS Code settings file: $_" $ErrorColor
            Write-Log "Failed to create VS Code settings file: $($_.Exception.Message)"
            Write-ColorOutput "Please add 'terminal.integrated.fontFamily': '$FontName NF' to your VS Code settings manually." $WarningColor
            return
        }
    }
    
    try {
        # Backup the settings file
        Copy-Item $settingsPath "${settingsPath}.backup"
        Write-ColorOutput "VS Code settings backed up to ${settingsPath}.backup" $SuccessColor
        Write-Log "VS Code settings file backed up"
        
        # Load the settings JSON
        $vsCodeSettings = Get-Content $settingsPath -Raw | ConvertFrom-Json
        
        # Add or update the font family setting
        $fontFace = Get-FontFaceName -Name $FontName
        $vsCodeSettings | Add-Member -Type NoteProperty -Name "terminal.integrated.fontFamily" -Value $fontFace -Force
        Write-Log "Set VS Code terminal font to: $fontFace"
        
        # Save the updated settings
        $vsCodeSettings | ConvertTo-Json -Depth 10 | Set-Content $settingsPath -Encoding UTF8
        
        Write-ColorOutput "VS Code has been configured to use '$fontFace' font in the integrated terminal." $SuccessColor
        Write-Log "VS Code configuration successful"
    }
    catch {
        Write-ColorOutput "Failed to configure VS Code: $_" $ErrorColor
        Write-Log "VS Code configuration failed: $($_.Exception.Message)"
        Write-ColorOutput "Please configure it manually by adding 'terminal.integrated.fontFamily': '$FontName NF' to your VS Code settings." $WarningColor
    }
}

function Show-OhMyPoshThemes {
    Write-ColorOutput "Available Oh My Posh themes:" $InfoColor
    Write-Log "Displaying available themes"
    
    try {
        $themes = oh-my-posh theme list
        foreach ($theme in $themes) {
            Write-Host $theme
        }
        
        Write-ColorOutput "`nTo use a different theme, run this script with the -Theme parameter:" $InfoColor
        Write-ColorOutput ".\Setup-OhMyPosh.ps1 -Theme <theme-name>" $InfoColor
        Write-Log "Theme list displayed successfully"
    }
    catch {
        Write-ColorOutput "Failed to list Oh My Posh themes: $_" $ErrorColor
        Write-Log "Failed to list themes: $($_.Exception.Message)"
    }
}

# Check if running as admin
$isAdmin = Test-AdminRights
if (-not $isAdmin) {
    Write-ColorOutput "This script is not running as Administrator." $WarningColor
    Write-ColorOutput "Some features may not work correctly." $WarningColor
    Write-ColorOutput "Consider running this script as Administrator for full functionality." $WarningColor
    Write-Log "Script running without administrator privileges"
}

# Main Execution
try {
    Write-ColorOutput "===================================" $InfoColor
    Write-ColorOutput "  Oh My Posh Setup Script" $InfoColor
    Write-ColorOutput "===================================" $InfoColor
    Write-ColorOutput "Log file: $logFile" $InfoColor
    Write-Log "Oh My Posh setup script started"
    
    # Install Oh My Posh
    Install-OhMyPosh
    
    # Install Nerd Font
    Install-NerdFont -Font $FontName
    
    # Configure PowerShell Profile
    Configure-PowerShellProfile -ThemeName $Theme
    
    # Configure Windows Terminal
    Configure-WindowsTerminal
    
    # Configure VS Code
    Configure-VSCode
    
    # Success message and next steps
    Write-ColorOutput "`n===================================" $SuccessColor
    Write-ColorOutput "  Oh My Posh Setup Complete!" $SuccessColor
    Write-ColorOutput "===================================" $SuccessColor
    Write-Log "Setup completed successfully"
    
    Write-ColorOutput "`nNext Steps:" $InfoColor
    Write-ColorOutput "1. Restart your PowerShell session or run: . $PROFILE" $InfoColor
    Write-ColorOutput "2. If the font doesn't look right, make sure your terminal is using a Nerd Font." $InfoColor
    Write-ColorOutput "3. Review the log file at: $logFile" $InfoColor
    
    # Show available themes only when explicitly requested; unattended runs
    # must never stop for console input.
    if ($ShowThemes) {
        Show-OhMyPoshThemes
    }
    
    Write-ColorOutput "`nFor more information, visit: https://ohmyposh.dev/" $InfoColor
    Write-Log "Script execution completed"
}
catch {
    Write-ColorOutput "An error occurred during Oh My Posh setup: $_" $ErrorColor
    Write-Log "Critical error: $($_.Exception.Message)"
    Write-Log "Stack trace: $($_.ScriptStackTrace)"
    Write-ColorOutput "Please check the log file for details: $logFile" $ErrorColor
    exit 1
}
