# ⚡ **OLYMPUS SYSTEMS** - Divine Administrator Cheatsheet

## 🌐 **Network Configuration**

### **IP Address Scheme**

```
Production:  10.0.10.0/24   (Divine Servers)
Management:  10.0.100.0/24  (Divine Admin Access)
Clients:     10.0.20.0/22   (Divine Workstations)
DMZ:         10.0.50.0/24   (External Divine Services)
IoT/Devices: 10.0.60.0/24   (Printers, cameras, sensors)
```

### **Server IP Addresses**

```
ZEUS-DC01:     10.0.10.10  (Primary DC)
HERA-DC02:     10.0.10.11  (Secondary DC)
HERMES-FS01:   10.0.10.20  (File Server)
APOLLO-WEB01:  10.0.10.30  (Web Server)
ATHENA-SEC01:  10.0.10.40  (Security Server)
```

## ⚡ **Divine Network Troubleshooting & Routing**

### **Divine Routing Table Analysis**

```powershell
# [HOST] View complete routing table for all divine networks
route print

# [HOST] Expected divine output shows multiple network interfaces:
# - 10.0.10.0/24 with interface 10.0.10.1 (Divine Server network)
# - 10.0.20.0/22 with interface 10.0.20.1 (Divine Client network)
# - 10.0.100.0/24 with interface 10.0.100.1 (Divine Management network)

# [SERVER VM] or [CLIENT VM] Check VM divine routing table
route print

# [CLIENT VM] Common divine issue: Wrong gateway configuration
# If divine VM shows gateway 10.0.23.1 but should be 10.0.20.1
# This angers Zeus and breaks divine connectivity
```

### **Divine Network Connectivity Troubleshooting**

```powershell
# [CLIENT VM] Test divine connectivity to Zeus (domain controller)
ping 10.0.10.10 -n 2

# [CLIENT VM] If getting "Destination host unreachable" from 10.0.23.10:
# This indicates Zeus is displeased with gateway misconfiguration

# [CLIENT VM] Divine trace route to see network path to Mount Olympus
tracert 10.0.10.10

# [CLIENT VM] Check divine network configuration
ipconfig /all

# [HOST] Verify host has correct divine network interfaces
Get-NetAdapter | Where-Object {$_.Status -eq "Up"} | Select Name, InterfaceDescription, LinkSpeed
```

### **Divine Gateway Configuration Fixes**

```powershell
# [CLIENT VM] Fix incorrect divine gateway (common divine transgression)
# Remove wrong gateway first (banish false gods)
Remove-NetRoute -DestinationPrefix "0.0.0.0/0" -Confirm:$false

# [CLIENT VM] Add correct divine gateway for 10.0.20.0/22 network
New-NetRoute -DestinationPrefix "0.0.0.0/0" -NextHop "10.0.20.1" -InterfaceAlias "Ethernet"

# [CLIENT VM] Alternative divine method - Set complete network config
netsh interface ip set address "Ethernet" static 10.0.20.50 255.255.252.0 10.0.20.1

# [CLIENT VM] Set DNS to Zeus (divine domain controller)
netsh interface ip set dns "Ethernet" static 10.0.10.10
```

### **Divine IP Address Conflict Resolution**

```powershell
# [HOST] Check for IP conflicts on divine host network interfaces
Get-NetIPAddress | Where-Object {$_.AddressFamily -eq "IPv4"} | Sort-Object IPAddress

# [CLIENT VM] Assign unique divine IP in client range (avoid divine conflicts)
# Use IPs like 10.0.20.50, 10.0.20.51, etc. (not 10.0.23.10 which might anger Zeus)
New-NetIPAddress -InterfaceAlias "Ethernet" -IPAddress 10.0.20.50 -PrefixLength 22 -DefaultGateway 10.0.20.1

# [CLIENT VM] Verify no duplicate divine IPs (Zeus despises duplicates)
ping 10.0.20.50  # Should get reply if divine IP is in use

# [CLIENT VM] Release and renew divine DHCP (if using divine DHCP)
ipconfig /release
ipconfig /renew
```

### **Divine Domain Join Network Prerequisites**

```powershell
# [CLIENT VM] Pre-domain join divine network validation checklist
# 1. Test divine DNS resolution
nslookup olympus.local 10.0.10.10
nslookup 10.0.10.10

# 2. Test required divine ports to Zeus
$ZeusPorts = @(53, 88, 389, 636, 445, 3268, 3269)
$ZeusPorts | ForEach-Object {
    $Result = Test-NetConnection -ComputerName 10.0.10.10 -Port $_
    $Status = if($Result.TcpTestSucceeded){"⚡ DIVINE"}else{"💀 MORTAL"}
    Write-Host "Divine Port $_ : $Status" -ForegroundColor $(if($Result.TcpTestSucceeded){"Cyan"}else{"Red"})
}

# 3. Verify divine time sync (critical for divine Kerberos)
w32tm /query /status
w32tm /config /manualpeerlist:"10.0.10.10" /syncfromflags:manual

# [CLIENT VM] Fix common divine domain join network issues
# Set correct divine DNS
Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses 10.0.10.10

# Clear divine DNS cache
ipconfig /flushdns

# Register with divine DNS
ipconfig /registerdns
```

