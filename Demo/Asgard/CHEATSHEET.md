# 🏰 **ASGARD TECHNOLOGIES** - Advanced Administrator Cheatsheet

## 🌐 **Network Configuration**

### **IP Address Scheme**

```
Production:  10.0.10.0/24   (Servers)
Management:  10.0.100.0/24  (Admin Access)
Clients:     10.0.20.0/22   (Workstations - 1022 addresses)
DMZ:         10.0.50.0/24   (External Services)
IoT/Devices: 10.0.60.0/24   (Printers, cameras, sensors)
```

### **Server IP Addresses**

```
ODIN-DC01:     10.0.10.10  (Primary DC)
FRIGG-DC02:    10.0.10.11  (Secondary DC)
HEIMDALL-FS01: 10.0.10.20  (File Server)
BALDER-WEB01:  10.0.10.30  (Web Server)
VIDAR-SEC01:   10.0.10.40  (Security Server)
```

## 🔧 **Network Troubleshooting & Routing**

### **Routing Table Analysis**

```powershell
# [HOST] View complete routing table for all networks
route print

# [HOST] Expected output shows multiple network interfaces:
# - 10.0.10.0/24 with interface 10.0.10.1 (Server network)
# - 10.0.20.0/22 with interface 10.0.20.1 (Client network)
# - 10.0.100.0/24 with interface 10.0.100.1 (Management network)

# [SERVER VM] or [CLIENT VM] Check VM routing table
route print

# [CLIENT VM] Common issue: Wrong gateway configuration
# If VM shows gateway 10.0.23.1 but should be 10.0.20.1
```

### **Network Connectivity Troubleshooting**

```powershell
# [CLIENT VM] Test connectivity to domain controller
ping 10.0.10.10 -n 2

# [CLIENT VM] If getting "Destination host unreachable" from 10.0.23.10:
# This indicates gateway misconfiguration

# [CLIENT VM] Trace route to see network path
tracert 10.0.10.10

# [CLIENT VM] Check network configuration
ipconfig /all

# [HOST] Verify host has correct network interfaces
Get-NetAdapter | Where-Object {$_.Status -eq "Up"} | Select Name, InterfaceDescription, LinkSpeed
```

### **Gateway Configuration Fixes**

```powershell
# [CLIENT VM] Fix incorrect gateway (common issue)
# Remove wrong gateway first
Remove-NetRoute -DestinationPrefix "0.0.0.0/0" -Confirm:$false

# [CLIENT VM] Add correct gateway for 10.0.20.0/22 network
New-NetRoute -DestinationPrefix "0.0.0.0/0" -NextHop "10.0.20.1" -InterfaceAlias "Ethernet"

# [CLIENT VM] Alternative method - Set complete network config
netsh interface ip set address "Ethernet" static 10.0.20.50 255.255.252.0 10.0.20.1

# [CLIENT VM] Set DNS to domain controller
netsh interface ip set dns "Ethernet" static 10.0.10.10
```

### **IP Address Conflict Resolution**

```powershell
# [HOST] Check for IP conflicts on host network interfaces
Get-NetIPAddress | Where-Object {$_.AddressFamily -eq "IPv4"} | Sort-Object IPAddress

# [CLIENT VM] Assign unique IP in client range (avoid conflicts)
# Use IPs like 10.0.20.50, 10.0.20.51, etc. (not 10.0.23.10 which might conflict)
New-NetIPAddress -InterfaceAlias "Ethernet" -IPAddress 10.0.20.50 -PrefixLength 22 -DefaultGateway 10.0.20.1

# [CLIENT VM] Verify no duplicate IPs
ping 10.0.20.50  # Should get reply if IP is in use

# [CLIENT VM] Release and renew DHCP (if using DHCP)
ipconfig /release
ipconfig /renew
```

### **Domain Join Network Prerequisites**

