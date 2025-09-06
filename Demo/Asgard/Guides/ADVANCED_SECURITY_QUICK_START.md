# 🔒 Asgard Technologies - Advanced Security Quick Start

**EXECUTION CONTEXT: All PowerShell commands run INSIDE Windows Server VM (ODIN-DC01 - Primary Domain Controller)**  
**ACCESS METHOD: RDP, Console, or PowerShell Direct to Domain Controller VM**  
**PREREQUISITES: Domain Administrator rights, Group Policy Management Tools**

This guide provides comprehensive advanced security configurations specifically for the Asgard Technologies lab environment.

# 🛡️ Advanced Security Features - Asgard Technologies Quick Start Guide

## 🎯 Overview

This guide demonstrates how to manually deploy and configure the **100+ advanced security features** in the **Asgard Technologies** demo environment. Unlike automated scripts, this manual approach provides complete control over each security configuration step.

**Asgard Technologies** represents a traditional Norse mythology enterprise organization with comprehensive security controls and established Windows Server enterprise features.

---

## 🏰 Environment Overview

### **Domain Information**

- **Domain**: `asgard.local`
- **NetBIOS**: `ASGARD`
- **Forest Functional Level**: Windows Server 2019+
- **Theme**: Norse mythology enterprise

### **Key Administrative Accounts**

- **odin.allfather** - CEO & Domain Admin (All-Father Supreme Power)
- **thor.thunderer** - CTO & Security Lead (Thunder God Protection)
- **heimdall.guardian** - CISO & Network Security (Guardian of the Bifrost)
- **frigg.queen** - CFO (Queen of Asgard)
- **balder.light** - Head of Innovation (God of Light & Purity)

### **Organizational Structure**

- **IT Operations** - Technology Infrastructure & Administration
- **Cybersecurity** - Information Security & Threat Management
- **Research & Development** - Innovation & Development
- **Finance & Administration** - Financial Operations & Governance
- **Human Resources** - Personnel & Employee Relations

---

## 🛡️ Manual Security Configuration

### **Phase 1: Domain Security Foundation**

#### **Step 1.1: Configure Domain Password Policy**

```powershell
# Run on ODIN-DC01 as Domain Administrator
Import-Module ActiveDirectory

# SECURE: Enhanced domain password policy for production
Set-ADDefaultDomainPasswordPolicy -Identity "asgard.local" `
    -MinPasswordLength 15 `
    -PasswordHistoryCount 50 `
    -MaxPasswordAge (New-TimeSpan -Days 60) `
    -MinPasswordAge (New-TimeSpan -Days 7) `
    -ComplexityEnabled $true `
    -LockoutDuration (New-TimeSpan -Hours 2) `
    -LockoutObservationWindow (New-TimeSpan -Minutes 15) `
    -LockoutThreshold 3

# Create fine-grained password policy for administrators
New-ADFineGrainedPasswordPolicy -Name "ASGARD-Admin-PSO" `
    -MinPasswordLength 20 `
    -PasswordHistoryCount 50 `
    -MaxPasswordAge (New-TimeSpan -Days 30) `
    -MinPasswordAge (New-TimeSpan -Days 1) `
    -LockoutDuration (New-TimeSpan -Hours 4) `
    -LockoutThreshold 2 `
    -Precedence 10

# Apply enhanced policy to privileged accounts
$PrivilegedUsers = @("odin.allfather", "thor.thunderer", "heimdall.guardian")
foreach ($User in $PrivilegedUsers) {
    Add-ADFineGrainedPasswordPolicySubject -Identity "ASGARD-Admin-PSO" -Subjects $User
}

Write-Host "✅ SECURE: Enhanced password policies configured for production" -ForegroundColor Green
```

#### **Step 1.2: Create Security Organizational Units**

```powershell
# Create security-focused OUs under Asgard Technologies
$SecurityOUs = @(
    "OU=Security_Groups,OU=Asgard Technologies,DC=asgard,DC=local",
    "OU=Security_Policies,OU=Asgard Technologies,DC=asgard,DC=local",
    "OU=Privileged_Accounts,OU=Asgard Technologies,DC=asgard,DC=local",
    "OU=Quarantine,OU=Asgard Technologies,DC=asgard,DC=local"
)

