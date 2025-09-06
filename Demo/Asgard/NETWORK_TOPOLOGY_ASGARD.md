# 🌐 **ASGARD TECHNOLOGIES NETWORK TOPOLOGY**

## Norse Mythology Enterprise Demo - Proxmox Edition

**Documentation Date:** December 2024  
**Platform:** Proxmox VE Virtualization  
**Domain:** asgard.local  
**Architecture:** 4-tier enterprise network with security segmentation

---

## 📋 **OVERVIEW**

Asgard Technologies implements a Norse mythology-themed enterprise network with proper security segmentation and enterprise-grade infrastructure. The design supports demonstration scenarios while maintaining production-ready architecture.

### **Network Architecture:**

- **4 Primary Networks** with security segmentation
- **Network Segmentation** via Proxmox bridges
- **Enterprise Security** with DMZ isolation
- **Scalable Design** supporting 25+ VMs

---

## 🏰 **ASGARD NETWORK SEGMENTATION**

| Network | CIDR | Purpose | Proxmox Bridge | Gateway | VLAN |
|---------|------|---------|----------------|---------|------|
| **Production** | `10.0.10.0/24` | Domain Controllers, Servers | `vmbr0` | `10.0.10.1` | 10 |
| **Management** | `10.0.100.0/24` | Administrative Access | `vmbr1` | `10.0.100.1` | 100 |
| **Client** | `10.0.20.0/22` | Workstations (1022 addresses) | `vmbr2` | `10.0.20.1` | 20 |
| **DMZ** | `10.0.50.0/24` | External-facing Services | `vmbr3` | `10.0.50.1` | 50 |

---

## 🖥️ **SERVER INFRASTRUCTURE**

### **Core Servers - Production Network**

| Server Role | Hostname | IP Address | VM ID | Specifications | Network Interfaces |
|-------------|----------|------------|-------|----------------|-------------------|
| **Primary DC** | ODIN-DC01 | `10.0.10.10` | 100 | 4 vCPU, 8GB RAM, 100GB | vmbr0, vmbr1 |
| **Secondary DC** | FRIGG-DC02 | `10.0.10.11` | 101 | 4 vCPU, 8GB RAM, 100GB | vmbr0, vmbr1 |
| **File Server** | HEIMDALL-FS01 | `10.0.10.20` | 102 | 4 vCPU, 8GB RAM, 500GB | vmbr0, vmbr1 |
| **Web Server** | BALDER-WEB01 | `10.0.10.30` | 103 | 4 vCPU, 8GB RAM, 200GB | vmbr0, vmbr1, vmbr3 |
| **Security Server** | VIDAR-SEC01 | `10.0.10.40` | 104 | 4 vCPU, 8GB RAM, 200GB | vmbr0, vmbr1 |

### **Server Roles & Services**

#### **ODIN-DC01 (Primary Domain Controller)**

- **Services:** Active Directory, DNS, DHCP, FSMO Roles
- **Norse Role:** All-Father, ruler of Asgard
- **Key Functions:**
  - Forest root domain controller
  - Global catalog server
  - DNS primary zone hosting
  - DHCP scope management

#### **FRIGG-DC02 (Secondary Domain Controller)**

- **Services:** Active Directory replication, DNS secondary
- **Norse Role:** Queen of Asgard, Odin's wife
- **Key Functions:**
  - Domain controller redundancy
  - DNS secondary zones
  - Global catalog replica
  - Backup authentication services

#### **HEIMDALL-FS01 (File Server)**

- **Services:** File shares, DFS, backup storage
- **Norse Role:** Guardian of the rainbow bridge
- **Key Functions:**
  - Departmental file shares
  - Home directory hosting
  - Distributed file system
  - Backup target storage

#### **BALDER-WEB01 (Web Server)**

- **Services:** IIS, web applications, public services
- **Norse Role:** God of light and purity
- **Key Functions:**
  - Corporate intranet
  - External web presence (DMZ)
  - Application hosting
  - Public-facing services

#### **VIDAR-SEC01 (Security Server)**

- **Services:** WSUS, monitoring, security tools
- **Norse Role:** God of vengeance and silence
- **Key Functions:**
  - Windows update management
  - Security monitoring
  - Antivirus management
  - Log aggregation