```powershell
# [CLIENT VM] Pre-domain join network validation checklist
# 1. Test DNS resolution
nslookup asgard.local 10.0.10.10
nslookup 10.0.10.10

# 2. Test required ports to DC
$DCPorts = @(53, 88, 389, 636, 445, 3268, 3269)
$DCPorts | ForEach-Object {
    $Result = Test-NetConnection -ComputerName 10.0.10.10 -Port $_
    Write-Host "Port $_ : $($Result.TcpTestSucceeded)" -ForegroundColor $(if($Result.TcpTestSucceeded){"Green"}else{"Red"})
}

# 3. Verify time sync (critical for Kerberos)
w32tm /query /status
w32tm /config /manualpeerlist:"10.0.10.10" /syncfromflags:manual

# [CLIENT VM] Fix common domain join network issues
# Set correct DNS
Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses 10.0.10.10

# Clear DNS cache
ipconfig /flushdns

# Register with DNS
ipconfig /registerdns
```

## 🚀 **Quick Deployment Commands**

### **Virtual Switch Setup**

```powershell
# [HOST] Production Network
New-VMSwitch -Name "ASGARD-Production" -NetAdapterName "Ethernet" -AllowManagementOS $true

# [HOST] Management Network
New-VMSwitch -Name "ASGARD-Management" -SwitchType Internal
New-NetIPAddress -IPAddress 10.0.100.1 -PrefixLength 24 -InterfaceAlias "vEthernet (ASGARD-Management)"

# [HOST] Client Network
New-VMSwitch -Name "ASGARD-Clients" -SwitchType Internal
New-NetIPAddress -IPAddress 10.0.20.1 -PrefixLength 22 -InterfaceAlias "vEthernet (ASGARD-Clients)"

# [HOST] NAT Configuration
New-NetNat -Name "ASGARD-NAT" -InternalIPInterfaceAddressPrefix 10.0.0.0/8
```

### **DHCP Configuration**

```powershell
# [SERVER VM] DHCP Scope
Add-DhcpServerV4Scope -Name "Client Network" -StartRange 10.0.20.100 -EndRange 10.0.23.200 -SubnetMask 255.255.252.0

# [SERVER VM] DHCP Options (CRITICAL: Correct gateway)
Set-DhcpServerV4OptionValue -ScopeId 10.0.20.0 -OptionId 3 -Value 10.0.20.1    # Gateway
Set-DhcpServerV4OptionValue -ScopeId 10.0.20.0 -OptionId 6 -Value 10.0.10.10   # DNS
Set-DhcpServerV4OptionValue -ScopeId 10.0.20.0 -OptionId 15 -Value "asgard.local" # Domain
```

## 👥 **Key User Accounts**

### **Administrative Accounts**

```
odin.allfather     - CTO & Domain Admin
heimdall.guardian  - CISO
frigg.queen       - CFO
```

### **Department Heads**

```
IT Operations:     odin.allfather (Odin's Realm)
Cybersecurity:     heimdall.guardian (Heimdall's Watch)
R&D:              freya.seidr (Freya's Workshop)
Finance:          frigg.queen (Frigg's Treasury)
HR:               sif.golden (Sif's Domain)
```

## 🔧 **Advanced PowerShell Arsenal**

### **Windows 11 Client Setup & OOBE Bypass**

```cmd
# Windows 11 Network Bypass during OOBE Setup
# This command bypasses network requirements and goes directly to local account setup
OOBE\BYPASSNRO

# Alternative methods for Windows 11 OOBE bypass:
# 1. During network setup screen, press Shift+F10 to open Command Prompt
# 2. Type: OOBE\BYPASSNRO
# 3. Press Enter - the system will restart and skip network requirements
# 4. You can then create a local account without Microsoft account requirement

# For automated deployment via PowerShell (run as administrator):
Start-Process -FilePath "cmd.exe" -ArgumentList "/c OOBE\BYPASSNRO" -Wait

# Additional Windows 11 OOBE bypass techniques:
# Method 1: Kill network connection during setup
taskkill /f /im NetworkConnectionFlow.exe

# Method 2: Disable network adapter temporarily
Get-NetAdapter | Disable-NetAdapter -Confirm:$false
# Re-enable after OOBE: Get-NetAdapter | Enable-NetAdapter -Confirm:$false
```

