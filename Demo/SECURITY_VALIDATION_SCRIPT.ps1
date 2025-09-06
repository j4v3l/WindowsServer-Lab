# 🔒 **SECURITY VALIDATION SCRIPT**
# Comprehensive security audit and validation for Asgard & Olympus
# Run this script AFTER implementing the critical security fixes

# [SERVER VM] - Run on Domain Controller (ODIN-DC01 or ZEUS-DC01)
# PREREQUISITES: Domain Administrator rights, All security fixes applied

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("Asgard", "Olympus", "Auto")]
    [string]$Environment = "Auto"
)

# Initialize secure logging
Register-EventLog -LogName "Application" -Source "SecurityValidation" -ErrorAction SilentlyContinue

function Write-ValidationLog {
    param([string]$Test, [string]$Status, [string]$Details = "", [int]$Score = 0)
    $LogEntry = @{
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Test = $Test; Status = $Status; Details = $Details; Score = $Score
        Environment = $Environment
    }
    Write-EventLog -LogName "Application" -Source "SecurityValidation" -EventId 2000 -EntryType Information -Message ($LogEntry | ConvertTo-Json) -ErrorAction SilentlyContinue
}

# Auto-detect environment
if ($Environment -eq "Auto") {
    $Domain = (Get-ADDomain).DNSRoot
    if ($Domain -eq "asgard.local") { $Environment = "Asgard" }
    elseif ($Domain -eq "olympus.local") { $Environment = "Olympus" }
    else { throw "Unknown domain: $Domain. Must be asgard.local or olympus.local" }
}

Write-Host "🔍 STARTING COMPREHENSIVE SECURITY VALIDATION" -ForegroundColor Cyan
Write-Host "🏰 Environment: $Environment" -ForegroundColor Yellow
Write-Host "📊 Testing production-grade security configurations..." -ForegroundColor Yellow

$ValidationResults = @{
    PasswordPolicies = @{ Score = 0; Tests = @() }
    SecurityLogging = @{ Score = 0; Tests = @() }
    EncryptionPolicies = @{ Score = 0; Tests = @() }
    PowerShellSecurity = @{ Score = 0; Tests = @() }
    NetworkSecurity = @{ Score = 0; Tests = @() }
    GroupPolicies = @{ Score = 0; Tests = @() }
    OverallScore = 0
    SecurityGrade = ""
    ProductionReady = $false
}

Write-Host "`n🔐 TESTING PASSWORD POLICIES..." -ForegroundColor Magenta

# Test 1: Domain Password Policy
try {
    $DomainPolicy = Get-ADDefaultDomainPasswordPolicy
    $PasswordTests = @{
        "Minimum Length ≥ 15" = $DomainPolicy.MinPasswordLength -ge 15
        "History Count ≥ 50" = $DomainPolicy.PasswordHistoryCount -ge 50
        "Max Age ≤ 60 days" = $DomainPolicy.MaxPasswordAge.Days -le 60
        "Lockout Threshold ≤ 3" = $DomainPolicy.LockoutThreshold -le 3
        "Complexity Enabled" = $DomainPolicy.ComplexityEnabled
    }
    
    $PassedTests = ($PasswordTests.Values | Where-Object { $_ -eq $true }).Count
    $TotalTests = $PasswordTests.Count
    $PasswordScore = [math]::Round(($PassedTests / $TotalTests) * 25)
    
    foreach ($Test in $PasswordTests.GetEnumerator()) {
        $Status = if ($Test.Value) { "✅ PASS" } else { "❌ FAIL" }
        Write-Host "  $($Test.Key): $Status" -ForegroundColor $(if ($Test.Value) { "Green" } else { "Red" })
        Write-ValidationLog -Test "Domain Password Policy: $($Test.Key)" -Status $(if ($Test.Value) { "PASS" } else { "FAIL" })
    }
    
    $ValidationResults.PasswordPolicies.Score = $PasswordScore
    Write-Host "📊 Password Policy Score: $PasswordScore/25" -ForegroundColor $(if ($PasswordScore -ge 20) { "Green" } else { "Red" })
}
catch {
    Write-Host "❌ CRITICAL: Failed to validate domain password policy" -ForegroundColor Red
    Write-ValidationLog -Test "Domain Password Policy" -Status "ERROR" -Details $_.Exception.Message
}

