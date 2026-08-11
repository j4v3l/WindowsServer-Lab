# 🎛️ Group Policy Objects (GPOs) in Active Directory

## 🎯 What You'll Learn

- What Group Policy Objects are and why they're important
- How to create and manage GPOs
- How to link GPOs to OUs
- Common GPO settings and best practices

## 📋 Prerequisites

- A working Windows Server domain (from [01_Setup_Lab_Environment.md](01_Setup_Lab_Environment.md))
- Basic understanding of OUs and groups (from [02_Manage_Users_Computers_AD.md](02_Manage_Users_Computers_AD.md) and [03_AD_Groups_Management.md](03_AD_Groups_Management.md))

**EXECUTION CONTEXT: All Group Policy operations run INSIDE Windows Server VMs (Domain Controllers)**  
**ACCESS METHOD: RDP, Console, or PowerShell Direct to Domain Controller VM**  
**PREREQUISITES: Domain Administrator rights, Group Policy Management Tools**

## 🔍 Understanding Group Policy

### What are GPOs?

Think of Group Policy Objects like rules for your network:

- They control how computers and users behave
- They help enforce security settings
- They can automate software installation
- They can customize the user experience

### Types of GPOs

1. **Computer Configuration**

   - Applies to computers regardless of who logs in
   - Examples:
     - Security settings
     - Software installation
     - Windows updates

2. **User Configuration**
   - Applies to users regardless of which computer they use
   - Examples:
     - Desktop settings
     - Start menu layout
     - Printer connections

## 🛠️ Creating and Managing GPOs

### Step 1: Open Group Policy Management

1. Press `Windows + R`
2. Type `gpmc.msc`
3. Press Enter

### Step 2: Create a New GPO

1. Right-click "Group Policy Objects"
2. Select "New"
3. Enter a name (e.g., "IT_Desktop_Settings")
4. Click OK

### Step 3: Edit the GPO

1. Right-click the new GPO
2. Select "Edit"
3. Navigate to desired settings:

   ```
   Computer Configuration
   └── Policies
       ├── Windows Settings
       │   ├── Security Settings
       │   └── Scripts
       └── Administrative Templates
           ├── Windows Components
           └── System
   ```

## 📝 Example: Common GPO Settings

### 1. Password Policy

1. Navigate to:

   ```
   Computer Configuration
   └── Policies
       └── Windows Settings
           └── Security Settings
               └── Account Policies
                   └── Password Policy
   ```

2. Configure:

   ```
   Minimum password length: 12
   Password complexity: Enabled
   Maximum password age: 90 days
   ```

### 2. Desktop Settings

1. Navigate to:

   ```
   User Configuration
   └── Policies
       └── Administrative Templates
           └── Desktop
   ```

2. Configure:

   ```
   Remove Recycle Bin: Disabled
   Hide Desktop Icons: Enabled
   ```

### 3. Security Settings

1. Navigate to:

   ```
   Computer Configuration
   └── Policies
       └── Windows Settings
           └── Security Settings
   ```

2. Configure:

   ```
   Account lockout threshold: 5 attempts
   Account lockout duration: 30 minutes
   ```

## 🔗 Linking GPOs to OUs

### Step 1: Link a GPO

1. Right-click the target OU
2. Select "Link an Existing GPO"
3. Choose your GPO
4. Click OK

### Step 2: Set Link Order

1. Select the OU
2. Go to "Linked Group Policy Objects" tab
3. Use "Move Up" and "Move Down" to set priority
   - Higher in list = higher priority

### Step 3: Set Inheritance

1. Right-click the OU
2. Select "Block Inheritance" if needed
   - This prevents GPOs from parent OUs

## 📋 Best Practices

### GPO Organization

1. Use clear naming conventions:

   ```
   GPO_IT_Security
   GPO_HR_Desktop
   GPO_Sales_Printers
   ```

2. Create a logical structure:

   ```
   Group Policy Objects
   ├── Security
   │   ├── Password Policy
   │   └── Account Lockout
   ├── Desktop
   │   ├── IT Settings
   │   └── HR Settings
   └── Software
       ├── Office Settings
       └── Browser Settings
   ```

