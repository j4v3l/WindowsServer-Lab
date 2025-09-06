# DHCP Server Setup Script
# This script installs and configures DHCP on Windows Server
#
# EXECUTION CONTEXT: Run INSIDE Windows Server VMs (DHCP Server or Domain Controller)
# ACCESS METHOD: RDP, Console, or PowerShell Direct to Windows VM
# PREREQUISITES: Windows Server VM running, Local Admin rights

# Install DHCP Server Role
Install-WindowsFeature -Name DHCP -IncludeManagementTools

# Authorize DHCP in Active Directory (if domain joined)
$hostname = (hostname)
$domain = (Get-ADDomain).DNSRoot
$ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notlike 'Loopback*' }).IPAddress
Add-DhcpServerInDC -DnsName "$hostname.$domain" -IpAddress $ip

# Create DHCP Scope
$ScopeName = "LabScope"
$StartRange = "192.168.1.100"
$EndRange = "192.168.1.200"
$SubnetMask = "255.255.255.0"
$Gateway = "192.168.1.1"
$DnsServers = @("192.168.1.10","192.168.1.11")
$DnsDomain = $domain

Add-DhcpServerv4Scope -Name $ScopeName -StartRange $StartRange -EndRange $EndRange -SubnetMask $SubnetMask -State Active
Set-DhcpServerv4OptionValue -ScopeId "192.168.1.0" -Router $Gateway
Set-DhcpServerv4OptionValue -ScopeId "192.168.1.0" -DnsServer $DnsServers -DnsDomain $DnsDomain

# Example: Add a reservation (edit MAC address as needed)
# Add-DhcpServerv4Reservation -ScopeId "192.168.1.0" -IPAddress "192.168.1.50" -ClientId "00-11-22-33-44-55" -Description "Printer Reservation"

# Example: Add an exclusion range
# Add-DhcpServerv4ExclusionRange -ScopeId "192.168.1.0" -StartRange "192.168.1.150" -EndRange "192.168.1.160"

# Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "DHCP Server installation and configuration complete." -ForegroundColor Green 