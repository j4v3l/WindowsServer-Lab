# 🏰 **ASGARD TECHNOLOGIES** - Manual Setup Guide

## 📋 **Overview**

This manual setup guide provides step-by-step instructions for deploying the Asgard Technologies Windows Server lab environment without using the automated deployment script. This approach gives you complete control over the installation process and allows for customization at each step.

---

## 🎯 **What You'll Build**

- **25 Virtual Machines** (5 servers + 20 workstations)
- **Norse Mythology Company**: Realistic enterprise organization
- **Complete Domain Environment**: `asgard.local`
- **4 Network Segments**: Production, Management, Client, DMZ
- **25 User Accounts**: Across 5 departments

---

## 📋 **Prerequisites**

### **Hardware Requirements**

| Component   | Minimum    | Recommended | Tested Optimal            |
| ----------- | ---------- | ----------- | ------------------------- |
| **CPU**     | 8 cores    | 12+ cores   | AMD Ryzen 7900X (12C/24T) |
| **RAM**     | 32GB       | 64GB        | 64GB DDR5                 |
| **Storage** | 500GB      | 1TB+        | 1TB NVMe SSD              |
| **GPU**     | Integrated | Dedicated   | NVIDIA RTX 5070 (12GB)    |

### **Software Requirements**

- **Windows 10/11 Pro or Enterprise**
- **Hyper-V Feature Enabled**
- **Windows Server 2019/2022/2025 ISO**
- **Windows 10/11 Client ISO**
- **PowerShell 5.1 or later**

### **Network Requirements**

- **Physical network adapter** (for external connectivity)
- **Internet access** (for updates and downloads)

---

## 🚀 **Phase 1: Environment Preparation**

### **Step 1.1: Enable Hyper-V**

```powershell
# Run as Administrator
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -All

# Alternative: Using DISM
DISM /Online /Enable-Feature /All /FeatureName:Microsoft-Hyper-V

# Restart required
Restart-Computer
```

### **Step 1.2: Create Directory Structure**

```powershell
# Create main VM directory
New-Item -Path "C:\VMs\Asgard" -ItemType Directory -Force

# Create subdirectories for organization
New-Item -Path "C:\VMs\Asgard\Servers" -ItemType Directory -Force
New-Item -Path "C:\VMs\Asgard\Workstations" -ItemType Directory -Force
New-Item -Path "C:\VMs\Asgard\ISOs" -ItemType Directory -Force
New-Item -Path "C:\VMs\Asgard\Scripts" -ItemType Directory -Force
New-Item -Path "C:\VMs\Asgard\Documentation" -ItemType Directory -Force
```

### **Step 1.3: Prepare ISO Files**

1. **Download Windows Server ISO**

   - Windows Server 2019/2022/2025
   - Place in: `C:\VMs\Asgard\ISOs\WindowsServer.iso`

2. **Download Windows Client ISO**
   - Windows 10/11 (22H2 or later recommended)
   - Place in: `C:\VMs\Asgard\ISOs\Windows10.iso`

---

## 🌐 **Phase 2: Network Infrastructure Setup**

### **Step 2.1: Create Virtual Switches**

#### **Production Network (External)**

```powershell
# Get available physical adapters
Get-NetAdapter -Physical | Where-Object { $_.Status -eq "Up" }

# Create external switch (replace with your adapter name)
New-VMSwitch -Name "ASGARD-Production" -NetAdapterName "Ethernet" -AllowManagementOS $true
```

#### **Management Network (Internal)**

```powershell
# Create internal switch
New-VMSwitch -Name "ASGARD-Management" -SwitchType Internal

# Configure IP for host management
$mgmtAdapter = Get-NetAdapter -Name "vEthernet (ASGARD-Management)"
New-NetIPAddress -IPAddress 10.0.100.1 -PrefixLength 24 -InterfaceIndex $mgmtAdapter.ifIndex
```

#### **Client Network (Internal)**

```powershell
# Create client network switch
New-VMSwitch -Name "ASGARD-Clients" -SwitchType Internal

# Configure IP for host
$clientAdapter = Get-NetAdapter -Name "vEthernet (ASGARD-Clients)"
New-NetIPAddress -IPAddress 10.0.20.1 -PrefixLength 22 -InterfaceIndex $clientAdapter.ifIndex
```

