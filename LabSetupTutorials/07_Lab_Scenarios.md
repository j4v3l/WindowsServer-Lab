# 🎯 Windows Server Lab Scenarios

## 🎯 What You'll Learn

- Practical exercises for Windows Server administration
- Real-world scenarios and solutions
- Hands-on troubleshooting
- Best practices implementation

## 📋 Prerequisites

- Completed all previous guides
- Working lab environment
- Basic understanding of Windows Server concepts

## 🔍 Lab Scenarios

### 1. User Migration Exercise

#### Scenario

You need to migrate 50 users from one OU to another while maintaining their group memberships and permissions.

#### Steps

1. Create source and destination OUs:

   ```powershell
   New-ADOrganizationalUnit -Name "SourceOU" -Path "DC=lab,DC=local"
   New-ADOrganizationalUnit -Name "DestinationOU" -Path "DC=lab,DC=local"
   ```

2. Create test users:

   ```powershell
   for ($i=1; $i -le 50; $i++) {
       New-ADUser -Name "User$i" `
                  -SamAccountName "user$i" `
                  -Path "OU=SourceOU,DC=lab,DC=local" `
                  -AccountPassword (ConvertTo-SecureString "P@ssw0rd123" -AsPlainText -Force) `
                  -Enabled $true
   }
   ```

3. Migrate users:

   ```powershell
   Get-ADUser -Filter * -SearchBase "OU=SourceOU,DC=lab,DC=local" | 
   ForEach-Object {
       Move-ADObject -Identity $_.DistinguishedName -TargetPath "OU=DestinationOU,DC=lab,DC=local"
   }
   ```

### 2. Group Policy Testing

#### Scenario

Test a new GPO that will deploy a shared printer to all users in the IT department.

#### Steps

1. Create test OU:

   ```powershell
   New-ADOrganizationalUnit -Name "GPO_Test" -Path "DC=lab,DC=local"
   ```

2. Create test GPO:

   ```powershell
   New-GPO -Name "Printer_Deployment_Test"
   ```

3. Configure printer settings:
   - Open GPO Editor
   - Navigate to User Configuration
   - Add shared printer
   - Set deployment options

4. Test deployment:
   - Link GPO to test OU
   - Add test user
   - Verify printer installation

### 3. Disaster Recovery

#### Scenario

Simulate a domain controller failure and practice recovery procedures.

#### Steps

1. Create backup:

   ```powershell
   wbadmin start systemstatebackup -backuptarget:E:
   ```

2. Simulate failure:
   - Stop AD services
   - Corrupt system files
   - Disable network adapter

3. Recovery process:
   - Boot into DSRM
   - Restore system state
   - Verify AD functionality

### 4. Security Hardening

#### Scenario

Implement security baseline configurations for your domain.

#### Steps

1. Configure password policy:

   ```powershell
   Set-ADDefaultDomainPasswordPolicy -MinPasswordLength 12 `
                                    -ComplexityEnabled $true `
                                    -MaxPasswordAge 90
   ```

2. Implement account lockout:

   ```powershell
   Set-ADDefaultDomainPasswordPolicy -LockoutThreshold 5 `
                                    -LockoutDuration 30 `
                                    -LockoutObservationWindow 30
   ```

3. Configure audit policy:

   ```powershell
   auditpol /set /category:* /success:enable /failure:enable
   ```

## 📝 Practical Exercises

### 1. User Management

1. Create bulk users
2. Set up home directories
3. Configure profile paths
4. Implement password policies

### 2. Group Management

1. Create department groups
2. Set up nested groups
3. Configure group permissions
4. Test group inheritance

### 3. GPO Management

1. Create desktop policies
2. Deploy software
3. Configure security settings
4. Test policy application

### 4. Backup and Recovery

1. Create backup schedule
2. Test backup restoration
3. Practice disaster recovery
4. Verify data integrity

## 🔒 Security Scenarios

### 1. Access Control

1. Implement least privilege
2. Configure share permissions
3. Set up NTFS permissions
4. Test access rights

### 2. Audit Configuration

1. Enable security auditing
2. Configure audit policies
3. Review audit logs
4. Generate reports

### 3. Firewall Rules

1. Configure inbound rules
2. Set up outbound rules
3. Test connectivity
4. Monitor traffic

## 📊 Performance Testing

### 1. Load Testing

1. Simulate user logins
2. Test file access
3. Monitor performance
4. Analyze results

### 2. Resource Monitoring

1. Set up performance counters
2. Create baseline
3. Monitor trends
4. Optimize settings

## 🎯 Best Practices

### 1. Documentation

- Record all changes
- Document procedures
- Create runbooks
- Maintain logs

### 2. Testing

- Test in lab first
- Verify backups
- Check permissions
- Validate settings

### 3. Security

- Follow least privilege
- Regular audits
- Update management
- Security scanning

## ❓ Troubleshooting Exercises

### 1. User Issues

- Login problems
- Permission issues
- Profile errors
- Group membership

### 2. System Issues

- Performance problems
- Service failures
- Network issues
- Resource constraints

## 📚 Next Steps

- Review previous guides:
  - [01_Setup_Lab_Environment.md](01_Setup_Lab_Environment.md)
  - [02_Manage_Users_Computers_AD.md](02_Manage_Users_Computers_AD.md)
  - [03_AD_Groups_Management.md](03_AD_Groups_Management.md)
  - [04_GPO_Creation_and_Linking.md](04_GPO_Creation_and_Linking.md)
  - [05_Troubleshooting.md](05_Troubleshooting.md)
  - [06_Monitoring_and_Maintenance.md](06_Monitoring_and_Maintenance.md)

## 🔗 Additional Resources

- [Microsoft Lab Exercises](https://docs.microsoft.com/en-us/windows-server/administration/windows-server-labs/)
- [TechNet Virtual Labs](https://www.microsoft.com/en-us/learning/virtual-labs.aspx)
- [Windows Server Documentation](https://docs.microsoft.com/en-us/windows-server/)
