# Windows Server Lab Environment

This repository contains comprehensive documentation and scripts for setting up and managing a Windows Server lab environment. The content is organized into two main sections: Lab Setup Tutorials and Management Scripts.

## 🏰 **Epic Demos Available!**

**NEW**: Experience the complete power of this lab environment with our comprehensive demo environments:

- **[Asgard Technologies Demo](Demo/README.md)** - Norse mythology-themed enterprise setup featuring 25 VMs, complete organizational structure, and professional-grade configurations
- **[Olympus Systems Demo](Demo/Olympus/README.md)** - Greek mythology-themed enterprise setup with advanced cloud integration and AI/ML capabilities

Both demos provide realistic enterprise environments perfect for demonstrations, learning, and showcasing Windows Server capabilities!

👉 **[Get Started with Asgard Demo](Demo/Asgard/Guides/QUICK_START_ASGARD.md)** - Deploy in 30-60 minutes!  
👉 **[Manual Asgard Setup Guide](Demo/Asgard/MANUAL_SETUP_ASGARD.md)** - Step-by-step manual deployment!  
👉 **[Get Started with Olympus Demo](Demo/Olympus/Guides/QUICK_START_OLYMPUS.md)** - Deploy in 30-60 minutes!  
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
├── ⚙️ Scripts/                            # Core PowerShell automation scripts
│   ├── 📋 WindowsServerLab.psd1          # PowerShell module manifest
│   ├── 📋 WindowsServerLab.psm1          # PowerShell module functions
│   ├── 🚀 Lab_Setup.ps1                  # Initial lab environment setup
│   ├── 🚀 Lab-FinishSetup.ps1            # Post-installation configuration
│   ├── 🚀 Create-LabUsers.ps1            # User account creation
│   ├── 🚀 DHCP_Setup.ps1                 # DHCP server setup
│   ├── 🚀 Hyper-V_Lab_Setup.ps1          # Hyper-V environment setup
│   ├── 🔧 Hyper-V_Management.ps1         # VM lifecycle management
│   ├── 🛡️ AdvancedGroupPolicyManager.ps1 # 100+ security policies (NEW!)
│   ├── 🛡️ AdvancedSecurityAudit.ps1      # Security assessment (NEW!)
│   ├── 🛡️ GroupPolicyManager.ps1         # Basic GPO management
│   ├── 🛡️ SecurityAudit.ps1              # Basic security assessment
│   ├── 💾 BackupRestoreManager.ps1       # Backup and restore operations
│   ├── 📊 SystemHealthMonitor.ps1        # System monitoring
│   ├── 🧪 Test-ModuleIntegrity.ps1       # Module validation
│   ├── 🧪 Test-LabEnvironment.ps1        # Environment testing
│   ├── 🗑️ Lab-Uninstall.ps1              # Safe component removal (NEW!)
│   ├── 🔄 Lab-Restore.ps1                # Backup restoration (NEW!)
│   └── 📁 Modules/                       # Additional PowerShell modules
│
├── 📚 LabSetupTutorials/                  # Step-by-step learning guides
│   ├── 🚀 00_Hyper-V_Quick_Start.md      # Hyper-V rapid setup guide
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
│   ├── 🏢 16_Hyper-V_Setup_and_Configuration.md # Virtualization setup
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

16. [Hyper-V Setup and Configuration](LabSetupTutorials/16_Hyper-V_Setup_and_Configuration.md)

    - Hyper-V installation and configuration
    - Virtual switch creation and management
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

- [Lab Setup Script](Scripts/Lab_Setup.ps1) - Initial lab environment setup
- [Lab Finish Setup Script](Scripts/Lab-FinishSetup.ps1) - Post-installation configuration
- [Create Lab Users Script](Scripts/Create-LabUsers.ps1) - User account creation
- [DHCP Setup Script](Scripts/DHCP_Setup.ps1) - DHCP server installation and configuration
- [Hyper-V Lab Setup Script](Scripts/Hyper-V_Lab_Setup.ps1) - Complete Hyper-V lab environment setup

#### Advanced Security and Policy Management Scripts (NEW!)