# SECURE: Initialize security audit logging
function Write-SecurityAuditLog {
    param([string]$Action, [string]$Status, [string]$Details = "")
    $LogEntry = @{
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Action = $Action; Status = $Status; User = $env:USERNAME; Details = $Details
    }
    $EventId = if ($Status -eq "SUCCESS") { 1000 } else { 1001 }
    Write-EventLog -LogName "Application" -Source "SecurityAudit" -EventId $EventId -EntryType Information -Message ($LogEntry | ConvertTo-Json) -ErrorAction SilentlyContinue
    if ($Status -eq "FAILED") { Write-Host "🚨 SECURITY ALERT: $Action failed - $Details" -ForegroundColor Red }
}

Register-EventLog -LogName "Application" -Source "SecurityAudit" -ErrorAction SilentlyContinue

foreach ($OU in $SecurityOUs) {
    try {
        $ouName = ($OU -split ',' | Select-Object -First 1).Replace('OU=','')
        New-ADOrganizationalUnit -Path "OU=Asgard Technologies,DC=asgard,DC=local" -Name $ouName -ProtectedFromAccidentalDeletion $true
        Write-Host "✅ Created OU: $OU" -ForegroundColor Green
        Write-SecurityAuditLog -Action "Create Security OU" -Status "SUCCESS" -Details $OU
    }
    catch {
        Write-SecurityAuditLog -Action "Create Security OU" -Status "FAILED" -Details "OU: $OU - Error: $($_.Exception.Message)"
        Write-Warning "⚠️ Failed to create OU: $OU - Review security logs for details"
    }
}
```

#### **Step 1.3: Create Security Groups**

```powershell
# Create security-focused groups
$SecurityGroups = @{
    "SEC-Camera_Restricted" = "Users with restricted camera access"
    "SEC-USB_Blocked" = "Users with blocked USB device access"
    "SEC-PowerShell_Restricted" = "Users with restricted PowerShell execution"
    "SEC-Admin_Workstations" = "Administrative workstation access"
    "SEC-High_Privilege" = "High privilege users requiring enhanced security"
    "SEC-VPN_Access" = "VPN access authorization group"
    "SEC-Remote_Desktop" = "Remote desktop access authorization"
    "SEC-File_Server_Access" = "File server access permissions"
}

foreach ($GroupName in $SecurityGroups.Keys) {
    try {
        New-ADGroup -Name $GroupName -GroupScope DomainLocal -GroupCategory Security -Path "OU=Security_Groups,OU=Asgard Technologies,DC=asgard,DC=local" -Description $SecurityGroups[$GroupName]
        Write-Host "✅ Created security group: $GroupName" -ForegroundColor Green
    }
    catch {
        Write-Warning "Group may already exist: $GroupName"
    }
}
```

---

### **Phase 2: Camera & Microphone Security**

#### **Step 2.1: Create Camera Security GPO**

```powershell
# Create new GPO for camera security
Import-Module GroupPolicy

$GPOName = "ASGARD-Camera-Security"
try {
    New-GPO -Name $GPOName -Comment "Asgard Technologies - Camera and Microphone Security Controls"
    Write-Host "✅ Created GPO: $GPOName" -ForegroundColor Green
}
catch {
    Write-Warning "GPO may already exist: $GPOName"
}

# Configure camera access restrictions
Set-GPRegistryValue -Name $GPOName -Key "HKLM\SOFTWARE\Policies\Microsoft\Camera" -ValueName "AllowCamera" -Type DWord -Value 0
Set-GPRegistryValue -Name $GPOName -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" -ValueName "LetAppsAccessCamera" -Type DWord -Value 2
Set-GPRegistryValue -Name $GPOName -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" -ValueName "LetAppsAccessMicrophone" -Type DWord -Value 2

# Configure Windows Hello camera settings
Set-GPRegistryValue -Name $GPOName -Key "HKLM\SOFTWARE\Policies\Microsoft\PassportForWork" -ValueName "DisablePostLogonProvisioning" -Type DWord -Value 1