#### **DMZ Network (Private)**

```powershell
# Create DMZ switch (isolated)
New-VMSwitch -Name "ASGARD-DMZ" -SwitchType Private
```

#### **Configure NAT**

```powershell
# Create NAT for internal networks
New-NetNat -Name "ASGARD-NAT" -InternalIPInterfaceAddressPrefix 10.0.0.0/8
```

### **Step 2.2: Verify Network Configuration**

```powershell
# List all VM switches
Get-VMSwitch | Format-Table Name, SwitchType, NetAdapterInterfaceDescription

# Verify NAT configuration
Get-NetNat

# Check IP configurations
Get-NetIPAddress | Where-Object { $_.InterfaceAlias -like "*ASGARD*" }
```

---

## 🖥️ **Phase 3: Server Infrastructure Deployment**

### **Step 3.1: Create Primary Domain Controller (ODIN-DC01)**

#### **Create VM**

```powershell
# Define VM specifications
$VMName = "ODIN-DC01"
$VMPath = "C:\VMs\Asgard\Servers\$VMName"
$Memory = 8GB
$VHDSize = 80GB
$CPUCount = 4

# Create VM
New-VM -Name $VMName -Path $VMPath -MemoryStartupBytes $Memory -Generation 2
Set-VM -Name $VMName -ProcessorCount $CPUCount

# Create and attach VHD
$VHDPath = "$VMPath\$VMName.vhdx"
New-VHD -Path $VHDPath -SizeBytes $VHDSize -Dynamic
Add-VMHardDiskDrive -VMName $VMName -Path $VHDPath

# Configure network adapters
Add-VMNetworkAdapter -VMName $VMName -SwitchName "ASGARD-Production" -Name "Production"
Add-VMNetworkAdapter -VMName $VMName -SwitchName "ASGARD-Management" -Name "Management"

# Attach ISO
$ISOPath = "C:\VMs\Asgard\ISOs\WindowsServer.iso"
Set-VMDvdDrive -VMName $VMName -Path $ISOPath

# Configure boot order
$VMDvdDrive = Get-VMDvdDrive -VMName $VMName
$VMHardDisk = Get-VMHardDiskDrive -VMName $VMName
Set-VMFirmware -VMName $VMName -BootOrder $VMDvdDrive, $VMHardDisk
```

#### **Install Windows Server**

1. **Start VM**: `Start-VM -Name "ODIN-DC01"`
2. **Connect**: Use Hyper-V Manager or `vmconnect localhost "ODIN-DC01"`
3. **Install Windows Server** with Desktop Experience
4. **Configure Basic Settings**:
   - Computer Name: `ODIN-DC01`
   - Administrator Password: (Choose secure password)
   - Network Configuration:
     - Production NIC: DHCP (temporary)
     - Management NIC: Static IP `10.0.100.10/24`

#### **Promote to Domain Controller**

```powershell
# Run on ODIN-DC01 after initial setup
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

# Import AD DS module
Import-Module ADDSDeployment

# Create new forest
$DomainName = "asgard.local"
$SafeModePassword = ConvertTo-SecureString "YourSecurePassword123!" -AsPlainText -Force

Install-ADDSForest `
    -CreateDnsDelegation:$false `
    -DatabasePath "C:\Windows\NTDS" `
    -DomainMode "WinThreshold" `
    -DomainName $DomainName `
    -DomainNetbiosName "ASGARD" `
    -ForestMode "WinThreshold" `
    -InstallDns:$true `
    -LogPath "C:\Windows\NTDS" `
    -NoRebootOnCompletion:$false `
    -SysvolPath "C:\Windows\SYSVOL" `
    -SafeModeAdministratorPassword $SafeModePassword `
    -Force:$true
```

### **Step 3.2: Create Secondary Domain Controller (FRIGG-DC02)**

#### **Create VM**