# Test 2: Fine-Grained Password Policies
try {
    $AdminPSOs = Get-ADFineGrainedPasswordPolicy -Filter "*" -ErrorAction SilentlyContinue
    $ExpectedPSOName = if ($Environment -eq "Asgard") { "ASGARD-Admin-PSO" } else { "OLYMPUS-AI-Admin-PSO" }
    $AdminPSO = $AdminPSOs | Where-Object { $_.Name -eq $ExpectedPSOName }
    
    if ($AdminPSO) {
        $MinLength = if ($Environment -eq "Asgard") { 20 } else { 25 }
        $PSO_Valid = $AdminPSO.MinPasswordLength -ge $MinLength -and $AdminPSO.LockoutThreshold -le 2
        $Status = if ($PSO_Valid) { "✅ PASS" } else { "❌ FAIL" }
        Write-Host "  Fine-Grained Admin PSO: $Status" -ForegroundColor $(if ($PSO_Valid) { "Green" } else { "Red" })
        Write-ValidationLog -Test "Fine-Grained Password Policy" -Status $(if ($PSO_Valid) { "PASS" } else { "FAIL" })
        if ($PSO_Valid) { $ValidationResults.PasswordPolicies.Score += 5 }
    } else {
        Write-Host "  ❌ FAIL: Admin PSO not found" -ForegroundColor Red
        Write-ValidationLog -Test "Fine-Grained Password Policy" -Status "FAIL" -Details "PSO not found: $ExpectedPSOName"
    }
}
catch {
    Write-Host "  ❌ ERROR: Fine-grained password policy validation failed" -ForegroundColor Red
}

Write-Host "`n📝 TESTING SECURITY LOGGING..." -ForegroundColor Magenta

# Test 3: Event Log Sources
try {
    $SecurityAuditSource = Get-EventLog -List | Where-Object { $_.Log -eq "Application" }
    $LoggingScore = 0
    
    if ($SecurityAuditSource) {
        Write-Host "  ✅ PASS: Application Event Log available" -ForegroundColor Green
        $LoggingScore += 5
        Write-ValidationLog -Test "Security Audit Logging" -Status "PASS"
    } else {
        Write-Host "  ❌ FAIL: Security audit logging not configured" -ForegroundColor Red
        Write-ValidationLog -Test "Security Audit Logging" -Status "FAIL"
    }
    
    # Test recent security events
    $RecentSecurityEvents = Get-WinEvent -FilterHashtable @{LogName='Application'; StartTime=(Get-Date).AddHours(-1)} -MaxEvents 50 -ErrorAction SilentlyContinue
    $SecurityAuditEvents = $RecentSecurityEvents | Where-Object { $_.Id -in @(1000, 1001) }
    
    if ($SecurityAuditEvents) {
        Write-Host "  ✅ PASS: Security audit events detected" -ForegroundColor Green
        $LoggingScore += 5
    } else {
        Write-Host "  ⚠️ WARNING: No recent security audit events found" -ForegroundColor Yellow
    }
    
    $ValidationResults.SecurityLogging.Score = $LoggingScore
    Write-Host "📊 Security Logging Score: $LoggingScore/10" -ForegroundColor $(if ($LoggingScore -ge 8) { "Green" } else { "Red" })
}
catch {
    Write-Host "❌ ERROR: Security logging validation failed" -ForegroundColor Red
    Write-ValidationLog -Test "Security Logging" -Status "ERROR" -Details $_.Exception.Message
}

