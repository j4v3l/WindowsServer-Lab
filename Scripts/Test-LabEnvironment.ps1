# Lab Environment Validation Script
# This script validates that the lab environment is properly configured

#Requires -RunAsAdministrator

[CmdletBinding()]
param(
    [switch]$Detailed = $false,
    [switch]$FixIssues = $false
)

# Enhanced Error Handling Configuration
$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"

# Logging Configuration
$LogPath = Join-Path $env:TEMP "Lab-Validation.log"
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARNING", "ERROR", "SUCCESS", "DEBUG")]
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Add-Content -Path $LogPath -Value $logEntry -ErrorAction SilentlyContinue
    
    # Also write to console with color
    switch ($Level) {
        "ERROR" { Write-Host "❌ $Message" -ForegroundColor Red }
        "WARNING" { Write-Host "⚠️  $Message" -ForegroundColor Yellow }
        "SUCCESS" { Write-Host "✅ $Message" -ForegroundColor Green }
        "INFO" { Write-Host "ℹ️  $Message" -ForegroundColor Cyan }
        "DEBUG" { if ($Detailed) { Write-Host "🔍 $Message" -ForegroundColor Gray } }
    }
}

# Validation Results
$script:ValidationResults = @{
    TotalTests = 0
    PassedTests = 0
    FailedTests = 0
    WarningTests = 0
    Issues = @()
}