### **Domain Operations & Authentication**

```powershell
# [CLIENT VM] Domain join with comprehensive error handling
Add-Computer -DomainName "asgard.local" -Credential (Get-Credential) -Restart -Force -Verbose -ErrorAction Stop

# [SERVER VM] Force domain replication across all DCs
repadmin /syncall /AdeP /e /q

# [CLIENT VM] or [SERVER VM] Check Kerberos tickets for current user
klist tickets

# [SERVER VM] Test domain controller health
dcdiag /v /c /d /e /s:ODIN-DC01

# [CLIENT VM] or [SERVER VM] Force Group Policy refresh
gpupdate /force /boot

# [SERVER VM] Check domain trust relationships
Get-ADTrust -Filter * | Format-Table -AutoSize

# [CLIENT VM] Validate domain controller secure channel
Test-ComputerSecureChannel -Server "ODIN-DC01.asgard.local" -Credential (Get-Credential) -Verbose
```

### **Elite Active Directory Queries**

```powershell
# Find users with passwords that never expire (security risk)
Get-ADUser -Filter {PasswordNeverExpires -eq $true -and Enabled -eq $true} | Select Name, LastLogonDate, PasswordLastSet, WhenCreated

# Identify stale computer accounts (not logged in for 90+ days)
$90Days = (Get-Date).AddDays(-90)
Get-ADComputer -Filter {LastLogonDate -lt $90Days -and Enabled -eq $true} | Select Name, LastLogonDate, OperatingSystem | Sort-Object LastLogonDate

# Find locked out accounts with details
Search-ADAccount -LockedOut | Get-ADUser -Properties LastBadPasswordAttempt, BadPwdCount | Select Name, LastBadPasswordAttempt, BadPwdCount, LockedOut

# Audit privileged group memberships
@("Domain Admins", "Enterprise Admins", "Schema Admins", "Administrators") | ForEach-Object {Write-Host "=== $_ ===" -ForegroundColor Cyan; Get-ADGroupMember $_ | Select Name, ObjectClass}

# Find service accounts and their SPNs
Get-ADUser -Filter {ServicePrincipalName -like "*"} | Select Name, ServicePrincipalName, LastLogonDate, PasswordLastSet

# Search for users with admin keywords in description
Get-ADUser -Filter {Description -like "*admin*" -or Description -like "*service*"} | Select Name, Description, Enabled

# Find recently created accounts (last 30 days)
$30Days = (Get-Date).AddDays(-30)
Get-ADUser -Filter {WhenCreated -gt $30Days} | Select Name, WhenCreated, Enabled | Sort-Object WhenCreated -Descending

# Get password policy details
Get-ADDefaultDomainPasswordPolicy | Format-List *

# Find users with non-expiring passwords in sensitive groups
Get-ADGroupMember "Domain Admins" | Get-ADUser -Properties PasswordNeverExpires | Where-Object {$_.PasswordNeverExpires -eq $true}
```

### **Network Diagnostics & Penetration Testing**