### Testing GPOs

1. Create a test OU
2. Link GPO to test OU
3. Add test computer/user
4. Verify settings apply correctly
5. Move to production if successful

## 🎯 Common Tasks

### Update a GPO

1. Right-click GPO → Edit
2. Make changes
3. Close Group Policy Editor
   - Changes save automatically

### Disable a GPO

1. Right-click GPO → GPO Status
2. Choose:
   - "All settings disabled"
   - "Computer configuration disabled"
   - "User configuration disabled"

### Remove a GPO Link

1. Select the OU
2. Go to "Linked Group Policy Objects"
3. Right-click GPO → Delete
4. Choose "Remove the link"

## ❓ Troubleshooting

### GPO Not Applying?

1. Check if GPO is linked to correct OU
2. Verify inheritance is not blocked
3. Check if GPO is enabled
4. Look for conflicting GPOs
5. Run `gpupdate /force` on client

### GPO Takes Too Long?

1. Check GPO size
2. Look for slow network links
3. Verify DNS is working
4. Check for replication issues

## 📚 Next Steps

- Need help? Check [05_Troubleshooting.md](05_Troubleshooting.md)
- Review previous guides:
  - [01_Setup_Lab_Environment.md](01_Setup_Lab_Environment.md)
  - [02_Manage_Users_Computers_AD.md](02_Manage_Users_Computers_AD.md)
  - [03_AD_Groups_Management.md](03_AD_Groups_Management.md)

# 🛡️ Advanced Group Policy Objects (GPOs) - Complete Feature Guide

## 🎯 What You'll Learn

- Comprehensive Group Policy management including camera, USB, and device controls
- Advanced security settings and personalization policies
- Application control and network security policies
- Modern privacy and data protection settings
- How to audit and monitor policy effectiveness

## 📋 Prerequisites

- A working Windows Server domain (from [01_Setup_Lab_Environment.md](01_Setup_Lab_Environment.md))
- Basic understanding of OUs and groups (from [02_Manage_Users_Computers_AD.md](02_Manage_Users_Computers_AD.md) and [03_AD_Groups_Management.md](03_AD_Groups_Management.md))
- Administrative access to domain controllers

## 🔍 Understanding Advanced Group Policy

### What are Advanced GPOs?

Modern Group Policy Objects go far beyond basic settings and now include:

- **Device Control**: Camera, microphone, USB, Bluetooth, and peripheral management
- **Privacy Protection**: Telemetry, OneDrive, Cortana, and data collection controls
- **Security Hardening**: Application control, PowerShell restrictions, and network security
- **User Experience**: Personalization, Windows Store, and interface customization
- **Compliance**: Audit logging, monitoring, and regulatory compliance features

### GPO Categories Overview

1. **Security Policies**

   - Camera and microphone access controls
   - USB and removable storage restrictions
   - Device installation policies
   - Windows Defender and BitLocker settings

2. **Personalization Policies**

   - Desktop background and theme controls
   - Start menu and taskbar customization
   - Screen saver and power management
   - User interface restrictions

3. **Device Control Policies**

   - Printer and fax management
   - CD/DVD and optical drive controls
   - Network adapter restrictions
   - External display policies

4. **Application Control Policies**

   - Software installation restrictions
   - Windows Store management
   - PowerShell execution policies
   - Web browser security settings

5. **Network Security Policies**

   - Firewall configuration
   - Remote access controls
   - VPN and connection management
   - SMB signing and encryption

6. **Data Protection Policies**
   - File and folder security
   - Cloud service controls
   - Telemetry and privacy settings
   - Windows Error Reporting

## 🚀 Quick Deployment with Advanced GPO Manager

### Step 1: Run the Advanced GPO Manager

```powershell
# Navigate to Scripts directory
cd C:\WindowsServer-Lab\Scripts

# Run the Advanced Group Policy Manager
.\Server\AdvancedGroupPolicyManager.ps1
```

### Step 2: Choose Your Policy Categories

The interactive menu offers these options:

1. **Deploy Security Policies** - Camera, USB, Device Controls
2. **Deploy Personalization Policies** - Desktop, Start Menu
3. **Deploy Device Control Policies** - Printers, Storage
4. **Deploy Application Control Policies** - Software, Store
5. **Deploy Network Security Policies** - Firewall, Remote Access
6. **Deploy Data Protection Policies** - Privacy, Cloud
7. **Deploy ALL Policies** - Complete security suite

### Step 3: Link to Organizational Units

```powershell
# Example: Deploy security policies to specific OUs
Deploy-AllAdvancedGPOs -Categories @("Security") -OUMappings @{
    "Security" = "OU=IT Department,DC=domain,DC=com"
}
```

## 🎥 Camera and Microphone Control

### Camera Access Policies

**Computer Configuration Path:**

```
Computer Configuration > Administrative Templates > Windows Components > Camera
```

**Key Settings:**

- `Allow Use of Camera`: Disabled
- `Allow access to camera on lock screen`: Disabled
- `Allow camera access for Microsoft Store apps`: Configurable

**User Configuration Path:**

```
User Configuration > Administrative Templates > Windows Components > Camera
```

### Microphone Access Policies

**Computer Configuration Path:**

```
Computer Configuration > Administrative Templates > Windows Components > Microphone
```

**Key Settings:**

- `Allow applications to access microphone`: Disabled
- `Allow desktop apps to access microphone`: Configurable

### Registry Implementation

```powershell
# Camera Control Registry Keys
$cameraRegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Camera"
New-Item -Path $cameraRegPath -Force
Set-ItemProperty -Path $cameraRegPath -Name "AllowCamera" -Value 0

# Microphone Control Registry Keys
$micRegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy"
New-Item -Path $micRegPath -Force
Set-ItemProperty -Path $micRegPath -Name "LetAppsAccessMicrophone" -Value 2
```

## 🔌 USB and Removable Storage Control

### Removable Storage Access Policies

**Computer Configuration Path:**

```
Computer Configuration > Administrative Templates > System > Removable Storage Access
```

**Key Policies:**

- `All Removable Storage classes: Deny all access`: Enabled
- `Removable Disks: Deny read access`: Enabled
- `Removable Disks: Deny write access`: Enabled
- `Removable Disks: Deny execute access`: Enabled
- `CD and DVD: Deny write access`: Enabled

### USB Device Installation Policies

**Computer Configuration Path:**

```
Computer Configuration > Administrative Templates > System > Device Installation > Device Installation Restrictions
```

**Key Settings:**

- `Prevent installation of removable devices`: Enabled
- `Display a custom message when installation is prevented by policy`: Enabled
- `Allow administrators to override Device Installation Restriction policies`: Configurable

### Registry Implementation

```powershell
# USB Storage Control
$usbRegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\RemovableStorageDevices"
$guidRemovable = "{53f5630d-b6bf-11d0-94f2-00a0c91efb8b}"

New-Item -Path "$usbRegPath\$guidRemovable" -Force
Set-ItemProperty -Path "$usbRegPath\$guidRemovable" -Name "Deny_Read" -Value 1
Set-ItemProperty -Path "$usbRegPath\$guidRemovable" -Name "Deny_Write" -Value 1
Set-ItemProperty -Path "$usbRegPath\$guidRemovable" -Name "Deny_Execute" -Value 1

# Device Installation Restrictions
$deviceRegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Restrictions"
New-Item -Path $deviceRegPath -Force
Set-ItemProperty -Path $deviceRegPath -Name "DenyRemovableDevices" -Value 1
```

## 🖥️ Device and Peripheral Control

### Bluetooth Management

**Computer Configuration Path:**

```
Computer Configuration > Administrative Templates > Network > Bluetooth
```

**Key Settings:**

- `Turn off Bluetooth`: Enabled
- `Allow advertising`: Disabled
- `Allow discoverable mode`: Disabled

### Printer Management

**User Configuration Path:**

```
User Configuration > Administrative Templates > Control Panel > Printers
```

**Computer Configuration Path:**

```
Computer Configuration > Administrative Templates > Printers
```

**Key Policies:**

- `Prevent addition of printers`: Configurable
- `Point and Print Restrictions`: Enabled
- `Allow Print Spooler to accept client connections`: Enabled

