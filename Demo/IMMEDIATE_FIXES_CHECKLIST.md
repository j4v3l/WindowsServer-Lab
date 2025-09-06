# ⚡ **IMMEDIATE FIXES CHECKLIST**

## Critical Actions for Production Readiness

**Priority Level:** 🔴 **URGENT - Complete before any production deployment**

---

## 🚨 **CRITICAL FIXES (Complete TODAY)**

### **1. Remove Hardcoded Passwords (30 minutes)**

**Risk:** Complete environment compromise
**Action:** Replace all hardcoded passwords in documentation

```bash
# Quick fix - Replace hardcoded passwords with placeholders
find . -name "*.md" -exec sed -i.bak 's/YourSecurePassword123!/[ADMIN_MUST_SET_SECURE_PASSWORD]/g' {} \;
find . -name "*.md" -exec sed -i.bak 's/TempPassword123!/[ADMIN_MUST_SET_SECURE_PASSWORD]/g' {} \;
find . -name "*.md" -exec sed -i.bak 's/TempDivinePassword123!/[ADMIN_MUST_SET_SECURE_PASSWORD]/g' {} \;

# Verify changes
grep -r "123!" . --include="*.md" || echo "✅ All hardcoded passwords removed"
```

**Files to update manually:**

- [ ] `Asgard/MANUAL_SETUP_ASGARD.md` line 203
- [ ] `Asgard/MANUAL_SETUP_ASGARD.md` line 943  
- [ ] `Olympus/MANUAL_SETUP_OLYMPUS.md` line 206
- [ ] `Olympus/MANUAL_SETUP_OLYMPUS.md` line 928

### **2. Add Security Warnings (15 minutes)**

Add critical security warning to all README files:

```markdown
# 🚨 SECURITY WARNING
**CRITICAL:** This environment contains DEFAULT CONFIGURATIONS that are NOT suitable for production use. 
Before any deployment:
1. Change ALL default passwords
2. Implement production security policies
3. Review SECURITY_HARDENING_GUIDE.md
4. Complete security assessment
```

**Files to update:**

- [ ] `README.md`
- [ ] `Asgard/README.md`
- [ ] `Olympus/README.md`

### **3. Create Secure Password Script (45 minutes)**

Replace hardcoded password usage with secure prompts:

```powershell
# Create: Scripts/Get-SecureCredentials.ps1
function Get-SecureDeploymentCredentials {
    [CmdletBinding()]
    param()
    
    Write-Host "🔒 PRODUCTION SECURITY: Setting up secure credentials" -ForegroundColor Yellow
    Write-Host "⚠️  NEVER use demo passwords in production!" -ForegroundColor Red
    
    $Credentials = @{}
    
    # Domain Safe Mode Password (DSRM)
    do {
        $SafeModePassword = Read-Host -AsSecureString -Prompt "Enter DSRM Safe Mode Password (minimum 15 characters)"
        $PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SafeModePassword))
        
        if ($PlainPassword.Length -lt 15) {
            Write-Host "❌ Password too short. Minimum 15 characters required." -ForegroundColor Red
            continue
        }
        
        if (-not ($PlainPassword -cmatch '[A-Z]' -and $PlainPassword -cmatch '[a-z]' -and 
                  $PlainPassword -cmatch '[0-9]' -and $PlainPassword -cmatch '[!@#$%^&*]')) {
            Write-Host "❌ Password must contain uppercase, lowercase, numbers, and symbols." -ForegroundColor Red
            continue
        }
        
        break
    } while ($true)
    
    $Credentials.SafeModePassword = $SafeModePassword
    
    # Default User Password
    do {
        $UserPassword = Read-Host -AsSecureString -Prompt "Enter default user password (minimum 12 characters)"
        $PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($UserPassword))
        
        if ($PlainPassword.Length -lt 12) {
            Write-Host "❌ Password too short. Minimum 12 characters required." -ForegroundColor Red
            continue
        }
        
        break
    } while ($true)
    
    $Credentials.UserPassword = $UserPassword
    
    Write-Host "✅ Secure credentials configured successfully" -ForegroundColor Green
    return $Credentials
}

# Usage in deployment scripts:
# $Creds = Get-SecureDeploymentCredentials
# Install-ADDSForest -SafeModeAdministratorPassword $Creds.SafeModePassword
```

