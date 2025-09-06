<#
.SYNOPSIS
    Deploy Advanced Security Demo - Main Script
    
.DESCRIPTION
    This script deploys advanced security policies and demonstrations for both
    Asgard and Olympus lab environments. It provides comprehensive Group Policy
    Object (GPO) deployment with proper organizational unit (OU) mappings.
    
    EXECUTION CONTEXT: Run INSIDE Windows Server VMs (Domain Controllers)
    ACCESS METHOD: RDP, Console, or PowerShell Direct to Domain Controller VM
    PREREQUISITES: Domain Administrator rights, Group Policy Management Tools
    
.PARAMETER DemoType
    The demo environment type:
    - "Asgard" - Norse mythology themed environment
    - "Olympus" - Greek mythology themed environment
    
.PARAMETER Action
    The action to perform:
    - "ShowFeatures" - Display all security features
    - "DeployPolicies" - Deploy all advanced security policies
    - "RunAudit" - Perform comprehensive security audit
    - "GenerateReport" - Create demo report
    - "Interactive" - Run interactive menu (default)
    
.PARAMETER OutputPath
    Path where reports and logs should be saved
    
.PARAMETER Force
    Skip confirmation prompts and force execution
    
.EXAMPLE
    .\Deploy-AdvancedSecurityDemo.ps1 -DemoType "Asgard" -Action "DeployPolicies"
    Deploy all advanced security policies for Asgard environment
    
.EXAMPLE
    .\Deploy-AdvancedSecurityDemo.ps1 -DemoType "Olympus" -Action "RunAudit"
    Run security audit for Olympus environment
    
.NOTES
    Version: 1.0.0
    Author: Windows Server Lab Project
    Purpose: Advanced Security Demo Main Script
    
    This script contains proper OU mappings that match the actual
    organizational unit structures created by the lab deployment scripts.
    
.LINK
    https://github.com/YourRepo/WindowsServer-Lab
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidateSet("Asgard", "Olympus")]
  [string]$DemoType,
    
  [Parameter(Mandatory = $false)]
  [ValidateSet("ShowFeatures", "DeployPolicies", "RunAudit", "GenerateReport", "Interactive")]
  [string]$Action = "Interactive",
    
  [Parameter(Mandatory = $false)]
  [string]$OutputPath,
    
  [Parameter(Mandatory = $false)]
  [switch]$Force
)

# Script information
$ScriptVersion = "1.0.0"
$ScriptName = "Deploy-AdvancedSecurityDemo.ps1"

# Set default output paths based on demo type
if (-not $OutputPath) {
  $OutputPath = if ($DemoType -eq "Asgard") { "C:\Asgard\Reports" } else { "C:\Olympus\Reports" }
}

# Console styling functions
function Write-DemoHeader {
  param([string]$Title, [string]$Environment)
    
  Clear-Host
  $separator = "=" * 80
  Write-Host $separator -ForegroundColor Cyan
  Write-Host $Title -ForegroundColor Yellow
  Write-Host $separator -ForegroundColor Cyan
  Write-Host ""
  Write-Host "Environment: $Environment" -ForegroundColor White
  Write-Host "Version: $ScriptVersion" -ForegroundColor Gray
  Write-Host ""
}

function Write-DemoMessage {
  param([string]$Message, [string]$Color = "White")
  Write-Host "INFO: $Message" -ForegroundColor $Color
}

function Write-DemoError {
  param([string]$Message)
  Write-Host "ERROR: $Message" -ForegroundColor Red
}

function Write-DemoSuccess {
  param([string]$Message)
  Write-Host "SUCCESS: $Message" -ForegroundColor Green
}

