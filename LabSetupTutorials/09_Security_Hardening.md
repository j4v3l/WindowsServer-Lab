# 🔒 Windows Server Security Hardening Guide

## 🎯 What You'll Learn

- Server security baseline configuration
- Advanced security features
- Security monitoring and auditing
- Compliance and best practices

## 📋 Prerequisites

- Working Windows Server environment
- Administrative access
- Basic understanding of security concepts
- Completed previous guides

## 🔐 Security Baseline Configuration

### 1. Windows Security Center

1. **Enable Windows Defender**

   ```powershell
   Set-MpPreference -DisableRealtimeMonitoring $false
   Set-MpPreference -DisableIOAVProtection $false
   ```

2. **Configure Firewall**

   ```powershell
   # Enable Windows Firewall
   Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True

   # Block all inbound by default
   Set-NetFirewallProfile -DefaultInboundAction Block
   ```

### 2. Account Security

1. **Password Policy**

   ```powershell
   Set-ADDefaultDomainPasswordPolicy -MinPasswordLength 12 `
                                    -ComplexityEnabled $true `
                                    -MaxPasswordAge 90 `
                                    -MinPasswordAge 1 `
                                    -PasswordHistoryCount 24
   ```

2. **Account Lockout**

   ```powershell
   Set-ADDefaultDomainPasswordPolicy -LockoutThreshold 5 `
                                    -LockoutDuration 30 `
                                    -LockoutObservationWindow 30
   ```

3. **Administrative Accounts**

   ```powershell
   # Create separate admin accounts with secure password prompt
   $AdminPassword = Read-Host -AsSecureString -Prompt "Enter secure password for admin account"

   New-ADUser -Name "Admin_John" `
              -SamAccountName "admin.john" `
              -UserPrincipalName "admin.john@domain.com" `
              -AccountPassword $AdminPassword `
              -Enabled $true `
              -ChangePasswordAtLogon $true
   ```

   **Security Benefits:**

   - ✅ No hardcoded passwords in security configurations
   - ✅ Secure password entry for administrative accounts
   - ✅ Forces password change on first login

## 🛡️ Advanced Security Features

### 1. BitLocker Encryption

1. **Enable BitLocker**

   ```powershell
   Install-WindowsFeature -Name BitLocker
   Enable-BitLocker -MountPoint "C:" -EncryptionMethod Aes256
   ```

2. **Configure Recovery Options**

   ```powershell
   Add-BitLockerKeyProtector -MountPoint "C:" -RecoveryPasswordProtector
   Backup-BitLockerKeyProtector -MountPoint "C:" -Path "E:\BitLockerRecovery"
   ```

### 2. Windows Defender Advanced Threat Protection

1. **Enable ATP**

   ```powershell
   Set-MpPreference -DisableRealtimeMonitoring $false
   Set-MpPreference -DisableBehaviorMonitoring $false
   Set-MpPreference -DisableBlockAtFirstSeen $false
   ```

2. **Configure Exclusions**

   ```powershell
   Add-MpPreference -ExclusionPath "C:\Program Files\CustomApp"
   Add-MpPreference -ExclusionProcess "CustomProcess.exe"
   ```

### 3. Just Enough Administration (JEA)

1. **Create JEA Session Configuration**

   ```powershell
   New-PSSessionConfigurationFile -Path "C:\JEA\Maintenance.pssc" `
                                -SessionType RestrictedRemoteServer `
                                -RunAsVirtualAccount
   ```

2. **Register JEA Configuration**

   ```powershell
   Register-PSSessionConfiguration -Name "Maintenance" `
                                 -Path "C:\JEA\Maintenance.pssc"
   ```

## 📊 Security Monitoring

### 1. Advanced Audit Policy

1. **Configure Audit Policies**

   ```powershell
   auditpol /set /category:* /success:enable /failure:enable
   ```

2. **Enable Detailed Auditing**

   ```powershell
   # Enable object access auditing
   auditpol /set /subcategory:"Object Access" /success:enable /failure:enable

   # Enable account management auditing
   auditpol /set /subcategory:"Account Management" /success:enable /failure:enable
   ```

### 2. Security Log Analysis