```powershell
$VMName = "FRIGG-DC02"
$VMPath = "C:\VMs\Asgard\Servers\$VMName"
$Memory = 6GB
$VHDSize = 60GB
$CPUCount = 3

# Create VM (same process as ODIN-DC01)
New-VM -Name $VMName -Path $VMPath -MemoryStartupBytes $Memory -Generation 2
Set-VM -Name $VMName -ProcessorCount $CPUCount

$VHDPath = "$VMPath\$VMName.vhdx"
New-VHD -Path $VHDPath -SizeBytes $VHDSize -Dynamic
Add-VMHardDiskDrive -VMName $VMName -Path $VHDPath

Add-VMNetworkAdapter -VMName $VMName -SwitchName "ASGARD-Production" -Name "Production"
Add-VMNetworkAdapter -VMName $VMName -SwitchName "ASGARD-Management" -Name "Management"

Set-VMDvdDrive -VMName $VMName -Path "C:\VMs\Asgard\ISOs\WindowsServer.iso"

$VMDvdDrive = Get-VMDvdDrive -VMName $VMName
$VMHardDisk = Get-VMHardDiskDrive -VMName $VMName
Set-VMFirmware -VMName $VMName -BootOrder $VMDvdDrive, $VMHardDisk
```

#### **Install and Configure**

1. Install Windows Server
2. Configure network settings:
   - Computer Name: `FRIGG-DC02`
   - Management NIC: `10.0.100.11/24`
   - DNS: `10.0.100.10` (ODIN-DC01)
3. Join domain and promote to DC

### **Step 3.3: Create File Server (HEIMDALL-FS01)**

#### **Create VM**

```powershell
$VMName = "HEIMDALL-FS01"
$VMPath = "C:\VMs\Asgard\Servers\$VMName"
$Memory = 8GB
$VHDSize = 120GB
$CPUCount = 4

# Create VM
New-VM -Name $VMName -Path $VMPath -MemoryStartupBytes $Memory -Generation 2
Set-VM -Name $VMName -ProcessorCount $CPUCount

$VHDPath = "$VMPath\$VMName.vhdx"
New-VHD -Path $VHDPath -SizeBytes $VHDSize -Dynamic
Add-VMHardDiskDrive -VMName $VMName -Path $VHDPath

Add-VMNetworkAdapter -VMName $VMName -SwitchName "ASGARD-Production" -Name "Production"
Add-VMNetworkAdapter -VMName $VMName -SwitchName "ASGARD-Management" -Name "Management"

Set-VMDvdDrive -VMName $VMName -Path "C:\VMs\Asgard\ISOs\WindowsServer.iso"

$VMDvdDrive = Get-VMDvdDrive -VMName $VMName
$VMHardDisk = Get-VMHardDiskDrive -VMName $VMName
Set-VMFirmware -VMName $VMName -BootOrder $VMDvdDrive, $VMHardDisk
```

#### **Configure File Server Role**

```powershell
# Run on HEIMDALL-FS01 after domain join
Install-WindowsFeature -Name File-Services -IncludeManagementTools
Install-WindowsFeature -Name FS-FileServer -IncludeManagementTools
Install-WindowsFeature -Name FS-DFS-Namespace -IncludeManagementTools
Install-WindowsFeature -Name FS-DFS-Replication -IncludeManagementTools
```

### **Step 3.4: Create Web Server (BALDER-WEB01)**

#### **Create VM**

```powershell
$VMName = "BALDER-WEB01"
$VMPath = "C:\VMs\Asgard\Servers\$VMName"
$Memory = 6GB
$VHDSize = 80GB
$CPUCount = 3

# Create VM (follow same pattern)
New-VM -Name $VMName -Path $VMPath -MemoryStartupBytes $Memory -Generation 2
Set-VM -Name $VMName -ProcessorCount $CPUCount

$VHDPath = "$VMPath\$VMName.vhdx"
New-VHD -Path $VHDPath -SizeBytes $VHDSize -Dynamic
Add-VMHardDiskDrive -VMName $VMName -Path $VHDPath

Add-VMNetworkAdapter -VMName $VMName -SwitchName "ASGARD-Production" -Name "Production"
Add-VMNetworkAdapter -VMName $VMName -SwitchName "ASGARD-DMZ" -Name "DMZ"
Add-VMNetworkAdapter -VMName $VMName -SwitchName "ASGARD-Management" -Name "Management"

Set-VMDvdDrive -VMName $VMName -Path "C:\VMs\Asgard\ISOs\WindowsServer.iso"

$VMDvdDrive = Get-VMDvdDrive -VMName $VMName
$VMHardDisk = Get-VMHardDiskDrive -VMName $VMName
Set-VMFirmware -VMName $VMName -BootOrder $VMDvdDrive, $VMHardDisk
```