---

## 🔒 **HIGH PRIORITY FIXES (Complete this WEEK)**

### **4. Configure Proxmox Security (2 hours)**

**Enable Proxmox Firewall:**

```bash
# Via Proxmox web interface:
# 1. Navigate to Datacenter → Firewall → Options
# 2. Enable: Firewall = Yes
# 3. Enable: ebtables = Yes
# 4. Set Input Policy = DROP
# 5. Set Output Policy = ACCEPT

# Via command line:
echo "Configuring Proxmox firewall rules..."

# Allow SSH only from management network
iptables -A INPUT -p tcp --dport 22 -s 10.0.100.0/24 -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j DROP

# Allow Proxmox web interface only from management network  
iptables -A INPUT -p tcp --dport 8006 -s 10.0.100.0/24 -j ACCEPT
iptables -A INPUT -p tcp --dport 8006 -j DROP

# Save rules
iptables-save > /etc/iptables/rules.v4
```

### **5. Implement VM Security Settings (1 hour)**

**Update VM configurations for security:**

```bash
# For each critical VM, apply security settings
VM_IDS=(100 101 102 103 104)  # Domain controllers and servers

for VM_ID in "${VM_IDS[@]}"; do
    echo "Securing VM $VM_ID..."
    
    # Enable CPU security features
    qm set $VM_ID --cpu host,flags=+spec-ctrl,+ssbd,+ibrs,+ibpb,+stibp,+virt-ssbd
    
    # Set resource limits
    qm set $VM_ID --cpulimit 4
    qm set $VM_ID --balloon 2048
    
    # Remove USB controllers (production security)
    qm set $VM_ID --usb0 none --usb1 none --usb2 none
    
    # Enable UEFI Secure Boot
    qm set $VM_ID --bios ovmf --efidisk0 local-lvm:1,format=qcow2,efitype=4m,pre-enrolled-keys=1
    
    echo "✅ VM $VM_ID security configuration updated"
done
```

### **6. Create Backup Automation (3 hours)**

**Basic backup script for critical VMs:**

```bash
#!/bin/bash
# Create: /usr/local/bin/production-backup.sh

BACKUP_STORAGE="local"
LOG_FILE="/var/log/production-backup.log"
DATE=$(date +%Y%m%d_%H%M%S)

# Critical VMs to backup daily
CRITICAL_VMS=(100 101 102 103 104)  # DCs and core servers

echo "Starting production backup: $DATE" >> $LOG_FILE

for VM_ID in "${CRITICAL_VMS[@]}"; do
    echo "Backing up VM $VM_ID..." >> $LOG_FILE
    
    if vzdump $VM_ID --storage $BACKUP_STORAGE --mode snapshot --compress lzo --notes "Production backup $DATE"; then
        echo "✅ VM $VM_ID backup completed successfully" >> $LOG_FILE
    else
        echo "❌ VM $VM_ID backup FAILED" >> $LOG_FILE
        # Send alert (configure email)
        echo "CRITICAL: VM $VM_ID backup failed at $DATE" | mail -s "Backup Failure Alert" admin@company.com
    fi
done

echo "Backup run completed: $DATE" >> $LOG_FILE
```

**Configure daily backup schedule:**

```bash
# Add to crontab
echo "0 2 * * * /usr/local/bin/production-backup.sh" | crontab -
```

---

## 📋 **MEDIUM PRIORITY FIXES (Complete within 2 WEEKS)**

### **7. Enhanced Monitoring Setup (4 hours)**

**Configure centralized logging:**

