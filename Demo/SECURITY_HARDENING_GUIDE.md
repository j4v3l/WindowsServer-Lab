# 🔒 **PRODUCTION SECURITY HARDENING GUIDE**

## Windows Server Lab Demo - Proxmox Production Deployment

**CRITICAL WARNING:** This guide MUST be implemented before any production deployment. The demo environment contains security configurations that are NOT suitable for production use.

---

## 🚨 **IMMEDIATE SECURITY ACTIONS REQUIRED**

### **1. Password Security Remediation**

#### **Remove All Hardcoded Passwords**

**Current Security Risk:**

- Hardcoded passwords in `MANUAL_SETUP_ASGARD.md` and `MANUAL_SETUP_OLYMPUS.md`
- Example patterns found: `YourSecurePassword123!`, `TempPassword123!`, `TempDivinePassword123!`

**Production Solution:**

```powershell
# SECURE: Use Windows Credential Manager or Azure Key Vault
function Get-SecurePassword {
    param(
        [string]$PromptMessage = "Enter secure password",
        [string]$KeyVaultName = $null,
        [string]$SecretName = $null
    )
    
    if ($KeyVaultName -and $SecretName) {
        # Production: Use Azure Key Vault
        $secret = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $SecretName
        return $secret.SecretValue
    } else {
        # Fallback: Secure prompt
        return Read-Host -Prompt $PromptMessage -AsSecureString
    }
}

# Usage in deployment scripts
$SafeModePassword = Get-SecurePassword -PromptMessage "Enter DSRM Safe Mode Password (minimum 15 characters)"
$UserPassword = Get-SecurePassword -PromptMessage "Enter default user password (minimum 12 characters)"

# Validate password complexity
function Test-PasswordComplexity {
    param([SecureString]$Password)
    
    $plainText = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password))
    
    $isValid = ($plainText.Length -ge 15) -and
               ($plainText -cmatch '[A-Z]') -and
               ($plainText -cmatch '[a-z]') -and
               ($plainText -cmatch '[0-9]') -and
               ($plainText -cmatch '[!@#$%^&*]')
    
    return $isValid
}
```

#### **Implement Secure Credential Storage**

```powershell
# Production credential management
$CredentialPath = "C:\SecureStore\Credentials.xml"

# Store credentials securely (one-time setup)
function Set-ProductionCredentials {
    $Credentials = @{
        SafeModePassword = (Read-Host -AsSecureString -Prompt "DSRM Password")
        ServiceAccount = Get-Credential -Message "Service Account"
        BackupAccount = Get-Credential -Message "Backup Service Account"
    }
    
    $Credentials | Export-Clixml -Path $CredentialPath
    
    # Set restrictive permissions
    icacls $CredentialPath /grant:r "NT AUTHORITY\SYSTEM:(F)" /inheritance:r
    icacls $CredentialPath /grant:r "BUILTIN\Administrators:(F)"
}

# Retrieve credentials in deployment scripts
function Get-ProductionCredentials {
    if (Test-Path $CredentialPath) {
        return Import-Clixml -Path $CredentialPath
    } else {
        throw "Credentials not found. Run Set-ProductionCredentials first."
    }
}
```

---

### **2. Network Security Hardening**

#### **Proxmox Bridge Security**

```bash
# Configure secure bridge settings on Proxmox host
# /etc/network/interfaces configuration

# Production network bridge (restricted)
auto vmbr0
iface vmbr0 inet static
    address 10.0.10.1/24
    bridge-ports none
    bridge-stp off
    bridge-fd 0
    # Disable bridge learning for security
    bridge-ageing 0
    bridge-disablelearning on

# Management network (admin only)
auto vmbr1
iface vmbr1 inet static
    address 10.0.100.1/24
    bridge-ports none
    bridge-stp off
    bridge-fd 0
    # Restrict to specific MAC addresses
    bridge-access-control on

# Enable firewall on all bridges
echo 1 > /proc/sys/net/bridge/bridge-nf-call-iptables
echo 1 > /proc/sys/net/bridge/bridge-nf-call-ip6tables
```

#### **Firewall Rules for Proxmox**

```bash
# Configure Proxmox firewall rules
# Navigate to Datacenter → Firewall → Options
# Enable firewall: Yes

# Default rules for production
# Block all by default, allow specific services

# Allow SSH from admin network only
iptables -A INPUT -p tcp --dport 22 -s 10.0.100.0/24 -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j DROP

# Allow Proxmox web interface from admin network only
iptables -A INPUT -p tcp --dport 8006 -s 10.0.100.0/24 -j ACCEPT
iptables -A INPUT -p tcp --dport 8006 -j DROP

# Allow VM console access (VNC/SPICE) from admin network only
iptables -A INPUT -p tcp --dport 5900:5999 -s 10.0.100.0/24 -j ACCEPT
iptables -A INPUT -p tcp --dport 5900:5999 -j DROP
```