---

## 💻 **WORKSTATION INFRASTRUCTURE**

### **Departmental Distribution**

#### **🔱 IT Operations (Odin's Inner Circle)**

| Workstation | User | VM ID | IP Range | Role |
|-------------|------|-------|----------|------|
| **ODIN-WS01** | Chief Technology Officer | 110 | `10.0.20.10` | All-Father of Technology |
| **THOR-WS01** | Senior System Engineer | 111 | `10.0.20.11` | God of Thunder & Power |
| **LOKI-WS01** | Lead Developer | 112 | `10.0.20.12` | Trickster & Innovation |
| **HERMOD-WS01** | Network Administrator | 113 | `10.0.20.13` | Messenger of the Gods |
| **TYR-WS01** | Security Analyst | 114 | `10.0.20.14` | God of War & Justice |

#### **🛡️ Cybersecurity (Asgard Guardians)**

| Workstation | User | VM ID | IP Range | Security Focus |
|-------------|------|-------|----------|----------------|
| **HEIMDALL-WS01** | Chief Information Security Officer | 115 | `10.0.20.15` | All-seeing Guardian |
| **MIMIR-WS01** | Threat Intelligence Analyst | 116 | `10.0.20.16` | Wisdom & Knowledge |
| **HUGINN-WS01** | SOC Analyst 1 | 117 | `10.0.20.17` | Thought & Reconnaissance |
| **MUNINN-WS01** | SOC Analyst 2 | 118 | `10.0.20.18` | Memory & Analysis |
| **GERI-WS01** | Incident Response Specialist | 119 | `10.0.20.19` | Wolf of War |

#### **🔬 Research & Development (Innovation Realm)**

| Workstation | User | VM ID | IP Range | R&D Focus |
|-------------|------|-------|----------|-----------|
| **FREYA-WS01** | R&D Director | 120 | `10.0.20.20` | Goddess of Love & Beauty |
| **NJORD-WS01** | Cloud Architect | 121 | `10.0.20.21` | God of Wind & Sea |
| **FREY-WS01** | Software Architect | 122 | `10.0.20.22` | God of Prosperity |
| **JORMUNGANDR-WS01** | DevOps Engineer | 123 | `10.0.20.23` | World Serpent |
| **SLEIPNIR-WS01** | Performance Engineer | 124 | `10.0.20.24` | Eight-legged Horse |

#### **💰 Finance (Wealth Guardians)**

| Workstation | User | VM ID | IP Range | Finance Role |
|-------------|------|-------|----------|--------------|
| **FRIGG-WS01** | Chief Financial Officer | 125 | `10.0.20.25` | Queen of Household |
| **EIR-WS01** | Senior Accountant | 126 | `10.0.20.26` | Goddess of Healing |
| **SAGA-WS01** | Financial Analyst | 127 | `10.0.20.27` | Goddess of Stories |
| **VAR-WS01** | Compliance Officer | 128 | `10.0.20.28` | Goddess of Oaths |
| **FORSETI-WS01** | Audit Manager | 129 | `10.0.20.29` | God of Justice |

#### **👥 Human Resources (Harmony Keepers)**

| Workstation | User | VM ID | IP Range | HR Specialty |
|-------------|------|-------|----------|--------------|
| **SIF-WS01** | HR Director | 130 | `10.0.20.30` | Thor's Golden-haired Wife |
| **IDUN-WS01** | Recruitment Specialist | 131 | `10.0.20.31` | Keeper of Youth |
| **BRAGI-WS01** | Training Coordinator | 132 | `10.0.20.32` | God of Poetry |
| **HEL-WS01** | Benefits Administrator | 133 | `10.0.20.33` | Ruler of the Underworld |
| **NANNA-WS01** | Employee Relations | 134 | `10.0.20.34` | Goddess of Joy |

---

## 🔧 **PROXMOX NETWORK CONFIGURATION**

### **Bridge Configuration**

#### **Production Bridge (vmbr0)**