1. **Configure Log Retention**

   ```powershell
   wevtutil sl Security /ms:1024000
   wevtutil sl Application /ms:1024000
   wevtutil sl System /ms:1024000
   ```

2. **Export Security Logs**

   ```powershell
   Get-EventLog -LogName Security -Newest 1000 |
   Export-Csv -Path "C:\Logs\SecurityAudit.csv"
   ```

## 🔍 Security Assessment

### 1. Security Compliance Manager

1. **Download Baselines**

   - Microsoft Security Compliance Toolkit
   - Industry-specific baselines
   - Custom security policies

2. **Apply Baselines**

   ```powershell
   # Import security policy
   Import-GPO -BackupId "GUID" -TargetName "Security Baseline"
   ```

### 2. Security Scanning

1. **Windows Defender Scan**

   ```powershell
   Start-MpScan -ScanType FullScan
   ```

2. **Vulnerability Assessment**

   ```powershell
   # Install Windows Assessment and Deployment Kit
   Add-WindowsFeature -Name Windows-Server-Backup
   ```

## 🚨 Incident Response

### 1. Preparation

1. **Create Response Plan**

   - Document procedures
   - Define roles
   - Establish communication
   - Set up monitoring

2. **Configure Alerts**

   ```powershell
   # Set up event log alerts
   $action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
                                   -Argument "-Command Send-MailMessage"
   $trigger = New-ScheduledTaskTrigger -AtStartup
   Register-ScheduledTask -TaskName "SecurityAlert" `
                         -Action $action `
                         -Trigger $trigger
   ```

### 2. Response Procedures

1. **Isolate Affected Systems**

   ```powershell
   # Disable network adapter
   Disable-NetAdapter -Name "Ethernet" -Confirm:$false
   ```

2. **Collect Evidence**

   ```powershell
   # Export event logs
   Get-EventLog -LogName Security -Newest 1000 |
   Export-Csv -Path "C:\Investigation\SecurityLogs.csv"
   ```

## 📝 Security Documentation

### 1. Security Policies

1. **Document Standards**

   - Password requirements
   - Access controls
   - Security procedures
   - Incident response

2. **Maintain Procedures**
   - Regular updates
   - Version control
   - Distribution list
   - Review schedule

### 2. Compliance Records

1. **Maintain Logs**

   - Security events
   - Configuration changes
   - Access attempts
   - System updates

2. **Generate Reports**

   ```powershell
   # Create security report
   Get-EventLog -LogName Security -Newest 1000 |
   Group-Object -Property EventID |
   Select-Object Name,Count |
   Export-Csv -Path "C:\Reports\SecurityReport.csv"
   ```

## 🎯 Best Practices

### 1. Regular Maintenance

- Weekly security updates
- Monthly policy review
- Quarterly access review
- Annual security assessment

### 2. Continuous Monitoring

- Real-time alerts
- Log analysis
- Performance monitoring
- Security scanning

### 3. Training and Awareness

- Security training
- Phishing awareness
- Password management
- Incident reporting

## 📚 Next Steps

- Review previous guides:
  - [01_Setup_Lab_Environment.md](01_Setup_Lab_Environment.md)
  - [02_Manage_Users_Computers_AD.md](02_Manage_Users_Computers_AD.md)
  - [03_AD_Groups_Management.md](03_AD_Groups_Management.md)
  - [04_GPO_Creation_and_Linking.md](04_GPO_Creation_and_Linking.md)
  - [05_Troubleshooting.md](05_Troubleshooting.md)
  - [06_Monitoring_and_Maintenance.md](06_Monitoring_and_Maintenance.md)
  - [07_Lab_Scenarios.md](07_Lab_Scenarios.md)
  - [08_Common_Mistakes.md](08_Common_Mistakes.md)

## 🔗 Additional Resources

- [Microsoft Security Baseline](https://docs.microsoft.com/en-us/windows/security/threat-protection/security-policy-settings/security-policy-settings)
- [Windows Server Security Guide](https://docs.microsoft.com/en-us/windows-server/security/)
- [Security Compliance Toolkit](https://www.microsoft.com/en-us/download/details.aspx?id=55319)