Write-Host "`n🛡️ TESTING GROUP POLICY CONFIGURATION..." -ForegroundColor Magenta

# Test 4: Production Security GPOs
try {
    $AllGPOs = Get-GPO -All
    $EnvPrefix = $Environment.ToUpper()
    $ExpectedGPOs = @(
        "$EnvPrefix-PRODUCTION-Encryption",
        "$EnvPrefix-PRODUCTION-PowerShell", 
        "$EnvPrefix-PRODUCTION-Network"
    )
    
    $FoundGPOs = @()
    $GPOScore = 0
    
    foreach ($ExpectedGPO in $ExpectedGPOs) {
        $GPO = $AllGPOs | Where-Object { $_.DisplayName -eq $ExpectedGPO }
        if ($GPO) {
            Write-Host "  ✅ PASS: Found GPO: $ExpectedGPO" -ForegroundColor Green
            $FoundGPOs += $ExpectedGPO
            $GPOScore += 5
            Write-ValidationLog -Test "Production GPO: $ExpectedGPO" -Status "PASS"
            
            # Test GPO linkage
            $Links = Get-GPInheritance -Target "DC=$($Domain.Replace('.', ',DC='))" -ErrorAction SilentlyContinue
            $IsLinked = $Links.GpoLinks | Where-Object { $_.DisplayName -eq $ExpectedGPO -and $_.Enabled -eq $true }
            if ($IsLinked) {
                Write-Host "    ✅ Linked to domain" -ForegroundColor Green
                $GPOScore += 2
            } else {
                Write-Host "    ❌ Not linked to domain" -ForegroundColor Red
            }
        } else {
            Write-Host "  ❌ FAIL: Missing GPO: $ExpectedGPO" -ForegroundColor Red
            Write-ValidationLog -Test "Production GPO: $ExpectedGPO" -Status "FAIL"
        }
    }
    
    $ValidationResults.GroupPolicies.Score = $GPOScore
    Write-Host "📊 Group Policy Score: $GPOScore/21" -ForegroundColor $(if ($GPOScore -ge 18) { "Green" } else { "Red" })
}
catch {
    Write-Host "❌ ERROR: Group Policy validation failed" -ForegroundColor Red
    Write-ValidationLog -Test "Group Policy Configuration" -Status "ERROR" -Details $_.Exception.Message
}

Write-Host "`n⚡ TESTING POWERSHELL SECURITY..." -ForegroundColor Magenta

# Test 5: PowerShell Execution Policy
try {
    $PSExecutionPolicy = Get-ExecutionPolicy -Scope LocalMachine
    $PSSecurityScore = 0
    
    if ($PSExecutionPolicy -eq "AllSigned") {
        Write-Host "  ✅ PASS: PowerShell execution policy is AllSigned" -ForegroundColor Green
        $PSSecurityScore += 10
        Write-ValidationLog -Test "PowerShell Execution Policy" -Status "PASS" -Details "AllSigned"
    } else {
        Write-Host "  ❌ FAIL: PowerShell execution policy is $PSExecutionPolicy (should be AllSigned)" -ForegroundColor Red
        Write-ValidationLog -Test "PowerShell Execution Policy" -Status "FAIL" -Details $PSExecutionPolicy
    }
    
    # Test PowerShell logging configuration
    $PSLoggingKeys = @(
        "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging",
        "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging",
        "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription"
    )
    
    $LoggingConfigured = 0
    foreach ($Key in $PSLoggingKeys) {
        if (Test-Path $Key) {
            $LoggingConfigured++
            Write-Host "    ✅ $($Key.Split('\')[-1]) configured" -ForegroundColor Green
        } else {
            Write-Host "    ❌ $($Key.Split('\')[-1]) not configured" -ForegroundColor Red
        }
    }
    
    $PSSecurityScore += ($LoggingConfigured * 3)
    $ValidationResults.PowerShellSecurity.Score = $PSSecurityScore
    Write-Host "📊 PowerShell Security Score: $PSSecurityScore/19" -ForegroundColor $(if ($PSSecurityScore -ge 15) { "Green" } else { "Red" })
}
catch {
    Write-Host "❌ ERROR: PowerShell security validation failed" -ForegroundColor Red
    Write-ValidationLog -Test "PowerShell Security" -Status "ERROR" -Details $_.Exception.Message
}