```bash
# [PROXMOX HOST] - Configure production bridge
# /etc/network/interfaces

auto vmbr0
iface vmbr0 inet static
    address 10.0.10.1/24
    bridge-ports ens18
    bridge-stp off
    bridge-fd 0
    # External connectivity for servers
    # VLAN 10 - Production Network
```

#### **Management Bridge (vmbr1)**

```bash
# [PROXMOX HOST] - Configure management bridge
auto vmbr1
iface vmbr1 inet static
    address 10.0.100.1/24
    bridge-ports none
    bridge-stp off
    bridge-fd 0
    # Internal management network
    # VLAN 100 - Management Network
```

#### **Client Bridge (vmbr2)**

```bash
# [PROXMOX HOST] - Configure client bridge
auto vmbr2
iface vmbr2 inet static
    address 10.0.20.1/22
    bridge-ports none
    bridge-stp off
    bridge-fd 0
    # Internal client network
    # VLAN 20 - Client Network
```

#### **DMZ Bridge (vmbr3)**

```bash
# [PROXMOX HOST] - Configure DMZ bridge
auto vmbr3
iface vmbr3 inet static
    address 10.0.50.1/24
    bridge-ports none
    bridge-stp off
    bridge-fd 0
    # Isolated DMZ network
    # VLAN 50 - DMZ Network
```

---

## 🔒 **ASGARD SECURITY ZONES**

### **Network Security Matrix**

| Source Zone | Target Zone | Access | Ports | Purpose |
|-------------|-------------|--------|-------|---------|
| **Management** | **Production** | Full | All | Administrative access |
| **Management** | **Client** | Limited | RDP (3389), WinRM (5985) | Workstation management |
| **Management** | **DMZ** | Limited | HTTP (80), HTTPS (443), SSH (22) | Web server management |
| **Production** | **Client** | Limited | DNS (53), DHCP (67/68), SMB (445) | Domain services |
| **Client** | **Production** | Limited | DNS (53), LDAP (389), Kerberos (88) | Authentication |
| **Client** | **DMZ** | Limited | HTTP (80), HTTPS (443) | Web access |
| **DMZ** | **Production** | **DENIED** | None | Security isolation |
| **Internet** | **DMZ** | Limited | HTTP (80), HTTPS (443) | Public web access |

### **Firewall Rules**

#### **Production Network Protection**

```bash
# [PROXMOX HOST] - Asgard production network firewall rules
# Allow management access to production
iptables -A FORWARD -s 10.0.100.0/24 -d 10.0.10.0/24 -j ACCEPT

# Allow client authentication to domain controllers
iptables -A FORWARD -s 10.0.20.0/22 -d 10.0.10.10 -p tcp --dport 53 -j ACCEPT   # DNS
iptables -A FORWARD -s 10.0.20.0/22 -d 10.0.10.10 -p tcp --dport 88 -j ACCEPT   # Kerberos
iptables -A FORWARD -s 10.0.20.0/22 -d 10.0.10.10 -p tcp --dport 389 -j ACCEPT  # LDAP
iptables -A FORWARD -s 10.0.20.0/22 -d 10.0.10.10 -p tcp --dport 445 -j ACCEPT  # SMB

# Allow client access to file server
iptables -A FORWARD -s 10.0.20.0/22 -d 10.0.10.20 -p tcp --dport 445 -j ACCEPT  # SMB shares

# Block DMZ to production (critical security rule)
iptables -A FORWARD -s 10.0.50.0/24 -d 10.0.10.0/24 -j DROP

# Allow internet to DMZ web services
iptables -A FORWARD -d 10.0.50.0/24 -p tcp --dport 80 -j ACCEPT
iptables -A FORWARD -d 10.0.50.0/24 -p tcp --dport 443 -j ACCEPT
```

---

## 📊 **DHCP CONFIGURATION**

### **DHCP Scopes**

#### **Asgard Client Network Scope**

