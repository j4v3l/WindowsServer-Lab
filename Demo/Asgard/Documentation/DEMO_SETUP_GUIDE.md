# 🏰 **ASGARD TECHNOLOGIES** - Complete Lab Demo Setup Guide

## 🎯 **Organization Overview**

**Asgard Technologies** is a cutting-edge cybersecurity and AI research company specializing in advanced threat detection and quantum computing solutions. The company operates globally with a Norse mythology-themed organizational structure.

### 🏢 **Company Profile**

- **Domain**: `asgard.local`
- **Company Size**: 50+ employees across 5 departments
- **Security Level**: High (Government contracts)
- **Mission**: "Protecting the Nine Realms of Cyberspace"

---

## 🌐 **Network Architecture**

### **IP Address Scheme**

| Network Zone        | CIDR            | Purpose                    | VLAN  |
| ------------------- | --------------- | -------------------------- | ----- |
| **Production**      | `10.0.10.0/24`  | Core servers and services  | 10    |
| **Management**      | `10.0.100.0/24` | Administrative access      | 100   |
| **Client Networks** | `10.0.20.0/22`  | Department workstations    | 20-23 |
| **DMZ**             | `10.0.50.0/24`  | External-facing services   | 50    |
| **IoT/Devices**     | `10.0.60.0/24`  | Printers, cameras, sensors | 60    |

### **Virtual Switch Configuration**

**Important Note:** When creating external VM switches, use `-NetAdapterName` instead of `-SwitchType External`. The `-AllowManagementOS $true` parameter allows the host OS to also use the network adapter.

### **Windows 11 Client Setup & OOBE Network Bypass**

**Critical for Lab Environment:** When setting up Windows 11 client VMs in this lab, use the OOBE network bypass to avoid Microsoft account requirements and ensure smooth integration with the domain.

**OOBE Bypass Steps:**

1. During Windows 11 initial setup, when prompted for network connection
2. Press `Shift + F10` to open Command Prompt
3. Type: `OOBE\BYPASSNRO`
4. Press Enter - the system will restart and skip network requirements
5. You can then create local accounts and join the domain without Microsoft account interference

**Alternative Methods:**

- Kill network flow: `taskkill /f /im NetworkConnectionFlow.exe`
- Disable network adapter temporarily during OOBE
- Use registry modification for automated deployments

```powershell
# Core Production Network (External Switch)
New-VMSwitch -Name "ASGARD-Production" -NetAdapterName "Ethernet" -AllowManagementOS $true

# Management Network
New-VMSwitch -Name "ASGARD-Management" -SwitchType Internal
New-NetIPAddress -IPAddress 10.0.100.1 -PrefixLength 24 -InterfaceAlias "vEthernet (ASGARD-Management)"

# DMZ Network
New-VMSwitch -Name "ASGARD-DMZ" -SwitchType Private

# Client Network
New-VMSwitch -Name "ASGARD-Clients" -SwitchType Internal
New-NetIPAddress -IPAddress 10.0.20.1 -PrefixLength 22 -InterfaceAlias "vEthernet (ASGARD-Clients)"
```

---

## 🖥️ **Server Infrastructure**

### **Core Servers (Required: 5 VMs)**

#### 1. **ODIN-DC01** - Primary Domain Controller

```yaml
Purpose: Active Directory, DNS, DHCP
Specs:
  Memory: 4GB
  Storage: 80GB
  CPUs: 2
  OS: Windows Server 2019/2022
Network:
  Production: 10.0.10.10/24
  Management: 10.0.100.10/24
Services:
  - Active Directory Domain Services
  - DNS Server
  - DHCP Server
  - Certificate Services
```

#### 2. **FRIGG-DC02** - Secondary Domain Controller

```yaml
Purpose: AD Replication, Backup DNS/DHCP
Specs:
  Memory: 4GB
  Storage: 80GB
  CPUs: 2
  OS: Windows Server 2019/2022
Network:
  Production: 10.0.10.11/24
  Management: 10.0.100.11/24
Services:
  - Active Directory Domain Services
  - DNS Server
  - DHCP Server (Backup)
```

#### 3. **HEIMDALL-FS01** - File Server & NAS