### Network Adapter Control

```powershell
# Disable WiFi auto-connect
$wifiRegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WlanSvc"
New-Item -Path $wifiRegPath -Force
Set-ItemProperty -Path $wifiRegPath -Name "AllowAutoConnectToWiFiSenseHotspots" -Value 0
```

## 🎨 Personalization and User Experience

### Desktop Personalization

**User Configuration Path:**

```
User Configuration > Administrative Templates > Control Panel > Personalization
```

**Available Controls:**

- `Prevent changing desktop background`: Configurable
- `Prevent changing theme`: Configurable
- `Prevent changing screen saver`: Configurable
- `Screen saver timeout`: Enabled (configurable time)
- `Password protect the screen saver`: Enabled

### Start Menu and Taskbar

**User Configuration Path:**

```
User Configuration > Administrative Templates > Start Menu and Taskbar
```

**Key Settings:**

- `Remove user's folders from the Start Menu`: Configurable
- `Remove frequent programs list from the Start Menu`: Configurable
- `Clear the recent documents list on exit`: Enabled

### Windows Store Control

**Computer Configuration Path:**

```
Computer Configuration > Administrative Templates > Windows Components > Store
```

**User Configuration Path:**

```
User Configuration > Administrative Templates > Windows Components > Store
```

**Key Policies:**

- `Turn off the Store application`: Configurable
- `Only display the private store within the Microsoft Store`: Configurable
- `Turn off Automatic Download and Install of updates`: Configurable

## 📱 Application and Software Control

### PowerShell Security

**Computer Configuration Path:**

```
Computer Configuration > Administrative Templates > Windows Components > Windows PowerShell
```

**Critical Settings:**

- `Turn on Script Execution`: Enabled (set to AllSigned or Restricted)
- `Turn on PowerShell Script Block Logging`: Enabled
- `Turn on PowerShell Transcription`: Enabled

### Software Installation Control

**Computer Configuration Path:**

```
Computer Configuration > Administrative Templates > Windows Components > Windows Installer
```

**Key Policies:**

- `Always install with elevated privileges`: Disabled
- `Prohibit rollback`: Configurable
- `Turn off Windows Installer RDS Compatibility`: Configurable

### AppLocker Policies

```powershell
# Example AppLocker policy creation
New-AppLockerPolicy -RuleType Publisher -User "Everyone" -RuleNamePrefix "Allow-Microsoft" -PublisherCondition "O=MICROSOFT CORPORATION*"
```

## 🌐 Network Security and Communication

### Windows Firewall Configuration

**Computer Configuration Path:**

```
Computer Configuration > Administrative Templates > Network > Network Connections > Windows Firewall
```

**Profile Settings:**

- `Domain Profile > Windows Firewall: Protect all network connections`: Enabled
- `Standard Profile > Windows Firewall: Protect all network connections`: Enabled
- `Domain Profile > Windows Firewall: Do not allow exceptions`: Configurable

### Remote Desktop Security

**Computer Configuration Path:**

```
Computer Configuration > Administrative Templates > Windows Components > Remote Desktop Services
```

**Key Controls:**

- `Allow users to connect remotely using Remote Desktop Services`: Disabled (if not needed)
- `Require user authentication for remote connections by using Network Level Authentication`: Enabled
- `Set client connection encryption level`: Enabled (High Level)

### SMB Security

```powershell
# Enable SMB signing
$smbRegPath = "HKLM:\SYSTEM\CurrentControlSet\Services\lanmanworkstation\parameters"
Set-ItemProperty -Path $smbRegPath -Name "RequireSecuritySignature" -Value 1

$smbServerRegPath = "HKLM:\SYSTEM\CurrentControlSet\Services\lanmanserver\parameters"
Set-ItemProperty -Path $smbServerRegPath -Name "RequireSecuritySignature" -Value 1
```

## 🔒 Data Protection and Privacy

### Telemetry and Data Collection

**Computer Configuration Path:**

```
Computer Configuration > Administrative Templates > Windows Components > Data Collection and Preview Builds
```

**Privacy Settings:**

