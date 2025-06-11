# Advanced Security Features Demo Script
# Demonstrates comprehensive camera, USB, device control, personalization, and security features
# Integrates with existing Asgard Technologies and Olympus Systems demo environments

param(
  [string]$DemoType = "Asgard", # "Asgard" or "Olympus"
  [string]$VMPath = "C:\VMs",
  [string]$Domain = "asgard.local",
  [switch]$DeployPolicies,
  [switch]$RunAudit,
  [switch]$GenerateReport,
  [switch]$ShowFeatures
)

# Import required modules
Import-Module ActiveDirectory -ErrorAction SilentlyContinue
Import-Module GroupPolicy -ErrorAction SilentlyContinue

# Configuration
$demoConfig = @{
  ScriptsPath = $PSScriptRoot
  ReportsPath = "C:\Demo\Reports"
  LogsPath    = "C:\Demo\Logs"
  BackupPath  = "C:\Demo\Backups"
}

# Create demo directories
$demoConfig.Values | ForEach-Object {
  New-Item -Path $_ -ItemType Directory -Force -ErrorAction SilentlyContinue
}

# Demo banner function
function Show-AdvancedSecurityBanner {
  param([string]$DemoName)
    
  Clear-Host
  $banner = @"
    
██████████████████████████████████████████████████████████████████████████████
█                                                                            █
█  🛡️  ADVANCED SECURITY FEATURES DEMONSTRATION - $DemoName EDITION 🛡️       █
█                                                                            █
█  📋 Camera & Microphone Controls    🔌 USB & Storage Security             █
█  🖥️  Device & Peripheral Management  🎨 Personalization Controls          █
█  📱 Application & Software Control   🌐 Network Security Policies         █
█  🔒 Data Protection & Privacy        📊 Comprehensive Security Auditing   █
█                                                                            █
██████████████████████████████████████████████████████████████████████████████

"@
    
  Write-Host $banner -ForegroundColor Cyan
  Write-Host "🚀 Initializing Advanced Security Demo Environment..." -ForegroundColor Yellow
  Write-Host "📍 Demo Type: $DemoName | Domain: $Domain | VM Path: $VMPath" -ForegroundColor Gray
  Write-Host ""
}

# Feature demonstration function
function Show-SecurityFeatures {
  Write-Host "🎯 ADVANCED SECURITY FEATURES OVERVIEW" -ForegroundColor Magenta
  Write-Host "=" * 70 -ForegroundColor Magenta
    
  $features = @(
    @{
      Category = "🎥 Camera & Microphone Security"
      Features = @(
        "Complete camera access control for applications",
        "Microphone usage restriction policies",
        "Windows Hello camera security settings",
        "Privacy protection for multimedia devices"
      )
    },
    @{
      Category = "🔌 USB & Removable Storage Control"
      Features = @(
        "Granular USB device type restrictions",
        "Removable storage read/write/execute controls",
        "Device installation prevention policies",
        "Autorun and autoplay security settings"
      )
    },
    @{
      Category = "🖥️ Device & Peripheral Management"
      Features = @(
        "Bluetooth and wireless device controls",
        "Printer and fax management policies",
        "CD/DVD and optical drive restrictions",
        "External display and monitor controls"
      )
    },
    @{
      Category = "🎨 Personalization & User Experience"
      Features = @(
        "Desktop background and theme controls",
        "Start menu and taskbar customization",
        "Screen saver and power management",
        "Windows Store and app installation policies"
      )
    },
    @{
      Category = "📱 Application & Software Control"
      Features = @(
        "PowerShell execution and logging policies",
        "AppLocker application whitelisting",
        "Software installation restrictions",
        "Windows Defender Application Guard"
      )
    },
    @{
      Category = "🌐 Network Security & Communication"
      Features = @(
        "Advanced Windows Firewall configuration",
        "Remote Desktop security controls",
        "SMB signing and encryption settings",
        "VPN and network connection policies"
      )
    },
    @{
      Category = "🔒 Data Protection & Privacy"
      Features = @(
        "Telemetry and data collection controls",
        "OneDrive and cloud service policies",
        "Cortana and search privacy settings",
        "Windows Error Reporting configuration"
      )
    },
    @{
      Category = "📊 Security Auditing & Monitoring"
      Features = @(
        "Comprehensive security score calculation",
        "Real-time policy compliance checking",
        "Advanced HTML reporting with analytics",
        "Security improvement recommendations"
      )
    }
  )
    
  foreach ($category in $features) {
    Write-Host "`n$($category.Category)" -ForegroundColor Cyan
    Write-Host ("-" * $category.Category.Length) -ForegroundColor Cyan
    foreach ($feature in $category.Features) {
      Write-Host "  ✓ $feature" -ForegroundColor Green
    }
  }
    
  Write-Host "`n" + "=" * 70 -ForegroundColor Magenta
  Write-Host "🎉 Total: $(($features.Features | Measure-Object).Count) Advanced Security Features!" -ForegroundColor Yellow
}