```yaml
Purpose: File storage, shares, backup
Specs:
  Memory: 6GB
  Storage: 200GB
  CPUs: 2
  OS: Windows Server 2019/2022
Network:
  Production: 10.0.10.20/24
  Management: 10.0.100.20/24
Services:
  - File and Storage Services
  - DFS Namespace
  - File Server Resource Manager
  - Backup Server
```

#### 4. **BALDER-WEB01** - Web/Application Server

```yaml
Purpose: Internal web apps, intranet
Specs:
  Memory: 4GB
  Storage: 100GB
  CPUs: 2
  OS: Windows Server 2019/2022
Network:
  Production: 10.0.10.30/24
  DMZ: 10.0.50.30/24
  Management: 10.0.100.30/24
Services:
  - IIS Web Server
  - .NET Framework
  - SQL Server Express
```

#### 5. **VIDAR-SEC01** - Security & Monitoring

```yaml
Purpose: Security monitoring, WSUS, antivirus
Specs:
  Memory: 6GB
  Storage: 150GB
  CPUs: 2
  OS: Windows Server 2019/2022
Network:
  Production: 10.0.10.40/24
  Management: 10.0.100.40/24
Services:
  - Windows Server Update Services
  - System Center Operations Manager
  - Windows Defender Advanced Threat Protection
```

---

## 👥 **Organizational Structure**

### **Active Directory Structure**

```
asgard.local
├── Asgard Technologies
│   ├── Departments
│   │   ├── IT_Operations (Odin's Realm)
│   │   ├── Cybersecurity (Heimdall's Watch)
│   │   ├── Research_Development (Freya's Workshop)
│   │   ├── Finance_Admin (Frigg's Treasury)
│   │   └── Human_Resources (Sif's Domain)
│   ├── Service_Accounts
│   ├── Shared_Resources
│   └── Workstations
│       ├── IT_Workstations
│       ├── Security_Workstations
│       ├── Research_Workstations
│       ├── Finance_Workstations
│       └── HR_Workstations
```

### **User Accounts (25 Total)**

#### **IT Operations Department** (Odin's Realm)

- **odin.allfather** - CTO & Domain Admin
- **thor.thunderer** - Senior Systems Engineer
- **loki.trickster** - Junior Developer (Intern)
- **hermod.messenger** - Network Administrator
- **tyr.brave** - Security Analyst

#### **Cybersecurity Department** (Heimdall's Watch)

- **heimdall.guardian** - CISO
- **mimir.wise** - Threat Intelligence Analyst
- **huginn.raven** - SOC Analyst I
- **muninn.memory** - SOC Analyst II
- **fenrir.wolf** - Penetration Tester

#### **Research & Development** (Freya's Workshop)

- **freya.seidr** - Head of R&D
- **njord.wind** - AI Research Scientist
- **frey.prosperity** - Quantum Computing Lead
- **jormungandr.serpent** - Data Scientist
- **sleipnir.swift** - DevOps Engineer

#### **Finance & Administration** (Frigg's Treasury)

- **frigg.queen** - CFO
- **eir.healer** - Financial Analyst
- **saga.storyteller** - Compliance Officer
- **var.oath** - Legal Counsel
- **forseti.justice** - Audit Manager

#### **Human Resources** (Sif's Domain)

- **sif.golden** - HR Director
- **idun.eternal** - Talent Acquisition
- **bragi.poet** - Training Coordinator
- **hel.half** - Benefits Administrator
- **sigyn.faithful** - Employee Relations

---

## 💻 **Client Workstations (20 VMs)**

### **Department Workstations**

#### **IT Operations Workstations**

- **ODIN-WS01** - 10.0.20.10 (odin.allfather)
- **THOR-WS01** - 10.0.20.11 (thor.thunderer)
- **LOKI-WS01** - 10.0.20.12 (loki.trickster)
- **HERMOD-WS01** - 10.0.20.13 (hermod.messenger)

#### **Cybersecurity Workstations**

- **HEIMDALL-WS01** - 10.0.21.10 (heimdall.guardian)
- **MIMIR-WS01** - 10.0.21.11 (mimir.wise)
- **HUGINN-WS01** - 10.0.21.12 (huginn.raven)
- **MUNINN-WS01** - 10.0.21.13 (muninn.memory)

