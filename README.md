# 🏰 Windows Server Lab Environment - Proxmox VE Edition

[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue.svg)](https://github.com/PowerShell/PowerShell)
[![Windows Server](https://img.shields.io/badge/Windows%20Server-2019%2F2022%2F2025-blue.svg)](https://www.microsoft.com/en-us/windows-server)
[![Proxmox VE](https://img.shields.io/badge/Proxmox%20VE-8.0%2B-orange.svg)](https://www.proxmox.com/en/proxmox-ve)

## 🎯 **EXECUTION CONTEXT - CRITICAL INFORMATION**

This lab environment uses a **two-tier architecture**:

### 🖥️ **Tier 1: Proxmox VE Host (Linux)**

- **VM Lifecycle**: `qm create`, `qm start`, `qm stop`, `qm destroy`
- **Network Management**: Bridge configuration, VLAN setup
- **Storage Operations**: `vzdump` backups, storage configuration
- **Access Method**: SSH to Proxmox host or web interface

### 🪟 **Tier 2: Windows VMs (Running on Proxmox)**

- **PowerShell Scripts**: All `.ps1` scripts in `/Scripts/` directory
- **Active Directory**: Domain controllers, user management, GPOs
- **Windows Features**: File shares, DHCP, DNS, web services
- **Access Method**: RDP, Console, or PowerShell Direct to Windows VMs

**⚠️ IMPORTANT**: Never run PowerShell scripts on the Proxmox host! They are designed for Windows VMs only.

For detailed execution contexts, see: [EXECUTION_CONTEXT_GUIDE.md](EXECUTION_CONTEXT_GUIDE.md)

---

## 🌟 **Overview**

This repository contains comprehensive documentation and guides for setting up and managing a Windows Server lab environment using Proxmox Virtual Environment (Proxmox VE). The content focuses on deploying Windows Server infrastructure on Proxmox with professional-grade virtualization capabilities.

## 🛠️ **CRITICAL FIXES: v1.3.1 Network Issues Resolved!**

**🚨 IMPORTANT UPDATE**: Version 1.3.1 includes critical networking fixes that resolve domain join failures and connectivity issues:

- **✅ Fixed Virtual Switch Configuration**: Both Asgard and Olympus demos now use proper Internal switches instead of External
- **✅ Fixed IP Forwarding**: Enabled routing between virtual networks to resolve "Access is denied" domain join errors
- **✅ Fixed User Passwords**: Added `-PasswordNeverExpires` to prevent password expiration issues in lab environments
- **✅ Added Network Validation**: New testing scripts to identify network issues before deployment

**Result**: Domain joins now work on first attempt without manual network troubleshooting! 🎉

👉 **[View Complete Fix Details](NETWORK_CONFIGURATION_AUDIT_FIXES.md)**  
👉 **[Network Troubleshooting Guide](LabSetupTutorials/20_Network_Troubleshooting_Guide.md)**

---

## 🏰 **Epic Demos Available!**

**Experience the complete power of this lab environment with our comprehensive demo environments:**

- **[Asgard Technologies Demo](Demo/README.md)** - Norse mythology-themed enterprise setup featuring 25 VMs, complete organizational structure, and professional-grade configurations
- **[Olympus Systems Demo](Demo/Olympus/README.md)** - Greek mythology-themed enterprise setup with advanced cloud integration and AI/ML capabilities

Both demos provide realistic enterprise environments perfect for demonstrations, learning, and showcasing Windows Server capabilities!

👉 **[Get Started with Asgard Demo](Demo/Asgard/Guides/QUICK_START_ASGARD.md)** - Deploy in 30-60 minutes!  
👉 **[Asgard Cheatsheet](Demo/Asgard/CHEATSHEET.md)** - Quick reference for commands and IPs!  
👉 **[Manual Asgard Setup Guide](Demo/Asgard/MANUAL_SETUP_ASGARD.md)** - Step-by-step manual deployment!  
👉 **[Get Started with Olympus Demo](Demo/Olympus/Guides/QUICK_START_OLYMPUS.md)** - Deploy in 30-60 minutes!  
👉 **[Olympus Cheatsheet](Demo/Olympus/CHEATSHEET.md)** - Quick reference for commands and IPs!  
👉 **[Manual Olympus Setup Guide](Demo/Olympus/MANUAL_SETUP_OLYMPUS.md)** - Advanced manual deployment!

## ⚠️ Important Disclaimer

**This is a work in progress and is intended for educational and development purposes only.**

- All scripts and tutorials are provided "as is" without warranty
- Known bugs and errors exist in both documentation and scripts
- This material should **NEVER** be used in a production environment
- Always test thoroughly in a development or lab environment
- Some scripts may require modification to work in your specific environment
- Documentation may contain inaccuracies or outdated information

Use at your own risk and always verify any changes in a safe testing environment before implementation.

## 📁 **Project Directory Structure**

This repository is organized into clearly defined sections for easy navigation and understanding:

```
WindowsServer-Lab/
├── 📋 README.md                           # This file - Project overview and navigation
├── 📋 CHANGELOG.md                        # Version history and updates
├── 📋 LICENSE                             # MIT License terms
├── 📋 CONTRIBUTING.md                     # Contribution guidelines and standards
├── 📋 .gitignore                          # Git ignore patterns for lab files
│
├── 🏛️ Demo/                               # Complete enterprise demo environments
│   ├── 📋 README.md                       # Demo overview and comparison
│   ├── 🏰 Asgard/                         # Norse mythology enterprise demo
│   │   ├── 📋 README.md                   # Asgard demo overview and features
│   │   ├── 📋 MANUAL_SETUP_ASGARD.md     # Step-by-step manual deployment
│   │   ├── ⚙️ Scripts/                    # Asgard deployment automation
│   │   │   ├── Deploy-AsgardLab.ps1       # Main deployment script
│   │   │   └── Deploy-AdvancedSecurityDemo.ps1  # Security features demo
│   │   ├── 🚀 Guides/                     # Quick start and setup guides
│   │   │   ├── QUICK_START_ASGARD.md      # 30-minute deployment guide
│   │   │   ├── ASGARD_NETWORK_SHARE_SETUP.md  # Network shares setup
│   │   │   └── ADVANCED_SECURITY_QUICK_START.md  # Security features guide
│   │   └── 📚 Documentation/              # Technical documentation
│   │       ├── DEMO_SETUP_GUIDE.md        # Complete setup reference
│   │       ├── HARDWARE_PERFORMANCE_GUIDE.md  # Performance optimization
│   │       └── NETWORK_SHARE_SETUP_GUIDE.md   # Network configuration
│   └── ⚡ Olympus/                        # Greek mythology enterprise demo
│       ├── 📋 README.md                   # Olympus demo overview and features
│       ├── 📋 MANUAL_SETUP_OLYMPUS.md    # Step-by-step manual deployment
│       ├── ⚙️ Scripts/                    # Olympus deployment automation
│       │   ├── Deploy-OlympusLab.ps1      # Main deployment script
│       │   └── Deploy-AdvancedSecurityDemo.ps1  # Security features demo
│       ├── 🚀 Guides/                     # Quick start and setup guides
│       │   ├── QUICK_START_OLYMPUS.md     # 30-minute deployment guide
│       │   └── OLYMPUS_NETWORK_SHARE_SETUP.md  # Network shares setup
│       └── 📚 Documentation/              # Technical documentation
│           ├── DEMO_SETUP_GUIDE.md        # Complete setup reference
│           └── HARDWARE_PERFORMANCE_GUIDE.md  # Performance optimization
│
├── ⚙️ Scripts/                            # PowerShell utilities for Windows Server
│   ├── 🚀 Lab-FinishSetup.ps1            # Post-installation configuration
│   ├── 🚀 Create-LabUsers.ps1            # User account creation
│   ├── 🚀 DHCP_Setup.ps1                 # DHCP server setup
│   ├── 🛡️ AdvancedGroupPolicyManager.ps1 # 100+ security policies (NEW!)
│   ├── 🛡️ AdvancedSecurityAudit.ps1      # Security assessment (NEW!)
│   ├── 🛡️ GroupPolicyManager.ps1         # Basic GPO management
│   ├── 🛡️ SecurityAudit.ps1              # Basic security assessment
│   ├── 💾 BackupRestoreManager.ps1       # Backup and restore operations
│   ├── 📊 SystemHealthMonitor.ps1        # System monitoring

│   ├── 🗑️ Lab-Uninstall.ps1              # Safe component removal (NEW!)

│   └── 📁 Modules/                       # Additional PowerShell modules
│
├── 📚 LabSetupTutorials/                  # Step-by-step learning guides
│   ├── 🚀 00_Proxmox_Quick_Start.md      # Proxmox VE rapid setup guide
│   ├── 🏗️ 01_Setup_Lab_Environment.md    # Lab environment foundation
│   ├── 👥 02_Manage_Users_Computers_AD.md # Active Directory basics
│   ├── 👥 03_AD_Groups_Management.md     # Group management
│   ├── 🔒 04_GPO_Creation_and_Linking.md # Group Policy management
│   ├── 🔧 05_Troubleshooting.md          # Problem solving guide
│   ├── 📊 06_Monitoring_and_Maintenance.md # System maintenance
│   ├── 🎯 07_Lab_Scenarios.md            # Practical scenarios
│   ├── ⚠️ 08_Common_Mistakes.md          # Pitfalls and solutions
│   ├── 🛡️ 09_Security_Hardening.md       # Security best practices
│   ├── 🤖 10_Automation_and_Scripting.md # Automation strategies
│   ├── 📝 11_Naming_Conventions.md       # Naming standards
│   ├── 💾 12_Disaster_Recovery.md        # Backup and recovery
│   ├── 🖥️ 13_Additional_Servers_Setup.md # Extended server roles
│   ├── 💻 14_Additional_Clients_Setup.md # Client deployment
│   ├── 🌐 15_DHCP_Server_Setup.md        # DHCP configuration
│   ├── 🏢 16_Proxmox_Setup_and_Configuration.md # Proxmox VE setup
│   └── 🗑️ 17_Uninstall_and_Revert.md     # Safe removal procedures
│
├── 🔄 .github/                           # GitHub automation and templates
│   ├── 🤖 workflows/                     # CI/CD automation workflows
│   │   ├── ci.yml                        # Continuous integration
│   │   ├── docs.yml                      # Documentation validation
│   │   └── release.yml                   # Release automation
│   ├── 📝 ISSUE_TEMPLATE/                # Issue reporting templates
│   ├── 📝 pull_request_template.md       # PR template
│   ├── 🛡️ SECURITY.md                    # Security policy
│   ├── 🤝 SUPPORT.md                     # Support resources
│   ├── 📋 CODE_OF_CONDUCT.md             # Community guidelines
│   ├── 💰 FUNDING.yml                    # Sponsorship information
│   └── 🔧 validate-compliance.ps1       # Compliance validation
│
├── 🧪 test-local-ci.ps1                  # Local CI testing script
├── 🧪 test-local-ci.sh                   # Local CI testing (Linux/macOS)
├── 📊 VERSION                            # Current version number
├── 📋 CODEBASE_AUDIT_REPORT.md           # Code quality audit results
├── 📋 AUDIT_REPORT.md                    # Security audit summary
├── 📋 DOCUMENTATION_AUDIT_SUMMARY.md    # Documentation review
└── 📋 DIRECTORY_STRUCTURE_AUDIT_REPORT.md # This audit's results
```

### **Key Directory Purposes**

| Directory                 | Purpose                          | Best Used For                               |
| ------------------------- | -------------------------------- | ------------------------------------------- |
| **🏛️ Demo/**              | Complete enterprise environments | Production-like deployments, demonstrations |
| **⚙️ Scripts/**           | Core automation tools            | Individual tasks, custom deployments        |
| **📚 LabSetupTutorials/** | Learning materials               | Step-by-step learning, troubleshooting      |
| **🔄 .github/**           | Project automation               | CI/CD, issue tracking, community            |

### **Getting Started Navigation**

- **🚀 New Users**: Start with [Demo/README.md](Demo/README.md) for quick deployment
- **📚 Learners**: Begin with [LabSetupTutorials/01_Setup_Lab_Environment.md](LabSetupTutorials/01_Setup_Lab_Environment.md)
- **⚙️ Developers**: Explore [Scripts/](Scripts/) for automation tools
- **🤝 Contributors**: Read [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines

## Table of Contents

### Lab Setup Tutorials

The tutorials are organized in a logical sequence from initial setup to advanced topics. Each tutorial builds upon the knowledge from previous ones:

#### Core Setup and Administration (1-4)

1. [Lab Environment Setup](LabSetupTutorials/01_Setup_Lab_Environment.md)

   - Initial environment configuration
   - Basic infrastructure setup
   - Prerequisites for all other tutorials

2. [Active Directory Management](LabSetupTutorials/02_Manage_Users_Computers_AD.md)

   - User and computer management
   - Active Directory basics
   - Required for all user/group management

3. [AD Groups Management](LabSetupTutorials/03_AD_Groups_Management.md)

   - Group creation and management
   - Group policy considerations
   - Builds on AD Management

4. [Group Policy Management](LabSetupTutorials/04_GPO_Creation_and_Linking.md)
   - GPO creation and configuration
   - Policy linking and inheritance
   - Core for system management

#### Maintenance and Troubleshooting (5-6)

5. [Troubleshooting Guide](LabSetupTutorials/05_Troubleshooting.md)

   - Common issues and solutions
   - Diagnostic procedures
   - Reference for all other tutorials

6. [Monitoring and Maintenance](LabSetupTutorials/06_Monitoring_and_Maintenance.md)
   - System monitoring
   - Regular maintenance tasks
   - Ongoing operations

#### Practical Applications (7-8)

7. [Lab Scenarios](LabSetupTutorials/07_Lab_Scenarios.md)

   - Common lab configurations
   - Use case examples
   - Practical applications of previous tutorials

8. [Common Mistakes](LabSetupTutorials/08_Common_Mistakes.md)
   - Known issues and pitfalls
   - Best practices
   - Lessons learned

#### Advanced Topics (9-15)

9. [Security Hardening](LabSetupTutorials/09_Security_Hardening.md)

   - Security best practices
   - System hardening procedures
   - Advanced security concepts

10. [Automation and Scripting](LabSetupTutorials/10_Automation_and_Scripting.md)

    - Automation strategies
    - Scripting guidelines
    - PowerShell automation

11. [Naming Conventions](LabSetupTutorials/11_Naming_Conventions.md)

    - Standard naming schemes
    - Best practices
    - Organization standards

12. [Disaster Recovery](LabSetupTutorials/12_Disaster_Recovery.md)

    - Backup and recovery procedures
    - Business continuity planning
    - Critical operations

13. [Additional Servers Setup](LabSetupTutorials/13_Additional_Servers_Setup.md)

    - Server role configuration
    - Additional services setup
    - Advanced server deployment

14. [Additional Clients Setup](LabSetupTutorials/14_Additional_Clients_Setup.md)

    - Client deployment
    - Client configuration
    - End-user management

15. [DHCP Server Setup](LabSetupTutorials/15_DHCP_Server_Setup.md)

    - DHCP role installation
    - Scope configuration
    - Reservations, exclusions, and best practices

16. [Proxmox VE Setup and Configuration](LabSetupTutorials/16_Proxmox_Setup_and_Configuration.md)

    - Proxmox VE installation and configuration
    - Virtual bridge creation and management
    - Advanced networking and security
    - VM creation and optimization

17. [Uninstall and Revert Changes](LabSetupTutorials/17_Uninstall_and_Revert.md)
    - Safe removal of lab components
    - Backup and restore procedures
    - Selective component uninstallation
    - Recovery from failed installations

### Management Scripts

The Scripts directory contains PowerShell scripts that complement the tutorials:

#### Setup Scripts

- [Lab Finish Setup Script](Scripts/Lab-FinishSetup.ps1) - Post-installation configuration
- [Create Lab Users Script](Scripts/Create-LabUsers.ps1) - User account creation
- [DHCP Setup Script](Scripts/DHCP_Setup.ps1) - DHCP server installation and configuration

#### Advanced Security and Policy Management Scripts (NEW!)

- [**Advanced Group Policy Manager**](Scripts/AdvancedGroupPolicyManager.ps1) - Comprehensive GPO management with camera, USB, device controls
- [**Advanced Security Audit**](Scripts/AdvancedSecurityAudit.ps1) - Complete security assessment with scoring and recommendations
- [**Advanced Security Documentation - Asgard**](Demo/Asgard/README.md) - Interactive demonstration documentation (Asgard)
  - [**Advanced Security Documentation - Olympus**](Demo/Olympus/README.md) - Interactive demonstration documentation (Olympus)

#### Traditional Management Scripts

- [Group Policy Manager](Scripts/GroupPolicyManager.ps1) - Basic GPO management
- [Security Audit Script](Scripts/SecurityAudit.ps1) - Basic security assessment
- [Backup Restore Manager](Scripts/BackupRestoreManager.ps1) - Backup and restore operations
- [System Health Monitor](Scripts/SystemHealthMonitor.ps1) - System monitoring

- [Oh My Posh Setup Script](Scripts/Setup-OhMyPosh.ps1) - PowerShell prompt customization with themes and icons
- [Quick Oh My Posh Install](Scripts/Quick-InstallOhMyPosh.ps1) - Streamlined installation of Oh My Posh

#### Uninstall and Recovery Scripts (NEW)

- [Lab Uninstall Script](Scripts/Lab-Uninstall.ps1) - Comprehensive component removal with backup

## 🛡️ Advanced Security Features (NEW!)

### Comprehensive Security Controls

This lab now includes **100+ advanced security features** across 8 major categories:

#### 🎥 **Camera & Microphone Security**

- Complete camera access control for applications
- Microphone usage restriction policies
- Windows Hello camera security settings
- Privacy protection for multimedia devices

#### 🔌 **USB & Removable Storage Control**

- Granular USB device type restrictions
- Removable storage read/write/execute controls
- Device installation prevention policies
- Autorun and autoplay security settings

#### 🖥️ **Device & Peripheral Management**

- Bluetooth and wireless device controls
- Printer and fax management policies
- CD/DVD and optical drive restrictions
- External display and monitor controls

#### 🎨 **Personalization & User Experience**

- Desktop background and theme controls
- Start menu and taskbar customization
- Screen saver and power management
- Windows Store and app installation policies

#### 📱 **Application & Software Control**

- PowerShell execution and logging policies
- AppLocker application whitelisting
- Software installation restrictions
- Windows Defender Application Guard

#### 🌐 **Network Security & Communication**

- Advanced Windows Firewall configuration
- Remote Desktop security controls
- SMB signing and encryption settings
- VPN and network connection policies

#### 🔒 **Data Protection & Privacy**

- Telemetry and data collection controls
- OneDrive and cloud service policies
- Cortana and search privacy settings
- Windows Error Reporting configuration

#### 📊 **Security Auditing & Monitoring**

- Comprehensive security score calculation (0-100%)
- Real-time policy compliance checking
- Advanced HTML reporting with analytics
- Security improvement recommendations

### Quick Start with Advanced Security

```powershell
# Run the Advanced Security Demo
.\Demo\Scripts\Deploy-AdvancedSecurityDemo.ps1

# Deploy all security policies
.\Scripts\AdvancedGroupPolicyManager.ps1

# Run comprehensive security audit
.\Scripts\AdvancedSecurityAudit.ps1
```

## 🔒 Traditional Security Features

### Secure Password Management

All scripts in this lab environment follow security best practices:

- **No Hardcoded Passwords**: All passwords are prompted securely at runtime
- **SecureString Handling**: Passwords are handled using PowerShell's SecureString type
- **Runtime Prompts**: Users are prompted for passwords when needed:
  - Safe Mode (DSRM) passwords for domain controllers
  - Default passwords for user account creation
  - Administrative passwords for service accounts

### Example Usage with Secure Passwords

```powershell
# When running scripts, you'll be prompted for passwords:
.\Scripts\Lab-FinishSetup.ps1
# Prompts: "Please enter the default password for new user accounts:"

# For automated scenarios, you can pre-provide SecureString parameters:
$securePassword = Read-Host -AsSecureString -Prompt "Enter password"
.\Scripts\Create-LabUsers.ps1 -DefaultUserPassword $securePassword

# Demo environment scripts with dual ISO support:
.\Demo\Scripts\Deploy-AsgardLab.ps1 -ServerISOPath "C:\ISOs\WindowsServer2025.iso" -ClientISOPath "C:\ISOs\Windows10.iso"
# Prompts for both Safe Mode and Default User passwords

# Olympus deployment with separate ISOs:
.\Demo\Olympus\Scripts\Deploy-OlympusLab.ps1 -ServerISOPath "C:\ISOs\WindowsServer2025.iso" -ClientISOPath "C:\ISOs\Windows10.iso"

# Legacy single ISO mode (backward compatibility):
.\Demo\Scripts\Deploy-AsgardLab.ps1 -ISOPath "C:\ISOs\WindowsServer.iso"
```

### Security Compliance

- ✅ **No plaintext passwords in code**
- ✅ **PSScriptAnalyzer validated** (0 critical security errors)
- ✅ **Secure parameter handling**
- ✅ **Runtime password validation**
- ✅ **Proper error handling for security operations**

## Learning Path

1. Start with the Core Setup and Administration tutorials (1-4)
2. Move to Maintenance and Troubleshooting (5-6)
3. Practice with Lab Scenarios (7-8)
4. Advance to Advanced Topics (9-15)

## Getting Started

### Quick Installation (PowerShell Module)

1. **Clone the repository:**

   ```powershell
   git clone https://github.com/j4v3l/WindowsServer-Lab.git
   cd WindowsServer-Lab
   ```

2. **Test module integrity (optional):**

   ```powershell
   # Validate module structure and consistency
   # Module validation no longer available - use manual procedures
   ```

3. **Import the PowerShell module:**

   ```powershell
   # Import the module
   # PowerShell utilities available in Scripts directory

# Run individual scripts as needed for Windows Server configuration

# Verify module loaded

# PowerShell module no longer available - use manual procedures

   ```

4. **Create your lab environment:**

   ```powershell
   # Test prerequisites first
   # Manual environment validation - no automated testing available

   # Create complete lab environment with separate ISOs (you'll be prompted for passwords)
   # Create VMs manually using Proxmox VE web interface
   # Follow the Proxmox setup guides for detailed instructions

   # Check lab status
   Get-LabStatus
   ```

5. **Uninstall or revert when needed:**

   ```powershell
   # Safely remove all lab components (creates backup first)
   # Manual component removal - use Lab-Uninstall.ps1 script
   .\Scripts\Lab-Uninstall.ps1 -Component All

   # Remove specific components  
   .\Scripts\Lab-Uninstall.ps1 -Component VMs

   # Restore from backup if needed
   # Manual restoration procedures - follow documentation guides
   ```

   **🔧 ISO Requirements:**

   - **Server ISO**: Windows Server 2019/2022/2025 for domain controllers and servers
   - **Client ISO**: Windows 10/11 for workstation VMs  
   - **VirtIO Drivers**: Latest VirtIO ISO for optimal VM performance on Proxmox VE
   - **Legacy Mode**: Single ISO can be used for all VMs (backward compatibility)

   **Security Note:** All scripts now use secure password prompts instead of hardcoded passwords. You'll be prompted to enter:

   - **Safe Mode Password**: For domain controller restore mode
   - **Default User Password**: For new user accounts

   Passwords are entered securely and never stored in plain text.

### Manual Setup Options

#### For Proxmox VE Users (Recommended)

1. Start with the [Proxmox VE Quick Start Guide](LabSetupTutorials/00_Proxmox_Quick_Start.md) for rapid setup
2. Or follow the detailed [Proxmox VE Setup and Configuration](LabSetupTutorials/16_Proxmox_Setup_and_Configuration.md) guide
3. Use the [Windows Server Optimization Guide](LabSetupTutorials/Windows_Server_on_Proxmox_Optimization.md) for best performance
3. Then proceed with [Lab Environment Setup](LabSetupTutorials/01_Setup_Lab_Environment.md)

#### For Other Virtualization Platforms

1. Begin with the [Lab Environment Setup](LabSetupTutorials/01_Setup_Lab_Environment.md) guide
2. Follow the tutorials in sequence
3. Use the provided scripts to automate common tasks
4. Refer to the troubleshooting guide for common issues

### PowerShell Module Commands

Once the module is imported, you have access to these commands:

| Command                   | Description                     |
| ------------------------- | ------------------------------- |
| **Manual VM Creation**    | Use Proxmox web interface      |
| **Manual Validation**     | Follow setup documentation     |
| **Manual VM Control**     | Use Proxmox VE web interface    |
| **Proxmox Commands**      | Use `qm start/stop` commands (on Proxmox host) |
| **Execution Guide**       | See [EXECUTION_CONTEXT_GUIDE.md](EXECUTION_CONTEXT_GUIDE.md) |
| `Get-LabStatus`           | Get current lab status          |
| `New-LabUsers`            | Create lab users and OUs        |
| `Invoke-LabSecurityAudit` | Run security audit              |
| `Set-LabGroupPolicy`      | Configure Group Policy          |
| `Set-LabConfiguration`    | Modify lab settings             |
| `Get-LabConfiguration`    | Get current lab settings        |

## Contributing

We welcome contributions! Our project includes comprehensive templates and community guidelines:

### 📝 How to Contribute

- **[Contributing Guidelines](CONTRIBUTING.md)**: Detailed code standards, PR process, and development setup
- **[Code of Conduct](.github/CODE_OF_CONDUCT.md)**: Community standards with educational focus
- **[Support Resources](.github/SUPPORT.md)**: Multiple ways to get help and connect with the community

### 🐛 Reporting Issues

Use our structured issue templates for better assistance:

- **[Bug Reports](https://github.com/j4v3l/WindowsServer-Lab/issues/new?template=bug_report.yml)**: Detailed environment and reproduction steps
- **[Feature Requests](https://github.com/j4v3l/WindowsServer-Lab/issues/new?template=feature_request.yml)**: Categorized with priority assessment
- **[Questions](https://github.com/j4v3l/WindowsServer-Lab/issues/new?template=question.yml)**: Help with guided troubleshooting

### 🔒 Security & Safety

- **[Security Policy](.github/SECURITY.md)**: Vulnerability reporting and lab security best practices
- **Private Disclosure**: Security issues handled confidentially through GitHub security advisories
- **Lab Isolation**: Guidelines for secure lab environment setup and network isolation

### 🤝 Community Guidelines

- **Respectful Communication**: Professional and welcoming interactions
- **Educational Focus**: No question is too basic - we all learn together
- **Knowledge Sharing**: Help others and share your lab experiences
- **Code Quality**: Follow PowerShell best practices and include proper documentation

## License

This project is licensed under the MIT License - see the LICENSE file for details.