Write-Host "✅ Camera security policies configured" -ForegroundColor Green
```

#### **Step 2.2: Link Camera Security GPO**

```powershell
# Link to specific OUs for testing
$TargetOUs = @(
    "OU=Cybersecurity,OU=Departments,OU=Asgard Technologies,DC=asgard,DC=local",
    "OU=Research_Development,OU=Departments,OU=Asgard Technologies,DC=asgard,DC=local"
)

foreach ($OU in $TargetOUs) {
    try {
        New-GPLink -Name $GPOName -Target $OU
        Write-Host "✅ Linked $GPOName to $OU" -ForegroundColor Green
    }
    catch {
        Write-Warning "Failed to link to: $OU - Error: $($_.Exception.Message)"
    }
}
```

---

### **Phase 3: USB & Storage Control**

#### **Step 3.1: Create USB Security GPO**

```powershell
$GPOName = "ASGARD-USB-Control"
New-GPO -Name $GPOName -Comment "Asgard Technologies - USB and Removable Storage Security"

# Block removable storage devices
$USBRegPath = "HKLM\SOFTWARE\Policies\Microsoft\Windows\RemovableStorageDevices"

# Block USB storage devices
Set-GPRegistryValue -Name $GPOName -Key "$USBRegPath\{53f5630d-b6bf-11d0-94f2-00a0c91efb8b}" -ValueName "Deny_Read" -Type DWord -Value 1
Set-GPRegistryValue -Name $GPOName -Key "$USBRegPath\{53f5630d-b6bf-11d0-94f2-00a0c91efb8b}" -ValueName "Deny_Write" -Type DWord -Value 1
Set-GPRegistryValue -Name $GPOName -Key "$USBRegPath\{53f5630d-b6bf-11d0-94f2-00a0c91efb8b}" -ValueName "Deny_Execute" -Type DWord -Value 1

# Block CD/DVD devices
Set-GPRegistryValue -Name $GPOName -Key "$USBRegPath\{53f5630f-b6bf-11d0-94f2-00a0c91efb8b}" -ValueName "Deny_Read" -Type DWord -Value 1
Set-GPRegistryValue -Name $GPOName -Key "$USBRegPath\{53f5630f-b6bf-11d0-94f2-00a0c91efb8b}" -ValueName "Deny_Write" -Type DWord -Value 1

# Disable autorun/autoplay
Set-GPRegistryValue -Name $GPOName -Key "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -ValueName "NoDriveTypeAutoRun" -Type DWord -Value 255

Write-Host "✅ USB security policies configured" -ForegroundColor Green
```

#### **Step 3.2: Configure Device Installation Restrictions**

```powershell
# Prevent installation of removable devices
$DeviceRegPath = "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Restrictions"

Set-GPRegistryValue -Name $GPOName -Key $DeviceRegPath -ValueName "DenyRemovableDevices" -Type DWord -Value 1
Set-GPRegistryValue -Name $GPOName -Key $DeviceRegPath -ValueName "DenyUnspecified" -Type DWord -Value 1

# Create exception list for approved devices (modify as needed)
Set-GPRegistryValue -Name $GPOName -Key "$DeviceRegPath\AllowedDeviceClasses" -ValueName "1" -Type String -Value "{4d36e967-e325-11ce-bfc1-08002be10318}" # Disk drives

Write-Host "✅ Device installation restrictions configured" -ForegroundColor Green
```

---

### **Phase 4: Device & Peripheral Management**

#### **Step 4.1: Create Device Control GPO**

```powershell
$GPOName = "ASGARD-Device-Control"
New-GPO -Name $GPOName -Comment "Asgard Technologies - Device and Peripheral Management"

# Bluetooth restrictions
Set-GPRegistryValue -Name $GPOName -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\Bluetooth" -ValueName "AllowDiscoverableMode" -Type DWord -Value 0
Set-GPRegistryValue -Name $GPOName -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\Bluetooth" -ValueName "AllowAdvertising" -Type DWord -Value 0
Set-GPRegistryValue -Name $GPOName -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\Bluetooth" -ValueName "AllowPrepairing" -Type DWord -Value 0