# Deploy advanced security policies
function Deploy-AdvancedSecurityPolicies {
  param([string]$TargetDomain)
    
  Write-Host "🚀 Deploying Advanced Security Policies..." -ForegroundColor Yellow
    
  try {
    # Check if Advanced GPO Manager exists
    $advancedGPOScript = Join-Path $PSScriptRoot "..\..\Scripts\AdvancedGroupPolicyManager.ps1"
    if (-not (Test-Path $advancedGPOScript)) {
      Write-Warning "Advanced GPO Manager script not found. Creating basic implementation..."
      return
    }
        
    # Source the Advanced GPO Manager
    . $advancedGPOScript
        
    # Define OU mappings based on demo type
    if ($DemoType -eq "Asgard") {
      $ouMappings = @{
        "Security"           = "OU=IT Operations,OU=Asgard Departments,DC=asgard,DC=local"
        "DeviceControl"      = "OU=General Users,OU=Asgard Departments,DC=asgard,DC=local"
        "ApplicationControl" = "OU=Cybersecurity,OU=Asgard Departments,DC=asgard,DC=local"
        "NetworkSecurity"    = "OU=Servers,OU=Asgard Infrastructure,DC=asgard,DC=local"
        "DataProtection"     = "OU=Finance,OU=Asgard Departments,DC=asgard,DC=local"
        "Personalization"    = "OU=HR,OU=Asgard Departments,DC=asgard,DC=local"
      }
    }
    else {
      $ouMappings = @{
        "Security"           = "OU=IT Operations,OU=Olympus Departments,DC=olympus,DC=local"
        "DeviceControl"      = "OU=General Users,OU=Olympus Departments,DC=olympus,DC=local"
        "ApplicationControl" = "OU=AI Research,OU=Olympus Departments,DC=olympus,DC=local"
        "NetworkSecurity"    = "OU=Cloud Infrastructure,OU=Olympus Infrastructure,DC=olympus,DC=local"
        "DataProtection"     = "OU=Data Analytics,OU=Olympus Departments,DC=olympus,DC=local"
        "Personalization"    = "OU=HR,OU=Olympus Departments,DC=olympus,DC=local"
      }
    }
        
    Write-Host "📋 Deploying policies to organizational units..." -ForegroundColor Cyan
        
    # Deploy all advanced GPO categories
    Deploy-AllAdvancedGPOs -OUMappings $ouMappings
        
    Write-Host "✅ Advanced security policies deployed successfully!" -ForegroundColor Green
        
    # Wait for policy replication
    Write-Host "⏳ Waiting for policy replication..." -ForegroundColor Yellow
    Start-Sleep -Seconds 30
        
    # Force group policy update on domain controllers
    Write-Host "🔄 Forcing group policy update..." -ForegroundColor Cyan
    try {
      Invoke-Command -ComputerName (Get-ADDomainController).Name -ScriptBlock {
        gpupdate /force
      } -ErrorAction SilentlyContinue
    }
    catch {
      Write-Warning "Could not force GP update on remote DCs: $_"
    }
        
    Write-Host "🎉 Advanced security policies are now active!" -ForegroundColor Green
        
  }
  catch {
    Write-Error "Failed to deploy advanced security policies: $_"
  }
}

