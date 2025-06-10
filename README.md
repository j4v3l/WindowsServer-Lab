# Windows Server Lab Environment

This repository contains comprehensive documentation and scripts for setting up and managing a Windows Server lab environment. The content is organized into two main sections: Lab Setup Tutorials and Management Scripts.

## 🏰 **Epic Demos Available!**

**NEW**: Experience the complete power of this lab environment with our comprehensive demo environments:

- **[Asgard Technologies Demo](Demo/README.md)** - Norse mythology-themed enterprise setup featuring 25 VMs, complete organizational structure, and professional-grade configurations
- **[Olympus Systems Demo](Demo/Olympus/README.md)** - Greek mythology-themed enterprise setup with advanced cloud integration and AI/ML capabilities

Both demos provide realistic enterprise environments perfect for demonstrations, learning, and showcasing Windows Server capabilities!

👉 **[Get Started with Asgard Demo](Demo/Guides/QUICK_START_ASGARD.md)** - Deploy in 30-60 minutes!  
👉 **[Get Started with Olympus Demo](Demo/Olympus/Guides/QUICK_START_OLYMPUS.md)** - Deploy in 30-60 minutes!

## ⚠️ Important Disclaimer

**This is a work in progress and is intended for educational and development purposes only.**

- All scripts and tutorials are provided "as is" without warranty
- Known bugs and errors exist in both documentation and scripts
- This material should **NEVER** be used in a production environment
- Always test thoroughly in a development or lab environment
- Some scripts may require modification to work in your specific environment
- Documentation may contain inaccuracies or outdated information

Use at your own risk and always verify any changes in a safe testing environment before implementation.

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

### Management Scripts

The Scripts directory contains PowerShell scripts that complement the tutorials:

#### Setup Scripts

- [Lab Setup Script](Scripts/Lab_Setup.ps1) - Initial lab environment setup
- [Lab Finish Setup Script](Scripts/Lab-FinishSetup.ps1) - Post-installation configuration
- [Create Lab Users Script](Scripts/Create-LabUsers.ps1) - User account creation
- [DHCP Setup Script](Scripts/DHCP_Setup.ps1) - DHCP server installation and configuration
- [Hyper-V Lab Setup Script](Scripts/Hyper-V_Lab_Setup.ps1) - Complete Hyper-V lab environment setup

#### Management Scripts

- [Group Policy Manager](Scripts/GroupPolicyManager.ps1) - GPO management
- [Security Audit Script](Scripts/SecurityAudit.ps1) - Security assessment
- [Backup Restore Manager](Scripts/BackupRestoreManager.ps1) - Backup and restore operations
- [System Health Monitor](Scripts/SystemHealthMonitor.ps1) - System monitoring
- [Hyper-V Management Script](Scripts/Hyper-V_Management.ps1) - Hyper-V lab lifecycle management

## 🔒 Security Features

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

# Demo environment scripts also follow the same pattern:
.\Demo\Scripts\Deploy-AsgardLab.ps1
# Prompts for both Safe Mode and Default User passwords
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

   # Create complete lab environment (you'll be prompted for passwords)
   New-LabEnvironment -VMPath "C:\VMs" -ISOPath "C:\path\to\WindowsServer.iso"

   # Check lab status
   Get-LabStatus
   ```

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