#### **Configure IIS and Web Services**

```powershell
# Run on BALDER-WEB01 after domain join
Install-WindowsFeature -Name Web-Server -IncludeManagementTools
Install-WindowsFeature -Name Web-Asp-Net45 -IncludeManagementTools
Install-WindowsFeature -Name Web-Net-Ext45 -IncludeManagementTools
```

### **Step 3.5: Create Security Server (VIDAR-SEC01)**

#### **Create VM**

```powershell
$VMName = "VIDAR-SEC01"
$VMPath = "C:\VMs\Asgard\Servers\$VMName"
$Memory = 8GB
$VHDSize = 100GB
$CPUCount = 4

# Create VM (follow same pattern)
New-VM -Name $VMName -Path $VMPath -MemoryStartupBytes $Memory -Generation 2
Set-VM -Name $VMName -ProcessorCount $CPUCount

$VHDPath = "$VMPath\$VMName.vhdx"
New-VHD -Path $VHDPath -SizeBytes $VHDSize -Dynamic
Add-VMHardDiskDrive -VMName $VMName -Path $VHDPath

Add-VMNetworkAdapter -VMName $VMName -SwitchName "ASGARD-Production" -Name "Production"
Add-VMNetworkAdapter -VMName $VMName -SwitchName "ASGARD-Management" -Name "Management"

Set-VMDvdDrive -VMName $VMName -Path "C:\VMs\Asgard\ISOs\WindowsServer.iso"

$VMDvdDrive = Get-VMDvdDrive -VMName $VMName
$VMHardDisk = Get-VMHardDiskDrive -VMName $VMName
Set-VMFirmware -VMName $VMName -BootOrder $VMDvdDrive, $VMHardDisk
```

#### **Configure WSUS and Security Features**

```powershell
# Run on VIDAR-SEC01 after domain join
Install-WindowsFeature -Name UpdateServices -IncludeManagementTools
Install-WindowsFeature -Name RSAT-AD-Tools -IncludeManagementTools
```

---

## 💻 **Phase 4: Workstation Deployment**

### **Step 4.1: Create Workstation Template**

Create a PowerShell function to standardize workstation creation:

```powershell
function New-AsgardWorkstation {
    param(
        [string]$VMName,
        [int64]$Memory = 4GB,
        [int64]$VHDSize = 60GB,
        [int]$CPUCount = 2,
        [string]$Description = ""
    )

    $VMPath = "C:\VMs\Asgard\Workstations\$VMName"

    # Create VM
    New-VM -Name $VMName -Path $VMPath -MemoryStartupBytes $Memory -Generation 2
    Set-VM -Name $VMName -ProcessorCount $CPUCount -Notes $Description

    # Create and attach VHD
    $VHDPath = "$VMPath\$VMName.vhdx"
    New-VHD -Path $VHDPath -SizeBytes $VHDSize -Dynamic
    Add-VMHardDiskDrive -VMName $VMName -Path $VHDPath

    # Configure network
    Add-VMNetworkAdapter -VMName $VMName -SwitchName "ASGARD-Clients" -Name "Clients"

    # Attach client ISO
    Set-VMDvdDrive -VMName $VMName -Path "C:\VMs\Asgard\ISOs\Windows10.iso"

    # Configure boot order
    $VMDvdDrive = Get-VMDvdDrive -VMName $VMName
    $VMHardDisk = Get-VMHardDiskDrive -VMName $VMName
    Set-VMFirmware -VMName $VMName -BootOrder $VMDvdDrive, $VMHardDisk

    Write-Host "Created workstation: $VMName" -ForegroundColor Green
}
```

### **Step 4.2: Create All Workstations**

#### **IT Operations Department (Odin's Realm)**