function Test-Prerequisites {
    Write-Log "=== TESTING PREREQUISITES ===" "INFO"
    
    # Test PowerShell version
    $psVersion = $PSVersionTable.PSVersion
    $script:ValidationResults.TotalTests++
    if ($psVersion.Major -ge 5) {
        Write-Log "PowerShell version: $($psVersion.ToString())" "SUCCESS"
        $script:ValidationResults.PassedTests++
    } else {
        Write-Log "PowerShell version too old: $($psVersion.ToString()). Requires 5.0 or later." "ERROR"
        $script:ValidationResults.FailedTests++
        $script:ValidationResults.Issues += "PowerShell version too old"
    }
    
    # Test if running as administrator
    $script:ValidationResults.TotalTests++
    if (([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Log "Running as Administrator" "SUCCESS"
        $script:ValidationResults.PassedTests++
    } else {
        Write-Log "Not running as Administrator" "ERROR"
        $script:ValidationResults.FailedTests++
        $script:ValidationResults.Issues += "Not running as Administrator"
    }
    
    # Test Hyper-V availability
    $script:ValidationResults.TotalTests++
    try {
        $hyperVFeature = Get-WindowsOptionalFeature -FeatureName Microsoft-Hyper-V -Online -ErrorAction Stop
        if ($hyperVFeature.State -eq "Enabled") {
            Write-Log "Hyper-V is enabled" "SUCCESS"
            $script:ValidationResults.PassedTests++
        } else {
            Write-Log "Hyper-V is not enabled" "WARNING"
            $script:ValidationResults.WarningTests++
            $script:ValidationResults.Issues += "Hyper-V not enabled"
        }
    } catch {
        Write-Log "Cannot check Hyper-V status: $($_.Exception.Message)" "ERROR"
        $script:ValidationResults.FailedTests++
        $script:ValidationResults.Issues += "Cannot check Hyper-V status"
    }
}

function Test-HyperVConfiguration {
    Write-Log "=== TESTING HYPER-V CONFIGURATION ===" "INFO"
    
    try {
        # Test if Hyper-V module is available
        $script:ValidationResults.TotalTests++
        if (Get-Module -ListAvailable -Name Hyper-V) {
            Write-Log "Hyper-V PowerShell module available" "SUCCESS"
            $script:ValidationResults.PassedTests++
            
            # Test virtual switches
            $expectedSwitches = @("LAB-External", "LAB-Management", "LAB-Isolated")
            foreach ($switchName in $expectedSwitches) {
                $script:ValidationResults.TotalTests++
                $switch = Get-VMSwitch -Name $switchName -ErrorAction SilentlyContinue
                if ($switch) {
                    Write-Log "Virtual switch exists: $switchName ($($switch.SwitchType))" "SUCCESS"
                    $script:ValidationResults.PassedTests++
                } else {
                    Write-Log "Virtual switch missing: $switchName" "WARNING"
                    $script:ValidationResults.WarningTests++
                    $script:ValidationResults.Issues += "Missing virtual switch: $switchName"
                }
            }
            
            # Test NAT configuration
            $script:ValidationResults.TotalTests++
            $nat = Get-NetNat -Name "LAB-ManagementNAT" -ErrorAction SilentlyContinue
            if ($nat) {
                Write-Log "NAT configuration exists: $($nat.InternalIPInterfaceAddressPrefix)" "SUCCESS"
                $script:ValidationResults.PassedTests++
            } else {
                Write-Log "NAT configuration missing for management network" "WARNING"
                $script:ValidationResults.WarningTests++
                $script:ValidationResults.Issues += "Missing NAT configuration"
            }
            
            # Test VMs
            $labVMs = Get-VM | Where-Object {$_.Name -like "*LAB*"}
            $script:ValidationResults.TotalTests++
            if ($labVMs) {
                Write-Log "Lab VMs found: $($labVMs.Count) VMs" "SUCCESS"
                $script:ValidationResults.PassedTests++
                
                foreach ($vm in $labVMs) {
                    Write-Log "  VM: $($vm.Name) - State: $($vm.State)" "DEBUG"
                    
                    # Check VM network adapters
                    $adapters = Get-VMNetworkAdapter -VMName $vm.Name
                    if ($adapters) {
                        Write-Log "    Network adapters: $($adapters.Count)" "DEBUG"
                        foreach ($adapter in $adapters) {
                            Write-Log "      $($adapter.Name) -> $($adapter.SwitchName)" "DEBUG"
                        }
                    }
                }
            } else {
                Write-Log "No lab VMs found" "WARNING"
                $script:ValidationResults.WarningTests++
                $script:ValidationResults.Issues += "No lab VMs found"
            }
            
        } else {
            Write-Log "Hyper-V PowerShell module not available" "ERROR"
            $script:ValidationResults.FailedTests++
            $script:ValidationResults.Issues += "Hyper-V PowerShell module not available"
        }
    } catch {
        Write-Log "Error testing Hyper-V configuration: $($_.Exception.Message)" "ERROR"
        $script:ValidationResults.FailedTests++
        $script:ValidationResults.Issues += "Error testing Hyper-V configuration"
    }
}

function Test-ActiveDirectoryEnvironment {
    Write-Log "=== TESTING ACTIVE DIRECTORY ENVIRONMENT ===" "INFO"
    
    try {
        # Test if AD module is available
        $script:ValidationResults.TotalTests++
        if (Get-Module -ListAvailable -Name ActiveDirectory) {
            Write-Log "Active Directory PowerShell module available" "SUCCESS"
            $script:ValidationResults.PassedTests++
            
            # Try to connect to domain
            $script:ValidationResults.TotalTests++
            try {
                $domain = Get-ADDomain -ErrorAction Stop
                Write-Log "Connected to domain: $($domain.DNSRoot)" "SUCCESS"
                $script:ValidationResults.PassedTests++
                
                # Test domain structure
                $expectedOUs = @("IT", "HR", "Sales", "Finance", "Marketing")
                foreach ($ouName in $expectedOUs) {
                    $script:ValidationResults.TotalTests++
                    try {
                        $ou = Get-ADOrganizationalUnit -Filter "Name -eq '$ouName'" -ErrorAction Stop
                        if ($ou) {
                            Write-Log "OU exists: $ouName" "SUCCESS"
                            $script:ValidationResults.PassedTests++
                        } else {
                            Write-Log "OU missing: $ouName" "WARNING"
                            $script:ValidationResults.WarningTests++
                            $script:ValidationResults.Issues += "Missing OU: $ouName"
                        }
                    } catch {
                        Write-Log "Cannot check OU: $ouName - $($_.Exception.Message)" "WARNING"
                        $script:ValidationResults.WarningTests++
                        $script:ValidationResults.Issues += "Cannot check OU: $ouName"
                    }
                }
                
            } catch {
                Write-Log "Cannot connect to domain (may not be domain-joined): $($_.Exception.Message)" "WARNING"
                $script:ValidationResults.WarningTests++
                $script:ValidationResults.Issues += "Cannot connect to domain"
            }
            
        } else {
            Write-Log "Active Directory PowerShell module not available (expected on domain controllers)" "WARNING"
            $script:ValidationResults.WarningTests++
            $script:ValidationResults.Issues += "AD PowerShell module not available"
        }
    } catch {
        Write-Log "Error testing Active Directory environment: $($_.Exception.Message)" "ERROR"
        $script:ValidationResults.FailedTests++
        $script:ValidationResults.Issues += "Error testing Active Directory"
    }
}

function Test-NetworkConfiguration {
    Write-Log "=== TESTING NETWORK CONFIGURATION ===" "INFO"
    
    # Test network adapters
    $script:ValidationResults.TotalTests++
    $adapters = Get-NetAdapter | Where-Object {$_.Status -eq "Up"}
    if ($adapters) {
        Write-Log "Active network adapters: $($adapters.Count)" "SUCCESS"
        $script:ValidationResults.PassedTests++
        
        foreach ($adapter in $adapters) {
            Write-Log "  $($adapter.Name): $($adapter.LinkSpeed)" "DEBUG"
        }
    } else {
        Write-Log "No active network adapters found" "ERROR"
        $script:ValidationResults.FailedTests++
        $script:ValidationResults.Issues += "No active network adapters"
    }
    
    # Test DNS resolution
    $script:ValidationResults.TotalTests++
    try {
        $dnsTest = Resolve-DnsName -Name "microsoft.com" -ErrorAction Stop
        Write-Log "DNS resolution working" "SUCCESS"
        $script:ValidationResults.PassedTests++
    } catch {
        Write-Log "DNS resolution failed: $($_.Exception.Message)" "ERROR"
        $script:ValidationResults.FailedTests++
        $script:ValidationResults.Issues += "DNS resolution failed"
    }
    
    # Test internet connectivity
    $script:ValidationResults.TotalTests++
    try {
        $pingTest = Test-NetConnection -ComputerName "8.8.8.8" -Port 53 -InformationLevel Quiet -ErrorAction Stop
        if ($pingTest) {
            Write-Log "Internet connectivity available" "SUCCESS"
            $script:ValidationResults.PassedTests++
        } else {
            Write-Log "Internet connectivity issues" "WARNING"
            $script:ValidationResults.WarningTests++
            $script:ValidationResults.Issues += "Internet connectivity issues"
        }
    } catch {
        Write-Log "Cannot test internet connectivity: $($_.Exception.Message)" "WARNING"
        $script:ValidationResults.WarningTests++
        $script:ValidationResults.Issues += "Cannot test internet connectivity"
    }
}

function Test-ScriptFiles {
    Write-Log "=== TESTING SCRIPT FILES ===" "INFO"
    
    $scriptPath = Split-Path -Parent $MyInvocation.ScriptName
    $expectedScripts = @(
        "Hyper-V_Lab_Setup.ps1",
        "Hyper-V_Management.ps1",
        "Lab_Setup.ps1",
        "Create-LabUsers.ps1",
        "GroupPolicyManager.ps1",
        "SecurityAudit.ps1"
    )
    
    foreach ($scriptName in $expectedScripts) {
        $script:ValidationResults.TotalTests++
        $fullPath = Join-Path $scriptPath $scriptName
        if (Test-Path $fullPath) {
            Write-Log "Script exists: $scriptName" "SUCCESS"
            $script:ValidationResults.PassedTests++
            
            # Test script syntax
            try {
                $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $fullPath -Raw), [ref]$null)
                Write-Log "  Script syntax valid: $scriptName" "DEBUG"
            } catch {
                Write-Log "  Script syntax error in $scriptName`: $($_.Exception.Message)" "WARNING"
                $script:ValidationResults.WarningTests++
                $script:ValidationResults.Issues += "Script syntax error: $scriptName"
            }
        } else {
            Write-Log "Script missing: $scriptName" "WARNING"
            $script:ValidationResults.WarningTests++
            $script:ValidationResults.Issues += "Missing script: $scriptName"
        }
    }
}

