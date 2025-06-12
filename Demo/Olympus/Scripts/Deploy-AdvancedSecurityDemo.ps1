<#
.SYNOPSIS
    Deploy Advanced Security Demo - Olympus Systems Edition
    
.DESCRIPTION
    This script is a wrapper for the main Deploy-AdvancedSecurityDemo.ps1 script,
    specifically configured for the Olympus Systems demo environment.
    
    It automatically sets the DemoType to "Olympus" and provides easy access to
    all advanced security features within the Greek mythology-themed demo environment.
    
.PARAMETER Action
    The action to perform:
    - "ShowFeatures" - Display all security features
    - "DeployPolicies" - Deploy all advanced security policies
    - "RunAudit" - Perform comprehensive security audit
    - "GenerateReport" - Create demo report
    - "Interactive" - Run interactive menu (default)
    
.PARAMETER OutputPath
    Path where reports and logs should be saved
    Default: "C:\Olympus\Reports"
    
.PARAMETER Force
    Skip confirmation prompts and force execution
    
.EXAMPLE
    .\Deploy-AdvancedSecurityDemo.ps1
    Run the interactive advanced security demo for Olympus Systems
    
.EXAMPLE
    .\Deploy-AdvancedSecurityDemo.ps1 -Action "DeployPolicies" -Force
    Deploy all advanced security policies without confirmation
    
.EXAMPLE
    .\Deploy-AdvancedSecurityDemo.ps1 -Action "RunAudit" -OutputPath "C:\MyReports"
    Run security audit and save report to custom location
    
.NOTES
    Version: 1.2.0
    Author: Windows Server Lab Project
    Purpose: Olympus Systems Advanced Security Demo Wrapper
    
    This script wraps the main Deploy-AdvancedSecurityDemo.ps1 located in
    the root Scripts/ directory and automatically configures it for the Olympus environment.
    
.LINK
    https://github.com/YourRepo/WindowsServer-Lab
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $false)]
  [ValidateSet("ShowFeatures", "DeployPolicies", "RunAudit", "GenerateReport", "Interactive")]
  [string]$Action = "Interactive",
    
  [Parameter(Mandatory = $false)]
  [string]$OutputPath = "C:\Olympus\Reports",
    
  [Parameter(Mandatory = $false)]
  [switch]$Force
)

# Script information
$ScriptVersion = "1.2.0"
$ScriptName = "Deploy-AdvancedSecurityDemo.ps1 (Olympus Edition)"

# Console styling
function Write-OlympusHeader {
  Clear-Host
  Write-Information "=" -InformationAction Continue * 80 -ForegroundColor Cyan
  Write-Host "⚡ OLYMPUS SYSTEMS - ADVANCED SECURITY DEMO ⚡" -ForegroundColor Yellow
  Write-Information "=" -InformationAction Continue * 80 -ForegroundColor Cyan
  Write-Information "" -InformationAction Continue
  # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "🏛️  Divine Power Meets Digital Security  🏛️" -ForegroundColor White
  Write-Information "" -InformationAction Continue
  # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "Version: $ScriptVersion" -ForegroundColor Gray
  # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "Demo Environment: Olympus Systems (Greek Mythology)" -ForegroundColor Gray
  # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "Domain: olympus.local" -ForegroundColor Gray
  Write-Information "" -InformationAction Continue
}

function Write-OlympusMessage {
  param([string]$Message, [string]$Color = "White")
  # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "🏛️ " -ForegroundColor Yellow -NoNewline
  # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host $Message -ForegroundColor $Color
}

function Write-OlympusError {
  param([string]$Message)
  # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "⚠️ " -ForegroundColor Red -NoNewline
  # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host $Message -ForegroundColor Red
}

function Write-OlympusSuccess {
  param([string]$Message)
  # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "✅ " -ForegroundColor Green -NoNewline
  # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host $Message -ForegroundColor Green
}

# Main execution
try {
  Write-OlympusHeader
    
  # Check if main script exists
  $MainScriptPath = Join-Path -Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) -ChildPath "Scripts\Deploy-AdvancedSecurityDemo.ps1"
    
  if (-not (Test-Path $MainScriptPath)) {
    Write-OlympusError "Main Deploy-AdvancedSecurityDemo.ps1 script not found at: $MainScriptPath"
    Write-Information "" -InformationAction Continue
    Write-Information "Expected location: Scripts/AdvancedSecurityAudit.ps1" -InformationAction Continue
    Write-Information "Please ensure the main Windows Server Lab project structure is intact." -InformationAction Continue
    Write-Information "" -InformationAction Continue
    Read-Host "Press Enter to exit"
    exit 1
  }
    
  Write-OlympusMessage "Main advanced security script found: $MainScriptPath"
  Write-Information "" -InformationAction Continue
    
  # Prepare parameters for main script
  $MainScriptParams = @{
    DemoType = "Olympus"
  }
    
  # Add action if not interactive
  if ($Action -ne "Interactive") {
    $MainScriptParams.Action = $Action
  }
    
  # Add output path if specified
  if ($OutputPath -ne "C:\Olympus\Reports") {
    $MainScriptParams.OutputPath = $OutputPath
  }
    
  # Add force parameter if specified
  if ($Force) {
    $MainScriptParams.Force = $true
  }
    
  Write-OlympusMessage "Launching Advanced Security Demo for Olympus Systems..."
  Write-Information "" -InformationAction Continue
  # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "Parameters:" -ForegroundColor Cyan
  $MainScriptParams.GetEnumerator() | ForEach-Object {
    Write-Host "  - $($_.Key): $($_.Value)" -ForegroundColor Gray
  }
  Write-Information "" -InformationAction Continue
    
  # Create output directory if it doesn't exist
  if (-not (Test-Path $OutputPath)) {
    try {
      New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
      Write-OlympusSuccess "Created output directory: $OutputPath"
    }
    catch {
      Write-OlympusError "Failed to create output directory: $OutputPath"
      # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
  }
    
  Write-Information "" -InformationAction Continue
  Write-OlympusMessage "Transferring control to main Advanced Security Demo script..."
  Write-Information "" -InformationAction Continue
  # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "🏛️ Welcome to the divine realm of Windows Server security! 🏛️" -ForegroundColor Yellow
  Write-Information "" -InformationAction Continue
    
  # Execute main script with parameters
  & $MainScriptPath @MainScriptParams
    
}
catch {
  Write-Information "" -InformationAction Continue
  Write-OlympusError "An error occurred while launching the Advanced Security Demo:"
  # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host $_.Exception.Message -ForegroundColor Red
  Write-Information "" -InformationAction Continue
  # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "Stack Trace:" -ForegroundColor Gray
  # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host $_.ScriptStackTrace -ForegroundColor Gray
  Write-Information "" -InformationAction Continue
  Read-Host "Press Enter to exit"
  exit 1
}

# Footer message
Write-Information "" -InformationAction Continue
Write-Information "=" -InformationAction Continue * 80 -ForegroundColor Cyan
# Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "⚡ Thank you for exploring Olympus Systems Advanced Security! ⚡" -ForegroundColor Yellow
Write-Information "=" -InformationAction Continue * 80 -ForegroundColor Cyan 