---

### **3. VM Security Configuration**

#### **Disable Non-Essential VM Features**

```bash
# Configure secure VM settings via Proxmox CLI
# Remove ISOs after installation
qm set 100 --ide2 none

# Disable USB passthrough in production
qm set 100 --usb0 none

# Configure CPU security features
qm set 100 --cpu host,flags=+spec-ctrl,+ssbd,+ibrs,+ibpb,+stibp,+virt-ssbd

# Enable UEFI Secure Boot
qm set 100 --bios ovmf --efidisk0 local-lvm:1,format=qcow2,efitype=4m,pre-enrolled-keys=1
```

#### **VM Resource Limits**

```bash
# Set memory ballooning for security
qm set 100 --balloon 2048  # Minimum 2GB reserved

# Configure CPU limits to prevent DoS
qm set 100 --cpulimit 2     # Max 2 CPUs for workstations
qm set 100 --cpulimit 4     # Max 4 CPUs for servers

# Set network rate limits
qm set 100 --net0 virtio,bridge=vmbr0,rate=50  # 50MB/s limit
```

---

### **4. Active Directory Security Hardening**

#### **Replace Weak Password Policies**

```powershell
# Production-grade password policy
Set-ADDefaultDomainPasswordPolicy -Identity "asgard.local" `
    -MinPasswordLength 15 `
    -PasswordHistoryCount 24 `
    -MaxPasswordAge (New-TimeSpan -Days 60) `
    -MinPasswordAge (New-TimeSpan -Days 1) `
    -ComplexityEnabled $true `
    -LockoutDuration (New-TimeSpan -Minutes 60) `
    -LockoutObservationWindow (New-TimeSpan -Minutes 60) `
    -LockoutThreshold 3

# Create fine-grained password policy for privileged accounts
New-ADFineGrainedPasswordPolicy -Name "AdminPasswordPolicy" `
    -Precedence 1 `
    -MinPasswordLength 20 `
    -PasswordHistoryCount 24 `
    -MaxPasswordAge (New-TimeSpan -Days 30) `
    -MinPasswordAge (New-TimeSpan -Days 1) `
    -LockoutDuration (New-TimeSpan -Hours 2) `
    -LockoutObservationWindow (New-TimeSpan -Hours 2) `
    -LockoutThreshold 2

# Apply to privileged groups
Add-ADFineGrainedPasswordPolicySubject -Identity "AdminPasswordPolicy" -Subjects "Domain Admins"
Add-ADFineGrainedPasswordPolicySubject -Identity "AdminPasswordPolicy" -Subjects "Enterprise Admins"
```

#### **Enable Advanced Audit Policies**

```powershell
# Enable comprehensive auditing
auditpol /set /category:"Account Logon" /success:enable /failure:enable
auditpol /set /category:"Account Management" /success:enable /failure:enable
auditpol /set /category:"Logon/Logoff" /success:enable /failure:enable
auditpol /set /category:"Object Access" /success:enable /failure:enable
auditpol /set /category:"Policy Change" /success:enable /failure:enable
auditpol /set /category:"Privilege Use" /success:enable /failure:enable
auditpol /set /category:"System" /success:enable /failure:enable

# Configure security event log retention
wevtutil sl Security /ms:1073741824  # 1GB max size
wevtutil sl Security /rt:false       # Don't overwrite
```

---

### **5. Backup and Disaster Recovery**

#### **Automated VM Backup Strategy**

```bash
# Configure automated backups via Proxmox
# Create backup schedule via Datacenter → Backup

# Daily backups with rotation
vzdump --mode snapshot --storage backup-storage --compress lzo --exclude-path /tmp --exclude-path /var/log --dow mon,tue,wed,thu,fri --starttime 02:00 --all --keep-daily 7 --keep-weekly 4 --keep-monthly 6

# Critical system backup script
#!/bin/bash
BACKUP_STORAGE="/backup/critical"
DATE=$(date +%Y%m%d_%H%M%S)

# Backup domain controllers daily
vzdump 100 --storage local --compress gzip --notes "ODIN-DC01 Critical Backup $DATE"
vzdump 101 --storage local --compress gzip --notes "FRIGG-DC02 Critical Backup $DATE"

# Verify backup integrity
if [ $? -eq 0 ]; then
    echo "Backup completed successfully: $DATE" >> /var/log/backup.log
else
    echo "Backup FAILED: $DATE" >> /var/log/backup.log
    mail -s "CRITICAL: Backup Failed" admin@company.com < /var/log/backup.log
fi
```

#### **Configuration Backup**

