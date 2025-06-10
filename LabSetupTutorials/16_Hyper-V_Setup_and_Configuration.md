# 🖥️ Hyper-V Setup and Virtual Switch Configuration

## 🎯 What You'll Learn

- How to enable and configure Hyper-V on Windows
- Creating and managing virtual switches for lab networking
- Setting up proper network isolation for your lab environment
- Configuring Hyper-V VMs for Windows Server lab scenarios
- Best practices for Hyper-V lab networking

## 📋 Prerequisites

Before we begin, ensure you have:

1. **Windows 10 Pro/Enterprise/Education or Windows 11 Pro/Enterprise**
   - Hyper-V is not available on Home editions
2. **Hardware Requirements:**
   - 64-bit processor with Second Level Address Translation (SLAT)
   - VM Monitor Mode Extensions
   - Hardware DEP (Data Execution Prevention)
   - At least 4GB RAM (8GB+ recommended for multiple VMs)
3. **BIOS/UEFI Settings:**
   - Virtualization Technology enabled
   - Hardware-assisted virtualization enabled
   - DEP/NX bit enabled

## 🚀 Step 1: Enable Hyper-V

### Method 1: Using Windows Features (GUI)

1. Press `Windows + R`, type `appwiz.cpl`, and press Enter
2. Click "Turn Windows features on or off"
3. Check "Hyper-V" (this includes both Platform and Management Tools)
4. Click "OK" and restart when prompted

### Method 2: Using PowerShell (Recommended)

Run PowerShell as Administrator and execute:

```powershell
# Enable Hyper-V feature
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -All

# Alternative method using DISM
DISM /Online /Enable-Feature /All /FeatureName:Microsoft-Hyper-V
```

### Method 3: Using Command Prompt

Run as Administrator:

```cmd
bcdedit /set hypervisorlaunchtype auto
```

## 🌐 Step 2: Understanding Virtual Switch Types

Hyper-V offers three types of virtual switches:

### 1. External Switch

- **Purpose**: VMs connect to physical network
- **Use Case**: When VMs need internet access or network resources
- **Lab Scenario**: Domain controllers, file servers needing external connectivity

### 2. Internal Switch

- **Purpose**: Communication between host and VMs only
- **Use Case**: Isolated environments with host management access
- **Lab Scenario**: Management networks, isolated testing environments

### 3. Private Switch

- **Purpose**: VM-to-VM communication only (no host access)
- **Use Case**: Completely isolated networks
- **Lab Scenario**: DMZ networks, secure isolated segments

## 🔧 Step 3: Creating Virtual Switches for Lab Environment

### Creating the Lab Management Switch (Internal)

1. Open **Hyper-V Manager**
2. Click "Virtual Switch Manager" in the Actions pane
3. Select "Internal" and click "Create Virtual Switch"
4. Configure:
   - **Name**: `LAB-Management`
   - **Connection Type**: Internal network
   - **Notes**: Management network for lab infrastructure
5. Click "OK"

### PowerShell Method

```powershell
# Create internal switch for lab management
New-VMSwitch -Name "LAB-Management" -SwitchType Internal

# Get the interface index for IP configuration
$adapter = Get-NetAdapter -Name "vEthernet (LAB-Management)"
$ifIndex = $adapter.ifIndex

# Configure IP address for the management network
New-NetIPAddress -IPAddress 192.168.100.1 -PrefixLength 24 -InterfaceIndex $ifIndex
```

### Creating the Production Lab Switch (External)

```powershell
# List available network adapters
Get-NetAdapter -Physical

# Create external switch (replace with your adapter name)
New-VMSwitch -Name "LAB-External" -NetAdapterName "Ethernet" -AllowManagementOS $true
```

### Creating Isolated Lab Switch (Private)

```powershell
# Create private switch for isolated testing
New-VMSwitch -Name "LAB-Isolated" -SwitchType Private
```

## 🏗️ Step 4: Recommended Lab Network Architecture

### Network Segmentation Plan