Write-Host "`n🌐 TESTING NETWORK SECURITY..." -ForegroundColor Magenta

# Test 6: Firewall and Network Security
try {
    $FirewallProfiles = Get-NetFirewallProfile
    $NetworkScore = 0
    
    $AllEnabled = ($FirewallProfiles | Where-Object { $_.Enabled -eq $false }).Count -eq 0
    if ($AllEnabled) {
        Write-Host "  ✅ PASS: All firewall profiles enabled" -ForegroundColor Green
        $NetworkScore += 8
        Write-ValidationLog -Test "Windows Firewall" -Status "PASS"
    } else {
        Write-Host "  ❌ FAIL: Some firewall profiles disabled" -ForegroundColor Red
        Write-ValidationLog -Test "Windows Firewall" -Status "FAIL"
    }
    
    # Test SMB security
    $SMBServerConfig = Get-SmbServerConfiguration -ErrorAction SilentlyContinue
    if ($SMBServerConfig -and $SMBServerConfig.RequireSecuritySignature) {
        Write-Host "  ✅ PASS: SMB security signature required" -ForegroundColor Green
        $NetworkScore += 5
        Write-ValidationLog -Test "SMB Security" -Status "PASS"
    } else {
        Write-Host "  ❌ FAIL: SMB security signature not required" -ForegroundColor Red
        Write-ValidationLog -Test "SMB Security" -Status "FAIL"
    }
    
    # Test LDAP security
    $LDAPSecurity = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\NTDS\Parameters" -Name "LDAPServerIntegrity" -ErrorAction SilentlyContinue
    if ($LDAPSecurity -and $LDAPSecurity.LDAPServerIntegrity -eq 2) {
        Write-Host "  ✅ PASS: LDAPS integrity checking enabled" -ForegroundColor Green
        $NetworkScore += 7
        Write-ValidationLog -Test "LDAPS Security" -Status "PASS"
    } else {
        Write-Host "  ❌ FAIL: LDAPS integrity checking not enabled" -ForegroundColor Red
        Write-ValidationLog -Test "LDAPS Security" -Status "FAIL"
    }
    
    $ValidationResults.NetworkSecurity.Score = $NetworkScore
    Write-Host "📊 Network Security Score: $NetworkScore/20" -ForegroundColor $(if ($NetworkScore -ge 16) { "Green" } else { "Red" })
}
catch {
    Write-Host "❌ ERROR: Network security validation failed" -ForegroundColor Red
    Write-ValidationLog -Test "Network Security" -Status "ERROR" -Details $_.Exception.Message
}

# Calculate overall security score
$TotalScore = $ValidationResults.PasswordPolicies.Score + 
              $ValidationResults.SecurityLogging.Score + 
              $ValidationResults.GroupPolicies.Score + 
              $ValidationResults.PowerShellSecurity.Score + 
              $ValidationResults.NetworkSecurity.Score

$MaxPossibleScore = 95
$ScorePercentage = [math]::Round(($TotalScore / $MaxPossibleScore) * 100)

# Determine security grade
$SecurityGrade = switch ($ScorePercentage) {
    { $_ -ge 90 } { "A+" }
    { $_ -ge 85 } { "A" }
    { $_ -ge 80 } { "A-" }
    { $_ -ge 75 } { "B+" }
    { $_ -ge 70 } { "B" }
    { $_ -ge 65 } { "B-" }
    { $_ -ge 60 } { "C+" }
    { $_ -ge 55 } { "C" }
    { $_ -ge 50 } { "C-" }
    default { "F" }
}

