# 💻 Setting Up Additional Client Machines

## 🎯 What You'll Learn

- How to set up department-specific client machines
- Joining clients to the domain
- Configuring client settings
- Testing department-specific access

## 📋 Prerequisites

- Working Windows Server domain
- Additional servers set up (from [13_Additional_Servers_Setup.md](13_Additional_Servers_Setup.md))
- Windows 10 ISO
- Virtualization software

## 🖥️ Setting Up IT Department Client (CL-IT-001)

### Step 1: Create Virtual Machine

1. Create new VM:

   ```
   Name: CL-IT-001
   Type: Microsoft Windows
   Version: Windows 10 (64-bit)
   Memory: 2048 MB (2GB)
   Hard disk: 50 GB
   Processors: 2
   ```

### Step 2: Install Windows 10

1. Start the VM
2. Select Windows 10 ISO
3. Follow installation steps
4. Set initial user as "LocalAdmin"

### Step 3: Configure Network

1. Set static IP:

   ```
   IP Address: 192.168.1.201
   Subnet Mask: 255.255.255.0
   Default Gateway: 192.168.1.1
   DNS Server: 192.168.1.100
   ```

### Step 4: Join Domain

1. Open System Properties
2. Click "Change"
3. Select "Domain"
4. Enter: `lab.local`
5. Enter domain admin credentials
6. Restart when prompted

### Step 5: Test IT Department Access

1. Log in as IT user:

   ```
   Username: thor@lab.local
   Password: (your set password)
   ```

2. Test access to IT share:

   ```powershell
   Test-Path "\\FS1\IT"
   ```

## 🏢 Setting Up HR Department Client (CL-HR-001)

### Step 1: Create Virtual Machine

1. Create new VM:

   ```
   Name: CL-HR-001
   Type: Microsoft Windows
   Version: Windows 10 (64-bit)
   Memory: 2048 MB (2GB)
   Hard disk: 50 GB
   Processors: 2
   ```

### Step 2: Install Windows 10

1. Follow same installation steps
2. Set static IP:

   ```
   IP Address: 192.168.1.202
   Subnet Mask: 255.255.255.0
   Default Gateway: 192.168.1.1
   DNS Server: 192.168.1.100
   ```

### Step 3: Join Domain

1. Join to `lab.local` domain
2. Restart when prompted

### Step 4: Test HR Department Access

1. Log in as HR user:

   ```
   Username: freya@lab.local
   Password: (your set password)
   ```

2. Test access to HR share:

   ```powershell
   Test-Path "\\FS1\HR"
   ```

## 💼 Setting Up Sales Department Client (CL-SALES-001)

### Step 1: Create Virtual Machine

1. Create new VM:

   ```
   Name: CL-SALES-001
   Type: Microsoft Windows
   Version: Windows 10 (64-bit)
   Memory: 2048 MB (2GB)
   Hard disk: 50 GB
   Processors: 2
   ```

### Step 2: Install Windows 10

1. Follow same installation steps
2. Set static IP:

   ```
   IP Address: 192.168.1.203
   Subnet Mask: 255.255.255.0
   Default Gateway: 192.168.1.1
   DNS Server: 192.168.1.100
   ```

### Step 3: Join Domain

1. Join to `lab.local` domain
2. Restart when prompted

### Step 4: Test Sales Department Access

1. Log in as Sales user:

   ```
   Username: sif@lab.local
   Password: (your set password)
   ```

2. Test access to Sales share:

   ```powershell
   Test-Path "\\FS1\Sales"
   ```

## 🔍 Testing Department-Specific Access

### 1. File Access Testing

1. On each client, test:
   - Access to department share
   - Access to other department shares (should be denied)
   - File creation in department share
   - File modification in department share

### 2. Group Policy Testing

1. Verify department-specific policies:

   ```powershell
   gpresult /r
   ```

2. Check applied settings:
   - Desktop background
   - Start menu layout
   - Installed software
   - Security settings

### 3. Network Access Testing

1. Test connectivity:

   ```powershell
   Test-NetConnection -ComputerName DC1
   Test-NetConnection -ComputerName DC2
   Test-NetConnection -ComputerName FS1
   Test-NetConnection -ComputerName SQL1
   ```

2. Test DNS resolution:

   ```powershell
   Resolve-DnsName -Name lab.local
   ```

## 📝 Client Configuration Checklist

### For Each Client

- [ ] Windows 10 installed
- [ ] Static IP configured
- [ ] Joined to domain
- [ ] Department user can log in
- [ ] Department share accessible
- [ ] Group policies applied
- [ ] Network connectivity verified
- [ ] DNS resolution working

## 🔧 Troubleshooting

### Common Issues

1. **Can't Join Domain**
   - Check DNS settings
   - Verify network connectivity
   - Check domain admin credentials

2. **Can't Access Shares**
   - Verify user group membership
   - Check share permissions
   - Check NTFS permissions

3. **Group Policy Not Applying**
   - Run `gpupdate /force`
   - Check GPO link order
   - Verify user/computer OU placement

## 📚 Next Steps

- Learn about user management in [02_Manage_Users_Computers_AD.md](02_Manage_Users_Computers_AD.md)
- Understand group policies in [04_GPO_Creation_and_Linking.md](04_GPO_Creation_and_Linking.md)
- Explore security settings in [09_Security_Hardening.md](09_Security_Hardening.md)

## 🔗 Additional Resources

- [Microsoft Docs: Windows 10 Deployment](https://docs.microsoft.com/en-us/windows/deployment/)
- [Microsoft Docs: Group Policy](https://docs.microsoft.com/en-us/windows/security/threat-protection/security-policy-settings/security-policy-settings)
- [Microsoft Docs: File Sharing](https://docs.microsoft.com/en-us/windows-server/storage/file-server/file-server-smb-overview)