# Run comprehensive security audit
function Start-AdvancedSecurityAudit {
  Write-Host "🔍 Running Comprehensive Security Audit..." -ForegroundColor Yellow
    
  try {
    # Check if Advanced Security Audit script exists
    $advancedAuditScript = Join-Path $PSScriptRoot "..\..\Scripts\AdvancedSecurityAudit.ps1"
    if (-not (Test-Path $advancedAuditScript)) {
      Write-Warning "Advanced Security Audit script not found."
      return
    }
        
    # Source the Advanced Security Audit script
    . $advancedAuditScript
        
    Write-Host "📊 Performing quick security check..." -ForegroundColor Cyan
    Start-QuickSecurityCheck
        
    Write-Host "`n🔍 Generating comprehensive security report..." -ForegroundColor Cyan
    $reportPath = Get-AdvancedSecurityReport -OutputPath $demoConfig.ReportsPath
        
    Write-Host "✅ Security audit completed!" -ForegroundColor Green
    Write-Host "📄 Report saved to: $reportPath" -ForegroundColor Cyan
        
    # Open report if possible
    if (Test-Path $reportPath) {
      Write-Host "🌐 Opening security report..." -ForegroundColor Yellow
      try {
        Start-Process $reportPath
      }
      catch {
        Write-Host "📄 Report available at: $reportPath" -ForegroundColor Cyan
      }
    }
        
  }
  catch {
    Write-Error "Failed to run security audit: $_"
  }
}

