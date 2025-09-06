# 🌐 **OLYMPUS SYSTEMS NETWORK TOPOLOGY**

## Greek Mythology Enterprise Demo - Proxmox Edition

**Documentation Date:** December 2024  
**Platform:** Proxmox VE Virtualization  
**Domain:** olympus.local  
**Architecture:** 5-tier enterprise network with AI/ML specialization

---

## 📋 **OVERVIEW**

Olympus Systems implements a Greek mythology-themed enterprise network with advanced AI/ML capabilities. The design features a specialized high-performance network for research and development workloads.

### **Network Architecture:**

- **5 Primary Networks** with advanced segmentation
- **AI/ML Specialized Network** for high-performance computing
- **Enterprise Security** with DMZ isolation
- **Scalable Design** supporting 30+ VMs with GPU acceleration

---

## ⚡ **OLYMPUS NETWORK SEGMENTATION**

| Network | CIDR | Purpose | Proxmox Bridge | Gateway | VLAN |
|---------|------|---------|----------------|---------|------|
| **Production** | `10.0.10.0/24` | Domain Controllers, Servers | `vmbr0` | `10.0.10.1` | 10 |
| **Management** | `10.0.100.0/24` | Administrative Access | `vmbr1` | `10.0.100.1` | 100 |
| **Client** | `10.0.20.0/22` | Standard Workstations | `vmbr2` | `10.0.20.1` | 20 |
| **DMZ** | `10.0.50.0/24` | External-facing Services | `vmbr3` | `10.0.50.1` | 50 |
| **AI/ML** | `10.0.60.0/24` | High-performance R&D Network | `vmbr4` | `10.0.60.1` | 60 |

---

## 🖥️ **SERVER INFRASTRUCTURE**

### **Core Servers - Production Network**

| Server Role | Hostname | IP Address | VM ID | Specifications | Network Interfaces |
|-------------|----------|------------|-------|----------------|-------------------|
| **Primary DC** | ZEUS-DC01 | `10.0.10.10` | 200 | 4 vCPU, 8GB RAM, 100GB | vmbr0, vmbr1 |
| **Secondary DC** | HERA-DC02 | `10.0.10.11` | 201 | 4 vCPU, 8GB RAM, 100GB | vmbr0, vmbr1 |
| **File Server** | HERMES-FS01 | `10.0.10.20` | 202 | 4 vCPU, 12GB RAM, 1TB | vmbr0, vmbr1 |
| **Web Server** | APOLLO-WEB01 | `10.0.10.30` | 203 | 4 vCPU, 8GB RAM, 200GB | vmbr0, vmbr1, vmbr3 |
| **Security Server** | ATHENA-SEC01 | `10.0.10.40` | 204 | 4 vCPU, 8GB RAM, 200GB | vmbr0, vmbr1 |

### **Server Roles & Services**

#### **ZEUS-DC01 (Primary Domain Controller)**

- **Services:** Active Directory, DNS, DHCP, FSMO Roles
- **Greek Role:** King of the Gods, ruler of Mount Olympus
- **Key Functions:**
  - Forest root domain controller
  - Global catalog server
  - DNS primary zone hosting
  - DHCP scope management (including AI/ML network)

#### **HERA-DC02 (Secondary Domain Controller)**

- **Services:** Active Directory replication, DNS secondary
- **Greek Role:** Queen of the Gods, Zeus's wife
- **Key Functions:**
  - Domain controller redundancy
  - DNS secondary zones
  - Global catalog replica
  - Backup authentication services

#### **HERMES-FS01 (File Server)**

- **Services:** File shares, DFS, data lake storage
- **Greek Role:** Messenger of the Gods, guide between worlds
- **Key Functions:**
  - Departmental file shares
  - Home directory hosting
  - Distributed file system
  - Big data storage for AI/ML workloads

#### **APOLLO-WEB01 (Web Server)**

- **Services:** IIS, web applications, API gateway
- **Greek Role:** God of light, music, and prophecy
- **Key Functions:**
  - Corporate intranet
  - External web presence (DMZ)
  - RESTful API hosting
  - Machine learning model endpoints