```powershell
New-AsgardWorkstation -VMName "ODIN-WS01" -Memory 6GB -VHDSize 80GB -Description "Odin's Command Center"
New-AsgardWorkstation -VMName "THOR-WS01" -Memory 4GB -VHDSize 60GB -Description "Thor's Thunder Station"
New-AsgardWorkstation -VMName "LOKI-WS01" -Memory 3GB -VHDSize 60GB -Description "Loki's Mischief Machine"
New-AsgardWorkstation -VMName "HERMOD-WS01" -Memory 3GB -VHDSize 60GB -Description "Hermod's Messenger Terminal"
New-AsgardWorkstation -VMName "TYR-WS01" -Memory 3GB -VHDSize 60GB -Description "Tyr's Brave Station"
```

#### **Cybersecurity Department (Heimdall's Watch)**

```powershell
New-AsgardWorkstation -VMName "HEIMDALL-WS01" -Memory 6GB -VHDSize 80GB -Description "Heimdall's Watchtower"
New-AsgardWorkstation -VMName "MIMIR-WS01" -Memory 4GB -VHDSize 60GB -Description "Mimir's Wisdom Terminal"
New-AsgardWorkstation -VMName "HUGINN-WS01" -Memory 3GB -VHDSize 60GB -Description "Huginn's Surveillance Station"
New-AsgardWorkstation -VMName "MUNINN-WS01" -Memory 3GB -VHDSize 60GB -Description "Muninn's Memory Bank"
New-AsgardWorkstation -VMName "FENRIR-WS01" -Memory 4GB -VHDSize 60GB -Description "Fenrir's Attack Lab"
```

#### **Research & Development (Freya's Workshop)**

```powershell
New-AsgardWorkstation -VMName "FREYA-WS01" -Memory 6GB -VHDSize 100GB -Description "Freya's Innovation Lab"
New-AsgardWorkstation -VMName "NJORD-WS01" -Memory 4GB -VHDSize 80GB -Description "Njord's Wind Tunnel"
New-AsgardWorkstation -VMName "FREY-WS01" -Memory 4GB -VHDSize 80GB -Description "Frey's Prosperity Engine"
New-AsgardWorkstation -VMName "JORMUNGANDR-WS01" -Memory 4GB -VHDSize 80GB -Description "Jormungandr's Data Lake"
New-AsgardWorkstation -VMName "SLEIPNIR-WS01" -Memory 4GB -VHDSize 80GB -Description "Sleipnir's Speed Demon"
```

#### **Finance & Administration (Frigg's Treasury)**

```powershell
New-AsgardWorkstation -VMName "FRIGG-WS01" -Memory 4GB -VHDSize 60GB -Description "Frigg's Treasury Terminal"
New-AsgardWorkstation -VMName "EIR-WS01" -Memory 3GB -VHDSize 60GB -Description "Eir's Healing Touch"
New-AsgardWorkstation -VMName "SAGA-WS01" -Memory 3GB -VHDSize 60GB -Description "Saga's Story Keeper"
New-AsgardWorkstation -VMName "VAR-WS01" -Memory 3GB -VHDSize 60GB -Description "Var's Oath Guardian"
New-AsgardWorkstation -VMName "FORSETI-WS01" -Memory 3GB -VHDSize 60GB -Description "Forseti's Justice Scale"
```

#### **Human Resources (Sif's Domain)**

```powershell
New-AsgardWorkstation -VMName "SIF-WS01" -Memory 4GB -VHDSize 60GB -Description "Sif's Golden Gateway"
New-AsgardWorkstation -VMName "IDUN-WS01" -Memory 3GB -VHDSize 60GB -Description "Idun's Eternal Garden"
New-AsgardWorkstation -VMName "BRAGI-WS01" -Memory 3GB -VHDSize 60GB -Description "Bragi's Poetic Portal"
New-AsgardWorkstation -VMName "HEL-WS01" -Memory 3GB -VHDSize 60GB -Description "Hel's Dual Nature"
New-AsgardWorkstation -VMName "SIGYN-WS01" -Memory 3GB -VHDSize 60GB -Description "Sigyn's Faithful Watch"
```

---

## 👥 **Phase 5: Active Directory Configuration**

### **Step 5.1: Create Organizational Units**

Run on ODIN-DC01:

```powershell
# Import AD module
Import-Module ActiveDirectory

# Create main OU structure
New-ADOrganizationalUnit -Name "Asgard Technologies" -Path "DC=asgard,DC=local"
$AsgardOU = "OU=Asgard Technologies,DC=asgard,DC=local"

# Create department OUs
New-ADOrganizationalUnit -Name "IT Operations" -Path $AsgardOU
New-ADOrganizationalUnit -Name "Cybersecurity" -Path $AsgardOU
New-ADOrganizationalUnit -Name "Research & Development" -Path $AsgardOU
New-ADOrganizationalUnit -Name "Finance & Administration" -Path $AsgardOU
New-ADOrganizationalUnit -Name "Human Resources" -Path $AsgardOU

# Create computer OUs
New-ADOrganizationalUnit -Name "Servers" -Path $AsgardOU
New-ADOrganizationalUnit -Name "Workstations" -Path $AsgardOU
```

### **Step 5.2: Create Security Groups**

```powershell
# Department groups
New-ADGroup -Name "IT-Operations" -GroupScope Global -GroupCategory Security -Path "OU=IT Operations,$AsgardOU"
New-ADGroup -Name "Cybersecurity" -GroupScope Global -GroupCategory Security -Path "OU=Cybersecurity,$AsgardOU"
New-ADGroup -Name "Research-Development" -GroupScope Global -GroupCategory Security -Path "OU=Research & Development,$AsgardOU"
New-ADGroup -Name "Finance-Administration" -GroupScope Global -GroupCategory Security -Path "OU=Finance & Administration,$AsgardOU"
New-ADGroup -Name "Human-Resources" -GroupScope Global -GroupCategory Security -Path "OU=Human Resources,$AsgardOU"

# Functional groups
New-ADGroup -Name "Domain Admins - Asgard" -GroupScope Global -GroupCategory Security -Path $AsgardOU
New-ADGroup -Name "Server Administrators" -GroupScope Global -GroupCategory Security -Path $AsgardOU
New-ADGroup -Name "Workstation Users" -GroupScope Global -GroupCategory Security -Path $AsgardOU
```

### **Step 5.3: Create User Accounts**

#### **IT Operations Department**

```powershell
$ITOperationsOU = "OU=IT Operations,$AsgardOU"
$SecurePassword = ConvertTo-SecureString "TempPassword123!" -AsPlainText -Force

# Create users
New-ADUser -Name "Odin Allfather" -SamAccountName "odin.allfather" -UserPrincipalName "odin.allfather@asgard.local" -Path $ITOperationsOU -AccountPassword $SecurePassword -Enabled $true -ChangePasswordAtLogon $true -Title "CTO & Domain Admin" -Department "IT Operations"

New-ADUser -Name "Thor Thunderer" -SamAccountName "thor.thunderer" -UserPrincipalName "thor.thunderer@asgard.local" -Path $ITOperationsOU -AccountPassword $SecurePassword -Enabled $true -ChangePasswordAtLogon $true -Title "Senior Systems Engineer" -Department "IT Operations"

New-ADUser -Name "Loki Trickster" -SamAccountName "loki.trickster" -UserPrincipalName "loki.trickster@asgard.local" -Path $ITOperationsOU -AccountPassword $SecurePassword -Enabled $true -ChangePasswordAtLogon $true -Title "Junior Developer (Intern)" -Department "IT Operations"

New-ADUser -Name "Hermod Messenger" -SamAccountName "hermod.messenger" -UserPrincipalName "hermod.messenger@asgard.local" -Path $ITOperationsOU -AccountPassword $SecurePassword -Enabled $true -ChangePasswordAtLogon $true -Title "Network Administrator" -Department "IT Operations"

New-ADUser -Name "Tyr Brave" -SamAccountName "tyr.brave" -UserPrincipalName "tyr.brave@asgard.local" -Path $ITOperationsOU -AccountPassword $SecurePassword -Enabled $true -ChangePasswordAtLogon $true -Title "Security Analyst" -Department "IT Operations"

# Add to groups
Add-ADGroupMember -Identity "IT-Operations" -Members "odin.allfather", "thor.thunderer", "loki.trickster", "hermod.messenger", "tyr.brave"
Add-ADGroupMember -Identity "Domain Admins" -Members "odin.allfather"
```

#### **Continue for all departments...**

_Note: Due to space constraints, the full user creation script would continue with all 25 users across the 5 departments. The pattern remains consistent for each department._