```powershell
# [SERVER VM] - Run on ODIN-DC01
# DHCP scope for Asgard client workstations

Add-DhcpServerV4Scope -Name "Asgard Client Network" -StartRange 10.0.20.100 -EndRange 10.0.23.200 -SubnetMask 255.255.252.0 -Description "Norse Workstation Network"

# DHCP Options for Asgard
Set-DhcpServerV4OptionValue -ScopeId 10.0.20.0 -OptionId 3 -Value 10.0.20.1         # Default Gateway
Set-DhcpServerV4OptionValue -ScopeId 10.0.20.0 -OptionId 6 -Value 10.0.10.10,10.0.10.11  # DNS Servers
Set-DhcpServerV4OptionValue -ScopeId 10.0.20.0 -OptionId 15 -Value "asgard.local"    # Domain Name
Set-DhcpServerV4OptionValue -ScopeId 10.0.20.0 -OptionId 44 -Value 10.0.10.10       # WINS Server

# DHCP Reservations for key workstations
Add-DhcpServerV4Reservation -ScopeId 10.0.20.0 -IPAddress 10.0.20.10 -ClientId "00-15-5D-XX-XX-01" -Name "ODIN-WS01"
Add-DhcpServerV4Reservation -ScopeId 10.0.20.0 -IPAddress 10.0.20.11 -ClientId "00-15-5D-XX-XX-02" -Name "THOR-WS01"
Add-DhcpServerV4Reservation -ScopeId 10.0.20.0 -IPAddress 10.0.20.15 -ClientId "00-15-5D-XX-XX-03" -Name "HEIMDALL-WS01"
```

---

## 🔍 **DNS CONFIGURATION**

### **Forward Lookup Zones**

#### **Asgard Domain Services**

```powershell
# [SERVER VM] - Run on ODIN-DC01
# DNS records for Asgard services

# Server A Records
Add-DnsServerResourceRecordA -ZoneName "asgard.local" -Name "odin-dc01" -IPv4Address "10.0.10.10"
Add-DnsServerResourceRecordA -ZoneName "asgard.local" -Name "frigg-dc02" -IPv4Address "10.0.10.11"
Add-DnsServerResourceRecordA -ZoneName "asgard.local" -Name "heimdall-fs01" -IPv4Address "10.0.10.20"
Add-DnsServerResourceRecordA -ZoneName "asgard.local" -Name "balder-web01" -IPv4Address "10.0.10.30"
Add-DnsServerResourceRecordA -ZoneName "asgard.local" -Name "vidar-sec01" -IPv4Address "10.0.10.40"

# Service aliases for easy access
Add-DnsServerResourceRecordCName -ZoneName "asgard.local" -Name "dc1" -HostNameAlias "odin-dc01.asgard.local"
Add-DnsServerResourceRecordCName -ZoneName "asgard.local" -Name "dc2" -HostNameAlias "frigg-dc02.asgard.local"
Add-DnsServerResourceRecordCName -ZoneName "asgard.local" -Name "fileserver" -HostNameAlias "heimdall-fs01.asgard.local"
Add-DnsServerResourceRecordCName -ZoneName "asgard.local" -Name "webserver" -HostNameAlias "balder-web01.asgard.local"
Add-DnsServerResourceRecordCName -ZoneName "asgard.local" -Name "security" -HostNameAlias "vidar-sec01.asgard.local"

# Departmental service records
Add-DnsServerResourceRecordCName -ZoneName "asgard.local" -Name "intranet" -HostNameAlias "balder-web01.asgard.local"
Add-DnsServerResourceRecordCName -ZoneName "asgard.local" -Name "wsus" -HostNameAlias "vidar-sec01.asgard.local"
```

### **Reverse Lookup Zones**

```powershell
# [SERVER VM] - Run on ODIN-DC01
# Reverse DNS zones for Asgard networks

Add-DnsServerPrimaryZone -NetworkID "10.0.10.0/24" -ReplicationScope Domain
Add-DnsServerPrimaryZone -NetworkID "10.0.20.0/22" -ReplicationScope Domain

# Reverse records for servers
Add-DnsServerResourceRecordPtr -ZoneName "10.0.10.in-addr.arpa" -Name "10" -PtrDomainName "odin-dc01.asgard.local"
Add-DnsServerResourceRecordPtr -ZoneName "10.0.10.in-addr.arpa" -Name "11" -PtrDomainName "frigg-dc02.asgard.local"
Add-DnsServerResourceRecordPtr -ZoneName "10.0.10.in-addr.arpa" -Name "20" -PtrDomainName "heimdall-fs01.asgard.local"
```