function Show-ValidationSummary {
    Write-Log "`n=== VALIDATION SUMMARY ===" "INFO"
    Write-Log "Total Tests: $($script:ValidationResults.TotalTests)" "INFO"
    Write-Log "Passed: $($script:ValidationResults.PassedTests)" "SUCCESS"
    Write-Log "Warnings: $($script:ValidationResults.WarningTests)" "WARNING"
    Write-Log "Failed: $($script:ValidationResults.FailedTests)" "ERROR"
    
    $successRate = if ($script:ValidationResults.TotalTests -gt 0) { 
        [math]::Round(($script:ValidationResults.PassedTests / $script:ValidationResults.TotalTests) * 100, 1) 
    } else { 0 }
    Write-Log "Success Rate: $successRate%" "INFO"
    
    if ($script:ValidationResults.Issues.Count -gt 0) {
        Write-Log "`nIssues Found:" "WARNING"
        foreach ($issue in $script:ValidationResults.Issues) {
            Write-Log "  - $issue" "WARNING"
        }
    }
    
    if ($script:ValidationResults.FailedTests -eq 0 -and $script:ValidationResults.WarningTests -eq 0) {
        Write-Log "`n🎉 All tests passed! Lab environment is properly configured." "SUCCESS"
    } elseif ($script:ValidationResults.FailedTests -eq 0) {
        Write-Log "`n⚠️  Lab environment is mostly configured but has some warnings." "WARNING"
    } else {
        Write-Log "`n❌ Lab environment has critical issues that need attention." "ERROR"
    }
    
    Write-Log "`nDetailed log saved to: $LogPath" "INFO"
}

# Main execution
try {
    Write-Log "=== LAB ENVIRONMENT VALIDATION STARTED ===" "INFO"
    Write-Log "Timestamp: $(Get-Date)" "INFO"
    Write-Log "Computer: $env:COMPUTERNAME" "INFO"
    Write-Log "User: $env:USERNAME" "INFO"
    Write-Log "Detailed mode: $Detailed" "INFO"
    
    # Clear previous log
    if (Test-Path $LogPath) {
        Remove-Item $LogPath -Force -ErrorAction SilentlyContinue
    }
    
    # Run validation tests
    Test-Prerequisites
    Test-HyperVConfiguration
    Test-ActiveDirectoryEnvironment
    Test-NetworkConfiguration
    Test-ScriptFiles
    
    # Show summary
    Show-ValidationSummary
    
    # Return exit code based on results
    if ($script:ValidationResults.FailedTests -gt 0) {
        exit 1
    } else {
        exit 0
    }
}
catch {
    Write-Log "Validation script failed: $($_.Exception.Message)" "ERROR"
    Write-Log "Stack trace: $($_.ScriptStackTrace)" "DEBUG"
    exit 1
} 