#### **Research Workstations**

- **FREYA-WS01** - 10.0.22.10 (freya.seidr)
- **NJORD-WS01** - 10.0.22.11 (njord.wind)
- **FREY-WS01** - 10.0.22.12 (frey.prosperity)
- **SLEIPNIR-WS01** - 10.0.22.13 (sleipnir.swift)

#### **Finance Workstations**

- **FRIGG-WS01** - 10.0.23.10 (frigg.queen)
- **EIR-WS01** - 10.0.23.11 (eir.healer)
- **SAGA-WS01** - 10.0.23.12 (saga.storyteller)
- **VAR-WS01** - 10.0.23.13 (var.oath)

#### **HR Workstations**

- **SIF-WS01** - 10.0.24.10 (sif.golden)
- **IDUN-WS01** - 10.0.24.11 (idun.eternal)
- **BRAGI-WS01** - 10.0.24.12 (bragi.poet)
- **HEL-WS01** - 10.0.24.13 (hel.half)

---

## 🔐 **Security Groups & Permissions**

### **Administrative Groups**

- **GRP-Domain_Admins** - Full domain control
- **GRP-Enterprise_Admins** - Enterprise-wide admin
- **GRP-Schema_Admins** - Schema modification rights
- **GRP-Server_Operators** - Server management rights

### **Department Security Groups**

- **GRP-IT_Staff** - IT department access
- **GRP-Security_Team** - Cybersecurity access
- **GRP-Research_Team** - R&D project access
- **GRP-Finance_Team** - Financial system access
- **GRP-HR_Team** - HR system access

### **Resource Access Groups**

- **GRP-File_Servers_RW** - Read/Write to file servers
- **GRP-File_Servers_RO** - Read-only file access
- **GRP-Printer_Users** - Printer access
- **GRP-Web_Applications** - Intranet access
- **GRP-VPN_Users** - Remote access

---

## 📁 **File Share Structure**

> **📋 For comprehensive setup instructions, see:** [Network Share Setup Guides Index](NETWORK_SHARE_GUIDES_INDEX.md)

### **Department Shares**

```
\\HEIMDALL-FS01\Departments\
├── IT_Operations\
│   ├── Scripts\
│   ├── Documentation\
│   ├── Software\
│   └── Projects\
├── Cybersecurity\
│   ├── Incident_Reports\
│   ├── Threat_Intelligence\
│   ├── Policies\
│   └── Tools\
├── Research_Development\
│   ├── AI_Projects\
│   ├── Quantum_Research\
│   ├── Patents\
│   └── Prototypes\
├── Finance_Admin\
│   ├── Budgets\
│   ├── Reports\
│   ├── Contracts\
│   └── Compliance\
└── Human_Resources\
    ├── Personnel_Files\
    ├── Policies\
    ├── Training\
    └── Benefits\
```

### **Shared Resources**

```
\\HEIMDALL-FS01\Shared\
├── Company_Documents\
├── Software_Repository\
├── Templates\
├── Public_Files\
└── Printer_Drivers\
```

---

## 🔧 **Group Policy Structure**

### **Domain-Level Policies**

- **GPO-Security_Baseline** - Core security settings
- **GPO-Password_Policy** - Password requirements
- **GPO-Audit_Policy** - Security auditing
- **GPO-Windows_Update** - Update management

### **Department-Specific Policies**

- **GPO-IT_Workstations** - Admin tools, elevated rights
- **GPO-Security_Hardening** - Enhanced security for security team
- **GPO-Research_Software** - Specialized development tools
- **GPO-Finance_Restrictions** - Limited internet, USB blocking
- **GPO-HR_Privacy** - Enhanced privacy controls

### **Application Deployment**

- **GPO-Office_365** - Microsoft Office deployment
- **GPO-Security_Tools** - Antivirus, monitoring agents
- **GPO-Development_Tools** - Visual Studio, IDEs
- **GPO-Finance_Software** - Accounting applications

---

## 📊 **Services Configuration**

### **DNS Configuration**

