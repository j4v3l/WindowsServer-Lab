# 🚀 Windows Server on Proxmox VE - Performance Optimization Guide

> The supported lab is declarative. Treat the settings below as background information only: make durable VM changes in `LabConfig/lab.json` or `terraform/lab/main.tf`, and template changes in `packer/windows/windows.pkr.hcl`. Do not run `qm create`, `qm clone`, or `qm set` against Terraform-owned lab VMs.

## 🎯 Overview

This guide provides comprehensive instructions for deploying and optimizing Windows Server virtual machines on Proxmox VE. Follow these best practices to achieve maximum performance, stability, and compatibility in your Windows Server lab environment.

## 📋 Prerequisites

- Proxmox VE 8.0+ installed and configured
- Windows Server 2019/2022/2025 ISO files
- VirtIO drivers ISO (latest version)
- Administrative access to Proxmox host
- Basic understanding of Proxmox management

## 🔧 VM Configuration Best Practices

### Optimal VM Settings for Windows Server

```bash
# Create optimized Windows Server VM
qm create 100 \
  --name "DC1-LAB" \
  --memory 4096 \
  --balloon 2048 \
  --cores 4 \
  --cpu host,flags=+aes \
  --machine q35 \
  --bios ovmf \
  --efidisk0 local-lvm:4 \
  --scsi0 local-lvm:80,cache=writeback,discard=on,ssd=1 \
  --scsihw virtio-scsi-single \
  --net0 virtio,bridge=vmbr1,firewall=1 \
  --net1 virtio,bridge=vmbr0,firewall=1 \
  --ide2 local:iso/WindowsServer2022.iso,media=cdrom \
  --ide0 local:iso/virtio-win.iso,media=cdrom \
  --ostype win10 \
  --agent 1,fstrim_cloned_disks=1 \
  --tablet 0 \
  --onboot 1
```

### Key Configuration Explanations

| Setting | Value | Purpose |
|---------|-------|---------|
| **CPU Type** | `host` | Maximum performance, exposes all host CPU features |
| **Machine Type** | `q35` | Modern chipset, better Windows compatibility |
| **BIOS** | `OVMF (UEFI)` | Required for modern Windows, better boot performance |
| **SCSI Controller** | `virtio-scsi-single` | Best storage performance |
| **Network Model** | `virtio` | Paravirtualized network for optimal performance |
| **Memory Ballooning** | `enabled` | Dynamic memory allocation |
| **Tablet** | `disabled` | Reduces CPU overhead |

## 🏗️ Step-by-Step VM Creation

### Step 1: Create Base VM

1. **Access Proxmox Web Interface**
   - Navigate to `https://your-proxmox-ip:8006`
   - Login with admin credentials

2. **Create New VM**
   - Click "Create VM"
   - **General Tab**:

     ```
     VM ID: 100
     Name: DC1-LAB
     Resource Pool: (optional)
     ```

3. **OS Tab**:

   ```
   Use CD/DVD disc image file: ✓
   Storage: local
   ISO image: WindowsServer2022.iso
   Type: Microsoft Windows
   Version: 10/2016/2019/2022/2025
   ```

4. **System Tab**:

   ```
   Graphic card: Default
   Machine: q35
   BIOS: OVMF (UEFI)
   EFI Storage: local-lvm
   Pre-Enroll keys: ✓ (for Secure Boot)
   SCSI Controller: VirtIO SCSI single
   Qemu Agent: ✓
   ```

5. **Hard Disk Tab**:

   ```
   Storage: local-lvm
   Disk size: 80 GB
   Cache: Write back
   Discard: ✓
   SSD emulation: ✓
   ```

6. **CPU Tab**:

   ```
   Sockets: 1
   Cores: 4
   Type: host
   Enable NUMA: ✓ (for larger VMs)
   ```

7. **Memory Tab**:

   ```
   Memory: 4096 MB
   Minimum memory: 2048 MB
   Ballooning: ✓
   ```

