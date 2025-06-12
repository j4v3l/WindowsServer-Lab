# Quick Install Script for Oh My Posh
# This script downloads and runs the Setup-OhMyPosh.ps1 script

# PowerShell 7 compatible web request
$repoUrl = "https://raw.githubusercontent.com/j4v3l/WindowsServer-Lab/main/Scripts/Setup-OhMyPosh.ps1"
$outputPath = "$env:TEMP\Setup-OhMyPosh.ps1"

# Show banner
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "  Oh My Posh Quick Installation Tool  " -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# Download the setup script
Write-Host "Downloading Oh My Posh setup script..." -ForegroundColor Yellow
try {
    Invoke-WebRequest -Uri $repoUrl -OutFile $outputPath -ErrorAction Stop
    Write-Host "Download successful!" -ForegroundColor Green
}
catch {
    Write-Host "Failed to download setup script: $_" -ForegroundColor Red
    Write-Host "Please download Setup-OhMyPosh.ps1 manually from GitHub." -ForegroundColor Red
    exit 1
}

# Ask for configuration options
Write-Host "`nConfiguration Options:" -ForegroundColor Yellow
$theme = Read-Host "Theme name (leave blank for default)"
if ([string]::IsNullOrWhiteSpace($theme)) {
    $theme = "jandedobbeleer"
}

$fontName = Read-Host "Font name (leave blank for MesloLGM)"
if ([string]::IsNullOrWhiteSpace($fontName)) {
    $fontName = "MesloLGM"
}

$configureTerminal = Read-Host "Configure Windows Terminal? (y/n)"
$configureVSCode = Read-Host "Configure VS Code? (y/n)"

# Build the parameter string
$params = "-Theme '$theme' -FontName '$fontName'"
if ($configureTerminal -eq "y") {
    $params += " -ConfigureWindowsTerminal"
}
if ($configureVSCode -eq "y") {
    $params += " -ConfigureVSCode"
}

# Run the script with parameters
Write-Host "`nRunning Oh My Posh setup with the following parameters:" -ForegroundColor Yellow
Write-Host "Theme: $theme" -ForegroundColor Yellow
Write-Host "Font: $fontName" -ForegroundColor Yellow
Write-Host "Configure Windows Terminal: $($configureTerminal -eq 'y')" -ForegroundColor Yellow
Write-Host "Configure VS Code: $($configureVSCode -eq 'y')" -ForegroundColor Yellow
Write-Host ""

try {
    # Construct and execute the command
    $command = "& '$outputPath' $params"
    Invoke-Expression $command
}
catch {
    Write-Host "Error running setup script: $_" -ForegroundColor Red
    exit 1
}