```powershell
# [CLIENT VM] or [HOST] Comprehensive network connectivity test suite
$TestPorts = @(
    @{Host="10.0.10.10"; Port=53; Service="DNS"},
    @{Host="10.0.10.10"; Port=88; Service="Kerberos"},
    @{Host="10.0.10.10"; Port=389; Service="LDAP"},
    @{Host="10.0.10.10"; Port=636; Service="LDAPS"},
    @{Host="10.0.10.20"; Port=445; Service="SMB"},
    @{Host="10.0.10.30"; Port=80; Service="HTTP"},
    @{Host="10.0.10.30"; Port=443; Service="HTTPS"}
)
$TestPorts | ForEach-Object {Test-NetConnection -ComputerName $_.Host -Port $_.Port | Select ComputerName, RemotePort, @{n="Service";e={$_.Service}}, TcpTestSucceeded}

# Advanced network scanning (be careful!)
1..254 | ForEach-Object {Test-NetConnection -ComputerName "10.0.10.$_" -Port 22 -InformationLevel Quiet -WarningAction SilentlyContinue} | Where-Object {$_.TcpTestSucceeded}

# DNS enumeration and validation
@("asgard.local", "_ldap._tcp.asgard.local", "_kerberos._tcp.asgard.local") | ForEach-Object {Resolve-DnsName -Name $_ -Server "10.0.10.10" -Type ALL}

# Network adapter deep dive
Get-NetAdapter | Where-Object {$_.Status -eq "Up"} | Get-NetAdapterAdvancedProperty | Select Name, DisplayName, DisplayValue

# Real-time network monitoring
Get-Counter "\Network Interface(*)\Bytes Total/sec" -SampleInterval 1 -MaxSamples 10

# Show established connections with process info
Get-NetTCPConnection | Where-Object {$_.State -eq "Established"} | Select LocalAddress, LocalPort, RemoteAddress, RemotePort, @{n="ProcessName";e={(Get-Process -Id $_.OwningProcess).ProcessName}}

# Network trace for advanced troubleshooting
netsh trace start capture=yes provider=Microsoft-Windows-TCPIP maxsize=100MB
# Run your problematic operation
# netsh trace stop
```

### **System Performance & Health Monitoring**

```powershell
# Real-time performance dashboard
while($true) {
    Clear-Host
    Write-Host "=== ASGARD SYSTEM MONITOR ===" -ForegroundColor Green
    Get-Counter "\Processor(_Total)\% Processor Time", "\Memory\Available MBytes", "\LogicalDisk(C:)\% Free Space" | Select CounterSamples | Format-Table -AutoSize
    Start-Sleep 5
}

# Top resource consumers
Get-Process | Sort-Object WorkingSet -Descending | Select-Object -First 10 ProcessName, @{n="Memory(MB)";e={[math]::Round($_.WorkingSet/1MB,2)}}, CPU, Id

# Disk space analysis with alerts
Get-WmiObject -Class Win32_LogicalDisk | ForEach-Object {
    $FreePercent = [math]::Round(($_.FreeSpace/$_.Size)*100,2)
    $Status = if($FreePercent -lt 10){"CRITICAL"}elseif($FreePercent -lt 20){"WARNING"}else{"OK"}
    [PSCustomObject]@{Drive=$_.DeviceID; "Size(GB)"=[math]::Round($_.Size/1GB,2); "Free(GB)"=[math]::Round($_.FreeSpace/1GB,2); "Free%"=$FreePercent; Status=$Status}
}

# Event log analysis with filtering
Get-WinEvent -FilterHashtable @{LogName='System','Application'; Level=1,2,3; StartTime=(Get-Date).AddHours(-24)} |
    Group-Object Id | Sort-Object Count -Descending | Select Count, Name, @{n="Sample";e={$_.Group[0].Message.Substring(0,[Math]::Min(100,$_.Group[0].Message.Length))}}

# Service health check
Get-Service | Where-Object {$_.StartType -eq "Automatic" -and $_.Status -ne "Running"} |
    Select Name, Status, StartType, @{n="Description";e={(Get-WmiObject -Class Win32_Service -Filter "Name='$($_.Name)'").Description}}

# Windows Update status
Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 10 HotFixID, Description, InstalledOn
```

### **Security & Forensics Commands**