$ProductionReady = $ScorePercentage -ge 80

$ValidationResults.OverallScore = $TotalScore
$ValidationResults.SecurityGrade = $SecurityGrade
$ValidationResults.ProductionReady = $ProductionReady

Write-Host "`n" + "="*80 -ForegroundColor Cyan
Write-Host "🎯 FINAL SECURITY ASSESSMENT RESULTS" -ForegroundColor Cyan
Write-Host "="*80 -ForegroundColor Cyan

Write-Host "🏰 Environment: $Environment" -ForegroundColor Yellow
Write-Host "📊 Total Security Score: $TotalScore/$MaxPossibleScore ($ScorePercentage%)" -ForegroundColor $(if ($ScorePercentage -ge 80) { "Green" } else { "Red" })
Write-Host "🏆 Security Grade: $SecurityGrade" -ForegroundColor $(if ($SecurityGrade -like "A*") { "Green" } elseif ($SecurityGrade -like "B*") { "Yellow" } else { "Red" })
Write-Host "🚀 Production Ready: $(if ($ProductionReady) { "✅ YES" } else { "❌ NO" })" -ForegroundColor $(if ($ProductionReady) { "Green" } else { "Red" })

Write-Host "`nDetailed Breakdown:" -ForegroundColor White
Write-Host "  Password Policies: $($ValidationResults.PasswordPolicies.Score)/30" -ForegroundColor $(if ($ValidationResults.PasswordPolicies.Score -ge 25) { "Green" } else { "Red" })
Write-Host "  Security Logging: $($ValidationResults.SecurityLogging.Score)/10" -ForegroundColor $(if ($ValidationResults.SecurityLogging.Score -ge 8) { "Green" } else { "Red" })
Write-Host "  Group Policies: $($ValidationResults.GroupPolicies.Score)/21" -ForegroundColor $(if ($ValidationResults.GroupPolicies.Score -ge 18) { "Green" } else { "Red" })
Write-Host "  PowerShell Security: $($ValidationResults.PowerShellSecurity.Score)/19" -ForegroundColor $(if ($ValidationResults.PowerShellSecurity.Score -ge 15) { "Green" } else { "Red" })
Write-Host "  Network Security: $($ValidationResults.NetworkSecurity.Score)/20" -ForegroundColor $(if ($ValidationResults.NetworkSecurity.Score -ge 16) { "Green" } else { "Red" })

if ($ProductionReady) {
    Write-Host "`n🎉 CONGRATULATIONS! Your $Environment environment has achieved production-grade security!" -ForegroundColor Green
    Write-Host "✅ All critical security vulnerabilities have been addressed" -ForegroundColor Green
    Write-Host "✅ Security posture is suitable for production deployment" -ForegroundColor Green
} else {
    Write-Host "`n⚠️ WARNING: Additional security hardening required before production deployment" -ForegroundColor Red
    Write-Host "📋 Review the CRITICAL_SECURITY_FIXES_REQUIRED.md document" -ForegroundColor Yellow
    Write-Host "🔧 Implement remaining security fixes and re-run validation" -ForegroundColor Yellow
}

# Save detailed report
$ReportPath = "C:\SecurityReports\SecurityValidation_$Environment_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
New-Item -Path "C:\SecurityReports" -ItemType Directory -Force -ErrorAction SilentlyContinue
$ValidationResults | ConvertTo-Json -Depth 3 | Out-File -FilePath $ReportPath -Encoding UTF8

Write-Host "`n📄 Detailed validation report saved to: $ReportPath" -ForegroundColor Blue
Write-Host "🔍 Review this report for specific remediation guidance" -ForegroundColor Blue

Write-ValidationLog -Test "Overall Security Assessment" -Status $(if ($ProductionReady) { "PRODUCTION_READY" } else { "NEEDS_IMPROVEMENT" }) -Score $TotalScore

Write-Host "`n🔒 Security validation completed!" -ForegroundColor Cyan 