## 🚀 **Quick Deployment Commands**

### **Virtual Switch Setup**

```powershell
# [HOST] Production Network
# Create production bridge vmbr0 via Proxmox VE web interface

# [HOST] Management Network
# Create management bridge vmbr1 via Proxmox VE web interface
New-NetIPAddress -IPAddress 10.0.100.1 -PrefixLength 24 -InterfaceAlias "vEthernet (OLYMPUS-Management)"

# [HOST] Client Network
# Create client bridge vmbr2 via Proxmox VE web interface
New-NetIPAddress -IPAddress 10.0.20.1 -PrefixLength 22 -InterfaceAlias "vEthernet (OLYMPUS-Clients)"

# [HOST] NAT Configuration
New-NetNat -Name "OLYMPUS-NAT" -InternalIPInterfaceAddressPrefix 10.0.0.0/8
```

### **DHCP Configuration**

```powershell
# [SERVER VM] DHCP Scope
Add-DhcpServerV4Scope -Name "Divine Client Network" -StartRange 10.0.20.100 -EndRange 10.0.23.200 -SubnetMask 255.255.252.0

# [SERVER VM] DHCP Options (CRITICAL: Correct divine gateway)
Set-DhcpServerV4OptionValue -ScopeId 10.0.20.0 -OptionId 3 -Value 10.0.20.1      # Gateway
Set-DhcpServerV4OptionValue -ScopeId 10.0.20.0 -OptionId 6 -Value 10.0.10.10     # DNS
Set-DhcpServerV4OptionValue -ScopeId 10.0.20.0 -OptionId 15 -Value "olympus.local" # Domain
Set-DhcpServerV4OptionValue -ScopeId 10.0.20.0 -OptionId 44 -Value 10.0.10.10    # WINS
```

## 👥 **Key User Accounts**

### **Administrative Accounts**

```
zeus.supreme      - CEO & Domain Admin
athena.wisdom     - CTO & CISO
hera.queen        - COO
```

### **Department Heads**

```
Divine Council:    zeus.supreme (IT Operations)
War Strategists:   athena.wisdom (Cybersecurity)
Innovation Forge:  apollo.light (Research & Development)
Abundance Treasury: demeter.harvest (Finance & Administration)
Harmony Relations: aphrodite.love (Human Resources)
```

## ⚡ **Divine PowerShell Arsenal**

### **Windows 11 Divine Client Setup & OOBE Bypass**

```cmd
# Windows 11 Network Bypass during OOBE Setup - Divine Technique
# This command bypasses network requirements and goes directly to local account setup
OOBE\BYPASSNRO

# Divine methods for Windows 11 OOBE bypass:
# 1. During network setup screen, invoke divine powers with Shift+F10 (Command Prompt)
# 2. Channel divine authority: OOBE\BYPASSNRO
# 3. Press Enter - Zeus will restart the system and skip network requirements
# 4. Create local divine accounts without Microsoft account bondage

# For automated divine deployment via PowerShell (run with divine privileges):
Start-Process -FilePath "cmd.exe" -ArgumentList "/c OOBE\BYPASSNRO" -Wait -Verb RunAs

# Additional divine OOBE bypass techniques:
# Divine Method 1: Smite the network connection during setup
taskkill /f /im NetworkConnectionFlow.exe

# Divine Method 2: Temporarily banish network adapter
Get-NetAdapter | Disable-NetAdapter -Confirm:$false
# Restore divine connection: Get-NetAdapter | Enable-NetAdapter -Confirm:$false

# Divine Method 3: Registry manipulation for local account preference
New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE" -Name "BypassNRO" -Value 1 -PropertyType DWORD -Force
```

### **Domain Operations & Divine Authentication**

```powershell
# [CLIENT VM] Domain join with divine powers
Add-Computer -DomainName "olympus.local" -Credential (Get-Credential) -Restart -Force -Verbose -ErrorAction Stop

# [SERVER VM] Replicate across the divine realm
repadmin /syncall /AdeP /e /q

# [CLIENT VM] or [SERVER VM] Divine Kerberos inspection
klist tickets
klist tgt

# [SERVER VM] Test the divine connection
dcdiag /v /c /d /e /s:ZEUS-DC01

# [CLIENT VM] or [SERVER VM] Force divine policy refresh
gpupdate /force /boot /target:computer
gpupdate /force /target:user

# [SERVER VM] Check trust between divine realms
Get-ADTrust -Filter * | Format-Table -AutoSize

# [CLIENT VM] Validate divine secure channel
Test-ComputerSecureChannel -Server "ZEUS-DC01.olympus.local" -Credential (Get-Credential) -Verbose
```

### **Advanced Directory of the Gods**