- `Allow Telemetry`: Enabled (set to Security level for enterprises)
- `Disable pre-release features or settings`: Enabled
- `Do not show feedback notifications`: Enabled

### OneDrive Control

**Computer Configuration Path:**

```
Computer Configuration > Administrative Templates > Windows Components > OneDrive
```

**User Configuration Path:**

```
User Configuration > Administrative Templates > Windows Components > OneDrive
```

**Key Policies:**

- `Prevent the usage of OneDrive for file storage`: Configurable
- `Save documents to OneDrive by default`: Disabled

### Cortana and Search

**Computer Configuration Path:**

```
Computer Configuration > Administrative Templates > Windows Components > Search
```

**Privacy Controls:**

- `Allow Cortana`: Disabled
- `Allow Cortana above lock screen`: Disabled
- `Allow search and Cortana to use location`: Disabled

## 📊 Monitoring and Auditing

### Security Audit Script

Run comprehensive security audits with the enhanced audit script:

```powershell
# Run advanced security audit
.\Server\AdvancedSecurityAudit.ps1

# Quick security check
Start-QuickSecurityCheck

# Generate comprehensive report
Get-AdvancedSecurityReport
```

### GPO Reporting

```powershell
# Generate comprehensive GPO report
Get-AdvancedGPOReport

# Backup all GPOs with metadata
Backup-AdvancedGPOs
```

## 🎯 Best Practices and Implementation Guide

### 1. Phased Deployment Strategy

**Phase 1: Security Essentials**

```powershell
Deploy-AllAdvancedGPOs -Categories @("Security", "NetworkSecurity")
```

**Phase 2: Device Controls**

```powershell
Deploy-AllAdvancedGPOs -Categories @("DeviceControl", "ApplicationControl")
```

**Phase 3: User Experience**

```powershell
Deploy-AllAdvancedGPOs -Categories @("Personalization", "DataProtection")
```

### 2. Testing and Validation

1. **Create Test OU Structure**

   ```
   Domain Root
   ├── Test-GPO
   │   ├── Test-Computers
   │   └── Test-Users
   ```

2. **Deploy to Test Environment First**

   ```powershell
   Deploy-AllAdvancedGPOs -Categories @("Security") -OUMappings @{
       "Security" = "OU=Test-Computers,OU=Test-GPO,DC=domain,DC=com"
   }
   ```

3. **Validate Policy Application**

   ```powershell
   # Check policy application
   gpresult /h C:\Reports\GPResult.html

   # Run security audit
   Get-AdvancedSecurityReport
   ```

### 3. Organizational Unit Mapping

```powershell
# Example OU mapping for different departments
$ouMappings = @{
    "Security" = "OU=IT Department,DC=domain,DC=com"
    "DeviceControl" = "OU=General Users,DC=domain,DC=com"
    "ApplicationControl" = "OU=Restricted Users,DC=domain,DC=com"
    "Personalization" = "OU=Executive,DC=domain,DC=com"
    "NetworkSecurity" = "OU=Servers,DC=domain,DC=com"
    "DataProtection" = "OU=Finance,DC=domain,DC=com"
}

Deploy-AllAdvancedGPOs -OUMappings $ouMappings
```

### 4. Regular Maintenance

```powershell
# Weekly security audit
Get-AdvancedSecurityReport

# Monthly GPO backup
Backup-AdvancedGPOs

# Quarterly policy review
Get-AdvancedGPOReport
```

## 🚨 Troubleshooting Common Issues

### Camera/Microphone Not Blocking

1. **Check Registry Settings**

   ```powershell
   Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Camera"
   ```

2. **Verify GPO Application**

   ```powershell
   gpresult /r
   ```

3. **Force Policy Update**

   ```powershell
   gpupdate /force
   ```

### USB Devices Still Accessible

1. **Check Device Installation Policies**

   ```powershell
   Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Restrictions"
   ```

2. **Verify Removable Storage Settings**

   ```powershell
   $usbPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\RemovableStorageDevices\{53f5630d-b6bf-11d0-94f2-00a0c91efb8b}"
   Get-ItemProperty -Path $usbPath
   ```