# Printer restrictions
Set-GPRegistryValue -Name $GPOName -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Printers" -ValueName "DisableAddPrinter" -Type DWord -Value 1
Set-GPRegistryValue -Name $GPOName -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Printers" -ValueName "DisableWebPnPDownload" -Type DWord -Value 1

# External display restrictions
Set-GPRegistryValue -Name $GPOName -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\Connect" -ValueName "AllowProjectionToPC" -Type DWord -Value 0

Write-Host "✅ Device control policies configured" -ForegroundColor Green
```

---

### **Phase 5: Application Control & PowerShell Security**

#### **Step 5.1: Create Application Control GPO**

```powershell
$GPOName = "ASGARD-App-Control"
New-GPO -Name $GPOName -Comment "Asgard Technologies - Application Control and PowerShell Security"

# SECURE: Hardened PowerShell execution policy (AllSigned for production security)
Set-GPRegistryValue -Name $GPOName -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\PowerShell" -ValueName "EnableScripts" -Type DWord -Value 1
Set-GPRegistryValue -Name $GPOName -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\PowerShell" -ValueName "ExecutionPolicy" -Type String -Value "AllSigned"

# Enhanced PowerShell logging and transcription
Set-GPRegistryValue -Name $GPOName -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging" -ValueName "EnableModuleLogging" -Type DWord -Value 1
Set-GPRegistryValue -Name $GPOName -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -ValueName "EnableScriptBlockLogging" -Type DWord -Value 1
Set-GPRegistryValue -Name $GPOName -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -ValueName "EnableScriptBlockInvocationLogging" -Type DWord -Value 1
Set-GPRegistryValue -Name $GPOName -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription" -ValueName "EnableTranscripting" -Type DWord -Value 1
Set-GPRegistryValue -Name $GPOName -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription" -ValueName "OutputDirectory" -Type String -Value "C:\PSTranscripts"

# Disable insecure PowerShell v2
Set-GPRegistryValue -Name $GPOName -Key "HKLM\SOFTWARE\Microsoft\PowerShell\1\PowerShellEngine" -ValueName "PowerShellVersion" -Type String -Value "5.0"

# Windows Store restrictions
Set-GPRegistryValue -Name $GPOName -Key "HKLM\SOFTWARE\Policies\Microsoft\WindowsStore" -ValueName "DisableStoreApps" -Type DWord -Value 1

# Command Prompt restrictions
Set-GPRegistryValue -Name $GPOName -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" -ValueName "DisableCMD" -Type DWord -Value 1

Write-Host "✅ Application control policies configured" -ForegroundColor Green
```

#### **Step 5.2: Configure AppLocker (Optional)**

```powershell
# Enable AppLocker service
Set-GPRegistryValue -Name $GPOName -Key "HKLM\SYSTEM\CurrentControlSet\Services\AppIDSvc" -ValueName "Start" -Type DWord -Value 2

# Basic AppLocker rules (customize as needed)
# This requires more complex XML configuration - see Microsoft documentation
Write-Host "⚠️  AppLocker requires additional XML rule configuration" -ForegroundColor Yellow
```

---

### **Phase 6: Network Security Controls**

#### **Step 6.1: Create Network Security GPO**

```powershell
$GPOName = "ASGARD-Network-Security"
New-GPO -Name $GPOName -Comment "Asgard Technologies - Network Security Controls"

# SECURE: Advanced Windows Firewall with enhanced logging
Set-GPRegistryValue -Name $GPOName -Key "HKLM\SOFTWARE\Policies\Microsoft\WindowsFirewall\DomainProfile" -ValueName "EnableFirewall" -Type DWord -Value 1
Set-GPRegistryValue -Name $GPOName -Key "HKLM\SOFTWARE\Policies\Microsoft\WindowsFirewall\StandardProfile" -ValueName "EnableFirewall" -Type DWord -Value 1
Set-GPRegistryValue -Name $GPOName -Key "HKLM\SOFTWARE\Policies\Microsoft\WindowsFirewall\DomainProfile" -ValueName "DefaultInboundAction" -Type DWord -Value 1
Set-GPRegistryValue -Name $GPOName -Key "HKLM\SOFTWARE\Policies\Microsoft\WindowsFirewall\DomainProfile" -ValueName "LogAllowedConnections" -Type DWord -Value 1
Set-GPRegistryValue -Name $GPOName -Key "HKLM\SOFTWARE\Policies\Microsoft\WindowsFirewall\DomainProfile" -ValueName "LogDroppedPackets" -Type DWord -Value 1