```
┌─────────────────────────────────────────────────────────────┐
│                    Physical Host Network                     │
│                      192.168.1.0/24                        │
└─────────────────────┬───────────────────────────────────────┘
                      │
              ┌───────▼────────┐
              │  LAB-External  │
              │   Switch       │
              └───────┬────────┘
                      │
    ┌─────────────────┼─────────────────┐
    │                 │                 │
┌───▼───┐         ┌───▼───┐         ┌───▼───┐
│  DC1  │         │  FS1  │         │ WEB1  │
│.1.10  │         │ .1.20 │         │ .1.30 │
└───┬───┘         └───┬───┘         └───┬───┘
    │                 │                 │
    └─────────────────┼─────────────────┘
                      │
              ┌───────▼────────┐
              │ LAB-Management │
              │    Switch      │
              │ 192.168.100.0/24│
              └────────────────┘
```

## 📝 Step 5: Creating Virtual Machines with Proper Network Configuration

### PowerShell Script for VM Creation

```powershell
# Define VM parameters
$VMName = "DC1-LAB"
$VMPath = "C:\VMs"
$VHDSize = 80GB
$Memory = 4GB
$CPUCount = 2

# Create VM
New-VM -Name $VMName -Path $VMPath -MemoryStartupBytes $Memory -Generation 2

# Configure VM
Set-VM -Name $VMName -ProcessorCount $CPUCount
Set-VM -Name $VMName -DynamicMemory -MemoryMinimumBytes 2GB -MemoryMaximumBytes 8GB

# Create and attach VHD
$VHDPath = "$VMPath\$VMName\$VMName.vhdx"
New-VHD -Path $VHDPath -SizeBytes $VHDSize -Dynamic
Add-VMHardDiskDrive -VMName $VMName -Path $VHDPath

# Configure network adapters
Add-VMNetworkAdapter -VMName $VMName -SwitchName "LAB-External" -Name "External"
Add-VMNetworkAdapter -VMName $VMName -SwitchName "LAB-Management" -Name "Management"

# Configure boot order and security
Set-VMFirmware -VMName $VMName -EnableSecureBoot On -SecureBootTemplate "MicrosoftWindows"
Set-VMFirmware -VMName $VMName -FirstBootDevice (Get-VMDvdDrive -VMName $VMName)

# Enable integration services
Enable-VMIntegrationService -VMName $VMName -Name "Guest Service Interface"
Enable-VMIntegrationService -VMName $VMName -Name "Heartbeat"
Enable-VMIntegrationService -VMName $VMName -Name "Key-Value Pair Exchange"
Enable-VMIntegrationService -VMName $VMName -Name "Shutdown"
Enable-VMIntegrationService -VMName $VMName -Name "Time Synchronization"
Enable-VMIntegrationService -VMName $VMName -Name "VSS"
```

## 🔐 Step 6: Security and VLAN Configuration

### Configure VLANs for Network Isolation

```powershell
# Configure VLAN for management network
Set-VMNetworkAdapterVlan -VMName "DC1-LAB" -VMNetworkAdapterName "Management" -Access -VlanId 100

# Configure trunk for multi-VLAN access
Set-VMNetworkAdapterVlan -VMName "DC1-LAB" -VMNetworkAdapterName "External" -Trunk -AllowedVlanIdList 1,10,20,30
```

### MAC Address Spoofing (if needed)

```powershell
# Enable MAC spoofing for specific scenarios
Set-VMNetworkAdapter -VMName "DC1-LAB" -MacAddressSpoofing On
```

## 📊 Step 7: Network Monitoring and Troubleshooting

### PowerShell Commands for Network Diagnostics

```powershell
# List all virtual switches
Get-VMSwitch | Format-Table Name, SwitchType, NetAdapterInterfaceDescription

# Show VM network configuration
Get-VM | Get-VMNetworkAdapter | Format-Table VMName, Name, SwitchName, MacAddress

# Monitor network traffic
Get-Counter "\Hyper-V Virtual Network Adapter(*)\Bytes/sec"

# Test network connectivity
Test-NetConnection -ComputerName "192.168.1.10" -Port 3389
```

## 🛠️ Step 8: Advanced Configuration Scripts

### Complete Lab Network Setup Script