### Application Control Not Working

1. **Check PowerShell Execution Policy**

   ```powershell
   Get-ExecutionPolicy -List
   ```

2. **Verify AppLocker Service**

   ```powershell
   Get-Service -Name "AppIDSvc"
   Start-Service -Name "AppIDSvc"
   ```

## 📈 Security Score and Compliance

The Advanced Security Audit provides a comprehensive security score based on:

- **Camera/Microphone Security**: 40 points maximum
- **USB/Storage Security**: 50 points maximum
- **Device Control**: 50 points maximum
- **Personalization/Privacy**: 45 points maximum
- **Application Control**: 70 points maximum
- **Network Security**: 40 points maximum

**Total Maximum Score**: 295 points

### Security Levels

- **90-100%**: Excellent security posture
- **75-89%**: Good security with minor improvements needed
- **50-74%**: Fair security requiring attention
- **Below 50%**: Poor security requiring immediate action

## 🔧 Advanced Configuration Examples

### Custom Camera Policy for Specific Applications

```powershell
# Allow camera access only for approved applications
$cameraRegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy"
New-Item -Path $cameraRegPath -Force

# Block camera for all apps except specified ones
Set-ItemProperty -Path $cameraRegPath -Name "LetAppsAccessCamera" -Value 2

# Create exceptions for approved applications
$approvedApps = @("Microsoft.SkypeApp", "Microsoft.WindowsCamera")
foreach ($app in $approvedApps) {
    Set-ItemProperty -Path $cameraRegPath -Name "LetAppsAccessCamera_UserInControlOfTheseApps" -Value $app
}
```

### Granular USB Control by Device Type

```powershell
# Control specific USB device classes
$deviceClasses = @{
    "CD_DVD" = "{53f56308-b6bf-11d0-94f2-00a0c91efb8b}"
    "Removable_Disks" = "{53f5630d-b6bf-11d0-94f2-00a0c91efb8b}"
    "Tape_Drives" = "{53f56309-b6bf-11d0-94f2-00a0c91efb8b}"
    "Floppy_Drives" = "{53f5630a-b6bf-11d0-94f2-00a0c91efb8b}"
}

$baseRegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\RemovableStorageDevices"

foreach ($deviceType in $deviceClasses.GetEnumerator()) {
    $deviceRegPath = "$baseRegPath\$($deviceType.Value)"
    New-Item -Path $deviceRegPath -Force

    # Deny write but allow read for CD/DVD
    if ($deviceType.Key -eq "CD_DVD") {
        Set-ItemProperty -Path $deviceRegPath -Name "Deny_Write" -Value 1
    }
    # Deny all access for removable disks
    elseif ($deviceType.Key -eq "Removable_Disks") {
        Set-ItemProperty -Path $deviceRegPath -Name "Deny_Read" -Value 1
        Set-ItemProperty -Path $deviceRegPath -Name "Deny_Write" -Value 1
        Set-ItemProperty -Path $deviceRegPath -Name "Deny_Execute" -Value 1
    }
}
```

## 📚 Additional Resources

### Microsoft Documentation

- [Group Policy Administrative Templates](https://docs.microsoft.com/en-us/windows/security/threat-protection/security-policy-settings/security-policy-settings)
- [Windows Security Baselines](https://docs.microsoft.com/en-us/windows/security/threat-protection/windows-security-baselines)
- [AppLocker and App Control guidance](https://learn.microsoft.com/en-us/windows/security/application-security/application-control/app-control-for-business/applocker/applocker-overview)

### Compliance Frameworks

- **NIST Cybersecurity Framework**
- **CIS Controls**
- **ISO 27001/27002**
- **GDPR Privacy Requirements**

### PowerShell Resources

- [GroupPolicy module reference](https://learn.microsoft.com/en-us/powershell/module/grouppolicy/)
- [PowerShell security features](https://learn.microsoft.com/en-us/powershell/scripting/security/security-features)

---

This comprehensive guide covers all aspects of modern Group Policy management with the enhanced features now available in the Windows Server Lab environment. Use the provided scripts and examples to implement robust security controls tailored to your organization's needs.