```powershell
# Backup AD configuration
$BackupPath = "C:\Backup\AD\$(Get-Date -Format 'yyyyMMdd')"
New-Item -Path $BackupPath -ItemType Directory -Force

# Backup AD objects
Export-Csv -Path "$BackupPath\Users.csv" -InputObject (Get-ADUser -Filter * -Properties *)
Export-Csv -Path "$BackupPath\Groups.csv" -InputObject (Get-ADGroup -Filter * -Properties *)
Export-Csv -Path "$BackupPath\OUs.csv" -InputObject (Get-ADOrganizationalUnit -Filter * -Properties *)

# Backup Group Policy
Backup-GPO -All -Path "$BackupPath\GPO"

# Backup DNS zones
dnscmd /ZoneExport asgard.local asgard.local.backup
```

---

### **6. Monitoring and Alerting**

#### **Production Monitoring Setup**

```powershell
# Configure Windows Event Forwarding
winrm quickconfig -force
wecutil qc -force

# Create custom event subscription
$SubscriptionXML = @"
<Subscription xmlns="http://schemas.microsoft.com/2006/03/windows/events/subscription">
    <SubscriptionId>Security-Critical-Events</SubscriptionId>
    <SubscriptionType>SourceInitiated</SubscriptionType>
    <Description>Critical security events from all domain systems</Description>
    <Enabled>true</Enabled>
    <Uri>http://schemas.microsoft.com/wbem/wsman/1/windows/EventLog</Uri>
    <ConfigurationMode>Normal</ConfigurationMode>
    <Query>
        <![CDATA[
        <QueryList>
            <Query Id="0">
                <Select Path="Security">*[System[(EventID=4625 or EventID=4648 or EventID=4656 or EventID=4719)]]</Select>
            </Query>
        </QueryList>
        ]]>
    </Query>
</Subscription>
"@

$SubscriptionXML | Out-File -FilePath C:\temp\SecuritySubscription.xml
wecutil cs C:\temp\SecuritySubscription.xml
```

#### **Performance Monitoring**

```powershell
# Create performance monitoring script
$Counters = @(
    "\Processor(_Total)\% Processor Time",
    "\Memory\Available MBytes",
    "\LogicalDisk(_Total)\% Free Space",
    "\Network Interface(*)\Bytes Total/sec"
)

# Log performance data
Get-Counter -Counter $Counters -SampleInterval 60 -MaxSamples 1440 | 
    Export-Counter -Path "C:\PerfLogs\$(Get-Date -Format 'yyyyMMdd').blg"
```

---

### **7. Compliance and Documentation**

#### **Security Compliance Checklist**

- [ ] All default passwords changed
- [ ] Administrative accounts use complex passwords (20+ characters)
- [ ] Multi-factor authentication enabled for privileged accounts
- [ ] Audit logging enabled and monitored
- [ ] Regular security updates applied
- [ ] Backup and recovery procedures tested
- [ ] Incident response plan documented
- [ ] Network segmentation implemented
- [ ] Firewall rules restrictive by default
- [ ] Service accounts use minimal privileges

#### **Required Documentation Updates**

1. **Remove all hardcoded passwords** from documentation
2. **Create secure deployment procedures** with proper credential management
3. **Document backup and recovery procedures**
4. **Create incident response playbook**
5. **Document network security architecture**
6. **Create user access management procedures**

---

## 🎯 **PRODUCTION DEPLOYMENT CHECKLIST**

### **Pre-Deployment** ✅

- [ ] Implement secure credential management
- [ ] Configure Proxmox firewall rules
- [ ] Set up automated backup procedures
- [ ] Configure monitoring and alerting
- [ ] Update all documentation to remove hardcoded passwords

### **During Deployment** ✅

- [ ] Use secure passwords for all accounts
- [ ] Enable audit logging from start
- [ ] Configure network security properly
- [ ] Apply least privilege principles
- [ ] Document all configuration changes

### **Post-Deployment** ✅

- [ ] Verify all security controls
- [ ] Test backup and recovery procedures
- [ ] Validate monitoring and alerting
- [ ] Conduct security assessment
- [ ] Create operational runbooks

---

## 📞 **EMERGENCY PROCEDURES**

### **Security Incident Response**

```powershell
# Immediate containment script
function Invoke-SecurityContainment {
    param(
        [string[]]$CompromisedSystems
    )
    
    foreach ($System in $CompromisedSystems) {
        # Disable compromised accounts
        Get-ADUser -Filter "Enabled -eq $true" -SearchBase "CN=Users,DC=asgard,DC=local" | 
            Disable-ADAccount
        
        # Reset machine account password
        Reset-ComputerMachinePassword -Server $System
        
        # Force immediate group policy update
        Invoke-Command -ComputerName $System -ScriptBlock { gpupdate /force }
    }
    
    # Alert administrators
    Send-MailMessage -To "admin@company.com" -Subject "SECURITY INCIDENT" -Body "Systems contained: $($CompromisedSystems -join ', ')"
}
```

---

**Implementation Priority:** 🔴 **CRITICAL - Implement before any production use**

**Estimated Implementation Time:** 16-24 hours for complete security hardening

**Required Skills:** Windows Server Administration, Proxmox VE, PowerShell, Network Security