---

## 🔧 **Phase 6: Services Configuration**

### **Step 6.1: Configure DNS**

On ODIN-DC01:

```powershell
# Create DNS zones for internal services
Add-DnsServerPrimaryZone -Name "services.asgard.local" -ZoneFile "services.asgard.local.dns" -DynamicUpdate Secure

# Add service records
Add-DnsServerResourceRecordA -ZoneName "asgard.local" -Name "fs01" -IPv4Address "10.0.10.20"
Add-DnsServerResourceRecordA -ZoneName "asgard.local" -Name "web01" -IPv4Address "10.0.10.30"
Add-DnsServerResourceRecordA -ZoneName "asgard.local" -Name "sec01" -IPv4Address "10.0.10.40"

# Create CNAME records
Add-DnsServerResourceRecordCName -ZoneName "asgard.local" -Name "fileserver" -HostNameAlias "fs01.asgard.local"
Add-DnsServerResourceRecordCName -ZoneName "asgard.local" -Name "webserver" -HostNameAlias "web01.asgard.local"
```

### **Step 6.2: Configure DHCP**

On ODIN-DC01:

```powershell
# Install DHCP role
Install-WindowsFeature -Name DHCP -IncludeManagementTools

# Configure DHCP scopes
Add-DhcpServerV4Scope -Name "Client Network" -StartRange 10.0.20.100 -EndRange 10.0.23.200 -SubnetMask 255.255.252.0

# Set DHCP options
Set-DhcpServerV4OptionValue -ScopeId 10.0.20.0 -OptionId 3 -Value 10.0.20.1  # Default Gateway
Set-DhcpServerV4OptionValue -ScopeId 10.0.20.0 -OptionId 6 -Value 10.0.10.10  # DNS Server
Set-DhcpServerV4OptionValue -ScopeId 10.0.20.0 -OptionId 15 -Value "asgard.local"  # Domain Name

# Authorize DHCP server
Add-DhcpServerInDC -DnsName "odin-dc01.asgard.local"
```

---

## 📝 **Phase 7: Group Policy Configuration**

### **Step 7.1: Create Group Policy Objects**

```powershell
# Create GPOs for different purposes
New-GPO -Name "Asgard Workstation Policy" -Domain "asgard.local"
New-GPO -Name "Asgard Server Policy" -Domain "asgard.local"
New-GPO -Name "Asgard Security Policy" -Domain "asgard.local"

# Link GPOs to OUs
New-GPLink -Name "Asgard Workstation Policy" -Target "OU=Workstations,OU=Asgard Technologies,DC=asgard,DC=local"
New-GPLink -Name "Asgard Server Policy" -Target "OU=Servers,OU=Asgard Technologies,DC=asgard,DC=local"
```

### **Step 7.2: Configure Security Policies**

Example security settings:

```powershell
# Password policy
Set-ADDefaultDomainPasswordPolicy -Identity "asgard.local" -MinPasswordLength 8 -MaxPasswordAge 90 -MinPasswordAge 1 -PasswordHistoryCount 12

# Account lockout policy
Set-ADDefaultDomainPasswordPolicy -Identity "asgard.local" -LockoutDuration 30 -LockoutObservationWindow 30 -LockoutThreshold 5
```

---

## ✅ **Phase 8: Verification and Testing**

### **Step 8.1: Network Connectivity Tests**

```powershell
# Test from host machine
Test-NetConnection -ComputerName "10.0.10.10" -Port 53  # DNS to ODIN-DC01
Test-NetConnection -ComputerName "10.0.10.20" -Port 445  # SMB to HEIMDALL-FS01
Test-NetConnection -ComputerName "10.0.10.30" -Port 80   # HTTP to BALDER-WEB01
```

### **Step 8.2: Active Directory Verification**

```powershell
# Verify AD structure
Get-ADOrganizationalUnit -Filter * | Select-Object Name, DistinguishedName
Get-ADUser -Filter * | Select-Object Name, SamAccountName, Department
Get-ADGroup -Filter * | Select-Object Name, GroupScope, GroupCategory
```

### **Step 8.3: Service Validation**