```powershell
# Forward Lookup Zones
asgard.local
├── odin-dc01.asgard.local (10.0.10.10)
├── frigg-dc02.asgard.local (10.0.10.11)
├── heimdall-fs01.asgard.local (10.0.10.20)
├── balder-web01.asgard.local (10.0.10.30)
└── vidar-sec01.asgard.local (10.0.10.40)

# Reverse Lookup Zones
10.0.10.0/24 (Production)
10.0.20.0/22 (Clients)
10.0.50.0/24 (DMZ)
10.0.100.0/24 (Management)
```

### **DHCP Scopes**

```powershell
# Production Scope
Scope: 10.0.10.0/24
Range: 10.0.10.100 - 10.0.10.200
Gateway: 10.0.10.1
DNS: 10.0.10.10, 10.0.10.11

# Client Scopes
IT Scope: 10.0.20.0/24 (Range: 10.0.20.100-200)
Security Scope: 10.0.21.0/24 (Range: 10.0.21.100-200)
Research Scope: 10.0.22.0/24 (Range: 10.0.22.100-200)
Finance Scope: 10.0.23.0/24 (Range: 10.0.23.100-200)
HR Scope: 10.0.24.0/24 (Range: 10.0.24.100-200)
```

---

## 🔒 **Security Configuration**

### **Password Requirements**

All Asgard Technologies lab environments now use secure password management:

#### **Deployment Passwords**

When using the automated deployment scripts, you'll be prompted for:

1. **Safe Mode Password (DSRM)**

   - Used for domain controller recovery operations
   - Must meet complexity requirements (8+ chars, mixed case, numbers, symbols)
   - Required for both ODIN-DC01 and FRIGG-DC02

2. **Default User Password**
   - Applied to all 25 Norse mythology user accounts
   - Users must change password on first login
   - Must meet domain password policy requirements

#### **Security Benefits**

- ✅ **No hardcoded passwords** in any scripts or documentation
- ✅ **SecureString handling** for all password operations
- ✅ **Runtime validation** ensures password complexity
- ✅ **PSScriptAnalyzer compliant** (0 critical security issues)

### **Domain Password Policy**

The lab implements enterprise-grade password policies:

```powershell
# Applied automatically during domain setup
Minimum Password Length: 12 characters
Password Complexity: Required
Maximum Password Age: 90 days
Minimum Password Age: 1 day
Password History: 24 passwords
Account Lockout Threshold: 5 attempts
Account Lockout Duration: 30 minutes
```

---

## 🚀 **Automated Setup Scripts**

### **1. Create the Complete Environment**

```powershell
# RECOMMENDED: Deploy with separate ISOs for optimal performance
.\Scripts\Deploy-AsgardLab.ps1 -VMPath "C:\VMs\Asgard" -ServerISOPath "C:\ISOs\WindowsServer2025.iso" -ClientISOPath "C:\ISOs\Windows10.iso"

# LEGACY: Single ISO mode (backward compatibility)
.\Scripts\Deploy-AsgardLab.ps1 -VMPath "C:\VMs\Asgard" -ISOPath "C:\path\to\WindowsServer.iso"
```

**🔧 ISO Requirements:**

- **Server ISO**: Windows Server 2019/2022/2025 for domain controllers and servers
- **Client ISO**: Windows 10/11 22H2+ for workstation VMs
- **Legacy Mode**: Single ISO can be used for all VMs (backward compatibility)

**Security Note:** The deployment script will prompt for passwords securely - no credentials are stored in plain text.

### **2. Individual Setup Commands**

```powershell
# Create virtual switches
New-AsgardVirtualSwitches

# Create all servers
New-AsgardServers

# Create all workstations
New-AsgardWorkstations

# Configure Active Directory
Set-AsgardActiveDirectory

# Create users and groups
New-AsgardUsers

# Configure file shares (See demo-specific setup guides)
New-AsgardFileShares  # For automated setup
# For manual setup, see:
# - Asgard Demo: Guides/ASGARD_NETWORK_SHARE_SETUP.md
# - Olympus Demo: Olympus/Guides/OLYMPUS_NETWORK_SHARE_SETUP.md

# Apply Group Policies
Set-AsgardGroupPolicies
```