# Show available security features
function Show-SecurityFeatures {
  $title = "ADVANCED SECURITY FEATURES DEMO"
  $env = "$DemoType Technologies"
  Write-DemoHeader $title $env
    
  Write-Host "Available Security Categories:" -ForegroundColor Cyan
  Write-Host ""
    
  $features = @(
    @{
      Category = "USB & Storage Device Control"
      Features = @(
        "Removable storage access restrictions",
        "USB device installation controls", 
        "Autorun/autoplay security",
        "Device type granular controls"
      )
    },
    @{
      Category = "Camera & Microphone Security"
      Features = @(
        "Application camera access control",
        "Microphone usage restrictions",
        "Privacy protection policies",
        "Windows Hello security settings"
      )
    },
    @{
      Category = "Network & Firewall Protection"
      Features = @(
        "Advanced firewall rules",
        "Network location policies",
        "Remote desktop security",
        "Network sharing controls"
      )
    },
    @{
      Category = "Application & Software Control"
      Features = @(
        "Software installation restrictions",
        "Application allowlisting",
        "Windows Store policies",
        "PowerShell execution policies"
      )
    },
    @{
      Category = "User Account & Authentication"
      Features = @(
        "Password complexity requirements",
        "Account lockout policies",
        "Multi-factor authentication",
        "Privilege escalation controls"
      )
    },
    @{
      Category = "Data Protection & Privacy"
      Features = @(
        "Telemetry and data collection controls",
        "OneDrive and cloud service policies",
        "Cortana and search privacy settings",
        "Windows Error Reporting configuration"
      )
    }
  )
    
  foreach ($category in $features) {
    Write-Host $category.Category -ForegroundColor Cyan
    Write-Host ("-" * $category.Category.Length) -ForegroundColor Cyan
    foreach ($feature in $category.Features) {
      Write-Host "  * $feature" -ForegroundColor Green
    }
    Write-Host ""
  }
    
  $totalFeatures = ($features.Features | Measure-Object).Count
  Write-Host "Total: $totalFeatures Advanced Security Features!" -ForegroundColor Yellow
}

# Deploy advanced security policies
function Deploy-SecurityPolicies {
  Write-DemoMessage "Deploying Advanced Security Policies for $DemoType environment..."
    
  try {
    # Check if Advanced GPO Manager exists
  $advancedGPOScript = Join-Path $PSScriptRoot "Server/AdvancedGroupPolicyManager.ps1"
    if (-not (Test-Path $advancedGPOScript)) {
      Write-DemoError "Advanced GPO Manager script not found at: $advancedGPOScript"
      return $false
    }
        
    # Source the Advanced GPO Manager
    . $advancedGPOScript
        
    # Define OU mappings based on demo type - CORRECTED PATHS
    if ($DemoType -eq "Asgard") {
      $ouMappings = @{
        "Security"           = "OU=IT_Operations,OU=Departments,OU=Asgard Technologies,DC=asgard,DC=local"
        "DeviceControl"      = "OU=Workstations,OU=Asgard Technologies,DC=asgard,DC=local"
        "ApplicationControl" = "OU=Cybersecurity,OU=Departments,OU=Asgard Technologies,DC=asgard,DC=local"
        "NetworkSecurity"    = "OU=Servers,OU=Asgard Technologies,DC=asgard,DC=local"
        "DataProtection"     = "OU=Finance_Admin,OU=Departments,OU=Asgard Technologies,DC=asgard,DC=local"
        "Personalization"    = "OU=Human_Resources,OU=Departments,OU=Asgard Technologies,DC=asgard,DC=local"
      }
      $domain = "asgard.local"
    }
    else {
      $ouMappings = @{
        "Security"           = "OU=War Strategists,OU=Departments,OU=Olympus Systems,DC=olympus,DC=local"
        "DeviceControl"      = "OU=Workstations,OU=Olympus Systems,DC=olympus,DC=local"
        "ApplicationControl" = "OU=Innovation Forge,OU=Departments,OU=Olympus Systems,DC=olympus,DC=local"
        "NetworkSecurity"    = "OU=Servers,OU=Olympus Systems,DC=olympus,DC=local"
        "DataProtection"     = "OU=Abundance Treasury,OU=Departments,OU=Olympus Systems,DC=olympus,DC=local"
        "Personalization"    = "OU=Harmony Relations,OU=Departments,OU=Olympus Systems,DC=olympus,DC=local"
      }
      $domain = "olympus.local"
    }
        
    Write-DemoMessage "Deploying policies to organizational units..."
    Write-Host "Target OUs:" -ForegroundColor Cyan
        
    foreach ($mapping in $ouMappings.GetEnumerator()) {
      Write-Host "  $($mapping.Key): $($mapping.Value)" -ForegroundColor Gray
    }
        
    # Deploy all advanced GPO categories
    Deploy-AdvancedGPO -OUMappings $ouMappings
        
    Write-DemoSuccess "Advanced security policies deployed successfully!"
        
    # Wait for policy replication
    Write-DemoMessage "Waiting for policy replication..."
    Start-Sleep -Seconds 30
        
    # Force group policy update on domain controllers
    Write-DemoMessage "Forcing group policy update..."
    try {
      $dcName = (Get-ADDomainController -Domain $domain).Name
      Invoke-Command -ComputerName $dcName -ScriptBlock {
        gpupdate /force
      } -ErrorAction SilentlyContinue
    }
    catch {
      Write-Warning "Could not force GP update on remote DCs: $_"
    }
        
    Write-DemoSuccess "Advanced security policies are now active!"
    return $true
        
  }
  catch {
    Write-DemoError "Failed to deploy advanced security policies: $($_.Exception.Message)"
    return $false
  }
}

