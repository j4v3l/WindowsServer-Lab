# 🖧 Windows Server DHCP Setup Tutorial

## 🎯 What You'll Learn

- How to install and configure the DHCP Server role
- How to create and manage DHCP scopes
- How to set reservations and exclusions
- Best practices for DHCP management

---

## 1️⃣ Install the DHCP Server Role

### Using Server Manager

1. Open **Server Manager**
2. Click **Add roles and features**
3. Select **Role-based or feature-based installation**
4. Choose your server
5. Check **DHCP Server**
6. Click **Next** and complete the wizard
7. After installation, click **Complete DHCP configuration**

### Using PowerShell

**EXECUTION CONTEXT: Run INSIDE Windows Server VM (DHCP Server)**  
**ACCESS METHOD: RDP, Console, or PowerShell Direct to DHCP Server VM**  
**PREREQUISITES: Local Administrator rights, DHCP role installed**

```powershell
Install-WindowsFeature -Name DHCP -IncludeManagementTools

# Authorize DHCP in Active Directory (if domain joined)
Add-DhcpServerInDC -DnsName "$(hostname).yourdomain.local" -IpAddress (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notlike 'Loopback*' }).IPAddress
```

---

## 2️⃣ Configure a DHCP Scope

### Using Server Manager

1. Open **DHCP Management Console** (`dhcpmgmt.msc`)
2. Expand your server > **IPv4** > **New Scope**
3. Enter a name and description
4. Set the IP address range (e.g., 192.168.1.100 to 192.168.1.200)
5. Set subnet mask, exclusions, and lease duration
6. Configure default gateway, DNS, and WINS as needed
7. Activate the scope

### Using PowerShell

```powershell
Add-DhcpServerv4Scope -Name "LabScope" -StartRange 192.168.1.100 -EndRange 192.168.1.200 -SubnetMask 255.255.255.0 -State Active

# Set default gateway
Set-DhcpServerv4OptionValue -ScopeId 192.168.1.0 -Router 192.168.1.1

# Set DNS servers
Set-DhcpServerv4OptionValue -ScopeId 192.168.1.0 -DnsServer 192.168.1.10,192.168.1.11 -DnsDomain "yourdomain.local"
```

---

## 3️⃣ Add Reservations and Exclusions

### Reservation (for a specific device)

```powershell
Add-DhcpServerv4Reservation -ScopeId 192.168.1.0 -IPAddress 192.168.1.50 -ClientId "00-11-22-33-44-55" -Description "Printer Reservation"
```

### Exclusion Range

```powershell
Add-DhcpServerv4ExclusionRange -ScopeId 192.168.1.0 -StartRange 192.168.1.150 -EndRange 192.168.1.160
```

---

## 4️⃣ Monitor and Manage DHCP

- Use **DHCP Management Console** or PowerShell cmdlets (e.g., `Get-DhcpServerv4Lease`)
- Regularly review the DHCP event log for issues
- Back up DHCP configuration:

```powershell
Backup-DhcpServer -Path "C:\DHCPBackup"
```

---

## 5️⃣ Best Practices

- Use reservations for servers/printers
- Limit scope to only needed addresses
- Regularly back up DHCP database
- Monitor for rogue DHCP servers
- Document all changes

---

## 📚 Additional Resources

- [Microsoft DHCP Documentation](https://docs.microsoft.com/en-us/windows-server/networking/technologies/dhcp/dhcp-top)