```powershell
# On domain controller, configure event forwarding
winrm quickconfig -force
wecutil qc -force

# Create subscription for critical security events
$SubscriptionXML = @"
<Subscription xmlns="http://schemas.microsoft.com/2006/03/windows/events/subscription">
    <SubscriptionId>Critical-Security-Events</SubscriptionId>
    <SubscriptionType>SourceInitiated</SubscriptionType>
    <Description>Critical security events from all domain systems</Description>
    <Enabled>true</Enabled>
    <Query>
        <![CDATA[
        <QueryList>
            <Query Id="0">
                <Select Path="Security">*[System[(EventID=4625 or EventID=4648 or EventID=4720 or EventID=4728 or EventID=4732)]]</Select>
            </Query>
        </QueryList>
        ]]>
    </Query>
</Subscription>
"@

$SubscriptionXML | Out-File -FilePath C:\temp\SecuritySubscription.xml
wecutil cs C:\temp\SecuritySubscription.xml
```

### **8. Update Documentation (6 hours)**

**Critical documentation updates:**

- [ ] Add security warnings to all setup guides
- [ ] Remove all hardcoded password references
- [ ] Add production deployment sections
- [ ] Create incident response procedures
- [ ] Document backup and recovery processes

### **9. Security Policy Implementation (8 hours)**

**Production-grade Active Directory policies:**

```powershell
# Enhanced password policy
Set-ADDefaultDomainPasswordPolicy -Identity "asgard.local" `
    -MinPasswordLength 15 `
    -PasswordHistoryCount 24 `
    -MaxPasswordAge (New-TimeSpan -Days 60) `
    -MinPasswordAge (New-TimeSpan -Days 1) `
    -ComplexityEnabled $true `
    -LockoutDuration (New-TimeSpan -Minutes 60) `
    -LockoutObservationWindow (New-TimeSpan -Minutes 60) `
    -LockoutThreshold 3

# Enable comprehensive auditing
auditpol /set /category:"Account Logon" /success:enable /failure:enable
auditpol /set /category:"Account Management" /success:enable /failure:enable
auditpol /set /category:"Logon/Logoff" /success:enable /failure:enable
auditpol /set /category:"Object Access" /success:enable /failure:enable
auditpol /set /category:"Policy Change" /success:enable /failure:enable
auditpol /set /category:"Privilege Use" /success:enable /failure:enable
```

---

## ✅ **VERIFICATION CHECKLIST**

### **Security Verification:**

- [ ] No hardcoded passwords in any documentation
- [ ] All VMs have secure configurations
- [ ] Proxmox firewall is enabled and configured
- [ ] Strong password policies are enforced
- [ ] Audit logging is enabled and working

### **Operational Verification:**

- [ ] Automated backups are running daily
- [ ] Backup restoration has been tested
- [ ] Monitoring and alerting is functional
- [ ] Documentation is updated and accurate
- [ ] Incident response procedures are documented

### **Final Security Assessment:**

- [ ] Vulnerability scan completed
- [ ] Penetration testing performed
- [ ] Compliance requirements verified
- [ ] Security controls tested
- [ ] Management sign-off obtained

---

## 🎯 **SUCCESS CRITERIA**

**Environment is production-ready when:**

1. ✅ All critical and high priority fixes completed
2. ✅ Security assessment passes with 80%+ score
3. ✅ Backup and recovery procedures tested successfully
4. ✅ Monitoring detects and alerts on security events
5. ✅ Documentation is complete and accurate

**Time Estimate:** 2-3 weeks for complete implementation

**Resources Needed:**

- Windows Server expert (40 hours)
- Proxmox administrator (16 hours)  
- Security specialist (24 hours)

---

## 📞 **EMERGENCY CONTACTS**

**Critical Issue Escalation:**

- Security Incident: [SECURITY_TEAM_EMAIL]
- System Outage: [OPERATIONS_TEAM_EMAIL]
- Backup Failure: [BACKUP_ADMIN_EMAIL]

**Next Review Date:** [SET_DATE_2_WEEKS_FROM_NOW]