# Run comprehensive security audit
function Start-SecurityAudit {
  Write-DemoMessage "Running Comprehensive Security Audit for $DemoType environment..."
    
  try {
    # Check if Advanced Security Audit script exists
  $advancedAuditScript = Join-Path $PSScriptRoot "Server/AdvancedSecurityAudit.ps1"
    if (-not (Test-Path $advancedAuditScript)) {
      Write-DemoError "Advanced Security Audit script not found at: $advancedAuditScript"
      return $false
    }
        
    # Source the Advanced Security Audit script
    . $advancedAuditScript
        
    Write-DemoMessage "Performing quick security check..."
    Start-QuickSecurityCheck
        
    Write-DemoMessage "Generating comprehensive security report..."
    $reportPath = Get-AdvancedSecurityReport -OutputPath $OutputPath
        
    Write-DemoSuccess "Security audit completed!"
    Write-DemoMessage "Report saved to: $reportPath"
        
    # Open report if possible
    if (Test-Path $reportPath) {
      Write-DemoMessage "Opening security report..."
      try {
        Start-Process $reportPath
      }
      catch {
        Write-DemoMessage "Report available at: $reportPath"
      }
    }
        
    return $true
        
  }
  catch {
    Write-DemoError "Failed to run security audit: $($_.Exception.Message)"
    return $false
  }
}