#### **ATHENA-SEC01 (Security Server)**

- **Services:** WSUS, monitoring, advanced threat protection
- **Greek Role:** Goddess of wisdom and strategic warfare
- **Key Functions:**
  - Windows update management
  - Advanced security monitoring
  - AI-powered threat detection
  - Comprehensive log aggregation

---

## 💻 **WORKSTATION INFRASTRUCTURE**

### **Divine Council (IT Operations)**

| Workstation | User | VM ID | IP Range | Role |
|-------------|------|-------|----------|------|
| **ZEUS-WS01** | Chief Executive Officer | 210 | `10.0.20.10` | King of Technology |
| **HERMES-WS01** | Senior System Engineer | 211 | `10.0.20.11` | Divine Messenger |
| **HADES-WS01** | Database Administrator | 212 | `10.0.20.12` | Lord of the Underworld |
| **POSEIDON-WS01** | Network Administrator | 213 | `10.0.20.13` | God of the Sea |
| **DIONYSUS-WS01** | Senior Developer | 214 | `10.0.20.14` | God of Wine & Ecstasy |

### **War Strategists (Cybersecurity)**

| Workstation | User | VM ID | IP Range | Security Focus |
|-------------|------|-------|----------|----------------|
| **ARES-WS01** | CISO | 215 | `10.0.20.15` | God of War |
| **KRATOS-WS01** | Security Architect | 216 | `10.0.20.16` | Strength & Power |
| **NIKE-WS01** | SOC Analyst Lead | 217 | `10.0.20.17` | Goddess of Victory |
| **BIA-WS01** | Threat Hunter | 218 | `10.0.20.18` | Goddess of Force |
| **ZELUS-WS01** | Compliance Officer | 219 | `10.0.20.19` | God of Zeal |

### **Innovation Forge (R&D - AI/ML Network)**

| Workstation | User | VM ID | Network | IP Range | GPU Config |
|-------------|------|-------|---------|----------|------------|
| **APOLLO-WS01** | AI Research Director | 220 | AI/ML | `10.0.60.10` | RTX 4090 |
| **ARTEMIS-WS01** | ML Engineer | 221 | AI/ML | `10.0.60.11` | RTX 4080 |
| **HEPHAESTUS-WS01** | DevOps Engineer | 222 | AI/ML | `10.0.60.12` | RTX 4070 |
| **DEMETER-WS01** | Data Scientist | 223 | AI/ML | `10.0.60.13` | RTX 4070 |
| **ATHENA-WS01** | AI Architect | 224 | AI/ML | `10.0.60.14` | RTX 4090 |

### **Finance & HR Departments**

| Department | VM IDs | Count | Network | IP Range |
|------------|--------|-------|---------|----------|
| **Finance** | 225-229 | 5 | Client | `10.0.20.20-24` |
| **HR** | 230-234 | 5 | Client | `10.0.20.25-29` |

---

## 🔧 **PROXMOX NETWORK CONFIGURATION**

### **Bridge Configuration**

#### **AI/ML Bridge (vmbr4) - Olympus Specialty**

```bash
# [PROXMOX HOST] - Configure high-performance AI/ML bridge
auto vmbr4
iface vmbr4 inet static
    address 10.0.60.1/24
    bridge-ports none
    bridge-stp off
    bridge-fd 0
    mtu 9000
    # High-performance AI/ML network with jumbo frames
```

---

## 🔒 **OLYMPUS SECURITY ZONES**

### **Network Security Matrix**

| Source Zone | Target Zone | Access | Ports | Purpose |
|-------------|-------------|--------|-------|---------|
| **Management** | **All Networks** | Full | All | Administrative access |
| **Production** | **Client/AI/ML** | Limited | DNS, DHCP, SMB | Domain services |
| **Client** | **Production** | Limited | DNS, LDAP, Kerberos | Authentication |
| **Client** | **AI/ML** | Limited | HTTP, HTTPS, SSH | Research collaboration |
| **AI/ML** | **Production** | Limited | DNS, SMB, HTTPS | Data access & storage |
| **AI/ML** | **DMZ** | Limited | HTTP, HTTPS | Model deployment |
| **DMZ** | **Production/AI/ML** | **DENIED** | None | Security isolation |