```powershell
# Failed login analysis
Get-WinEvent -FilterHashtable @{LogName='Security'; ID=4625; StartTime=(Get-Date).AddDays(-1)} |
    Select TimeCreated, @{n="Account";e={$_.Properties[5].Value}}, @{n="SourceIP";e={$_.Properties[19].Value}}, @{n="Reason";e={$_.Properties[8].Value}} |
    Group-Object Account | Sort-Object Count -Descending

# Successful logons from external IPs
Get-WinEvent -FilterHashtable @{LogName='Security'; ID=4624; StartTime=(Get-Date).AddDays(-1)} |
    Where-Object {$_.Properties[18].Value -notlike "10.0.*" -and $_.Properties[18].Value -ne "-" -and $_.Properties[18].Value -ne "127.0.0.1"} |
    Select TimeCreated, @{n="Account";e={$_.Properties[5].Value}}, @{n="SourceIP";e={$_.Properties[18].Value}}

# Local administrators audit
Get-LocalGroupMember -Group "Administrators" | Select Name, ObjectClass, PrincipalSource

# Installed software inventory
Get-WmiObject -Class Win32_Product | Select Name, Version, Vendor, InstallDate | Sort-Object Name

# Network shares and permissions audit
Get-SmbShare | ForEach-Object {
    $Share = $_
    Get-SmbShareAccess -Name $Share.Name | Select @{n="ShareName";e={$Share.Name}}, AccountName, AccessControlType, AccessRight
}

# File integrity monitoring setup
$WatchFolder = "C:\ImportantData"
$Baseline = Get-ChildItem -Path $WatchFolder -Recurse -File | Get-FileHash
$Baseline | Export-Csv -Path "C:\FileBaseline.csv" -NoTypeInformation

# Registry monitoring for persistence
Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" | Format-List
Get-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" | Format-List

# Check for suspicious scheduled tasks
Get-ScheduledTask | Where-Object {$_.State -eq "Ready" -and $_.Principal.UserId -ne "SYSTEM"} | Select TaskName, State, @{n="User";e={$_.Principal.UserId}}, @{n="Action";e={$_.Actions.Execute}}
```

### **Hyper-V & Virtualization Management**

```powershell
# VM status dashboard
Get-VM | Select Name, State, CPUUsage, @{n="Memory(MB)";e={$_.MemoryAssigned/1MB}}, Uptime, Status

# VM performance monitoring
Get-VM | Get-VMProcessor | Select VMName, @{n="CPU%";e={$_.CPUUsage}}
Get-VM | Get-VMMemory | Select VMName, @{n="MemoryGB";e={[math]::Round($_.Assigned/1GB,2)}}, @{n="Demand%";e={[math]::Round(($_.Assigned/$_.Maximum)*100,2)}}

# Quick VM operations
# Start all VMs
Get-VM | Where-Object {$_.State -eq "Off"} | Start-VM -Verbose

# Create VM snapshot for all running VMs
Get-VM | Where-Object {$_.State -eq "Running"} | Checkpoint-VM -SnapshotName "Emergency-$(Get-Date -Format 'yyyy-MM-dd-HHmm')"

# VM network troubleshooting
Get-VM | Get-VMNetworkAdapter | Select VMName, SwitchName, MacAddress, IPAddresses

# Export VM configuration for backup
Get-VM | Export-VM -Path "C:\VMBackups" -Verbose
```

### **File System & Storage Forensics**