- [**Advanced Group Policy Manager**](Scripts/AdvancedGroupPolicyManager.ps1) - Comprehensive GPO management with camera, USB, device controls
- [**Advanced Security Audit**](Scripts/AdvancedSecurityAudit.ps1) - Complete security assessment with scoring and recommendations
- [**Advanced Security Demo - Asgard**](Demo/Asgard/Scripts/Deploy-AdvancedSecurityDemo.ps1) - Interactive demonstration of all security features (Asgard)
  - [**Advanced Security Demo - Olympus**](Demo/Olympus/Scripts/Deploy-AdvancedSecurityDemo.ps1) - Interactive demonstration of all security features (Olympus)

#### Traditional Management Scripts

- [Group Policy Manager](Scripts/GroupPolicyManager.ps1) - Basic GPO management
- [Security Audit Script](Scripts/SecurityAudit.ps1) - Basic security assessment
- [Backup Restore Manager](Scripts/BackupRestoreManager.ps1) - Backup and restore operations
- [System Health Monitor](Scripts/SystemHealthMonitor.ps1) - System monitoring
- [Hyper-V Management Script](Scripts/Hyper-V_Management.ps1) - Hyper-V lab lifecycle management

#### Uninstall and Recovery Scripts (NEW)

- [Lab Uninstall Script](Scripts/Lab-Uninstall.ps1) - Comprehensive component removal with backup
- [Lab Restore Script](Scripts/Lab-Restore.ps1) - Restore from backups created during uninstall

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
.\Scripts\Lab_Setup.ps1
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
   .\Scripts\Test-ModuleIntegrity.ps1
   ```

3. **Import the PowerShell module:**

   ```powershell
   # Import the module
   Import-Module .\Scripts\WindowsServerLab.psd1 -Force

   # Verify module loaded
   Get-Command -Module WindowsServerLab
   ```

4. **Create your lab environment:**

   ```powershell
   # Test prerequisites first
   Test-LabEnvironment -Detailed

   # Create complete lab environment with separate ISOs (you'll be prompted for passwords)
   New-LabEnvironment -VMPath "C:\VMs" -ServerISOPath "C:\path\to\WindowsServer2025.iso" -ClientISOPath "C:\path\to\Windows10.iso"

   # Or use legacy single ISO for both (backward compatibility)
   New-LabEnvironment -VMPath "C:\VMs" -ISOPath "C:\path\to\WindowsServer.iso"

   # Check lab status
   Get-LabStatus
   ```

5. **Uninstall or revert when needed:**

   ```powershell
   # Safely remove all lab components (creates backup first)
   Remove-LabEnvironment -Component All

   # Remove specific components only
   Remove-LabEnvironment -Component VMs
   Remove-LabEnvironment -Component AD

   # Restore from backup if needed
   Restore-LabEnvironment -BackupPath "C:\LabBackup"
   ```

   **🔧 ISO Requirements:**

   - **Server ISO**: Windows Server 2019/2022/2025 for domain controllers and servers
   - **Client ISO**: Windows 10/11 for workstation VMs
   - **Legacy Mode**: Single ISO can be used for all VMs (backward compatibility)

   **Security Note:** All scripts now use secure password prompts instead of hardcoded passwords. You'll be prompted to enter:

   - **Safe Mode Password**: For domain controller restore mode
   - **Default User Password**: For new user accounts

   Passwords are entered securely and never stored in plain text.

### Manual Setup Options

#### For Hyper-V Users (Recommended)

1. Start with the [Hyper-V Quick Start Guide](LabSetupTutorials/00_Hyper-V_Quick_Start.md) for rapid setup
2. Or follow the detailed [Hyper-V Setup and Configuration](LabSetupTutorials/16_Hyper-V_Setup_and_Configuration.md) guide
3. Then proceed with [Lab Environment Setup](LabSetupTutorials/01_Setup_Lab_Environment.md)

#### For VirtualBox/VMware Users

1. Begin with the [Lab Environment Setup](LabSetupTutorials/01_Setup_Lab_Environment.md) guide
2. Follow the tutorials in sequence
3. Use the provided scripts to automate common tasks
4. Refer to the troubleshooting guide for common issues

### PowerShell Module Commands

Once the module is imported, you have access to these commands:

| Command                   | Description                     |
| ------------------------- | ------------------------------- |
| `New-LabEnvironment`      | Create complete lab environment |
| `Test-LabEnvironment`     | Validate lab configuration      |
| `Start-LabVMs`            | Start all or specific lab VMs   |
| `Stop-LabVMs`             | Stop all or specific lab VMs    |
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
