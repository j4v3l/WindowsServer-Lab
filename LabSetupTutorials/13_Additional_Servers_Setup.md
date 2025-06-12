# 🖥️ Setting Up Additional Servers in Your Lab Environment

## 🎯 What You'll Learn

- How to set up a second domain controller
- Configuring file server roles
- Setting up SQL Server
- Best practices for server deployment

## 📋 Prerequisites

- Working Windows Server domain (from [01_Setup_Lab_Environment.md](01_Setup_Lab_Environment.md))
- Virtualization software (VMware, VirtualBox, or Hyper-V)
- Windows Server ISO (2019 or 2022)
- At least 16GB RAM on host machine
- 200GB free disk space

## 🔄 Setting Up DC2 (Second Domain Controller)

### Step 1: Create Virtual Machine

1. Open your virtualization software
2. Create new VM with these settings:

   ```
   Name: DC2
   Type: Microsoft Windows
   Version: Windows Server 2019 (64-bit)
   Memory: 4096 MB (4GB)
   Hard disk: 60 GB
   Processors: 2
   ```

### Step 2: Install Windows Server

1. Start the VM
2. Select your Windows Server ISO
3. Follow installation steps:

   ```
   Language: English
   Time format: Your local time
   Keyboard: Your local keyboard
   ```

4. Choose "Windows Server 2019 Standard (Desktop Experience)"

### Step 3: Configure Network

1. Set static IP:

   ```
   IP Address: 192.168.1.101
   Subnet Mask: 255.255.255.0
   Default Gateway: 192.168.1.1
   DNS Server: 192.168.1.100 (DC1's IP)
   ```

2. Verify connectivity:

   ```powershell
   Test-NetConnection -ComputerName 192.168.1.100
   ```

### Step 4: Install Active Directory

1. Open Server Manager
2. Add roles and features:

   - Select "Active Directory Domain Services"
   - Click "Add Features" when prompted
   - Complete installation

3. Promote to domain controller:

   ```powershell
   Install-ADDSDomainController `
       -DomainName "lab.local" `
       -InstallDns:$true `
       -DatabasePath "C:\Windows\NTDS" `
       -LogPath "C:\Windows\NTDS" `
       -SysvolPath "C:\Windows\SYSVOL" `
       -NoGlobalCatalog:$false `
       -CreateDnsDelegation:$false `
       -Credential (Get-Credential) `
       -Force:$true
   ```

4. Server will restart automatically

### Step 5: Verify Replication

1. Check replication status:

   ```powershell
   repadmin /showrepl
   ```

2. Verify DNS records:

   ```powershell
   Get-DnsServerResourceRecord -ZoneName "lab.local" -RRType A
   ```

## 📁 Setting Up FS1 (File Server)

### Step 1: Create Virtual Machine

1. Create new VM:

   ```
   Name: FS1
   Type: Microsoft Windows
   Version: Windows Server 2019 (64-bit)
   Memory: 2048 MB (2GB)
   Hard disk: 100 GB
   Processors: 2
   ```

### Step 2: Install Windows Server

1. Follow same installation steps as DC2
2. Set static IP:

   ```
   IP Address: 192.168.1.102
   Subnet Mask: 255.255.255.0
   Default Gateway: 192.168.1.1
   DNS Server: 192.168.1.100
   ```

### Step 3: Join Domain

1. Open System Properties
2. Click "Change"
3. Select "Domain"
4. Enter: `lab.local`
5. Enter domain admin credentials
6. Restart when prompted

### Step 4: Install File Server Role

1. Open Server Manager
2. Add roles and features:
   - Select "File and Storage Services"
   - Select "File Server"
   - Complete installation

### Step 5: Create Shares

1. Create department folders:

   ```powershell
   New-Item -Path "C:\Shares\IT" -ItemType Directory
   New-Item -Path "C:\Shares\HR" -ItemType Directory
   New-Item -Path "C:\Shares\Sales" -ItemType Directory
   ```

2. Create shares:

   ```powershell
   New-SmbShare -Name "IT" -Path "C:\Shares\IT" -FullAccess "LAB\IT_Staff"
   New-SmbShare -Name "HR" -Path "C:\Shares\HR" -FullAccess "LAB\HR_Staff"
   New-SmbShare -Name "Sales" -Path "C:\Shares\Sales" -FullAccess "LAB\Sales_Staff"
   ```

```

**📋 For comprehensive network share setup instructions, see:**
- [Asgard Technologies Demo Guide](../Demo/Asgard/Guides/ASGARD_NETWORK_SHARE_SETUP.md)
- [Olympus Systems Demo Guide](../Demo/Olympus/Guides/OLYMPUS_NETWORK_SHARE_SETUP.md)
- [Generic Setup Guide](../Demo/Asgard/Documentation/NETWORK_SHARE_SETUP_GUIDE.md)

## 💾 Setting Up SQL1 (SQL Server)

### Step 1: Create Virtual Machine

1. Create new VM:

```

Name: SQL1
Type: Microsoft Windows
Version: Windows Server 2019 (64-bit)
Memory: 4096 MB (4GB)
Hard disk: 100 GB
Processors: 2

```

### Step 2: Install Windows Server

1. Follow same installation steps
2. Set static IP:

```

IP Address: 192.168.1.103
Subnet Mask: 255.255.255.0
Default Gateway: 192.168.1.1
DNS Server: 192.168.1.100

```

### Step 3: Join Domain

1. Join to `lab.local` domain
2. Restart when prompted

### Step 4: Install SQL Server

1. Download SQL Server 2019 Developer Edition
2. Run installation
3. Select features:
- Database Engine Services
- SQL Server Replication
- Client Tools Connectivity
- Management Tools

4. Configure instance:

```

Instance Name: SQL1
Authentication: Windows Authentication

````

## ✅ Verification Steps

### Check All Servers

1. Verify domain membership:

```powershell
Get-ComputerInfo | Select-Object CsDomain
````

2. Check network connectivity:

   ```powershell
   Test-NetConnection -ComputerName 192.168.1.100
   Test-NetConnection -ComputerName 192.168.1.101
   Test-NetConnection -ComputerName 192.168.1.102
   Test-NetConnection -ComputerName 192.168.1.103
   ```

3. Verify services:

   ```powershell
   Get-Service -ComputerName DC2 | Where-Object {$_.DisplayName -like "*Active Directory*"}
   Get-Service -ComputerName FS1 | Where-Object {$_.DisplayName -like "*File Server*"}
   Get-Service -ComputerName SQL1 | Where-Object {$_.DisplayName -like "*SQL*"}
   ```

## 📚 Next Steps

- Learn about AD replication in [03_AD_Groups_Management.md](03_AD_Groups_Management.md)
- Set up file server permissions in [02_Manage_Users_Computers_AD.md](02_Manage_Users_Computers_AD.md)
- Configure SQL Server high availability in [12_Disaster_Recovery.md](12_Disaster_Recovery.md)

## 🔗 Additional Resources

- [Microsoft Docs: Active Directory Replication](https://docs.microsoft.com/en-us/windows-server/identity/ad-ds/get-started/replication/active-directory-replication-concepts)
- [Microsoft Docs: File Server Management](https://docs.microsoft.com/en-us/windows-server/storage/file-server/file-server-smb-overview)
- [Microsoft Docs: SQL Server Installation](https://docs.microsoft.com/en-us/sql/database-engine/install-windows/install-sql-server)
