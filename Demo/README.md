# 🏰 **WINDOWS SERVER DEMO ENVIRONMENTS**

## 🎯 **Overview**

This directory contains comprehensive Windows Server demo environments that showcase every feature of the WindowsServer project. Choose from two epic mythology-themed labs, each creating realistic enterprise environments with 25 virtual machines, complete organizational structures, and professional-grade configurations.

### **🏰 Asgard Technologies Demo** (Primary)

Norse mythology-themed Windows Server lab with traditional enterprise features and configurations.

### **⚡ Olympus Systems Demo**

Greek mythology-themed Windows Server lab with advanced cloud integration and AI/ML capabilities.

---

## 🚀 **Choose Your Adventure**

### **🏰 Asgard Technologies** (Recommended for beginners)

- **Focus**: Traditional Windows Server enterprise features
- **Theme**: Norse mythology (Odin, Thor, Heimdall, etc.)
- **Specialty**: Core Windows Server capabilities
- **📂 Location**: This directory (`Demo/`)
- **👉 [Get Started](Guides/QUICK_START_ASGARD.md)**

### **⚡ Olympus Systems** (Advanced users)

- **Focus**: Advanced cloud integration and AI/ML capabilities
- **Theme**: Greek mythology (Zeus, Athena, Apollo, etc.)
- **Specialty**: Hybrid cloud, AI/ML pipelines, modern workloads
- **📂 Location**: `Demo/Olympus/`
- **👉 [Get Started](Olympus/Guides/QUICK_START_OLYMPUS.md)**

---

# 🏰 **ASGARD TECHNOLOGIES DEMO** - Core Windows Server Lab

## 🎯 **Asgard Overview**

The **Asgard Technologies** demo environment is an epic Norse mythology-themed Windows Server lab that showcases core enterprise features. This demo creates a realistic enterprise environment with 25 virtual machines, complete organizational structure, and professional-grade configurations.

---

## 📁 **Directory Structure**

```
Demo/
├── README.md                          # This file - Demo environments overview
├── MANUAL_SETUP_ASGARD.md            # Manual step-by-step Asgard deployment guide
├── Scripts/                           # Asgard deployment and management scripts
│   └── Deploy-AsgardLab.ps1          # Asgard deployment script
├── Documentation/                     # Asgard technical documentation
│   ├── DEMO_SETUP_GUIDE.md           # Asgard complete setup guide
│   └── HARDWARE_PERFORMANCE_GUIDE.md # Hardware optimization guide
├── Guides/                           # Asgard quick-start and user guides
│   └── QUICK_START_ASGARD.md         # Asgard 3-step deployment guide
└── Olympus/                          # Olympus Systems demo environment
    ├── README.md                      # Olympus demo overview
    ├── MANUAL_SETUP_OLYMPUS.md       # Manual step-by-step Olympus deployment guide
    ├── Scripts/                       # Olympus deployment scripts
    ├── Documentation/                 # Olympus technical documentation
    └── Guides/                       # Olympus quick-start guides
```

---

## 🚀 **Quick Start**

### **1-Minute Overview**

```powershell
# Navigate to the demo scripts
cd Demo/Scripts

# Deploy with separate ISOs for servers and clients (RECOMMENDED)
.\Deploy-AsgardLab.ps1 -VMPath "C:\VMs\Asgard" -ServerISOPath "C:\path\to\WindowsServer2025.iso" -ClientISOPath "C:\path\to\Windows10.iso"

# Or use legacy single ISO mode (backward compatibility)
.\Deploy-AsgardLab.ps1 -VMPath "C:\VMs\Asgard" -ISOPath "C:\path\to\WindowsServer.iso"
```

### **🔧 ISO Requirements**

For optimal deployment, use separate ISOs:

- **Server ISO**: Windows Server 2019/2022/2025 for domain controllers and servers
- **Client ISO**: Windows 10/11 22H2+ for workstation VMs
- **Legacy Mode**: Single ISO can be used for all VMs (backward compatibility)

### **🔒 Security Requirements**

The deployment script will prompt you for:

- **Safe Mode Password**: For domain controller recovery
- **Default User Password**: For all 25 Norse mythology user accounts

All passwords are handled securely with no hardcoded credentials.

### **What You Get**

- **🖥️ 5 Servers**: Domain controllers, file server, web server, security server
- **💻 20 Workstations**: Department-specific client machines
- **👥 25 Users**: Norse mythology-themed employees across 5 departments
- **🌐 4 Networks**: Production, management, client, and DMZ zones
- **🔐 Complete Security**: Groups, policies, permissions, and monitoring

---

## 📚 **Documentation Guide**

### **Start Here**

1. **[QUICK_START_ASGARD.md](Guides/QUICK_START_ASGARD.md)** - 3-step deployment guide
2. **[DEMO_SETUP_GUIDE.md](Documentation/DEMO_SETUP_GUIDE.md)** - Complete technical reference
3. **[HARDWARE_PERFORMANCE_GUIDE.md](Documentation/HARDWARE_PERFORMANCE_GUIDE.md)** - Performance optimization