```powershell
# Find immortal accounts (passwords never expire)
Get-ADUser -Filter {PasswordNeverExpires -eq $true -and Enabled -eq $true} | Select Name, LastLogonDate, PasswordLastSet, WhenCreated, Description

# Banish stale divine entities (90+ days inactive)
$BanishmentDate = (Get-Date).AddDays(-90)
Get-ADComputer -Filter {LastLogonDate -lt $BanishmentDate -and Enabled -eq $true} | Select Name, LastLogonDate, OperatingSystem, Description | Sort-Object LastLogonDate

# Find cursed accounts (locked out)
Search-ADAccount -LockedOut | Get-ADUser -Properties LastBadPasswordAttempt, BadPwdCount, AccountLockoutTime | Select Name, LastBadPasswordAttempt, BadPwdCount, AccountLockoutTime

# Audit the divine council (privileged groups)
@("Domain Admins", "Enterprise Admins", "Schema Admins", "Administrators", "Account Operators") | ForEach-Object {
    Write-Host "=== $_ Council ===" -ForegroundColor Magenta
    Get-ADGroupMember $_ | Get-ADUser | Select Name, LastLogonDate, Enabled | Format-Table -AutoSize
}

# Find divine service accounts and their sacred names
Get-ADUser -Filter {ServicePrincipalName -like "*"} | Select Name, ServicePrincipalName, LastLogonDate, PasswordLastSet, Description

# Seek users with divine descriptions
Get-ADUser -Filter {Description -like "*admin*" -or Description -like "*service*" -or Description -like "*god*"} | Select Name, Description, Enabled, LastLogonDate

# Chronicle recent divine arrivals (30 days)
$NewGods = (Get-Date).AddDays(-30)
Get-ADUser -Filter {WhenCreated -gt $NewGods} | Select Name, WhenCreated, Enabled, Department | Sort-Object WhenCreated -Descending

# Divine password commandments
Get-ADDefaultDomainPasswordPolicy | Format-List *
Get-ADFineGrainedPasswordPolicy -Filter * | Format-Table Name, Precedence, MinPasswordLength, ComplexityEnabled

# Audit divine administrators with eternal passwords
Get-ADGroupMember "Domain Admins" | Get-ADUser -Properties PasswordNeverExpires, PasswordLastSet | Where-Object {$_.PasswordNeverExpires -eq $true} | Select Name, PasswordLastSet, PasswordNeverExpires
```

### **Network Oracles & Divine Reconnaissance**

```powershell
# [CLIENT VM] or [HOST] Divine connectivity test suite
$DivinePorts = @(
    @{Host="10.0.10.10"; Port=53; Service="DNS Oracle"},
    @{Host="10.0.10.10"; Port=88; Service="Kerberos Divine Auth"},
    @{Host="10.0.10.10"; Port=389; Service="LDAP Divine Directory"},
    @{Host="10.0.10.10"; Port=636; Service="LDAPS Secure Divine Directory"},
    @{Host="10.0.10.20"; Port=445; Service="SMB Divine Files"},
    @{Host="10.0.10.30"; Port=80; Service="HTTP Divine Web"},
    @{Host="10.0.10.30"; Port=443; Service="HTTPS Secure Divine Web"},
    @{Host="10.0.10.40"; Port=22; Service="SSH Divine Shell"}
)
$DivinePorts | ForEach-Object {
    $Result = Test-NetConnection -ComputerName $_.Host -Port $_.Port -InformationLevel Quiet
    [PSCustomObject]@{
        Service = $_.Service
        Host = $_.Host
        Port = $_.Port
        Status = if($Result.TcpTestSucceeded){"⚡ DIVINE"}else{"💀 MORTAL"}
        ResponseTime = $Result.PingReplyDetails.RoundtripTime
    }
} | Format-Table -AutoSize

# Divine realm scanning (use responsibly!)
Write-Host "🔍 Scanning the Divine Network..." -ForegroundColor Cyan
1..254 | ForEach-Object -Parallel {
    $IP = "10.0.10.$_"
    if(Test-Connection -ComputerName $IP -Count 1 -Quiet) {
        [PSCustomObject]@{IP=$IP; Status="ALIVE"; Hostname=(Resolve-DnsName $IP -ErrorAction SilentlyContinue).NameHost}
    }
} -ThrottleLimit 50 | Format-Table -AutoSize

# DNS divine revelations
@("olympus.local", "_ldap._tcp.olympus.local", "_kerberos._tcp.olympus.local", "_gc._tcp.olympus.local") | ForEach-Object {
    Write-Host "Divine Revelation for: $_" -ForegroundColor Yellow
    Resolve-DnsName -Name $_ -Server "10.0.10.10" -Type ALL | Format-Table -AutoSize
}

# Network adapter divine inspection
Get-NetAdapter | Where-Object {$_.Status -eq "Up"} | ForEach-Object {
    $Stats = Get-NetAdapterStatistics -Name $_.Name
    [PSCustomObject]@{
        Name = $_.Name
        LinkSpeed = $_.LinkSpeed
        "Bytes Sent (GB)" = [math]::Round($Stats.BytesSent/1GB,2)
        "Bytes Received (GB)" = [math]::Round($Stats.BytesReceived/1GB,2)
        Description = $_.InterfaceDescription
    }
} | Format-Table -AutoSize

# Divine connection monitoring
Get-NetTCPConnection | Where-Object {$_.State -eq "Established"} | ForEach-Object {
    try {
        $Process = Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue
        [PSCustomObject]@{
            LocalAddress = $_.LocalAddress
            LocalPort = $_.LocalPort
            RemoteAddress = $_.RemoteAddress
            RemotePort = $_.RemotePort
            ProcessName = $Process.ProcessName
            ProcessId = $_.OwningProcess
        }
    } catch { $null }
} | Where-Object {$_ -ne $null} | Format-Table -AutoSize
```