```powershell
# Check domain controller services
Get-Service -Name "ADWS", "DNS", "DHCP", "Netlogon", "KDC" | Select-Object Name, Status
```

---

## 🚀 **Phase 9: Client Configuration**

### **Step 9.1: Install and Configure Workstations**

For each workstation:

1. **Install Windows 10/11**
2. **Join to Domain**:
   ```cmd
   # Run as Administrator
   netdom join %COMPUTERNAME% /domain:asgard.local /userd:odin.allfather /passwordd:*
   ```
3. **Configure Network Settings**:
   - Use DHCP for IP configuration
   - Verify DNS resolution to `asgard.local`

### **Step 9.2: User Logon Testing**

Test user accounts:

- Log on to various workstations with created user accounts
- Verify group membership and permissions
- Test file share access
- Confirm Group Policy application

---

## 📊 **Phase 10: Monitoring and Maintenance**

### **Step 10.1: Set Up Basic Monitoring**

```powershell
# Enable audit policies
auditpol /set /category:"Logon/Logoff" /success:enable /failure:enable
auditpol /set /category:"Account Logon" /success:enable /failure:enable
auditpol /set /category:"Object Access" /success:enable /failure:enable
```

### **Step 10.2: Create Maintenance Scripts**

Create PowerShell scripts for regular maintenance:

- **Health checks** for all VMs
- **Backup verification**
- **Performance monitoring**
- **Event log analysis**

---

## 🎯 **Expected Results**

After completing this manual setup, you will have:

### **Infrastructure**

- ✅ **5 Servers**: Fully configured and domain-joined
- ✅ **20 Workstations**: Ready for user logon
- ✅ **4 Network Segments**: Properly isolated and configured
- ✅ **NAT Configuration**: Internet access for internal networks

### **Active Directory**

- ✅ **25 User Accounts**: Across 5 departments with realistic roles
- ✅ **Security Groups**: Department and functional groups
- ✅ **Organizational Units**: Logical AD structure
- ✅ **Group Policies**: Basic security and configuration policies

### **Services**

- ✅ **DNS**: Name resolution for internal services
- ✅ **DHCP**: Automatic IP configuration for clients
- ✅ **File Services**: Central file storage and sharing
- ✅ **Web Services**: IIS with basic websites
- ✅ **Security Services**: WSUS and monitoring

### **Network Architecture**

```
Production:  10.0.10.0/24  (Servers)
Management:  10.0.100.0/24 (Admin Access)
Clients:     10.0.20.0/22  (Workstations - 1022 addresses)
DMZ:         10.0.50.0/24  (External Services)
```

### **Key Server IPs**

```
ODIN-DC01:     10.0.10.10  (Primary DC)
FRIGG-DC02:    10.0.10.11  (Secondary DC)
HEIMDALL-FS01: 10.0.10.20  (File Server)
BALDER-WEB01:  10.0.10.30  (Web Server)
VIDAR-SEC01:   10.0.10.40  (Security Server)
```

---

## 🛠️ **Troubleshooting**

### **Common Issues and Solutions**

#### **Network Connectivity**

- **Issue**: VMs cannot reach internet
- **Solution**: Verify NAT configuration and external switch setup

#### **Domain Join Failures**

- **Issue**: Workstations cannot join domain
- **Solution**: Check DNS configuration and domain controller availability

#### **Performance Issues**

- **Issue**: Slow VM performance
- **Solution**: Adjust memory allocation, check host resources, use SSD storage

#### **Authentication Problems**

- **Issue**: Users cannot log on
- **Solution**: Verify user account status, check domain controller services

---

## 📚 **Next Steps**

After completing the basic setup:

1. **Implement advanced security policies**
2. **Configure backup and disaster recovery**
3. **Set up monitoring and alerting**
4. **Create custom applications and services**
5. **Implement certificate services**
6. **Configure VPN access**
7. **Set up additional sites and replication**

---

## 🏆 **Congratulations!**

You have successfully deployed the Asgard Technologies Windows Server lab environment manually. This setup provides a solid foundation for learning Windows Server administration, Active Directory management, and enterprise networking concepts.

The Norse mythology theme makes the learning experience engaging while providing realistic enterprise scenarios for hands-on practice.

**May the Allfather guide your Windows Server journey!** 🏰⚡