# Enhanced RDP security hardening  
Set-GPRegistryValue -Name $GPOName -Key "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" -ValueName "fDenyTSConnections" -Type DWord -Value 0
Set-GPRegistryValue -Name $GPOName -Key "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -ValueName "UserAuthentication" -Type DWord -Value 1
Set-GPRegistryValue -Name $GPOName -Key "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -ValueName "SecurityLayer" -Type DWord -Value 2
Set-GPRegistryValue -Name $GPOName -Key "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -ValueName "MinEncryptionLevel" -Type DWord -Value 3

# Enhanced SMB security with encryption
Set-GPRegistryValue -Name $GPOName -Key "HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -ValueName "RequireSecuritySignature" -Type DWord -Value 1
Set-GPRegistryValue -Name $GPOName -Key "HKLM\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" -ValueName "RequireSecuritySignature" -Type DWord -Value 1
Set-GPRegistryValue -Name $GPOName -Key "HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -ValueName "EncryptSmb3Traffic" -Type DWord -Value 1
Set-GPRegistryValue -Name $GPOName -Key "HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -ValueName "RejectUnencryptedAccess" -Type DWord -Value 1

# Network access restrictions
Set-GPRegistryValue -Name $GPOName -Key "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" -ValueName "RestrictAnonymous" -Type DWord -Value 2
Set-GPRegistryValue -Name $GPOName -Key "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" -ValueName "NoLMHash" -Type DWord -Value 1

Write-Host "✅ Network security policies configured" -ForegroundColor Green
```

---

### **Phase 7: Data Protection & Privacy**

#### **Step 7.1: Create Privacy Control GPO**

```powershell
$GPOName = "ASGARD-Privacy-Control"
New-GPO -Name $GPOName -Comment "Asgard Technologies - Data Protection and Privacy Controls"

# Telemetry restrictions
Set-GPRegistryValue -Name $GPOName -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -ValueName "AllowTelemetry" -Type DWord -Value 1

# Cortana restrictions
Set-GPRegistryValue -Name $GPOName -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -ValueName "AllowCortana" -Type DWord -Value 0

# OneDrive restrictions
Set-GPRegistryValue -Name $GPOName -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\OneDrive" -ValueName "DisableFileSyncNGSC" -Type DWord -Value 1

# Location services
Set-GPRegistryValue -Name $GPOName -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" -ValueName "DisableLocation" -Type DWord -Value 1

# Windows Error Reporting
Set-GPRegistryValue -Name $GPOName -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting" -ValueName "Disabled" -Type DWord -Value 1

Write-Host "✅ Privacy control policies configured" -ForegroundColor Green
```

---

### **Phase 8: Personalization Controls**

#### **Step 8.1: Create Personalization GPO**

```powershell
$GPOName = "ASGARD-Personalization"
New-GPO -Name $GPOName -Comment "Asgard Technologies - Personalization and User Experience Controls"

# Desktop personalization restrictions
Set-GPRegistryValue -Name $GPOName -Key "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop" -ValueName "NoChangingWallPaper" -Type DWord -Value 1
Set-GPRegistryValue -Name $GPOName -Key "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -ValueName "NoDispBackgroundPage" -Type DWord -Value 1

# Start menu restrictions
Set-GPRegistryValue -Name $GPOName -Key "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -ValueName "NoChangeStartMenu" -Type DWord -Value 1
Set-GPRegistryValue -Name $GPOName -Key "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -ValueName "NoTaskGrouping" -Type DWord -Value 1

# Screen saver security
Set-GPRegistryValue -Name $GPOName -Key "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -ValueName "ScreenSaverIsSecure" -Type DWord -Value 1
Set-GPRegistryValue -Name $GPOName -Key "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -ValueName "ScreenSaveTimeOut" -Type String -Value "900"