```powershell
# Find large files consuming space
Get-ChildItem -Path "C:\" -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object {$_.Length -gt 100MB} |
    Sort-Object Length -Descending |
    Select-Object -First 20 Name, @{n="Size(GB)";e={[math]::Round($_.Length/1GB,2)}}, DirectoryName, LastWriteTime

# Recent file modifications (potential data exfiltration)
Get-ChildItem -Path "C:\Users" -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object {$_.LastWriteTime -gt (Get-Date).AddDays(-1)} |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 50 Name, LastWriteTime, @{n="Size(KB)";e={[math]::Round($_.Length/1KB,2)}}, DirectoryName

# Duplicate file finder
Get-ChildItem -Path "C:\Users" -Recurse -File |
    Group-Object -Property @{Expression={Get-FileHash $_.FullName -Algorithm MD5 | Select-Object -ExpandProperty Hash}} |
    Where-Object {$_.Count -gt 1} |
    ForEach-Object {$_.Group | Select Name, FullName, @{n="DuplicateHash";e={$_.Group[0].Hash}}}

# File permission audit
Get-ChildItem -Path "C:\ImportantData" -Recurse | ForEach-Object {
    $Acl = Get-Acl $_.FullName
    $Acl.Access | Select @{n="Path";e={$_.FullName}}, IdentityReference, FileSystemRights, AccessControlType
}

# Shadow copy analysis
vssadmin list shadows

# USB device history
Get-WmiObject -Class Win32_LogicalDisk | Where-Object {$_.DriveType -eq 2} | Select DeviceID, VolumeName, Size
```

### **Network Share & File Server Management**

```powershell
# Create advanced network share with detailed permissions
New-SmbShare -Name "AsgardSecure" -Path "C:\AsgardSecure" -FullAccess "asgard\Domain Admins" -ChangeAccess "asgard\IT_Operations" -ReadAccess "asgard\Domain Users" -FolderEnumerationMode AccessBased

# Share usage monitoring
Get-SmbOpenFile | Select ClientComputerName, ClientUserName, Path, SessionId

# DFS namespace management
Get-DfsnRoot | Select Path, State, Flags
Get-DfsnFolder -Path "\\asgard.local\shares\*" | Select Path, State, @{n="Targets";e={$_.Targets.Count}}

# File server resource manager quotas
# New-FsrmQuota -Path "C:\Users\*" -Size 5GB -Template "5 GB User Quota"

# Shared folder permissions report
Get-SmbShare | ForEach-Object {
    $ShareName = $_.Name
    Write-Host "=== Share: $ShareName ===" -ForegroundColor Yellow
    Get-SmbShareAccess -Name $ShareName | Format-Table -AutoSize
}
```

## 🛡️ **Security Essentials**

### **Default Passwords** (Change immediately!)

```
Local Admin: P@ssw0rd123!
Domain Admin: AsgardAdmin2024!
Service Accounts: ServiceP@ss123!
```

### **Critical Security Ports**

```
RDP:   3389 (Management network only)
WinRM: 5985/5986 (PowerShell remoting)
SSH:   22 (If OpenSSH enabled)
HTTPS: 443 (Web services)
LDAPS: 636 (Secure LDAP)
SMB:   445 (File sharing)
```

## 🔥 **Advanced Troubleshooting & Incident Response**

### **Domain & Authentication Issues**

```powershell
# Complete domain health check
dcdiag /v /c /d /e /s:ODIN-DC01 > C:\dcdiag_results.txt

# Kerberos troubleshooting
klist purge
kinit username@ASGARD.LOCAL

# Time synchronization fix (critical for Kerberos)
w32tm /config /manualpeerlist:"time.windows.com" /syncfromflags:manual
w32tm /resync /force

# SYSVOL replication check
dfsrdiag ReplicationState /member:ODIN-DC01 /rgname:"Domain System Volume"

# Reset computer account
Reset-ComputerMachinePassword -Credential (Get-Credential)

# DNS scavenging and cleanup
dnscmd /Config /ScavengingInterval 168
dnscmd /StartScavenging
```

### **Network Emergencies**