### **For Different Audiences**

#### **🏃‍♂️ Quick Deployment**

- Read: `Guides/QUICK_START_ASGARD.md`
- Run: `Scripts/Deploy-AsgardLab.ps1`
- Time: 30-60 minutes

#### **📚 Manual Step-by-Step Setup**

- Read: `MANUAL_SETUP_ASGARD.md`
- Complete manual deployment with full control
- Perfect for learning and customization

#### **🔧 Technical Implementation**

- Read: `Documentation/DEMO_SETUP_GUIDE.md`
- Understand the complete architecture
- Customize for specific needs

#### **💪 Performance Optimization**

- Read: `Documentation/HARDWARE_PERFORMANCE_GUIDE.md`
- Optimize for your hardware specifications
- Monitor and tune performance

---

## 🏰 **The Asgard Technologies Company**

### **🎭 Organization Structure**

**Domain**: `asgard.local`  
**Mission**: "Protecting the Nine Realms of Cyberspace"

#### **Departments**

1. **IT Operations** (Odin's Realm) - 5 users
2. **Cybersecurity** (Heimdall's Watch) - 5 users
3. **Research & Development** (Freya's Workshop) - 5 users
4. **Finance & Administration** (Frigg's Treasury) - 5 users
5. **Human Resources** (Sif's Domain) - 5 users

#### **Key Characters**

- **odin.allfather** - CTO & Domain Admin
- **thor.thunderer** - Senior Systems Engineer
- **heimdall.guardian** - CISO
- **freya.seidr** - Head of R&D
- **frigg.queen** - CFO
- **sif.golden** - HR Director
- _...and many more epic characters!_

---

## 🖥️ **Infrastructure Overview**

### **Server Infrastructure**

| Server            | Role         | Specs    | Purpose                      |
| ----------------- | ------------ | -------- | ---------------------------- |
| **ODIN-DC01**     | Primary DC   | 8GB/4CPU | Active Directory, DNS, DHCP  |
| **FRIGG-DC02**    | Secondary DC | 6GB/3CPU | AD Replication, Backup       |
| **HEIMDALL-FS01** | File Server  | 8GB/4CPU | File Storage, Shares, Backup |
| **BALDER-WEB01**  | Web Server   | 6GB/3CPU | IIS, .NET, Applications      |
| **VIDAR-SEC01**   | Security     | 8GB/4CPU | WSUS, Monitoring, Security   |

### **Network Architecture**

```
Production:  10.0.10.0/24  (Servers)
Management:  10.0.100.0/24 (Admin Access)
Clients:     10.0.20.0/22  (Workstations)
DMZ:         10.0.50.0/24  (External Services)
```

### **Features Demonstrated**

#### **Core Infrastructure**

- ✅ Active Directory Domain Services
- ✅ DNS & DHCP Configuration
- ✅ File Shares & Permissions
- ✅ Group Policy Management
- ✅ Security Groups & User Management
- ✅ Network Segmentation
- ✅ Monitoring & Auditing
- ✅ Backup & Recovery
- ✅ Hyper-V Virtualization
- ✅ PowerShell Automation

#### **🛡️ Advanced Security Features (NEW!)**

- ✅ **Camera & Microphone Controls** - Complete privacy protection
- ✅ **USB & Storage Security** - Granular device access restrictions
- ✅ **Device & Peripheral Management** - Bluetooth, WiFi, printer controls
- ✅ **Personalization Policies** - Desktop, Start menu, Windows Store management
- ✅ **Application Control** - PowerShell, AppLocker, software restrictions
- ✅ **Network Security** - Advanced firewall, RDP, SMB signing
- ✅ **Data Protection** - Telemetry, OneDrive, Cortana privacy controls
- ✅ **Security Auditing** - Comprehensive scoring and compliance reporting

---

## 🎯 **Demo Scenarios**

### **Included Scenarios**

1. **🔥 New Employee Onboarding** - Complete user lifecycle with security policies
2. **⚔️ Security Incident Response** - Breach simulation and containment
3. **🛡️ Compliance Auditing** - Generate reports and demonstrate compliance
4. **🔧 Server Maintenance** - Backup, update, and recovery procedures
5. **🏢 Department Reorganization** - Moving users and resources
6. **🎥 Camera/USB Security Testing** - Demonstrate device access controls _(NEW!)_
7. **🔒 Advanced Security Audit** - Comprehensive security assessment _(NEW!)_
8. **📱 Application Control Demo** - PowerShell and software restrictions _(NEW!)_

### **Custom Scenarios**

The demo environment supports any Windows Server scenario:

- Multi-domain forests
- Site-to-site replication
- Certificate services
- Web applications
- Database services
- Remote access solutions

---

## ⚠️ **Hardware Requirements**

### **✅ Tested & Optimized On**

- **CPU**: AMD Ryzen 7900X (12 cores, 24 threads)
- **RAM**: 64GB DDR5
- **Storage**: 1TB NVMe SSD
- **GPU**: NVIDIA RTX 5070 (12GB VRAM)
- **OS**: Windows 11 Pro with Hyper-V

### **⚙️ Minimum Requirements**

- **RAM**: 32GB (64GB recommended)
- **CPU**: 8+ cores (12+ recommended)
- **Storage**: 1TB+ NVMe SSD
- **OS**: Windows 10/11 Pro with Hyper-V enabled

---

## 🛠️ **Management & Maintenance**

### **Deployment Commands**

```powershell
# Full deployment with advanced security features
.\Deploy-AsgardLab.ps1 -VMPath "C:\VMs\Asgard"

# Deploy advanced security demo
.\Deploy-AdvancedSecurityDemo.ps1 -DemoType "Asgard"

# Network only
.\Deploy-AsgardLab.ps1 -SkipVMs

# Custom domain
.\Deploy-AsgardLab.ps1 -DomainName "custom.local"
```

### **Advanced Security Commands (NEW!)**

```powershell
# Run interactive security demo
.\Deploy-AdvancedSecurityDemo.ps1

# Deploy comprehensive security policies
.\Scripts\AdvancedGroupPolicyManager.ps1

# Run complete security audit
.\Scripts\AdvancedSecurityAudit.ps1

# Quick security assessment
Start-QuickSecurityCheck
```

### **VM Management**

```powershell
# Start all Asgard VMs
Get-VM | Where-Object {$_.Name -like "*ASGARD*" -or $_.Name -like "*ODIN*"} | Start-VM

# Check status
Get-VM | Where-Object {$_.Name -like "*ASGARD*"} | Select-Object Name, State, Status
```

### **Performance Monitoring**

```powershell
# Resource usage
Get-VM | Measure-Object -Property MemoryAssigned -Sum
Get-Counter "\Memory\Available MBytes"
```

---

## 🔗 **Integration with Main Project**

### **Relationship to Core Project**

This demo showcases features from:

- **📖 LabSetupTutorials/**: Step-by-step learning guides
- **⚙️ Scripts/**: Core automation and management scripts
- **📋 Documentation**: Contributing guidelines and project info

### **Using Core Scripts**

The demo leverages core project scripts:

- `Scripts/Hyper-V_Lab_Setup.ps1` - Base VM creation
- `Scripts/Test-LabEnvironment.ps1` - Environment validation
- `Scripts/WindowsServerLab.psm1` - PowerShell module functions
- `Scripts/AdvancedGroupPolicyManager.ps1` - 100+ security policies _(NEW!)_
- `Scripts/AdvancedSecurityAudit.ps1` - Comprehensive security scoring _(NEW!)_

### **Advanced Security Quick Start**

🛡️ **NEW**: [Advanced Security Features Quick Start Guide](Guides/ADVANCED_SECURITY_QUICK_START.md)

Experience 100+ enterprise security features including:

- Camera & microphone access controls
- USB & removable storage restrictions
- Device & peripheral management
- Application control & PowerShell policies
- Network security & data protection
- Comprehensive security auditing with scoring

---

## 🎓 **Educational Value**

### **Learning Objectives**

1. **Enterprise Architecture** - Realistic organizational design
2. **Windows Server Administration** - Hands-on experience with all roles
3. **Network Design** - Multi-segment networking with proper security
4. **Automation Skills** - PowerShell scripting and deployment
5. **Security Implementation** - Groups, policies, and monitoring
6. **Troubleshooting** - Real-world problem-solving scenarios

### **Skill Development**

- Active Directory management
- DNS/DHCP configuration
- File server administration
- Group policy creation
- Security hardening
- Performance monitoring
- Backup and recovery
- Virtualization management

---

## 🆘 **Support & Troubleshooting**

### **Common Issues**

- **Memory constraints**: Reduce VM allocations in `Deploy-AsgardLab.ps1`
- **Network conflicts**: Check existing Hyper-V switches
- **Storage space**: Ensure adequate disk space for VMs

### **Getting Help**

1. Check the main project's `LabSetupTutorials/05_Troubleshooting.md`
2. Review `HARDWARE_PERFORMANCE_GUIDE.md` for optimization
3. Use the project's core validation scripts

---

## 🎊 **Conclusion**

The **Asgard Technologies** demo represents the pinnacle of Windows Server lab environments - combining technical excellence with immersive storytelling. Whether you're learning, teaching, or demonstrating Windows Server capabilities, this environment provides a comprehensive, engaging, and professional platform.

**Welcome to Asgard Technologies - Where IT Meets Legend!** ⚡🏰

---

_For questions or contributions, see the main project's CONTRIBUTING.md file._