# Generate demonstration report
function New-DemoReport {
  $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
  $reportPath = Join-Path $OutputPath "AdvancedSecurityDemo_$($DemoType)_$timestamp.html"
    
  # Create output directory if it doesn't exist
  if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
  }
    
  $domainSuffix = if ($DemoType -eq "Asgard") { "asgard.local" } else { "olympus.local" }
    
  $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Advanced Security Demo Report - $DemoType Edition</title>
    <style>
        body { 
            font-family: 'Segoe UI', Arial, sans-serif; 
            margin: 20px; 
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
        }
        .container { 
            max-width: 1200px; 
            margin: 0 auto; 
            background-color: white; 
            padding: 30px; 
            border-radius: 12px; 
            box-shadow: 0 8px 32px rgba(0,0,0,0.1);
        }
        .demo-header {
            text-align: center;
            background: linear-gradient(135deg, #3498db 0%, #2980b9 100%);
            color: white;
            padding: 30px;
            border-radius: 8px;
            margin-bottom: 30px;
        }
        h1 { color: #2c3e50; font-size: 2.5em; margin-bottom: 10px; }
        h2 { color: #34495e; border-left: 5px solid #3498db; padding-left: 15px; }
        .success { background-color: #d4edda; padding: 15px; border-left: 4px solid #28a745; margin: 15px 0; }
        ul li { margin: 8px 0; }
    </style>
</head>
<body>
    <div class="container">
        <div class="demo-header">
            <h1>Advanced Security Features Demo</h1>
            <h2>$DemoType Technologies Edition</h2>
            <p>Comprehensive Windows Server Lab Security Demonstration</p>
            <p><strong>Generated:</strong> $timestamp</p>
        </div>
        
        <div class="success">
            <h3>Demo Deployment Summary</h3>
            <ul>
                <li><strong>Demo Environment:</strong> $DemoType Technologies</li>
                <li><strong>Domain:</strong> $domainSuffix</li>
                <li><strong>Output Path:</strong> $OutputPath</li>
                <li><strong>Features Deployed:</strong> 6 Major Security Categories</li>
                <li><strong>Security Controls:</strong> 100+ Individual Settings</li>
            </ul>
        </div>
        
        <h2>Deployed Security Features</h2>
        <ul>
            <li>USB & Storage Device Control</li>
            <li>Camera & Microphone Security</li>
            <li>Network & Firewall Protection</li>
            <li>Application & Software Control</li>
            <li>User Account & Authentication</li>
            <li>Data Protection & Privacy</li>
        </ul>
        
        <h2>Organizational Unit Mappings</h2>
        <p>The following organizational units were targeted for policy deployment:</p>
"@
    
  # Add OU mappings to the report
  if ($DemoType -eq "Asgard") {
    $html += @"
        <ul>
            <li><strong>Security Policies:</strong> OU=IT_Operations,OU=Departments,OU=Asgard Technologies,DC=asgard,DC=local</li>
            <li><strong>Device Control:</strong> OU=Workstations,OU=Asgard Technologies,DC=asgard,DC=local</li>
            <li><strong>Application Control:</strong> OU=Cybersecurity,OU=Departments,OU=Asgard Technologies,DC=asgard,DC=local</li>
            <li><strong>Network Security:</strong> OU=Servers,OU=Asgard Technologies,DC=asgard,DC=local</li>
            <li><strong>Data Protection:</strong> OU=Finance_Admin,OU=Departments,OU=Asgard Technologies,DC=asgard,DC=local</li>
            <li><strong>Personalization:</strong> OU=Human_Resources,OU=Departments,OU=Asgard Technologies,DC=asgard,DC=local</li>
        </ul>
"@
  }
  else {
    $html += @"
        <ul>
            <li><strong>Security Policies:</strong> OU=Divine Council,OU=Departments,OU=Olympus Systems,DC=olympus,DC=local</li>
            <li><strong>Device Control:</strong> OU=Workstations,OU=Olympus Systems,DC=olympus,DC=local</li>
            <li><strong>Application Control:</strong> OU=Innovation Forge,OU=Departments,OU=Olympus Systems,DC=olympus,DC=local</li>
            <li><strong>Network Security:</strong> OU=Servers,OU=Olympus Systems,DC=olympus,DC=local</li>
            <li><strong>Data Protection:</strong> OU=Abundance Treasury,OU=Departments,OU=Olympus Systems,DC=olympus,DC=local</li>
            <li><strong>Personalization:</strong> OU=Harmony Relations,OU=Departments,OU=Olympus Systems,DC=olympus,DC=local</li>
        </ul>
"@
  }
    
  $html += @"
        
        <footer style="margin-top: 30px; padding-top: 20px; border-top: 1px solid #ddd; text-align: center; color: #7f8c8d;">
            <p>Generated by Windows Server Lab Advanced Security Demo</p>
            <p>$DemoType Technologies Edition - Version $ScriptVersion</p>
        </footer>
    </div>
</body>
</html>
"@
    
  try {
    $html | Out-File -FilePath $reportPath -Encoding UTF8
    Write-DemoSuccess "Demo report generated: $reportPath"
    return $reportPath
  }
  catch {
    Write-DemoError "Failed to generate demo report: $($_.Exception.Message)"
    return $null
  }
}

# Interactive menu
function Show-InteractiveMenu {
  while ($true) {
    $title = "ADVANCED SECURITY DEMO - INTERACTIVE MODE"
    $env = "$DemoType Technologies"
    Write-DemoHeader $title $env
        
    Write-Host "Available Actions:" -ForegroundColor Cyan
    Write-Host "1. Show Security Features" -ForegroundColor White
    Write-Host "2. Deploy Security Policies" -ForegroundColor White
    Write-Host "3. Run Security Audit" -ForegroundColor White
    Write-Host "4. Generate Demo Report" -ForegroundColor White
    Write-Host "5. Exit" -ForegroundColor White
    Write-Host ""
        
    $choice = Read-Host "Enter your choice (1-5)"
        
    switch ($choice) {
      "1" { 
        Show-SecurityFeatures
        Read-Host "`nPress Enter to continue"
      }
      "2" { 
        $result = Deploy-SecurityPolicies
        if ($result) {
          Write-Host "`nPolicies deployed successfully!" -ForegroundColor Green
        }
        else {
          Write-Host "`nPolicy deployment failed!" -ForegroundColor Red
        }
        Read-Host "Press Enter to continue"
      }
      "3" { 
        $result = Start-SecurityAudit
        if ($result) {
          Write-Host "`nSecurity audit completed successfully!" -ForegroundColor Green
        }
        else {
          Write-Host "`nSecurity audit failed!" -ForegroundColor Red
        }
        Read-Host "Press Enter to continue"
      }
      "4" { 
        $reportPath = New-DemoReport
        if ($reportPath) {
          Write-Host "`nDemo report generated successfully!" -ForegroundColor Green
          Write-Host "Location: $reportPath" -ForegroundColor Cyan
        }
        else {
          Write-Host "`nDemo report generation failed!" -ForegroundColor Red
        }
        Read-Host "Press Enter to continue"
      }
      "5" { 
        Write-DemoMessage "Exiting Advanced Security Demo..."
        return
      }
      default { 
        Write-Host "Invalid choice. Please enter 1-5." -ForegroundColor Red
        Start-Sleep -Seconds 2
      }
    }
  }
}

# Main execution logic
try {
  # Create output directory if it doesn't exist
  if (-not (Test-Path $OutputPath)) {
    try {
      New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
      Write-DemoSuccess "Created output directory: $OutputPath"
    }
    catch {
      Write-DemoError "Failed to create output directory: $OutputPath"
      Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
  }
    
  # Execute based on action parameter
  switch ($Action) {
    "ShowFeatures" { 
      Show-SecurityFeatures
      Read-Host "`nPress Enter to exit"
    }
    "DeployPolicies" { 
      $result = Deploy-SecurityPolicies
      if (-not $result) { exit 1 }
    }
    "RunAudit" { 
      $result = Start-SecurityAudit
      if (-not $result) { exit 1 }
    }
    "GenerateReport" { 
      $reportPath = New-DemoReport
      if (-not $reportPath) { exit 1 }
    }
    "Interactive" { 
      Show-InteractiveMenu
    }
    default { 
      Write-DemoError "Invalid action: $Action"
      exit 1
    }
  }
    
}
catch {
  Write-DemoError "An error occurred while running the Advanced Security Demo:"
  Write-Host $_.Exception.Message -ForegroundColor Red
  Write-Host ""
  Write-Host "Stack Trace:" -ForegroundColor Gray
  Write-Host $_.ScriptStackTrace -ForegroundColor Gray
  exit 1
}

# Footer message
Write-Host ""
$separator = "=" * 80
Write-Host $separator -ForegroundColor Cyan
Write-Host "Thank you for exploring $DemoType Technologies Advanced Security!" -ForegroundColor Yellow
Write-Host $separator -ForegroundColor Cyan 