8. **Network Tab**:

   ```
   Bridge: vmbr1
   Model: VirtIO (paravirtualized)
   ```

## 💿 Windows Server Installation with VirtIO Drivers

### Pre-Installation Driver Loading

1. **Boot from Windows Server ISO**
2. **When prompted for installation location**:
   - Click "Load Driver"
   - Browse to VirtIO CD (usually D: or E:)
   - Navigate to appropriate driver folder:

     ```
     vioscsi\2k22\amd64   # Storage driver
     NetKVM\2k22\amd64    # Network driver
     ```

   - Install both drivers

3. **Continue Windows Installation**
   - Select storage drive (now visible)
   - Complete standard Windows installation

### Post-Installation VirtIO Driver Setup

```powershell
# After Windows installation, install remaining VirtIO drivers
# Mount VirtIO ISO and run:
D:\virtio-win-gt-x64.msi

# Or install individual drivers:
# - Balloon driver (memory management)
# - Guest Agent (VM integration)
# - Serial driver (enhanced console)
# - Display driver (if needed)
```

## 🔧 Performance Optimization Settings

### Windows Server Optimization

```powershell
# Disable unnecessary services for lab environment
$services = @(
    "Fax",
    "WSearch",
    "Themes",
    "TabletInputService",
    "Spooler"  # Only if not printing
)

foreach ($service in $services) {
    Set-Service -Name $service -StartupType Disabled -ErrorAction SilentlyContinue
    Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
}

# Optimize power settings for performance
powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c  # High performance

# Disable Windows Defender for lab environment (optional)
Set-MpPreference -DisableRealtimeMonitoring $true

# Optimize network settings
netsh int tcp set global autotuninglevel=normal
netsh int tcp set global chimney=enabled
netsh int tcp set global rss=enabled
```

### Registry Optimizations

```powershell
# Disable Windows animations and visual effects
$regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
New-Item -Path $regPath -Force | Out-Null
Set-ItemProperty -Path $regPath -Name "VisualFXSetting" -Value 2

# Optimize system responsiveness
$regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
Set-ItemProperty -Path $regPath -Name "SystemResponsiveness" -Value 10

# Optimize network performance
$regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
Set-ItemProperty -Path $regPath -Name "TcpAckFrequency" -Value 1
Set-ItemProperty -Path $regPath -Name "TCPNoDelay" -Value 1
```

## 🌐 Network Configuration

### Multi-Homed Network Setup

```powershell
# Configure multiple network interfaces
# Get network adapters
Get-NetAdapter | Format-Table Name, InterfaceDescription, Status

# Configure Management Network (first adapter)
New-NetIPAddress -InterfaceAlias "Ethernet" -IPAddress 192.168.100.10 -PrefixLength 24 -DefaultGateway 192.168.100.1
Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses 192.168.100.10

# Configure Production Network (second adapter)
New-NetIPAddress -InterfaceAlias "Ethernet 2" -IPAddress 192.168.1.10 -PrefixLength 24
Set-DnsClientServerAddress -InterfaceAlias "Ethernet 2" -ServerAddresses 192.168.1.10

# Set interface metrics (lower = higher priority)
Set-NetIPInterface -InterfaceAlias "Ethernet" -InterfaceMetric 10
Set-NetIPInterface -InterfaceAlias "Ethernet 2" -InterfaceMetric 20
```

### Network Performance Tuning

```powershell
# Enable jumbo frames (if supported by network)
Get-NetAdapterAdvancedProperty -Name "Ethernet" -DisplayName "*Jumbo*"
Set-NetAdapterAdvancedProperty -Name "Ethernet" -DisplayName "Jumbo Packet" -DisplayValue "9014 Bytes"

# Optimize receive buffer
Set-NetAdapterAdvancedProperty -Name "Ethernet" -DisplayName "Receive Buffers" -DisplayValue "2048"

# Enable RSS (Receive Side Scaling)
Set-NetAdapterRss -Name "Ethernet" -Enabled $true
```