---

## 🚀 **ROUTING CONFIGURATION**

### **Inter-VLAN Routing**

#### **Host Routing Table**

```bash
# [PROXMOX HOST] - Configure routing between Asgard networks
# Enable IP forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward
echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf

# Static routes for Asgard network communication
ip route add 10.0.20.0/22 via 10.0.20.1 dev vmbr2
ip route add 10.0.50.0/24 via 10.0.50.1 dev vmbr3

# Persistent routing configuration
echo "10.0.20.0/22 via 10.0.20.1 dev vmbr2" >> /etc/network/interfaces
echo "10.0.50.0/24 via 10.0.50.1 dev vmbr3" >> /etc/network/interfaces
```

#### **NAT Configuration**

```bash
# [PROXMOX HOST] - NAT for outbound internet access
iptables -t nat -A POSTROUTING -s 10.0.10.0/24 -o vmbr0 -j MASQUERADE
iptables -t nat -A POSTROUTING -s 10.0.20.0/22 -o vmbr0 -j MASQUERADE

# Save iptables rules
iptables-save > /etc/iptables/rules.v4
```

---

## 📋 **ASGARD TROUBLESHOOTING GUIDE**

### **Common Network Issues**

#### **Domain Join Failures**

```powershell
# [CLIENT VM] - Verify network connectivity before domain join
# Test DNS resolution for Asgard domain
nslookup asgard.local 10.0.10.10
nslookup odin-dc01.asgard.local 10.0.10.10

# Test required ports for domain join
Test-NetConnection -ComputerName odin-dc01.asgard.local -Port 53    # DNS
Test-NetConnection -ComputerName odin-dc01.asgard.local -Port 88    # Kerberos
Test-NetConnection -ComputerName odin-dc01.asgard.local -Port 389   # LDAP
Test-NetConnection -ComputerName odin-dc01.asgard.local -Port 445   # SMB

# Check time synchronization (critical for Kerberos)
w32tm /query /status
w32tm /resync
```

#### **File Share Access Issues**

```powershell
# [CLIENT VM] - Troubleshoot file server access
# Test connectivity to Heimdall file server
Test-NetConnection -ComputerName heimdall-fs01.asgard.local -Port 445

# Check SMB shares
Get-SmbConnection
Get-SmbShare -CimSession heimdall-fs01.asgard.local

# Test with explicit credentials
New-PSDrive -Name "Z" -PSProvider FileSystem -Root "\\heimdall-fs01.asgard.local\shared" -Credential (Get-Credential)
```

#### **Web Server DMZ Issues**

```bash
# [PROXMOX HOST] - Check DMZ connectivity
# Verify DMZ bridge status
ip addr show vmbr3
brctl show vmbr3

# Test web server connectivity from DMZ
ping -c 4 10.0.50.30  # Should be web server DMZ IP
```

---

## 📊 **PERFORMANCE OPTIMIZATION**

### **Network Performance Tuning**

#### **Bridge Optimization**

```bash
# [PROXMOX HOST] - Optimize Asgard network bridges
# Disable spanning tree for performance
echo 0 > /sys/class/net/vmbr0/bridge/stp_state
echo 0 > /sys/class/net/vmbr1/bridge/stp_state
echo 0 > /sys/class/net/vmbr2/bridge/stp_state
echo 0 > /sys/class/net/vmbr3/bridge/stp_state

# Set bridge forward delay to 0
echo 0 > /sys/class/net/vmbr0/bridge/forward_delay
echo 0 > /sys/class/net/vmbr1/bridge/forward_delay
echo 0 > /sys/class/net/vmbr2/bridge/forward_delay
echo 0 > /sys/class/net/vmbr3/bridge/forward_delay
```

#### **VM Network Optimization**