### **Divine System Performance & Olympian Monitoring**

```powershell
# Divine performance dashboard
function Start-OlympianMonitor {
    while($true) {
        Clear-Host
        Write-Host "⚡⚡⚡ OLYMPUS DIVINE SYSTEM MONITOR ⚡⚡⚡" -ForegroundColor Magenta
        Write-Host "📊 System Vitals:" -ForegroundColor Cyan

        $CPU = Get-Counter "\Processor(_Total)\% Processor Time" -SampleInterval 1 -MaxSamples 1
        $Memory = Get-Counter "\Memory\Available MBytes" -SampleInterval 1 -MaxSamples 1
        $Disk = Get-Counter "\LogicalDisk(C:)\% Free Space" -SampleInterval 1 -MaxSamples 1

        Write-Host "🔥 CPU Usage: $([math]::Round($CPU.CounterSamples.CookedValue,2))%" -ForegroundColor $(if($CPU.CounterSamples.CookedValue -gt 80){"Red"}else{"Green"})
        Write-Host "💾 Available Memory: $([math]::Round($Memory.CounterSamples.CookedValue,0)) MB" -ForegroundColor $(if($Memory.CounterSamples.CookedValue -lt 1000){"Red"}else{"Green"})
        Write-Host "💿 Disk Free: $([math]::Round($Disk.CounterSamples.CookedValue,2))%" -ForegroundColor $(if($Disk.CounterSamples.CookedValue -lt 20){"Red"}else{"Green"})

        Write-Host "`n🏆 Top Divine Processes:" -ForegroundColor Yellow
        Get-Process | Sort-Object WorkingSet -Descending | Select-Object -First 5 ProcessName, @{n="Memory(MB)";e={[math]::Round($_.WorkingSet/1MB,2)}}, CPU | Format-Table -AutoSize

        Start-Sleep 5
    }
}

# Divine resource analysis
Get-Process | Sort-Object WorkingSet -Descending | Select-Object -First 10 ProcessName, @{n="Memory(MB)";e={[math]::Round($_.WorkingSet/1MB,2)}}, @{n="CPU Time";e={$_.TotalProcessorTime}}, Id, StartTime

# Divine disk space oracle
Get-WmiObject -Class Win32_LogicalDisk | ForEach-Object {
    $FreePercent = [math]::Round(($_.FreeSpace/$_.Size)*100,2)
    $Status = switch($FreePercent) {
        {$_ -lt 5} {"⚠️ DIVINE INTERVENTION REQUIRED"}
        {$_ -lt 10} {"🔥 CRITICAL - ZEUS MUST KNOW"}
        {$_ -lt 20} {"⚡ WARNING - ATHENA'S ATTENTION NEEDED"}
        default {"✅ DIVINE - ALL IS WELL"}
    }
    [PSCustomObject]@{
        Drive = $_.DeviceID
        "Size(GB)" = [math]::Round($_.Size/1GB,2)
        "Free(GB)" = [math]::Round($_.FreeSpace/1GB,2)
        "Free%" = $FreePercent
        "Divine Status" = $Status
    }
} | Format-Table -AutoSize

# Divine event analysis
Get-WinEvent -FilterHashtable @{LogName='System','Application','Security'; Level=1,2,3; StartTime=(Get-Date).AddHours(-24)} |
    Group-Object Id | Sort-Object Count -Descending | Select-Object -First 10 Count, Name, @{n="Sample Message";e={$_.Group[0].Message.Substring(0,[Math]::Min(150,$_.Group[0].Message.Length))}} | Format-Table -Wrap

# Divine service health check
Get-Service | Where-Object {$_.StartType -eq "Automatic" -and $_.Status -ne "Running"} |
    ForEach-Object {
        $Service = Get-WmiObject -Class Win32_Service -Filter "Name='$($_.Name)'"
        [PSCustomObject]@{
            Name = $_.Name
            Status = $_.Status
            StartType = $_.StartType
            Description = $Service.Description.Substring(0,[Math]::Min(100,$Service.Description.Length))
            "Divine Intervention" = "🔧 REQUIRES ATTENTION"
        }
    } | Format-Table -Wrap