## 💾 Storage Optimization

### Disk Performance Settings

```bash
# On Proxmox host - optimize VM storage
qm set 100 --scsi0 local-lvm:80,cache=writeback,discard=on,ssd=1,iothread=1

# Enable write-back cache for better performance
# Enable discard for SSD TRIM support
# Enable IO threads for better disk performance
```

### Windows Storage Optimization

```powershell
# Optimize disk performance
fsutil behavior set DisableDeleteNotify 0  # Enable TRIM
fsutil behavior set EncryptPagingFile 0    # Disable paging file encryption

# Disable system restore for lab environment
Disable-ComputerRestore -Drive "C:\"

# Configure page file on separate disk (if available)
$pagefile = Get-WmiObject -Class Win32_ComputerSystem -EnableAllPrivileges
$pagefile.AutomaticManagedPagefile = $false
$pagefile.Put()

# Set custom page file size
$pagefileset = Get-WmiObject -Class Win32_PageFileSetting
$pagefileset.InitialSize = 2048
$pagefileset.MaximumSize = 4096
$pagefileset.Put()
```

## 🔧 Proxmox Host Optimizations

### Host-Level Performance Tuning

```bash
# Enable CPU frequency scaling
echo 'performance' | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

# Optimize kernel parameters
cat >> /etc/sysctl.conf << EOF
# Network optimizations
net.core.netdev_max_backlog = 5000
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728

# Virtual memory optimizations
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
vm.swappiness = 10
EOF

sysctl -p
```

### NUMA Optimization

```bash
# Check NUMA topology
numactl --hardware

# For VMs with multiple vCPUs, enable NUMA
qm set 100 --numa 1

# Pin VM to specific NUMA node (if needed)
qm set 100 --cpus 4 --numa 1
```

## 🎯 Active Directory Optimization

### AD-Specific Performance Settings

```powershell
# Optimize Active Directory for lab environment
# Disable AD recycle bin (if not needed)
Set-ADOptionalFeature 'Recycle Bin Feature' -Enabled $false -Target (Get-ADForest)

# Optimize LDAP query performance
$configNC = (Get-ADRootDSE).ConfigurationNamingContext
Set-ADObject -Identity "CN=Directory Service,CN=Windows NT,CN=Services,$configNC" -Replace @{"dSHeuristics"="001"}

# Configure DNS scavenging
Set-DnsServerScavenging -RefreshInterval "7.00:00:00" -NoRefreshInterval "7.00:00:00" -ScavengingState $true

# Optimize SYSVOL replication
dfsrdiag pollad
```

### Domain Controller Memory Optimization

```powershell
# Increase NTDS cache size for better performance
$regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\NTDS\Parameters"
Set-ItemProperty -Path $regPath -Name "DB log buffer size" -Value 2048
Set-ItemProperty -Path $regPath -Name "DB max sessions" -Value 20000
```

## 📊 Monitoring and Maintenance

### Performance Monitoring

```powershell
# Create performance monitoring script
$counters = @(
    "\Processor(_Total)\% Processor Time",
    "\Memory\Available MBytes",
    "\PhysicalDisk(_Total)\% Disk Time",
    "\Network Interface(*)\Bytes Total/sec"
)

Get-Counter -Counter $counters -SampleInterval 5 -MaxSamples 12
```

### Automated Maintenance

```powershell
# Create weekly maintenance script
$maintenanceScript = @'
# Clear DNS cache
Clear-DnsClientCache

# Update Group Policy
gpupdate /force

# Restart DNS service
Restart-Service DNS

# Clear event logs (for lab environment)
Get-EventLog -LogName System | Clear-EventLog
Get-EventLog -LogName Application | Clear-EventLog
'@

# Schedule maintenance task
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-Command & {$maintenanceScript}"
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 2AM
Register-ScheduledTask -TaskName "Lab Maintenance" -Action $action -Trigger $trigger
```

## 🛡️ Security Considerations

### Lab Environment Security