```bash
# [PROXMOX HOST] - Optimize Asgard VM network adapters
# Configure VirtIO for all Asgard servers
qm set 100 --net0 virtio,bridge=vmbr0,firewall=1  # ODIN-DC01 Production
qm set 100 --net1 virtio,bridge=vmbr1,firewall=1  # ODIN-DC01 Management
qm set 101 --net0 virtio,bridge=vmbr0,firewall=1  # FRIGG-DC02 Production
qm set 101 --net1 virtio,bridge=vmbr1,firewall=1  # FRIGG-DC02 Management

# Enable multiqueue for high-performance workstations
qm set 110 --net0 virtio,bridge=vmbr2,queues=4    # ODIN-WS01
qm set 111 --net0 virtio,bridge=vmbr2,queues=4    # THOR-WS01
```

---

## 📈 **MONITORING & MAINTENANCE**

### **Network Monitoring**

#### **Bandwidth Monitoring**

```bash
# [PROXMOX HOST] - Monitor Asgard network traffic
# Install monitoring tools
apt update && apt install iftop nethogs vnstat

# Monitor specific bridge traffic
iftop -i vmbr0  # Production network
iftop -i vmbr2  # Client network

# Historical network statistics
vnstat -i vmbr0
vnstat -i vmbr2
```

#### **Domain Controller Monitoring**

```powershell
# [SERVER VM] - Monitor Odin-DC01 connections
Get-ADReplicationConnection -Filter *
Get-ADReplicationFailure -Target "odin-dc01.asgard.local"

# Check DNS server statistics
Get-DnsServerStatistics -ComputerName "odin-dc01.asgard.local"

# Monitor DHCP lease statistics
Get-DhcpServerV4ScopeStatistics -ComputerName "odin-dc01.asgard.local"
```

---

## 🎯 **ASGARD DEPLOYMENT CHECKLIST**

### **Pre-Deployment Network Setup**

- [ ] Create Proxmox bridges (vmbr0, vmbr1, vmbr2, vmbr3)
- [ ] Configure IP addresses on all bridge interfaces
- [ ] Enable IP forwarding on Proxmox host
- [ ] Configure firewall rules for network segmentation
- [ ] Test inter-VLAN routing functionality
- [ ] Verify internet connectivity from production network

### **Server Deployment Verification**

- [ ] Deploy ODIN-DC01 with dual NICs (Production + Management)
- [ ] Deploy FRIGG-DC02 with dual NICs (Production + Management)
- [ ] Deploy HEIMDALL-FS01 with dual NICs (Production + Management)
- [ ] Deploy BALDER-WEB01 with triple NICs (Production + Management + DMZ)
- [ ] Deploy VIDAR-SEC01 with dual NICs (Production + Management)
- [ ] Verify all servers can communicate on production network

### **Domain Services Verification**

- [ ] Verify DNS resolution for asgard.local domain
- [ ] Test domain join from client networks
- [ ] Confirm DHCP lease distribution on client network
- [ ] Test file share access from client workstations
- [ ] Validate web server accessibility from DMZ
- [ ] Verify security server update services

### **Security Validation**

- [ ] Confirm DMZ isolation from production network
- [ ] Test firewall rule effectiveness
- [ ] Validate management network access controls
- [ ] Verify client network authentication requirements
- [ ] Test internet access through production network

### **Performance & Monitoring Setup**

- [ ] Configure network monitoring tools
- [ ] Set up bandwidth monitoring and alerting
- [ ] Enable comprehensive network logging
- [ ] Document network change procedures
- [ ] Establish backup connectivity methods
- [ ] Create network performance baselines

---

## 🔗 **RELATED ASGARD DOCUMENTATION**

- **[QUICK_START_ASGARD.md](Guides/QUICK_START_ASGARD.md)** - Rapid deployment guide
- **[MANUAL_SETUP_ASGARD.md](MANUAL_SETUP_ASGARD.md)** - Complete manual configuration
- **[ASGARD_NETWORK_SHARE_SETUP.md](Guides/ASGARD_NETWORK_SHARE_SETUP.md)** - File sharing configuration
- **[ADVANCED_SECURITY_QUICK_START.md](Guides/ADVANCED_SECURITY_QUICK_START.md)** - Security hardening
- **[CHEATSHEET.md](CHEATSHEET.md)** - Quick reference commands

---

**This network topology provides enterprise-grade segmentation with proper security zones specifically designed for the Asgard Technologies Norse mythology demonstration environment.**