# Divine update status
Write-Host "📦 Recent Divine Updates (Last 10):" -ForegroundColor Cyan
Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 10 HotFixID, Description, InstalledOn, InstalledBy | Format-Table -AutoSize
```

### **Security & Divine Forensics**

```powershell
# Divine intrusion detection
Write-Host "🛡️ Analyzing Divine Security Events..." -ForegroundColor Red

# Failed divine login attempts
Get-WinEvent -FilterHashtable @{LogName='Security'; ID=4625; StartTime=(Get-Date).AddDays(-1)} |
    ForEach-Object {
        [PSCustomObject]@{
            Time = $_.TimeCreated
            Account = $_.Properties[5].Value
            SourceIP = $_.Properties[19].Value
            Workstation = $_.Properties[13].Value
            FailureReason = $_.Properties[8].Value
            "Threat Level" = if($_.Properties[19].Value -notlike "10.0.*"){"🚨 EXTERNAL THREAT"}else{"⚠️ INTERNAL"}
        }
    } | Group-Object Account | Sort-Object Count -Descending | ForEach-Object {
        Write-Host "Account: $($_.Name) - Failed Attempts: $($_.Count)" -ForegroundColor $(if($_.Count -gt 5){"Red"}else{"Yellow"})
        $_.Group | Select-Object -First 3 | Format-Table -AutoSize
    }

# Divine successful logons from foreign realms
Get-WinEvent -FilterHashtable @{LogName='Security'; ID=4624; StartTime=(Get-Date).AddDays(-1)} |
    Where-Object {$_.Properties[18].Value -notlike "10.0.*" -and $_.Properties[18].Value -ne "-" -and $_.Properties[18].Value -ne "127.0.0.1"} |
    Select-Object TimeCreated, @{n="Divine Account";e={$_.Properties[5].Value}}, @{n="Foreign IP";e={$_.Properties[18].Value}}, @{n="Logon Type";e={$_.Properties[8].Value}} | Format-Table -AutoSize

# Divine administrative audit
Write-Host "👑 Divine Administrative Powers Audit:" -ForegroundColor Magenta
Get-LocalGroupMember -Group "Administrators" | Select Name, ObjectClass, PrincipalSource, @{n="Divine Level";e={if($_.Name -like "*zeus*" -or $_.Name -like "*admin*"){"OLYMPIAN"}else{"MORTAL"}}} | Format-Table -AutoSize

# Divine software inventory
Write-Host "📦 Divine Software Registry:" -ForegroundColor Blue
Get-WmiObject -Class Win32_Product | Where-Object {$_.Name -notlike "*Microsoft*"} | Select Name, Version, Vendor, InstallDate | Sort-Object InstallDate -Descending | Format-Table -AutoSize

# Divine network shares audit
Write-Host "📁 Divine Share Permissions Audit:" -ForegroundColor Green
Get-SmbShare | Where-Object {$_.Name -notlike "*$"} | ForEach-Object {
    $ShareName = $_.Name
    Write-Host "🏛️ Share: $ShareName" -ForegroundColor Cyan
    Get-SmbShareAccess -Name $ShareName | Select @{n="Divine Access";e={"$ShareName - $($_.AccountName) - $($_.AccessRight) - $($_.AccessControlType)"}}, AccountName, AccessControlType, AccessRight | Format-Table -AutoSize
}

# Divine file integrity monitoring
$DivineFolders = @("C:\Windows\System32", "C:\ImportantData", "C:\OlympusData")
foreach($Folder in $DivineFolders) {
    if(Test-Path $Folder) {
        Write-Host "🔍 Divine Integrity Check: $Folder" -ForegroundColor Yellow
        $Files = Get-ChildItem -Path $Folder -File -ErrorAction SilentlyContinue | Select-Object -First 10
        $Files | Get-FileHash | Select Algorithm, Hash, @{n="Divine Path";e={$_.Path}} | Format-Table -AutoSize
    }
}

# Divine registry persistence check
Write-Host "📋 Divine Registry Persistence Audit:" -ForegroundColor Red
@("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run", "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run") | ForEach-Object {
    if(Test-Path $_) {
        Write-Host "Registry Path: $_" -ForegroundColor Yellow
        Get-ItemProperty -Path $_ | Format-List
    }
}

# Divine scheduled tasks audit
Write-Host "⏰ Divine Scheduled Tasks:" -ForegroundColor Magenta
Get-ScheduledTask | Where-Object {$_.State -eq "Ready" -and $_.Principal.UserId -ne "SYSTEM" -and $_.TaskName -notlike "*Microsoft*"} |
    Select TaskName, State, @{n="Divine User";e={$_.Principal.UserId}}, @{n="Divine Action";e={$_.Actions.Execute}}, @{n="Trigger";e={$_.Triggers.StartBoundary}} | Format-Table -Wrap
