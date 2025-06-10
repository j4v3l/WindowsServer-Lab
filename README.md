# Windows Server Lab Environment

This repository contains comprehensive documentation and scripts for setting up and managing a Windows Server lab environment. The content is organized into two main sections: Lab Setup Tutorials and Management Scripts.

## 🏰 **Epic Demo Available!**

**NEW**: Experience the complete power of this lab environment with our **[Asgard Technologies Demo](Demo/README.md)** - a Norse mythology-themed enterprise setup featuring 25 VMs, complete organizational structure, and professional-grade configurations. Perfect for demonstrations, learning, and showcasing Windows Server capabilities!

👉 **[Get Started with the Demo](Demo/Guides/QUICK_START_ASGARD.md)** - Deploy in 30-60 minutes!

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

## Learning Path

1. Start with the Core Setup and Administration tutorials (1-4)
2. Move to Maintenance and Troubleshooting (5-6)
3. Practice with Lab Scenarios (7-8)
4. Advance to Advanced Topics (9-15)

## Getting Started

### Quick Installation (PowerShell Module)

1. **Clone the repository:**

   ```powershell
   git clone https://github.com/yourusername/WindowsServer.git
   cd WindowsServer
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
   
   # Create complete lab environment
   New-LabEnvironment -VMPath "C:\VMs" -ISOPath "C:\path\to\WindowsServer.iso"
   
   # Check lab status
   Get-LabStatus
   ```

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

| Command | Description |
|---------|-------------|
| `New-LabEnvironment` | Create complete lab environment |
| `Test-LabEnvironment` | Validate lab configuration |
| `Start-LabVMs` | Start all or specific lab VMs |
| `Stop-LabVMs` | Stop all or specific lab VMs |
| `Get-LabStatus` | Get current lab status |
| `New-LabUsers` | Create lab users and OUs |
| `Invoke-LabSecurityAudit` | Run security audit |
| `Set-LabGroupPolicy` | Configure Group Policy |
| `Set-LabConfiguration` | Modify lab settings |
| `Get-LabConfiguration` | Get current lab settings |

## Contributing

We welcome contributions to improve this project. Please follow these guidelines when contributing:

### Pull Request Process

1. **Fork and Clone**
   - Fork the repository
   - Clone your fork locally
   - Create a new branch for your changes

2. **Development**
   - Make your changes in a new branch
   - Follow existing code style and formatting
   - Update documentation as needed
   - Test your changes thoroughly

3. **Commit Guidelines**
   - Use clear, descriptive commit messages
   - Reference issues and pull requests in commit messages
   - Keep commits focused and atomic

4. **Pull Request**
   - Push your changes to your fork
   - Create a pull request against the main branch
   - Fill out the PR template completely
   - Link any related issues

5. **Review Process**
   - All PRs require at least one review
   - Address review comments promptly
   - Keep the PR up to date with the main branch

### Contribution Standards

- **Code Quality**
  - Follow PowerShell best practices
  - Include error handling
  - Add comments for complex logic
  - Maintain consistent formatting

- **Documentation**
  - Update relevant markdown files
  - Include examples where appropriate
  - Document any new dependencies
  - Update the table of contents if needed

- **Testing**
  - Test in a development environment
  - Include test cases for new features
  - Verify backward compatibility
  - Document test procedures

### Getting Help

- Open an issue for bugs or feature requests
- Use the issue template provided
- Include steps to reproduce for bugs
- Provide environment details when relevant

## License

This project is licensed under the MIT License - see the LICENSE file for details.