Write-Host "✅ Personalization control policies configured" -ForegroundColor Green
```

---

## 🔗 Link All GPOs to Organizational Units

### **Apply Security Policies**

```powershell
# Define GPO to OU mappings for Asgard Technologies
$GPOLinks = @{
    "ASGARD-Camera-Security" = @(
        "OU=Cybersecurity,OU=Departments,OU=Asgard Technologies,DC=asgard,DC=local",
        "OU=Research_Development,OU=Departments,OU=Asgard Technologies,DC=asgard,DC=local"
    )
    "ASGARD-USB-Control" = @(
        "OU=Cybersecurity,OU=Departments,OU=Asgard Technologies,DC=asgard,DC=local",
        "OU=Finance_Admin,OU=Departments,OU=Asgard Technologies,DC=asgard,DC=local"
    )
    "ASGARD-Device-Control" = @(
        "OU=Departments,OU=Asgard Technologies,DC=asgard,DC=local"
    )
    "ASGARD-App-Control" = @(
        "OU=Workstations,OU=Asgard Technologies,DC=asgard,DC=local"
    )
    "ASGARD-Network-Security" = @(
        "DC=asgard,DC=local"
    )
    "ASGARD-Privacy-Control" = @(
        "OU=Workstations,OU=Asgard Technologies,DC=asgard,DC=local"
    )
    "ASGARD-Personalization" = @(
        "OU=Workstations,OU=Asgard Technologies,DC=asgard,DC=local"
    )
}

foreach ($GPO in $GPOLinks.Keys) {
    foreach ($OU in $GPOLinks[$GPO]) {
        try {
            New-GPLink -Name $GPO -Target $OU -LinkEnabled Yes
            Write-Host "✅ Linked $GPO to $OU" -ForegroundColor Green
        }
        catch {
            Write-Warning "Failed to link $GPO to $OU : $_"
        }
    }
}

# Force Group Policy update
Write-Host "🔄 Forcing Group Policy update on all systems..." -ForegroundColor Yellow
Invoke-Command -ComputerName (Get-ADComputer -Filter * | Select-Object -ExpandProperty Name) -ScriptBlock { gpupdate /force } -ErrorAction SilentlyContinue
```

---

## 🧪 Security Testing & Validation

### **Test 1: Camera Access Control**

```powershell
# Test on client workstations
# Run on affected workstations to verify camera restrictions

# Check camera policy
Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Camera" -Name "AllowCamera" -ErrorAction SilentlyContinue

# Verify app privacy settings
Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" -Name "LetAppsAccessCamera" -ErrorAction SilentlyContinue
```

### **Test 2: USB Device Restrictions**

```powershell
# Check USB device policies
$USBPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\RemovableStorageDevices\{53f5630d-b6bf-11d0-94f2-00a0c91efb8b}"
Get-ItemProperty -Path $USBPath -ErrorAction SilentlyContinue

# List currently connected USB devices
Get-CimInstance -ClassName Win32_PnPEntity | Where-Object { $_.PNPDeviceID -like "USB*" }
```

### **Test 3: Network Security Validation**

```powershell
# Check Windows Firewall status
Get-NetFirewallProfile | Format-Table Name, Enabled

