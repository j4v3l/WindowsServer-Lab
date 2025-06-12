# 🔧 Network Troubleshooting Guide

## 🎯 **Overview**

This guide addresses common networking issues encountered in Windows Server lab environments, specifically focusing on Hyper-V virtual networking configuration problems that prevent domain joins and network connectivity.

---

## 🚨 **Common Network Issues**

### **Issue 1: Domain Join Fails with "Access is denied"**

#### **Symptoms:**

- `Add-Computer` fails with "Access is denied"
- `netdom join` command not found
- DNS resolution timeouts
- Cannot ping domain controller

#### **Root Causes:**

1. Virtual switch misconfiguration (Private vs Internal)
2. Missing IP forwarding between networks
3. No default gateways configured on VMs
4. Incorrect DNS server settings

#### **Solution Steps:**

**Step 1: Check Virtual Switch Types**

```powershell
# Check current switch configuration
Get-VMSwitch | Select-Object Name, SwitchType, NetAdapterInterfaceDescription

# Expected configuration:
# ASGARD-Production: Internal (NOT External)
# ASGARD-Management: Internal
# ASGARD-Clients: Internal
# ASGARD-DMZ: Private
```

**Step 2: Verify IP Forwarding**

```powershell
# Check IP forwarding status
Get-NetIPInterface | Where-Object {$_.InterfaceAlias -like "*ASGARD*"} | Select-Object InterfaceAlias, Forwarding

# Enable IP forwarding if disabled
Set-NetIPInterface -InterfaceAlias "vEthernet (ASGARD-Production)" -Forwarding Enabled
Set-NetIPInterface -InterfaceAlias "vEthernet (ASGARD-Clients)" -Forwarding Enabled
Set-NetIPInterface -InterfaceAlias "vEthernet (ASGARD-Management)" -Forwarding Enabled
```

**Step 3: Configure Gateway IPs on Host**

```powershell
# Verify gateway IPs are configured
Get-NetIPAddress | Where-Object {$_.InterfaceAlias -like "*ASGARD*"}

# Configure missing gateways
New-NetIPAddress -IPAddress 10.0.10.1 -PrefixLength 24 -InterfaceAlias "vEthernet (ASGARD-Production)"
New-NetIPAddress -IPAddress 10.0.20.1 -PrefixLength 22 -InterfaceAlias "vEthernet (ASGARD-Clients)"
New-NetIPAddress -IPAddress 10.0.100.1 -PrefixLength 24 -InterfaceAlias "vEthernet (ASGARD-Management)"
```

**Step 4: Configure VM Network Settings**

```cmd
# On domain controller (ODIN-DC01)
netsh interface ip set address "Ethernet" static 10.0.10.10 255.255.255.0 10.0.10.1
netsh interface ip set dns "Ethernet" static 127.0.0.1

# On client VMs (e.g., FREYA-WS01)
netsh interface ip set address "Ethernet" static 10.0.20.101 255.255.252.0 10.0.20.1
netsh interface ip set dns "Ethernet" static 10.0.10.10

# Add static route on client (if needed)
route add 10.0.10.0 mask 255.255.255.0 10.0.20.1 -p
```

---

### **Issue 2: User Account Password Problems**

#### **Symptoms:**

- "Password must be changed at next logon"
- "Password has expired"
- Cannot authenticate to domain

#### **Root Cause:**

User accounts created with password expiration enabled in lab environment.

#### **Solution:**

```powershell
# Reset user password and disable expiration
Set-ADAccountPassword -Identity "odin.allfather" -Reset -NewPassword (ConvertTo-SecureString "NewPassword123!" -AsPlainText -Force)
Set-ADUser -Identity "odin.allfather" -PasswordNeverExpires $true -ChangePasswordAtLogon $false

# For lab environments, disable password policies
Set-ADDefaultDomainPasswordPolicy -MaxPasswordAge 0 -MinPasswordAge 0
```

---

### **Issue 3: DNS Resolution Failures**

#### **Symptoms:**

- `nslookup domain.local` fails
- Cannot resolve server names
- Intermittent connectivity

#### **Diagnostic Commands:**

```powershell
# Test DNS resolution
nslookup asgard.local
nslookup asgard.local 10.0.10.10

# Check DNS server configuration
Get-DnsClientServerAddress

# Test connectivity to DNS server
Test-NetConnection -ComputerName 10.0.10.10 -Port 53
```

#### **Solution:**

```cmd
# Set correct DNS server
netsh interface ip set dns "Ethernet" static 10.0.10.10

# Flush DNS cache
ipconfig /flushdns

# Register with DNS
ipconfig /registerdns
```

---

### **Issue 4: Gateway Connectivity Problems**

#### **Symptoms:**

- Cannot ping gateway
- "Network unreachable" errors
- VMs isolated from other networks

#### **Diagnostic Commands:**

```powershell
# Test gateway connectivity
ping 10.0.10.1
ping 10.0.20.1
ping 10.0.100.1

# Check routing table
route print

# Test cross-network connectivity
ping 10.0.10.10  # From client to server network
```

#### **Solution:**

```cmd
# Add default gateway
netsh interface ip set address "Ethernet" static [IP] [MASK] [GATEWAY]

# Add specific routes
route add 10.0.10.0 mask 255.255.255.0 10.0.20.1 -p
route add 10.0.100.0 mask 255.255.255.0 10.0.20.1 -p
```

---

## 🛠️ **Automated Network Validation**

### **Quick Network Test Script**

Save as `Test-NetworkConnectivity.ps1`:

```powershell
# Quick network connectivity test
$tests = @(
    @{Name="Production Gateway"; Target="10.0.10.1"},
    @{Name="Client Gateway"; Target="10.0.20.1"},
    @{Name="Management Gateway"; Target="10.0.100.1"},
    @{Name="Domain Controller"; Target="10.0.10.10"},
    @{Name="DNS Resolution"; Target="asgard.local"}
)

Write-Host "🔍 Network Connectivity Test" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan

foreach ($test in $tests) {
    if ($test.Name -eq "DNS Resolution") {
        $result = try { Resolve-DnsName $test.Target -ErrorAction Stop; $true } catch { $false }
    } else {
        $result = Test-NetConnection -ComputerName $test.Target -InformationLevel Quiet -WarningAction SilentlyContinue
    }

    $status = if ($result) { "✅" } else { "❌" }
    $color = if ($result) { "Green" } else { "Red" }
    Write-Host "$status $($test.Name) ($($test.Target))" -ForegroundColor $color
}
```

### **Comprehensive Network Validation**

Use the provided `Test-AsgardNetwork.ps1` script for complete validation:

```powershell
# Run complete network test
.\Demo\Asgard\Scripts\Test-AsgardNetwork.ps1

# Quick connectivity test only
.\Test-NetworkConnectivity.ps1
```

---

## 🔄 **Network Configuration Reset**

### **Complete Network Reset (Nuclear Option)**

If all else fails, reset and recreate the network:

```powershell
# Stop all VMs
Get-VM | Where-Object {$_.Name -like "*ASGARD*"} | Stop-VM -Force

# Remove existing switches
Get-VMSwitch | Where-Object {$_.Name -like "*ASGARD*"} | Remove-VMSwitch -Force

# Remove NAT configurations
Get-NetNat | Where-Object {$_.Name -like "*ASGARD*"} | Remove-NetNat -Confirm:$false

# Recreate network infrastructure
.\Demo\Asgard\Scripts\Deploy-AsgardLab.ps1 -NetworkOnly -Force

# Validate configuration
.\Demo\Asgard\Scripts\Test-AsgardNetwork.ps1
```

---

## 📋 **Network Configuration Checklist**

### **Pre-Deployment Checklist**

- [ ] Hyper-V feature fully enabled
- [ ] Sufficient RAM and disk space
- [ ] No IP address conflicts with existing networks
- [ ] Physical network adapter available and functional

### **Post-Deployment Validation**

- [ ] All virtual switches created with correct types
- [ ] Gateway IPs configured on host interfaces
- [ ] IP forwarding enabled on all virtual interfaces
- [ ] NAT configuration active
- [ ] VM network adapters connected to correct switches
- [ ] DNS resolution working from all VMs
- [ ] Cross-network connectivity functional

### **VM-Specific Configuration**

- [ ] Static IP addresses assigned
- [ ] Default gateways configured
- [ ] DNS servers set correctly
- [ ] Domain join successful
- [ ] User authentication working

---

## 🚨 **Emergency Network Recovery**

### **Quick Fix Commands**

If domain join fails immediately, run these commands on the client VM:

```cmd
# Reset network configuration
netsh interface ip set address "Ethernet" static 10.0.20.101 255.255.252.0 10.0.20.1
netsh interface ip set dns "Ethernet" static 10.0.10.10
ipconfig /flushdns
ipconfig /registerdns

# Test connectivity
ping 10.0.20.1
ping 10.0.10.10
nslookup asgard.local

# Retry domain join
Add-Computer -DomainName "asgard.local" -Credential (Get-Credential asgard\odin.allfather) -Restart
```

### **Host Network Recovery**

If host networking is broken:

```powershell
# Reset IP forwarding
Get-NetIPInterface | Where-Object {$_.InterfaceAlias -like "*ASGARD*"} | Set-NetIPInterface -Forwarding Enabled

# Recreate gateway IPs if missing
$adapters = @{
    "vEthernet (ASGARD-Production)" = "10.0.10.1/24"
    "vEthernet (ASGARD-Clients)" = "10.0.20.1/22"
    "vEthernet (ASGARD-Management)" = "10.0.100.1/24"
}

foreach ($adapter in $adapters.Keys) {
    $ip, $prefix = $adapters[$adapter] -split '/'
    $netAdapter = Get-NetAdapter -Name $adapter -ErrorAction SilentlyContinue
    if ($netAdapter) {
        Remove-NetIPAddress -InterfaceIndex $netAdapter.ifIndex -Confirm:$false -ErrorAction SilentlyContinue
        New-NetIPAddress -IPAddress $ip -PrefixLength $prefix -InterfaceIndex $netAdapter.ifIndex -ErrorAction SilentlyContinue
    }
}
```

---

## 📞 **Still Having Issues?**

### **Advanced Diagnostic Commands**

```powershell
# Get detailed network configuration
Get-NetAdapter | Get-NetIPConfiguration
Get-VMSwitch | Get-VMNetworkAdapter
Get-NetRoute | Where-Object {$_.DestinationPrefix -like "10.0.*"}

# Test VM network connectivity
Get-VM | Get-VMNetworkAdapter | Select-Object VMName, Name, SwitchName, Connected

# Monitor network traffic
Get-Counter "\Hyper-V Virtual Network Adapter(*)\Bytes/sec"
```

### **Log Files to Check**

- Event Viewer: System and Application logs
- Hyper-V logs: `Applications and Services Logs\Microsoft\Windows\Hyper-V-*`
- DNS logs: `DNS Server` logs if available
- Domain join logs: Check domain controller security logs

---

## ✅ **Success Indicators**

Your network is properly configured when:

- ✅ All gateway IPs respond to ping
- ✅ DNS resolution works for domain names
- ✅ Cross-network connectivity established
- ✅ Domain join completes successfully
- ✅ User authentication functions properly
- ✅ Network validation script passes all tests

**Remember:** Network issues in lab environments are almost always configuration-related, not hardware problems. Follow this guide systematically to identify and resolve the root cause.