```powershell
# Disable unnecessary protocols
Disable-NetAdapterBinding -Name "Ethernet" -ComponentID ms_lltdio
Disable-NetAdapterBinding -Name "Ethernet" -ComponentID ms_rspndr

# Configure Windows Firewall for lab use
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True
New-NetFirewallRule -DisplayName "Allow RDP" -Direction Inbound -Protocol TCP -LocalPort 3389 -Action Allow

# Enable secure boot (if using UEFI)
Confirm-SecureBootUEFI
```

## 🔄 Backup and Snapshot Strategy

### Proxmox Snapshot Management

```bash
# Create pre-configuration snapshot
qm snapshot 100 pre-ad-install

# Create post-installation snapshot
qm snapshot 100 post-ad-install

# List snapshots
qm listsnapshot 100

# Rollback if needed
qm rollback 100 pre-ad-install
```

### Automated Backup

```bash
# Create backup job
vzdump 100 --mode snapshot --storage backup-storage --compress zstd --remove 0

# Schedule daily backups
cat > /etc/cron.d/vm-backup << EOF
0 2 * * * root vzdump 100 --mode snapshot --storage backup-storage --compress zstd --remove 7
EOF
```

## 🎯 Testing and Validation

### Performance Testing

```powershell
# Test disk performance
$testFile = "C:\temp\disktest.tmp"
$data = New-Object byte[] 1GB
Measure-Command { [System.IO.File]::WriteAllBytes($testFile, $data) }

# Test network performance
Test-NetConnection -ComputerName "192.168.1.1" -Port 3389 -InformationLevel Detailed

# Memory stress test
$memory = @()
for ($i = 0; $i -lt 100; $i++) {
    $memory += New-Object byte[] 10MB
}
```

### Connectivity Testing

```powershell
# Test all network interfaces
Get-NetAdapter | Test-NetConnection -ComputerName "8.8.8.8" -Port 53

# Test domain connectivity
Test-ComputerSecureChannel -Verbose
nltest /query
```

## 📈 Performance Monitoring Dashboard

### Key Metrics to Monitor

| Metric | Optimal Range | Command |
|--------|---------------|---------|
| **CPU Usage** | < 80% | `Get-Counter "\Processor(_Total)\% Processor Time"` |
| **Memory Usage** | < 80% | `Get-Counter "\Memory\% Committed Bytes In Use"` |
| **Disk Response** | < 50ms | `Get-Counter "\PhysicalDisk(_Total)\Avg. Disk sec/Read"` |
| **Network Utilization** | < 80% | `Get-Counter "\Network Interface(*)\% Bandwidth Utilization"` |

### Performance Baseline

```powershell
# Create performance baseline
$baseline = @{
    CPU = (Get-Counter "\Processor(_Total)\% Processor Time" -SampleInterval 1 -MaxSamples 10).CounterSamples.CookedValue | Measure-Object -Average
    Memory = (Get-Counter "\Memory\Available MBytes" -SampleInterval 1 -MaxSamples 10).CounterSamples.CookedValue | Measure-Object -Average
    Disk = (Get-Counter "\PhysicalDisk(_Total)\% Disk Time" -SampleInterval 1 -MaxSamples 10).CounterSamples.CookedValue | Measure-Object -Average
}

$baseline | ConvertTo-Json | Out-File "C:\temp\performance-baseline.json"
```

## 🎉 Conclusion

This comprehensive optimization guide ensures your Windows Server VMs running on Proxmox VE achieve maximum performance and reliability. Regular monitoring and maintenance of these settings will maintain optimal performance throughout your lab environment's lifecycle.

### Key Takeaways

1. **Use VirtIO drivers** for all components
2. **Enable UEFI boot** for modern features
3. **Optimize network configuration** for multi-homed setups
4. **Monitor performance metrics** regularly
5. **Implement proper backup strategies**
6. **Test configurations** before production use

Following these guidelines will result in a high-performance, stable Windows Server lab environment suitable for learning, testing, and development purposes.