# Verify SMB signing
Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -Name "RequireSecuritySignature"
```

---

## 📊 Security Audit & Reporting

### **Manual Security Audit Script**

```powershell
# Comprehensive security audit for Asgard Technologies
function Start-AsgardSecurityAudit {
    $AuditResults = @{
        CameraPolicy = $null
        USBPolicy = $null
        DeviceControl = $null
        NetworkSecurity = $null
        AppControl = $null
        PrivacyControl = $null
        SecurityScore = 0
        Recommendations = @()
        Timestamp = Get-Date
    }

    Write-Host "🔍 Starting Asgard Technologies Security Audit..." -ForegroundColor Cyan

    # Camera security audit
    try {
        $cameraReg = Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Camera" -ErrorAction SilentlyContinue
        $AuditResults.CameraPolicy = if ($cameraReg.AllowCamera -eq 0) { "Secured" } else { "Not Secured" }
        if ($AuditResults.CameraPolicy -eq "Secured") { $AuditResults.SecurityScore += 15 }
    }
    catch {
        $AuditResults.CameraPolicy = "Not Configured"
        $AuditResults.Recommendations += "Configure camera access restrictions"
    }

    # USB security audit
    try {
        $usbReg = Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\RemovableStorageDevices\{53f5630d-b6bf-11d0-94f2-00a0c91efb8b}" -ErrorAction SilentlyContinue
        $AuditResults.USBPolicy = if ($usbReg.Deny_Read -eq 1 -and $usbReg.Deny_Write -eq 1) { "Secured" } else { "Partially Secured" }
        if ($AuditResults.USBPolicy -eq "Secured") { $AuditResults.SecurityScore += 20 }
    }
    catch {
        $AuditResults.USBPolicy = "Not Configured"
        $AuditResults.Recommendations += "Configure USB device restrictions"
    }

    # Network security audit
    try {
        $firewallProfiles = Get-NetFirewallProfile
        $allEnabled = ($firewallProfiles | Where-Object { $_.Enabled -eq $false }).Count -eq 0
        $AuditResults.NetworkSecurity = if ($allEnabled) { "Secured" } else { "Not Secured" }
        if ($AuditResults.NetworkSecurity -eq "Secured") { $AuditResults.SecurityScore += 20 }
    }
    catch {
        $AuditResults.NetworkSecurity = "Unable to audit"
        $AuditResults.Recommendations += "Verify Windows Firewall configuration"
    }

    # Generate audit report
    $reportPath = "C:\Reports\AsgardSecurityAudit_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
    New-Item -Path "C:\Reports" -ItemType Directory -Force -ErrorAction SilentlyContinue

    $AuditResults | ConvertTo-Json -Depth 3 | Out-File -FilePath $reportPath

    Write-Host "✅ Security audit completed. Score: $($AuditResults.SecurityScore)/100" -ForegroundColor Green
    Write-Host "📄 Report saved to: $reportPath" -ForegroundColor Blue

    return $AuditResults
}

# Run the audit
Start-AsgardSecurityAudit
```

---

## 🚀 Deployment Scenarios

### **Scenario 1: High-Security Department (Cybersecurity)**

```powershell
# Apply all security controls to cybersecurity team
$TargetOU = "OU=Cybersecurity,OU=Departments,OU=Asgard Technologies,DC=asgard,DC=local"

$SecurityGPOs = @(
    "ASGARD-Camera-Security",
    "ASGARD-USB-Control",
    "ASGARD-Device-Control",
    "ASGARD-App-Control",
    "ASGARD-Network-Security",
    "ASGARD-Privacy-Control"
)

foreach ($GPO in $SecurityGPOs) {
    New-GPLink -Name $GPO -Target $TargetOU -LinkEnabled Yes
}
```

### **Scenario 2: R&D Environment (Research & Development)**

```powershell
# Selective security for development environment
$TargetOU = "OU=Research_Development,OU=Departments,OU=Asgard Technologies,DC=asgard,DC=local"

# Apply only essential security controls to maintain development flexibility
$DeveloperGPOs = @(
    "ASGARD-Camera-Security",
    "ASGARD-Network-Security",
    "ASGARD-Privacy-Control"
)

foreach ($GPO in $DeveloperGPOs) {
    New-GPLink -Name $GPO -Target $TargetOU -LinkEnabled Yes
}
```

### **Scenario 3: Executive Level (IT Operations)**

```powershell
# Enhanced security for executive users
$ExecutiveOU = "OU=IT_Operations,OU=Departments,OU=Asgard Technologies,DC=asgard,DC=local"

# Create executive-specific security group
New-ADGroup -Name "SEC-Executive-Enhanced" -GroupScope DomainLocal -GroupCategory Security -Path "OU=Security_Groups,OU=Asgard Technologies,DC=asgard,DC=local"

# Add executives to enhanced security group
$Executives = @("odin.allfather", "frigg.queen", "thor.thunderer")
foreach ($Executive in $Executives) {
    Add-ADGroupMember -Identity "SEC-Executive-Enhanced" -Members $Executive
}
```

---

## 🛠️ Troubleshooting

### **Common Issues & Solutions**

#### **Issue 1: Group Policy Not Applying**

```powershell
# Force Group Policy refresh
gpupdate /force