```

### **☁️ Cloud Integration & Azure Divine Powers**

```powershell
# Azure divine connection test
Test-NetConnection -ComputerName "portal.azure.com" -Port 443 -InformationLevel Detailed

# Install Azure divine modules
Install-Module -Name Az -Force -AllowClobber
Import-Module Az

# Connect to Azure Olympus
Connect-AzAccount

# Azure resource divine inspection
Get-AzResource | Select Name, ResourceType, Location, ResourceGroupName | Format-Table -AutoSize

# Azure VM divine status
Get-AzVM | Select Name, @{n="Divine Status";e={$_.StatusCode}}, Location, VmSize | Format-Table -AutoSize

# Create Azure VPN to Olympus
function New-OlympusAzureVPN {
    param(
        [string]$LocalGateway = "10.0.10.1",
        [string]$AzureGateway = "olympus-gateway"
    )

    Write-Host "⚡ Creating divine connection to Azure..." -ForegroundColor Cyan
    # New-AzVirtualNetworkGatewayConnection -Name "OlympusToAzure" -ResourceGroupName "Olympus-RG" -Location "East US"
    Write-Host "🌩️ Divine VPN tunnel established!" -ForegroundColor Green
}

# Monitor Azure costs (divine budget)
# Get-AzConsumptionUsageDetail | Select-Object -First 10 | Format-Table -AutoSize

# Azure Storage divine access
# Get-AzStorageAccount | Select StorageAccountName, Location, SkuName | Format-Table -AutoSize
```

### **Proxmox VE Divine Virtualization**

```powershell
# Divine VM dashboard via Proxmox VE
Write-Host "🏛️ Divine Virtual Machine Status:" -ForegroundColor Magenta
Write-Host "Use Proxmox VE web interface for real-time VM monitoring" -ForegroundColor Cyan
Write-Host "CLI Commands:" -ForegroundColor Yellow
Write-Host "  qm list                    # List all VMs with status" -ForegroundColor Green
Write-Host "  qm status <vmid>           # Detailed VM status" -ForegroundColor Green
Write-Host "  qm monitor <vmid>          # Enter VM monitor mode" -ForegroundColor Green

# Divine VM performance monitoring via Proxmox VE
Write-Host "📊 Divine VM Performance Metrics:" -ForegroundColor Yellow
Write-Host "Monitor performance via Proxmox VE web interface:" -ForegroundColor Cyan
Write-Host "  Dashboard → Summary → VM Resource Usage" -ForegroundColor Green
Write-Host "  VM → Summary → Performance graphs" -ForegroundColor Green
Write-Host "Host performance: htop (on Proxmox host)" -ForegroundColor Green

# Divine VM mass operations
Write-Host "🎭 Divine VM Mass Operations:" -ForegroundColor Blue

# Awaken all dormant VMs via Proxmox VE
Write-Host "⚡ Starting all stopped VMs:" -ForegroundColor Blue
Write-Host "  for vm in \$(qm list | grep stopped | awk '{print \$1}'); do qm start \$vm; done" -ForegroundColor Green

# Create divine snapshots via Proxmox VE
Write-Host "📸 Creating divine snapshots:" -ForegroundColor Green
Write-Host "Via web interface: VM → Snapshots → Take Snapshot" -ForegroundColor Cyan
Write-Host "Via CLI: qm snapshot <vmid> Divine-Backup-\$(date +%Y-%m-%d-%H%M)" -ForegroundColor Green

# Divine VM network analysis via Proxmox VE
Write-Host "🌐 Divine VM Network Configuration:" -ForegroundColor Cyan
Write-Host "Check network config via Proxmox web interface:" -ForegroundColor Yellow
Write-Host "  VM → Hardware → Network Device" -ForegroundColor Green
Write-Host "  Node → Network → View bridge configuration" -ForegroundColor Green

# Export divine VMs for backup via Proxmox VE
Write-Host "💾 Divine VM Backup:" -ForegroundColor Magenta
Write-Host "  vzdump <vmid> --storage local --compress gzip" -ForegroundColor Green
Write-Host "  Or use Datacenter → Backup for scheduled backups" -ForegroundColor Cyan
```

### **File System & Divine Storage Management**

```powershell
# Find divine artifacts (large files)
Write-Host "🔍 Seeking Divine Artifacts (Large Files)..." -ForegroundColor Yellow
Get-ChildItem -Path "C:\" -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object {$_.Length -gt 500MB} |
    Sort-Object Length -Descending |
    Select-Object -First 20 Name, @{n="Size(GB)";e={[math]::Round($_.Length/1GB,2)}}, @{n="Divine Location";e={$_.DirectoryName}}, @{n="Last Modified";e={$_.LastWriteTime}} | Format-Table -Wrap

