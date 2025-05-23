# 🔧 Troubleshooting Windows Server and Active Directory

## 🎯 What You'll Learn

- Common problems and their solutions
- How to use built-in troubleshooting tools
- Best practices for problem-solving
- How to prevent issues before they happen

## 📋 Prerequisites

- A working Windows Server domain (from [01_Setup_Lab_Environment.md](01_Setup_Lab_Environment.md))
- Basic understanding of Active Directory concepts

## 🔍 Common Problems and Solutions

### 1. User Login Issues

#### Problem: User Can't Log In

1. **Check Account Status**
   - Open Active Directory Users and Computers
   - Right-click user → Properties
   - Verify account is enabled
   - Check if password is expired

2. **Verify Group Membership**
   - Check if user is in correct groups
   - Look for deny permissions
   - Verify OU placement

3. **Check Password Policy**
   - Run `gpresult /r` on client
   - Verify password meets requirements
   - Check if account is locked

#### Solution Steps

1. Reset password if needed
2. Unlock account if locked
3. Add to required groups
4. Move to correct OU

### 2. Computer Issues

#### Problem: Computer Can't Join Domain

1. **Check Network**
   - Verify IP settings
   - Test DNS resolution
   - Check firewall settings

2. **Verify DNS**
   - Run `nslookup lab.local`
   - Check DNS server settings
   - Verify DNS records

3. **Check Computer Account**
   - Look for existing account
   - Verify computer name
   - Check OU placement

#### Solution Steps

1. Set correct DNS server
2. Create computer account
3. Join domain with admin credentials
4. Restart computer

### 3. Group Policy Problems

#### Problem: GPO Not Applying

1. **Check GPO Status**
   - Verify GPO is enabled
   - Check if linked to correct OU
   - Look for inheritance issues

2. **Verify Client Settings**
   - Run `gpupdate /force`
   - Check event logs
   - Verify network connectivity

3. **Check GPO Order**
   - Look for conflicting GPOs
   - Verify link order
   - Check for enforced GPOs

#### Solution Steps

1. Enable GPO if disabled
2. Link to correct OU
3. Fix inheritance issues
4. Update client settings

## 🛠️ Troubleshooting Tools

### 1. Command Line Tools

#### DNS Troubleshooting

```powershell
# Check DNS resolution
nslookup lab.local

# Flush DNS cache
ipconfig /flushdns

# Register DNS
ipconfig /registerdns
```

#### Group Policy

```powershell
# Force GPO update
gpupdate /force

# Check GPO results
gpresult /r

# Check GPO status
gpresult /h report.html
```

#### Active Directory

```powershell
# Check AD replication
repadmin /showrepl

# Check AD health
dcdiag /v

# Check FSMO roles
netdom query fsmo
```

### 2. GUI Tools

#### Event Viewer

1. Press `Windows + R`
2. Type `eventvwr.msc`
3. Check:
   - System logs
   - Application logs
   - Directory Service logs

#### Active Directory Tools

1. **Users and Computers**
   - Press `Windows + R`
   - Type `dsa.msc`
   - Check user/computer properties

2. **Sites and Services**
   - Press `Windows + R`
   - Type `dssite.msc`
   - Check replication

3. **Domains and Trusts**
   - Press `Windows + R`
   - Type `domain.msc`
   - Check trust relationships

## 📋 Best Practices

### 1. Documentation

- Keep records of changes
- Document network settings
- Maintain password policies
- Track GPO modifications

### 2. Testing

- Test changes in lab first
- Use test OUs for new policies
- Verify backups before changes
- Document test results

### 3. Monitoring

- Check event logs regularly
- Monitor disk space
- Watch for failed logins
- Track GPO application

## 🎯 Common Tasks

### Reset a Domain Controller

1. Check FSMO roles
2. Verify replication
3. Check DNS settings
4. Restart services:

   ```powershell
   net stop ntds
   net start ntds
   ```

### Fix DNS Issues

1. Check DNS server settings
2. Verify forwarders
3. Check zone transfers
4. Update DNS records

### Repair AD Database

1. Stop AD services
2. Run integrity check
3. Repair if needed
4. Restart services

## ❓ When to Call for Help

### Critical Issues

- Multiple DCs down
- Complete authentication failure
- Data corruption
- Security breaches

### Warning Signs

- Frequent replication errors
- Growing event log errors
- Slow logon times
- Failed backups

## 📚 Next Steps

- Review previous guides:
  - [01_Setup_Lab_Environment.md](01_Setup_Lab_Environment.md)
  - [02_Manage_Users_Computers_AD.md](02_Manage_Users_Computers_AD.md)
  - [03_AD_Groups_Management.md](03_AD_Groups_Management.md)
  - [04_GPO_Creation_and_Linking.md](04_GPO_Creation_and_Linking.md)

## 🔗 Additional Resources

- [Microsoft Docs](https://docs.microsoft.com/en-us/windows-server/)
- [TechNet Forums](https://social.technet.microsoft.com/Forums/)
- [Server Fault](https://serverfault.com/)