---

## 🎯 **Demo Scenarios**

### **Scenario 1: New Employee Onboarding**

- Create user account for new R&D employee
- Add to appropriate groups
- Configure workstation
- Test access to resources

### **Scenario 2: Security Incident Response**

- Simulate security breach
- Use monitoring tools
- Implement containment
- Generate incident report

### **Scenario 3: Department Reorganization**

- Move users between OUs
- Update group memberships
- Reconfigure permissions
- Test access changes

### **Scenario 4: Server Maintenance**

- Create server backups
- Perform maintenance tasks
- Test disaster recovery
- Validate service restoration

### **Scenario 5: Compliance Audit**

- Generate user reports
- Review security settings
- Document configurations
- Demonstrate compliance

---

## 📈 **Monitoring & Maintenance**

### **Performance Monitoring**

- Server resource usage
- Network bandwidth utilization
- Active Directory replication
- Service availability

### **Security Monitoring**

- Failed login attempts
- Privilege escalation events
- File access auditing
- Group membership changes

### **Backup Strategy**

- Daily incremental backups
- Weekly full system backups
- Monthly disaster recovery tests
- Quarterly backup restoration tests

---

## 🎓 **Training Objectives**

This lab environment allows you to practice:

1. **Active Directory Management**

   - User and computer management
   - Group policy configuration
   - Domain controller setup

2. **Network Services**

   - DNS configuration
   - DHCP management
   - Network troubleshooting

3. **File Services**

   - Share permissions
   - NTFS security
   - File server management

4. **Security Hardening**

   - Group policy security
   - User access control
   - Audit configuration

5. **Disaster Recovery**
   - Backup and restore
   - Service recovery
   - Business continuity

---

## 🔥 **Epic Features Showcase**

### **What Makes This Lab COOL:**

1. **Norse Mythology Theme** - Immersive storytelling
2. **Realistic Company Structure** - Real-world scenarios
3. **Advanced Security** - Government-level security practices
4. **Comprehensive Coverage** - All Windows Server features
5. **Automated Deployment** - One-click environment creation
6. **Scalable Design** - Easy to expand and modify
7. **Professional Documentation** - Industry-standard practices

### **Impressive Capabilities:**

- **25 User Accounts** across 5 departments
- **25 Virtual Machines** (5 servers + 20 workstations)
- **Multiple Network Zones** with proper segmentation
- **Advanced Group Policies** for different security levels
- **Comprehensive File Sharing** with proper permissions
- **Monitoring and Alerting** systems
- **Disaster Recovery** capabilities

---

## 🎊 **Ready to Deploy?**

This **Asgard Technologies** lab environment showcases every feature in your Windows Server Lab project in the most epic way possible!

**📋 HARDWARE SPECIFICATIONS:**

**⚡ Tested & Optimized On:**

- **CPU**: AMD Ryzen 7900X (12 cores, 24 threads)
- **RAM**: 64GB DDR5
- **Storage**: 1TB NVMe SSD
- **GPU**: NVIDIA RTX 5070 (12GB VRAM)
- **OS**: Windows 11 Pro with Hyper-V

**💪 What This Hardware Can Handle:**

- **35+ Virtual Machines** simultaneously
- **All 25 lab VMs** with enhanced specifications
- **4-8GB RAM per server** (vs 4GB minimum)
- **2-4GB RAM per workstation** (vs 2GB minimum)
- **Parallel VM operations** without performance issues
- **Enhanced graphics acceleration** for VM displays
- **Rapid deployment** (30-60 minutes total setup)

**⚠️ Minimum Requirements for Others:**

- **RAM**: 32GB minimum (64GB recommended)
- **CPU**: 8+ cores (12+ cores recommended)
- **Storage**: 1TB+ NVMe SSD
- **GPU**: Dedicated GPU recommended for multiple VMs
- **Network**: Multiple virtual switches

**Next Steps:**

1. Run the automated setup scripts (optimized for high-end hardware)
2. Follow the step-by-step tutorials
3. Practice the demo scenarios
4. Customize for your specific needs

**Welcome to Asgard Technologies - Where IT Meets Legend!** ⚡🏰