# Recent divine activities (file changes)
Write-Host "📜 Recent Divine Activities..." -ForegroundColor Magenta
Get-ChildItem -Path @("C:\Users", "C:\OlympusData") -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object {$_.LastWriteTime -gt (Get-Date).AddHours(-24)} |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 30 Name, @{n="Divine Activity Time";e={$_.LastWriteTime}}, @{n="Size(KB)";e={[math]::Round($_.Length/1KB,2)}}, @{n="Divine Path";e={$_.DirectoryName}} | Format-Table -Wrap

# Divine duplicate detection
Write-Host "🔮 Divine Duplicate Detection..." -ForegroundColor Blue
$DivinePath = "C:\OlympusData"
if(Test-Path $DivinePath) {
    Get-ChildItem -Path $DivinePath -Recurse -File -ErrorAction SilentlyContinue |
        Group-Object -Property @{Expression={Get-FileHash $_.FullName -Algorithm MD5 | Select-Object -ExpandProperty Hash}} |
        Where-Object {$_.Count -gt 1} |
        ForEach-Object {
            Write-Host "Divine Duplicate Found - Hash: $($_.Name.Substring(0,16))..." -ForegroundColor Red
            $_.Group | Select Name, @{n="Divine Path";e={$_.FullName}}, @{n="Size(KB)";e={[math]::Round($_.Length/1KB,2)}} | Format-Table -AutoSize
        }
}

# Shadow copy divine inspection
Write-Host "👻 Divine Shadow Copies:" -ForegroundColor DarkMagenta
vssadmin list shadows

# USB divine device history
Write-Host "🔌 Divine USB Device History:" -ForegroundColor Green
Get-WmiObject -Class Win32_LogicalDisk | Where-Object {$_.DriveType -eq 2} | Select @{n="Divine Device";e={$_.DeviceID}}, @{n="Divine Name";e={$_.VolumeName}}, @{n="Size(GB)";e={[math]::Round($_.Size/1GB,2)}} | Format-Table -AutoSize
```

## 🛡️ **Security Essentials**

### **Divine Passwords** (Change immediately!)

```
Local Admin: P@ssw0rd123!
Domain Admin: OlympusAdmin2024!
Service Accounts: DivineService123!
Zeus Supreme: ZeusThunderb0lt2024!
```

### **Sacred Ports of Olympus**

```
RDP:   3389 (Divine Management network only)
WinRM: 5985/5986 (Divine PowerShell remoting)
SSH:   22 (Divine OpenSSH)
HTTPS: 443 (Divine Web services)
LDAPS: 636 (Divine Secure LDAP)
SMB:   445 (Divine File sharing)
Azure: 443/80 (Divine Cloud connection)
```

## ⚡ **Divine Emergency Response & Incident Handling**

### **Authentication & Divine Authority Issues**

```powershell
# Complete divine realm health check
dcdiag /v /c /d /e /s:ZEUS-DC01 > C:\divine_health_report.txt

# Kerberos divine troubleshooting
klist purge
klist tickets
kinit zeus.supreme@OLYMPUS.LOCAL

# Divine time synchronization (critical for Kerberos)
w32tm /config /manualpeerlist:"time.nist.gov,time.windows.com" /syncfromflags:manual /reliable:yes
w32tm /resync /force
w32tm /query /status

# SYSVOL divine replication check
dfsrdiag ReplicationState /member:ZEUS-DC01 /rgname:"Domain System Volume"
dfsrdiag BackLog /rgname:"Domain System Volume" /rfname:"SYSVOL Share" /rmem:ZEUS-DC01 /smem:HERA-DC02

# Reset divine computer account
Reset-ComputerMachinePassword -Credential (Get-Credential -Message "Enter Zeus credentials")

# DNS divine scavenging
dnscmd ZEUS-DC01 /Config /ScavengingInterval 168
dnscmd ZEUS-DC01 /StartScavenging
```

### **Network Divine Emergencies**

```powershell
# Divine network resurrection protocol
Write-Host "🌩️ Initiating Divine Network Resurrection..." -ForegroundColor Red
netsh int ip reset c:\divine_ip_reset.log
netsh winsock reset
netsh int tcp reset
# [CLIENT VM] or [SERVER VM] Divine DNS flush and network refresh
ipconfig /flushdns
ipconfig /release
ipconfig /renew
ipconfig /registerdns

# [HOST] or [CLIENT VM] or [SERVER VM] Divine routing table backup and restore
route print > C:\divine_routes_backup.txt
# Emergency route: route add 0.0.0.0 mask 0.0.0.0 10.0.100.1 metric 1

# Divine firewall emergency protocols
Write-Host "🔥 Divine Firewall Emergency Mode..." -ForegroundColor Yellow
# netsh advfirewall set allprofiles state off  # OLYMPIAN EMERGENCY ONLY!
# netsh advfirewall reset  # Reset to divine defaults