# Generate demonstration report
function New-DemoReport {
  $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
  $reportPath = Join-Path $demoConfig.ReportsPath "AdvancedSecurityDemo_$timestamp.html"
    
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
        .feature-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
            margin: 30px 0;
        }
        .feature-card {
            background: linear-gradient(135deg, #f8f9fa 0%, #e9ecef 100%);
            border-radius: 8px;
            padding: 20px;
            box-shadow: 0 4px 15px rgba(0,0,0,0.1);
            border-left: 5px solid #3498db;
        }
        .demo-section {
            background-color: #f8f9fa;
            border-radius: 8px;
            padding: 20px;
            margin: 20px 0;
            border: 1px solid #e9ecef;
        }
        h1 { color: #2c3e50; font-size: 2.5em; margin-bottom: 10px; }
        h2 { color: #34495e; border-left: 5px solid #3498db; padding-left: 15px; }
        h3 { color: #7f8c8d; }
        .highlight { background-color: #fff3cd; padding: 15px; border-left: 4px solid #ffc107; margin: 15px 0; }
        .success { background-color: #d4edda; padding: 15px; border-left: 4px solid #28a745; margin: 15px 0; }
        ul li { margin: 8px 0; }
    </style>
</head>
<body>
    <div class="container">
        <div class="demo-header">
            <h1>🛡️ Advanced Security Features Demo</h1>
            <h2>$DemoType Technologies Edition</h2>
            <p>Comprehensive Windows Server Lab Security Demonstration</p>
            <p><strong>Generated:</strong> $timestamp</p>
        </div>
        
        <div class="success">
            <h3>🎉 Demo Deployment Summary</h3>
            <ul>
                <li><strong>Demo Environment:</strong> $DemoType Technologies</li>
                <li><strong>Domain:</strong> $Domain</li>
                <li><strong>VM Path:</strong> $VMPath</li>
                <li><strong>Features Deployed:</strong> 8 Major Security Categories</li>
                <li><strong>Policies Created:</strong> 6 Advanced Group Policy Objects</li>
                <li><strong>Security Controls:</strong> 100+ Individual Settings</li>
            </ul>
        </div>
        
        <h2>🎯 Deployed Security Features</h2>
        
        <div class="feature-grid">
            <div class="feature-card">
                <h3>🎥 Camera & Microphone Security</h3>
                <ul>
                    <li>Application camera access control</li>
                    <li>Microphone usage restrictions</li>
                    <li>Privacy protection policies</li>
                    <li>Windows Hello security settings</li>
                </ul>
            </div>
            
            <div class="feature-card">
                <h3>🔌 USB & Storage Control</h3>
                <ul>
                    <li>Removable storage access restrictions</li>
                    <li>USB device installation controls</li>
                    <li>Autorun/autoplay security</li>
                    <li>Device type granular controls</li>
                </ul>
            </div>
            
            <div class="feature-card">
                <h3>🖥️ Device & Peripheral Management</h3>
                <ul>
                    <li>Bluetooth and wireless controls</li>
                    <li>Printer management policies</li>
                    <li>CD/DVD access restrictions</li>
                    <li>External display controls</li>
                </ul>
            </div>
            
            <div class="feature-card">
                <h3>🎨 Personalization Controls</h3>
                <ul>
                    <li>Desktop customization policies</li>
                    <li>Start menu and taskbar control</li>
                    <li>Screen saver management</li>
                    <li>Windows Store restrictions</li>
                </ul>
            </div>
            
            <div class="feature-card">
                <h3>📱 Application Security</h3>
                <ul>
                    <li>PowerShell execution policies</li>
                    <li>AppLocker whitelisting</li>
                    <li>Software installation controls</li>
                    <li>Browser security settings</li>
                </ul>
            </div>
            
            <div class="feature-card">
                <h3>🌐 Network Security</h3>
                <ul>
                    <li>Advanced firewall configuration</li>
                    <li>Remote Desktop controls</li>
                    <li>SMB signing and encryption</li>
                    <li>VPN connection policies</li>
                </ul>
            </div>
            
            <div class="feature-card">
                <h3>🔒 Data Protection</h3>
                <ul>
                    <li>Telemetry and privacy controls</li>
                    <li>OneDrive and cloud policies</li>
                    <li>Cortana usage restrictions</li>
                    <li>Error reporting settings</li>
                </ul>
            </div>
            
            <div class="feature-card">
                <h3>📊 Security Monitoring</h3>
                <ul>
                    <li>Comprehensive audit reporting</li>
                    <li>Security score calculation</li>
                    <li>Policy compliance checking</li>
                    <li>Improvement recommendations</li>
                </ul>
            </div>
        </div>
        
        <div class="demo-section">
            <h2>🚀 Next Steps for Testing</h2>
            
            <h3>1. Policy Validation</h3>
            <ul>
                <li>Connect to domain-joined VMs and test camera access</li>
                <li>Attempt USB device connections to verify restrictions</li>
                <li>Try customizing desktop to test personalization controls</li>
                <li>Test application installations and PowerShell execution</li>
            </ul>
            
            <h3>2. Security Auditing</h3>
            <ul>
                <li>Run the Advanced Security Audit script: <code>.\AdvancedSecurityAudit.ps1</code></li>
                <li>Generate comprehensive security reports</li>
                <li>Review security scores and recommendations</li>
                <li>Monitor policy compliance across the environment</li>
            </ul>
            
            <h3>3. Policy Management</h3>
            <ul>
                <li>Use the Advanced GPO Manager for policy modifications</li>
                <li>Test different policy combinations and scenarios</li>
                <li>Create custom policies for specific requirements</li>
                <li>Backup and restore policy configurations</li>
            </ul>
        </div>
        
        <div class="highlight">
            <h3>💡 Demo Environment Access</h3>
            <p>To fully experience these features:</p>
            <ul>
                <li><strong>Domain Controllers:</strong> Access via RDP to test policy deployment</li>
                <li><strong>Client Workstations:</strong> Log in with domain users to test restrictions</li>
                <li><strong>Administrative Tools:</strong> Use GPMC to view and modify policies</li>
                <li><strong>Audit Scripts:</strong> Run from any domain-joined machine with admin rights</li>
            </ul>
        </div>
        
        <div class="demo-section">
            <h2>📚 Documentation and Resources</h2>
            <ul>
                <li><strong>Advanced GPO Guide:</strong> LabSetupTutorials/04_GPO_Creation_and_Linking.md</li>
                <li><strong>Security Hardening:</strong> LabSetupTutorials/09_Security_Hardening.md</li>
                <li><strong>PowerShell Scripts:</strong> Scripts/AdvancedGroupPolicyManager.ps1</li>
                <li><strong>Security Auditing:</strong> Scripts/AdvancedSecurityAudit.ps1</li>
                <li><strong>Demo Environments:</strong> Demo/ directory with complete setups</li>
            </ul>
        </div>
        
        <footer style="text-align: center; margin-top: 40px; padding-top: 20px; border-top: 2px solid #ddd; color: #7f8c8d;">
            <p><strong>Advanced Security Demo - Windows Server Lab Environment</strong></p>
            <p>$DemoType Technologies Edition | Generated: $timestamp</p>
            <p>🛡️ Comprehensive Security Controls Demonstration</p>
        </footer>
    </div>
</body>
</html>
"@
    
  $html | Out-File -FilePath $reportPath -Encoding UTF8
  Write-Host "📄 Demo report generated: $reportPath" -ForegroundColor Green
    
  # Open report
  try {
    Start-Process $reportPath
  }
  catch {
    Write-Host "📄 Report available at: $reportPath" -ForegroundColor Cyan
  }
    
  return $reportPath
}

# Interactive demo menu
function Show-DemoMenu {
  do {
    Clear-Host
    Show-AdvancedSecurityBanner -DemoName $DemoType
        
    Write-Host "🎮 ADVANCED SECURITY DEMO MENU" -ForegroundColor Magenta
    Write-Host "=" * 50 -ForegroundColor Magenta
    Write-Host "1. 🎯 Show Security Features Overview" -ForegroundColor White
    Write-Host "2. 🚀 Deploy Advanced Security Policies" -ForegroundColor White
    Write-Host "3. 🔍 Run Comprehensive Security Audit" -ForegroundColor White
    Write-Host "4. 📊 Generate Demo Report" -ForegroundColor White
    Write-Host "5. 🛠️  Open Advanced GPO Manager" -ForegroundColor White
    Write-Host "6. 📋 Open Group Policy Management Console" -ForegroundColor White
    Write-Host "7. 🌐 View Security Documentation" -ForegroundColor White
    Write-Host "8. 🔄 Switch Demo Environment ($DemoType ⟷ $(if($DemoType -eq 'Asgard'){'Olympus'}else{'Asgard'}))" -ForegroundColor Yellow
    Write-Host "0. 🚪 Exit Demo" -ForegroundColor Red
    Write-Host "=" * 50 -ForegroundColor Magenta
        
    $choice = Read-Host "Select an option (0-8)"
        
    switch ($choice) {
      "1" { 
        Show-SecurityFeatures
        Read-Host "`nPress Enter to continue"
      }
      "2" { 
        Deploy-AdvancedSecurityPolicies -TargetDomain $Domain
        Read-Host "`nPress Enter to continue"
      }
      "3" { 
        Start-AdvancedSecurityAudit
        Read-Host "`nPress Enter to continue"
      }
      "4" { 
        New-DemoReport
        Read-Host "`nPress Enter to continue"
      }
      "5" {
        $gpoManagerScript = Join-Path $PSScriptRoot "..\..\Scripts\AdvancedGroupPolicyManager.ps1"
        if (Test-Path $gpoManagerScript) {
          & $gpoManagerScript
        }
        else {
          Write-Warning "Advanced GPO Manager not found"
          Read-Host "Press Enter to continue"
        }
      }
      "6" {
        try {
          Start-Process "gpmc.msc"
        }
        catch {
          Write-Warning "Could not open GPMC: $_"
          Read-Host "Press Enter to continue"
        }
      }
      "7" {
        $docPath = Join-Path $PSScriptRoot "..\..\LabSetupTutorials\04_GPO_Creation_and_Linking.md"
        if (Test-Path $docPath) {
          Start-Process "notepad.exe" -ArgumentList $docPath
        }
        else {
          Write-Warning "Documentation not found"
        }
        Read-Host "Press Enter to continue"
      }
      "8" {
        $script:DemoType = if ($DemoType -eq "Asgard") { "Olympus" } else { "Asgard" }
        Write-Host "✅ Switched to $DemoType demo environment" -ForegroundColor Green
        Start-Sleep 2
      }
      "0" { 
        Write-Host "👋 Thank you for exploring Advanced Security Features!" -ForegroundColor Green
        Write-Host "📚 Visit our documentation for more information." -ForegroundColor Cyan
        break 
      }
      default { 
        Write-Host "❌ Invalid option. Please try again." -ForegroundColor Red
        Start-Sleep 2 
      }
    }
  } while ($choice -ne "0")
}

# Main execution logic
function Start-AdvancedSecurityDemo {
  try {
    # Show banner
    Show-AdvancedSecurityBanner -DemoName $DemoType
        
    # Handle command line parameters
    if ($ShowFeatures) {
      Show-SecurityFeatures
      return
    }
        
    if ($DeployPolicies) {
      Deploy-AdvancedSecurityPolicies -TargetDomain $Domain
      return
    }
        
    if ($RunAudit) {
      Start-AdvancedSecurityAudit
      return
    }
        
    if ($GenerateReport) {
      New-DemoReport
      return
    }
        
    # Show interactive menu if no specific action requested
    Show-DemoMenu
        
  }
  catch {
    Write-Error "Demo execution failed: $_"
    Write-Host "Please check the error details and try again." -ForegroundColor Red
    Read-Host "Press Enter to exit"
  }
}

# Export functions for external use
Export-ModuleMember -Function Start-AdvancedSecurityDemo, Deploy-AdvancedSecurityPolicies, Start-AdvancedSecurityAudit

# Auto-run if script is called directly
if ($MyInvocation.InvocationName -eq $MyInvocation.MyCommand.Path) {
  Start-AdvancedSecurityDemo
} 