```powershell
# Emergency network reset
netsh int ip reset
netsh winsock reset
# [CLIENT VM] or [SERVER VM] DNS flush and network refresh
ipconfig /flushdns
ipconfig /release
ipconfig /renew
ipconfig /registerdns

# [HOST] or [CLIENT VM] or [SERVER VM] Route table emergency backup/restore
route print > C:\route_backup.txt
# route add 0.0.0.0 mask 0.0.0.0 10.0.100.1 metric 1

# Firewall emergency commands
netsh advfirewall set allprofiles state off  # EMERGENCY ONLY!
# netsh advfirewall reset  # Reset to defaults

# Network adapter reset
Get-NetAdapter | Reset-NetAdapter -Confirm:$false
```

### **Performance Emergency Response**

```powershell
# Kill resource-heavy processes
Get-Process | Where-Object {$_.CPU -gt 80 -or $_.WorkingSet -gt 1GB} | Stop-Process -Force -Confirm:$false

# Clear temp files and logs
Get-ChildItem -Path @("C:\Windows\Temp", "C:\Users\*\AppData\Local\Temp") -Recurse | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue

# Memory pressure relief
[System.GC]::Collect()
[System.GC]::WaitForPendingFinalizers()

# Service restart for common issues
@("Spooler", "DHCP", "DNS", "Netlogon") | ForEach-Object {Restart-Service $_ -Force -ErrorAction SilentlyContinue}
```

## 📊 **Monitoring & Alerting One-Liners**

```powershell
# CPU alert
if((Get-Counter "\Processor(_Total)\% Processor Time").CounterSamples.CookedValue -gt 80) {Write-Warning "HIGH CPU!"}

# Memory alert
if((Get-Counter "\Memory\Available MBytes").CounterSamples.CookedValue -lt 1000) {Write-Warning "LOW MEMORY!"}

# Disk space alert
Get-WmiObject Win32_LogicalDisk | Where-Object {$_.FreeSpace/$_.Size -lt 0.1} | ForEach-Object {Write-Warning "Disk $($_.DeviceID) is >90% full!"}

# Failed logins alert
if((Get-WinEvent -FilterHashtable @{LogName='Security'; ID=4625; StartTime=(Get-Date).AddMinutes(-5)} | Measure-Object).Count -gt 5) {Write-Warning "MULTIPLE FAILED LOGINS DETECTED!"}
```

## 🎯 **Pro Tips & Hidden Gems**

```powershell
# PowerShell profile customization for efficiency
# Add to $PROFILE:
function Get-DomainInfo { Get-ADDomain | Select Name, DomainMode, PDCEmulator }
function Get-NetworkSummary { Get-NetAdapter | Where-Object {$_.Status -eq "Up"} | Select Name, InterfaceDescription, LinkSpeed }
function Quick-Reboot { Restart-Computer -Force }

# Create custom PSReadLine shortcuts
Set-PSReadLineKeyHandler -Key Ctrl+d -Function MenuComplete
Set-PSReadLineKeyHandler -Key Ctrl+r -Function ReverseSearchHistory

# PowerShell ISE snippet for common tasks
$psISE.CurrentPowerShellTab.AddOnsMenu.Submenus.Add("Quick AD User", {Get-ADUser -Filter * | Out-GridView}, $null)

# Remote management session
Enter-PSSession -ComputerName ODIN-DC01 -Credential (Get-Credential)
```

## 📚 **Documentation References**

- **[Quick Start Guide](Guides/QUICK_START_ASGARD.md)** - 30-minute deployment
- **[Manual Setup Guide](MANUAL_SETUP_ASGARD.md)** - Detailed step-by-step
- **[Demo Setup Guide](Documentation/DEMO_SETUP_GUIDE.md)** - Complete reference
- **[Network Share Setup](Guides/ASGARD_NETWORK_SHARE_SETUP.md)** - File sharing
- **[Hardware Performance Guide](Documentation/HARDWARE_PERFORMANCE_GUIDE.md)** - Optimization

---

**🔥 Master these commands and become the Odin of Windows Server administration! 🔥**

**📖 For complete setup instructions, see: [QUICK_START_ASGARD.md](Guides/QUICK_START_ASGARD.md)**