### **Firewall Rules**

#### **Production Network Protection**

```bash
# [PROXMOX HOST] - Olympus production network firewall rules
# Allow management access to all networks
iptables -A FORWARD -s 10.0.100.0/24 -d 10.0.10.0/24 -j ACCEPT    # Management to Production
iptables -A FORWARD -s 10.0.100.0/24 -d 10.0.20.0/22 -j ACCEPT    # Management to Client
iptables -A FORWARD -s 10.0.100.0/24 -d 10.0.60.0/24 -j ACCEPT    # Management to AI/ML

# Allow client authentication to domain controllers
iptables -A FORWARD -s 10.0.20.0/22 -d 10.0.10.10 -p tcp --dport 53 -j ACCEPT   # DNS
iptables -A FORWARD -s 10.0.20.0/22 -d 10.0.10.10 -p tcp --dport 88 -j ACCEPT   # Kerberos
iptables -A FORWARD -s 10.0.20.0/22 -d 10.0.10.10 -p tcp --dport 389 -j ACCEPT  # LDAP

# Allow AI/ML network authentication
iptables -A FORWARD -s 10.0.60.0/24 -d 10.0.10.10 -p tcp --dport 53 -j ACCEPT   # DNS
iptables -A FORWARD -s 10.0.60.0/24 -d 10.0.10.10 -p tcp --dport 88 -j ACCEPT   # Kerberos
iptables -A FORWARD -s 10.0.60.0/24 -d 10.0.10.10 -p tcp --dport 389 -j ACCEPT  # LDAP

# Allow file server access
iptables -A FORWARD -s 10.0.20.0/22 -d 10.0.10.20 -p tcp --dport 445 -j ACCEPT  # Client to FS
iptables -A FORWARD -s 10.0.60.0/24 -d 10.0.10.20 -p tcp --dport 445 -j ACCEPT  # AI/ML to FS

# AI/ML to DMZ for model deployment
iptables -A FORWARD -s 10.0.60.0/24 -d 10.0.50.0/24 -p tcp --dport 80 -j ACCEPT
iptables -A FORWARD -s 10.0.60.0/24 -d 10.0.50.0/24 -p tcp --dport 443 -j ACCEPT

# Block DMZ to production (critical security rule)
iptables -A FORWARD -s 10.0.50.0/24 -d 10.0.10.0/24 -j DROP
iptables -A FORWARD -s 10.0.50.0/24 -d 10.0.60.0/24 -j DROP

# Allow internet to DMZ web services
iptables -A FORWARD -d 10.0.50.0/24 -p tcp --dport 80 -j ACCEPT
iptables -A FORWARD -d 10.0.50.0/24 -p tcp --dport 443 -j ACCEPT
```

---

## 📊 **DHCP CONFIGURATION**

### **AI/ML Network Scope**

```powershell
# [SERVER VM] - Run on ZEUS-DC01
# DHCP scope for AI/ML high-performance network

Add-DhcpServerV4Scope -Name "Olympus AI/ML Network" -StartRange 10.0.60.100 -EndRange 10.0.60.200 -SubnetMask 255.255.255.0

# AI/ML DHCP Options
Set-DhcpServerV4OptionValue -ScopeId 10.0.60.0 -OptionId 3 -Value 10.0.60.1
Set-DhcpServerV4OptionValue -ScopeId 10.0.60.0 -OptionId 6 -Value 10.0.10.10,10.0.10.11
Set-DhcpServerV4OptionValue -ScopeId 10.0.60.0 -OptionId 15 -Value "olympus.local"
```

---

## 🧠 **AI/ML NETWORK SPECIALIZATION**

### **GPU Passthrough Setup**