```powershell
# Lab Network Setup Script
param(
    [string]$ManagementNetwork = "192.168.100.0/24",
    [string]$ProductionNetwork = "192.168.1.0/24",
    [string]$PhysicalAdapter = "Ethernet"
)

# Create virtual switches
Write-Host "Creating virtual switches..." -ForegroundColor Green

# External switch for internet access
New-VMSwitch -Name "LAB-External" -NetAdapterName $PhysicalAdapter -AllowManagementOS $true

# Internal switch for management
New-VMSwitch -Name "LAB-Management" -SwitchType Internal

# Private switch for isolated testing
New-VMSwitch -Name "LAB-Isolated" -SwitchType Private

# Configure management network
$mgmtAdapter = Get-NetAdapter -Name "vEthernet (LAB-Management)"
New-NetIPAddress -IPAddress 192.168.100.1 -PrefixLength 24 -InterfaceIndex $mgmtAdapter.ifIndex

# Enable NAT for management network (optional)
New-NetNat -Name "LAB-ManagementNAT" -InternalIPInterfaceAddressPrefix 192.168.100.0/24

Write-Host "Virtual switches created successfully!" -ForegroundColor Green
Write-Host "External Switch: LAB-External" -ForegroundColor Yellow
Write-Host "Management Switch: LAB-Management (192.168.100.1/24)" -ForegroundColor Yellow
Write-Host "Isolated Switch: LAB-Isolated" -ForegroundColor Yellow
```

## 🎯 Best Practices for Lab Networking

### 1. Network Isolation

- Use separate switches for different security zones
- Implement VLANs for additional segmentation
- Keep production and lab networks isolated

### 2. IP Address Planning

```
Management Network: 192.168.100.0/24
Production Lab: 192.168.1.0/24
DMZ Network: 192.168.50.0/24
Client Network: 192.168.200.0/24
```

### 3. Virtual Machine Naming

- Include purpose: DC1, FS1, WEB1, CL01
- Include network location: LAB-DC1, PROD-FS1
- Use consistent naming conventions

### 4. Resource Allocation

- Start with minimum resources and scale up
- Use dynamic memory for better resource utilization
- Monitor performance and adjust accordingly

## 🔍 Troubleshooting Common Issues

### Issue 1: VMs Can't Access Internet

```powershell
# Check external switch configuration
Get-VMSwitch "LAB-External" | Format-List *

# Verify physical adapter binding
Get-VMSwitchTeam "LAB-External"

# Test connectivity from host
Test-NetConnection -ComputerName "8.8.8.8" -Port 53
```

### Issue 2: VM-to-VM Communication Fails

```powershell
# Check virtual switch configuration
Get-VMNetworkAdapter -VMName "DC1-LAB" | Format-Table VMName, SwitchName, MacAddress

# Verify firewall settings
Get-NetFirewallRule | Where-Object DisplayName -like "*Hyper-V*"
```

### Issue 3: Poor Network Performance

```powershell
# Check for VMQ support
Get-NetAdapterVmq

# Optimize network adapter settings
Set-NetAdapterAdvancedProperty -Name "vEthernet (LAB-External)" -DisplayName "Virtual Machine Queues" -DisplayValue "Enabled"
```

## 📚 Next Steps

1. **Configure Windows Server VMs**: Follow [01_Setup_Lab_Environment.md](01_Setup_Lab_Environment.md) with Hyper-V specific configurations
2. **Set up Network Services**: Implement DHCP, DNS, and other network services
3. **Create Client VMs**: Build client machines using the virtual switches created
4. **Implement Security**: Configure firewalls, VLANs, and network access control

## 🔗 Related Documentation

- [Lab Environment Setup](01_Setup_Lab_Environment.md)
- [Additional Servers Setup](13_Additional_Servers_Setup.md)
- [Network Troubleshooting](05_Troubleshooting.md)
- [Security Hardening](09_Security_Hardening.md)

---

**⚠️ Important Notes:**

- Always backup your VMs before making network changes
- Test network configurations in isolated environments first
- Document your network architecture for future reference
- Monitor network performance and adjust resources as needed