# Check Group Policy application
gpresult /r

# Verify OU structure
Get-ADOrganizationalUnit -Filter * | Select-Object Name, DistinguishedName
```

#### **Issue 2: Camera Still Accessible**

```powershell
# Check registry settings
Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Camera"

# Verify GPO linkage
Get-GPInheritance -Target "OU=TargetOU,DC=asgard,DC=local"

# Test specific user
gpresult /user username /r
```

#### **Issue 3: USB Devices Not Blocked**

```powershell
# Check device installation policies
Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Restrictions"

# Verify removable storage policies
Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\RemovableStorageDevices\*"
```

---

## 📈 Security Scoring

### **Asgard Security Score Calculation**

- **Camera/Microphone Control**: 25 points
- **USB/Storage Security**: 30 points
- **Device Management**: 20 points
- **Network Security**: 25 points
- **Application Control**: 20 points
- **Privacy Controls**: 15 points
- **Personalization Restrictions**: 10 points

**Total Maximum Score**: 145 points

### **Security Maturity Levels**

- **130-145 points (90-100%)**: 🛡️ **Valhalla Protection** - Asgardian-level security
- **115-129 points (80-89%)**: ⚡ **Thor's Shield** - Strong security posture
- **100-114 points (70-79%)**: 🏰 **Fortress Guard** - Good security foundation
- **85-99 points (60-69%)**: ⚠️ **Midgard Risk** - Requires improvement
- **Below 85 points (60%)**: 🚨 **Ragnarok Warning** - Critical security gaps

---

## 🎯 Testing Scenarios

### **Scenario 1: Device Control Testing**

1. **Camera Access**: Try using camera in various applications
2. **USB Devices**: Plug in USB drives, external storage
3. **Bluetooth**: Attempt to pair Bluetooth devices
4. **Printer Access**: Try adding new printers

### **Scenario 2: Application Restrictions**

1. **Software Installation**: Try installing unauthorized software
2. **PowerShell Execution**: Run scripts with different execution policies
3. **Windows Store**: Access Windows Store and try downloading apps
4. **Web Browsing**: Test browser security restrictions

### **Scenario 3: Personalization Limits**

1. **Desktop Changes**: Try changing wallpaper, themes
2. **Start Menu**: Modify Start menu layout and shortcuts
3. **Taskbar**: Customize taskbar settings
4. **Screen Saver**: Change screen saver settings

### **Scenario 4: Network Security**

1. **Remote Desktop**: Test RDP access restrictions
2. **File Sharing**: Try accessing network shares
3. **Firewall**: Verify firewall rule enforcement
4. **WiFi**: Test automatic connection restrictions

---

## 🎯 Next Steps

### **Phase 1: Complete Basic Deployment**

1. ✅ Configure domain security foundation
2. ✅ Deploy camera and microphone controls
3. ✅ Implement USB and storage restrictions
4. ✅ Set up device management policies

### **Phase 2: Enhanced Security**

1. Configure advanced application control (AppLocker)
2. Implement certificate-based authentication
3. Deploy advanced threat protection
4. Set up security monitoring and alerting

### **Phase 3: Compliance & Monitoring**

1. Regular security audits and assessments
2. User training and awareness programs
3. Incident response procedures
4. Continuous security improvements

---

## 📚 Additional Resources

### **Key Files & Scripts**

- **Advanced Security Audit**: `Scripts\AdvancedSecurityAudit.ps1`
- **GPO Management**: `Scripts\AdvancedGroupPolicyManager.ps1`
- **Deployment Script**: `Demo\Asgard\Scripts\Deploy-AdvancedSecurityDemo.ps1`

### **Documentation References**

- **Full Setup Guide**: `Demo\Asgard\MANUAL_SETUP_ASGARD.md`
- **Cheat Sheet**: `Demo\Asgard\CHEATSHEET.md`
- **Demo Overview**: `Demo\Asgard\README.md`

---

**🏰 May the power of Asgard protect your digital realm! 🏰**

_This guide provides comprehensive manual security configuration for the Asgard Technologies demo environment. Each step can be customized based on your specific security requirements and organizational policies._