```bash
# [PROXMOX HOST] - Configure GPU passthrough for AI/ML workstations
# Enable IOMMU
echo 'GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt"' >> /etc/default/grub
update-grub

# Load VFIO modules
echo 'vfio' >> /etc/modules
echo 'vfio_iommu_type1' >> /etc/modules
echo 'vfio_pci' >> /etc/modules
```

### **High-Performance VM Configuration**

```bash
# [PROXMOX HOST] - Configure AI/ML workstations
# APOLLO-WS01 (RTX 4090)
qm set 220 --hostpci0 0000:01:00,pcie=1,x-vga=1
qm set 220 --net0 virtio,bridge=vmbr4,queues=8,mtu=9000
qm set 220 --memory 32768 --cores 16

# ATHENA-WS01 (RTX 4090)
qm set 224 --hostpci0 0000:03:00,pcie=1,x-vga=1
qm set 224 --net0 virtio,bridge=vmbr4,queues=8,mtu=9000
qm set 224 --memory 32768 --cores 16
```

---

## 📋 **TROUBLESHOOTING GUIDE**

### **AI/ML Network Connectivity**

```bash
# [AI/ML VM] - Test high-performance network
# Check MTU size for jumbo frames
ip link show | grep mtu

# Test bandwidth between AI/ML nodes
iperf3 -s -p 5001  # On target
iperf3 -c 10.0.60.10 -p 5001 -t 60  # From source

# Verify GPU visibility
nvidia-smi
```

### **Domain Join Issues**

```powershell
# [CLIENT VM] - Test domain connectivity
nslookup olympus.local 10.0.10.10
Test-NetConnection -ComputerName zeus-dc01.olympus.local -Port 389
```

---

## 📊 **PERFORMANCE OPTIMIZATION**

### **AI/ML Network Tuning**

```bash
# [PROXMOX HOST] - Optimize for AI/ML workloads
# Enable jumbo frames on AI/ML bridge
ip link set dev vmbr4 mtu 9000

# Increase network buffer sizes
echo 'net.core.rmem_max = 536870912' >> /etc/sysctl.conf
echo 'net.core.wmem_max = 536870912' >> /etc/sysctl.conf
sysctl -p
```

---

## 🎯 **OLYMPUS DEPLOYMENT CHECKLIST**

### **Pre-Deployment**

- [ ] Create all Proxmox bridges (vmbr0-vmbr4)
- [ ] Configure IOMMU for GPU passthrough
- [ ] Set up jumbo frames on AI/ML network
- [ ] Configure firewall rules for 5-tier segmentation

### **AI/ML Network Deployment**

- [ ] Deploy AI/ML workstations with GPU passthrough
- [ ] Configure high-performance networking (MTU 9000)
- [ ] Verify GPU visibility in AI/ML VMs
- [ ] Test large dataset transfers
- [ ] Configure AI/ML network monitoring

### **Security Validation**

- [ ] Confirm DMZ isolation from all internal networks
- [ ] Validate AI/ML network access controls
- [ ] Test secure data transfer between networks
- [ ] Verify GPU security isolation

---

## 🔗 **RELATED OLYMPUS DOCUMENTATION**

- **[QUICK_START_OLYMPUS.md](Guides/QUICK_START_OLYMPUS.md)** - Rapid deployment guide
- **[MANUAL_SETUP_OLYMPUS.md](MANUAL_SETUP_OLYMPUS.md)** - Complete manual configuration
- **[OLYMPUS_NETWORK_SHARE_SETUP.md](Guides/OLYMPUS_NETWORK_SHARE_SETUP.md)** - File sharing configuration
- **[ADVANCED_SECURITY_QUICK_START.md](Guides/ADVANCED_SECURITY_QUICK_START.md)** - Security hardening
- **[CHEATSHEET.md](CHEATSHEET.md)** - Quick reference commands

---

**This network topology provides enterprise-grade segmentation with AI/ML specialization for the Olympus Systems Greek mythology demonstration environment.**