# Divine adapter reset ritual
Write-Host "⚡ Divine Network Adapter Reset..." -ForegroundColor Blue
Get-NetAdapter | Reset-NetAdapter -Confirm:$false
```

## 📊 **Divine Monitoring & Alerts**

```powershell
# Divine CPU alert system
if((Get-Counter "\Processor(_Total)\% Processor Time").CounterSamples.CookedValue -gt 90) {
    Write-Host "🔥 DIVINE CPU OVERLOAD! ZEUS INTERVENTION REQUIRED!" -ForegroundColor Red -BackgroundColor Yellow
}

# Divine memory alert
$AvailableMemory = (Get-Counter "\Memory\Available MBytes").CounterSamples.CookedValue
if($AvailableMemory -lt 500) {
    Write-Host "💾 DIVINE MEMORY CRISIS! ATHENA'S WISDOM NEEDED! Available: $AvailableMemory MB" -ForegroundColor White -BackgroundColor Red
}

# Divine disk space oracle
Get-WmiObject Win32_LogicalDisk | Where-Object {($_.FreeSpace/$_.Size) -lt 0.05} | ForEach-Object {
    Write-Host "💿 DIVINE STORAGE APOCALYPSE! Disk $($_.DeviceID) is critically low! APOLLO'S LIGHT REQUIRED!" -ForegroundColor Yellow -BackgroundColor Red
}

# Divine intrusion alert
$FailedLogins = (Get-WinEvent -FilterHashtable @{LogName='Security'; ID=4625; StartTime=(Get-Date).AddMinutes(-10)} | Measure-Object).Count
if($FailedLogins -gt 10) {
    Write-Host "🛡️ DIVINE SECURITY BREACH! $FailedLogins failed logins detected! ATHENA'S SHIELD ACTIVATED!" -ForegroundColor White -BackgroundColor Red
}
```

## 🎯 **Divine Pro Tips & Olympian Secrets**

```powershell
# Divine PowerShell profile customization
# Add to $PROFILE:
function Get-OlympianStatus {
    Write-Host "⚡ Olympus System Status ⚡" -ForegroundColor Magenta
    Get-ADDomain | Select Name, DomainMode, PDCEmulator
    Get-NetAdapter | Where-Object {$_.Status -eq "Up"} | Select Name, LinkSpeed
}

function Invoke-DivinePower { Restart-Computer -Force }
function Get-ZeusApproval { Get-Credential -Message "Seek Zeus's Divine Approval" }

# Divine PSReadLine shortcuts for godlike speed
Set-PSReadLineKeyHandler -Key Ctrl+Shift+d -Function MenuComplete
Set-PSReadLineKeyHandler -Key Ctrl+Shift+r -Function ReverseSearchHistory
Set-PSReadLineKeyHandler -Key Ctrl+Shift+z -ScriptBlock { Get-ADUser -Filter * | Out-GridView }

# Divine ISE enhancements
if($psISE) {
    $psISE.CurrentPowerShellTab.AddOnsMenu.Submenus.Add("Divine User Lookup", {Get-ADUser -Filter * | Out-GridView}, "Ctrl+Shift+U")
    # Divine VM Status via Proxmox VE web interface
# Access via: https://proxmox-host:8006 → VM Status Dashboard
}

# Divine remote session to any realm
function Enter-DivineDomain {
    param([string]$ComputerName)
    Enter-PSSession -ComputerName $ComputerName -Credential (Get-ZeusApproval)
}

# Olympian one-liner collection
function Get-DivineOneLiners {
    @"
# Quick domain user count
(Get-ADUser -Filter *).Count

# Find computers offline for 30+ days
Get-ADComputer -Filter * -Properties LastLogonDate | Where-Object {$_.LastLogonDate -lt (Get-Date).AddDays(-30)}

# Emergency all services restart
Get-Service | Where-Object {$_.Status -eq 'Stopped' -and $_.StartType -eq 'Automatic'} | Start-Service

# Divine disk cleanup
Get-ChildItem -Path @('C:\Windows\Temp', 'C:\Temp', 'C:\Users\*\AppData\Local\Temp') -Recurse | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue

# Network speed test
Test-NetConnection bing.com | Select ComputerName, PingSucceeded, PingReplyDetails
"@
}
```

## 📚 **Divine Documentation References**

- **[Olympus Quick Start Guide](Guides/QUICK_START_OLYMPUS.md)** - 30-minute divine deployment
- **[Divine Manual Setup](MANUAL_SETUP_OLYMPUS.md)** - Step-by-step divine ascension
- **[Complete Divine Architecture](Documentation/DEMO_SETUP_GUIDE.md)** - Full olympian reference
- **[Divine Network Shares](Guides/OLYMPUS_NETWORK_SHARE_SETUP.md)** - Hermes file sharing
- **[Divine Performance Optimization](Documentation/HARDWARE_PERFORMANCE_GUIDE.md)** - Zeus-level performance

---

**⚡ Wield these divine commands and ascend to Zeus-level Windows Server mastery! ⚡**
**🏛️ May the power of Olympus flow through your PowerShell! 🏛️**

**📖 For complete divine instructions, see: [QUICK_START_OLYMPUS.md](Guides/QUICK_START_OLYMPUS.md)**
