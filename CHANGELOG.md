# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.1] - 2025-06-12

### Fixed - Critical Network Configuration Issues

- **🔧 Virtual Switch Configuration**: Fixed both Asgard and Olympus demos to use Internal switches instead of External

  - **ASGARD-Production**: Changed from External to Internal with proper 10.0.10.1/24 gateway
  - **OLYMPUS-Production**: Changed from External to Internal with proper 10.0.10.1/24 gateway
  - **Issue Resolution**: Prevents IP address conflicts with host network (192.168.x.x vs 10.0.x.x)

- **🌐 IP Forwarding Configuration**: Added missing IP forwarding enablement on all virtual interfaces

  - **Critical Fix**: Enables routing between virtual networks (Production ↔ Clients ↔ Management)
  - **All Demos**: Applied to both Asgard and Olympus deployment scripts
  - **Impact**: Resolves "Access is denied" domain join failures and network isolation issues

- **👤 User Account Password Issues**: Fixed password expiration problems in lab environments

  - **Added**: `-PasswordNeverExpires $true` to all user account creation commands
  - **Prevents**: "Password must be changed at next logon" and expired password authentication failures
  - **Lab-Optimized**: Appropriate for lab/demo environments where password policies should be relaxed

- **🛠️ Network Validation Tools**: Created comprehensive network testing scripts

  - **New**: `Demo/Asgard/Scripts/Test-AsgardNetwork.ps1` - Complete Asgard network validation
  - **New**: `Demo/Olympus/Scripts/Test-OlympusNetwork.ps1` - Complete Olympus network validation
  - **Features**: Tests switches, IP configuration, forwarding, NAT, connectivity, and VM network status
  - **Proactive**: Identifies network issues before attempting domain joins

- **📚 Troubleshooting Documentation**: Added comprehensive network troubleshooting guide
  - **New**: `LabSetupTutorials/20_Network_Troubleshooting_Guide.md`
  - **Emergency Recovery**: Quick fix commands for common network failures
  - **Step-by-Step**: Solutions for domain join, DNS, gateway, and connectivity issues
  - **Automated Tools**: Integration with network validation scripts

### Technical Details

- **Root Cause Analysis**: External virtual switches caused IP conflicts between host network and lab networks
- **DNS Resolution**: Fixed by ensuring proper gateway configuration and IP forwarding
- **Cross-Network Routing**: Static routes and IP forwarding now enable communication between network segments
- **User Authentication**: Password policies optimized for lab environments to prevent authentication loops

### Impact

- **Domain Joins**: Now succeed on first attempt without manual network configuration
- **DNS Resolution**: Proper resolution of lab domains (asgard.local, olympus.local)
- **Network Connectivity**: Full connectivity between all network segments and VMs
- **User Experience**: Eliminates hours of manual troubleshooting for new users

## [1.3.0] - 2025-06-12

### Added - Comprehensive Manual Setup Documentation

- **📚 Manual Setup Guide for Asgard Technologies**: Complete step-by-step manual deployment documentation

  - 25 virtual machines with detailed configuration instructions
  - Network infrastructure setup (4 network segments)
  - Active Directory manual configuration with organizational structure
  - Server deployment guides for all 5 servers (ODIN-DC01, FRIGG-DC02, HEIMDALL-FS01, BALDER-WEB01, VIDAR-SEC01)
  - Workstation creation across 5 Norse mythology departments
  - DNS, DHCP, and services manual configuration
  - Security policies and group management setup

- **📚 Manual Setup Guide for Olympus Systems**: Advanced manual deployment documentation

  - Greek mythology-themed enterprise environment
  - Enhanced security features with 100+ security controls
  - Cloud integration capabilities and AI/ML development environment
  - Advanced security controls (camera, USB, application restrictions)
  - Divine organizational structure with 5 departments
  - Modern workload support and hybrid cloud readiness

- **🔍 Comprehensive Codebase Audit Report**: Complete technical analysis
  - Architecture overview and component analysis
  - Security assessment with recommendations
  - Performance analysis and optimization insights
  - Code quality evaluation and technical debt analysis
  - Strategic recommendations for future development

### Enhanced

- **Documentation Navigation**: Updated all README files to reference manual setup guides
- **Directory Structure**: Added manual setup documentation to proper locations
- **Cross-References**: Enhanced navigation between automated and manual setup options
- **Hardware Requirements**: Properly formatted tables with aligned columns
- **User Options**: Clear choice between automated scripts and manual step-by-step setup

### Documentation Improvements

- **Main README**: Added direct links to manual setup guides alongside automated options
- **Demo README**: Enhanced directory structure and audience-specific guidance
- **Olympus README**: Added manual setup section for advanced users
- **Table Formatting**: Improved consistency across all documentation files

## [1.2.0] - 2025-06-11

### Added - Advanced Security Features Suite

- **🛡️ Advanced Group Policy Manager**: 100+ comprehensive security policies across 6 categories

  - Camera & Microphone Security: Application access controls, privacy protection
  - USB & Removable Storage Control: Granular device restrictions, installation prevention
  - Device Control: Bluetooth, WiFi, printer, CD/DVD, external display management
  - Personalization Policies: Desktop, Start menu, taskbar, Windows Store controls
  - Application Control: PowerShell policies, AppLocker, software installation restrictions
  - Network Security: Advanced firewall, Remote Desktop, SMB signing configurations
  - Data Protection: Telemetry, OneDrive, Cortana, privacy settings

- **🔍 Advanced Security Audit System**: Comprehensive security scoring and assessment

  - Professional HTML reporting with visual dashboards and analytics
  - Security scoring (0-100%) across all categories with improvement recommendations
  - Individual audit functions for each security domain
  - Quick security check functionality and connected device analysis

- **🎮 Interactive Demo System**: Enhanced demo environments with security showcase

  - Integration with existing Asgard and Olympus demo environments
  - Interactive menu system showcasing all security features
  - Automated policy deployment to appropriate organizational units
  - Demo-specific security assessment and reporting

- **📚 Enhanced Documentation Suite**:
  - Complete rewrite of GPO Creation and Linking tutorial with advanced features
  - Advanced Security Quick Start Guide for both demo environments
  - Registry implementation examples and troubleshooting sections
  - Best practices for phased deployment and compliance framework alignment

### Enhanced

- **Demo Environments**: Updated both Asgard Technologies and Olympus Systems demos

  - Added 8 new security-focused demo scenarios
  - Enhanced organizational unit mapping for security policies
  - Updated feature demonstrations to include 100+ security controls
  - Added environment-specific security commands and testing scenarios

- **Main Documentation**: Updated README.md with comprehensive security feature overview
  - Quick start examples and command-line usage for security features
  - Visual formatting and feature categorization
  - Integration information for existing demo environments

### Security Features

- **Device & Privacy Controls**: Camera/microphone restrictions, USB device management
- **Application Security**: PowerShell execution policies, AppLocker implementation
- **Network Security**: Advanced firewall rules, Remote Desktop restrictions
- **Data Protection**: Privacy settings, telemetry controls, cloud service restrictions
- **Comprehensive Monitoring**: Security auditing, compliance scoring, professional reporting

### Technical Implementation

- Registry-based policy enforcement with detailed key paths
- Group Policy Object creation and linking automation
- Organizational Unit mapping for different departments
- Policy backup and restore capabilities
- Interactive menu systems for user-friendly management
- HTML report generation with professional styling

## [1.1.0] - 2025-06-09

### Added - Demo Organization & Code Cleanup

- **🏰 Asgard Technologies Demo**: Complete Norse mythology-themed enterprise demo
- **Clean Project Structure**: Organized all demo materials into dedicated `Demo/` directory
- **Comprehensive Demo Documentation**: Epic demo guide with 25 VMs, 25 users, 4 networks
- **Demo Management**: Automated deployment and management scripts for demo environment
- **Hardware Optimization**: Performance guides optimized for high-end hardware specifications

### Changed

- **Project Organization**: Moved all demo-specific files to `Demo/` directory structure
- **Main README**: Added prominent demo section with quick access to Asgard Technologies
- **File Structure**: Clean separation between core lab tools and demo materials
- **Documentation**: Enhanced main project documentation with clear demo integration

### Demo Structure

```
Demo/
├── README.md                   # Complete demo overview
├── Scripts/Deploy-AsgardLab.ps1  # Main deployment script
├── Documentation/              # Technical documentation
│   ├── DEMO_SETUP_GUIDE.md     # Complete setup guide
│   └── HARDWARE_PERFORMANCE_GUIDE.md  # Hardware optimization
└── Guides/                     # Quick-start guides
    └── QUICK_START_ASGARD.md   # 3-step deployment guide
```

### Demo Features

- **25 Virtual Machines**: 5 servers + 20 workstations with Norse mythology names
- **Complete Organization**: Asgard Technologies cybersecurity company with 5 departments
- **Network Architecture**: 4-tier networking (Production, Management, Clients, DMZ)
- **Professional Deployment**: 30-60 minute automated setup on high-end hardware
- **Educational Value**: Comprehensive Windows Server feature demonstration

## [1.0.0] - 2025-06-09

### Added

- Initial release of Windows Server Lab Environment
- 16 comprehensive tutorial guides covering Windows Server lab setup
- 10 PowerShell automation scripts for lab management
- Complete Proxmox VE lab setup documentation
- Security hardening and audit scripts
- Active Directory management automation
- Group Policy management tools
- System monitoring and maintenance scripts
- Comprehensive documentation and learning path
- MIT License
- Contributing guidelines
- Enhanced error handling and logging
- PowerShell module structure with proper manifest and wrapper functions
- Comprehensive validation script for environment testing

### Features

- **Lab Setup Tutorials**: Step-by-step guides from basic setup to advanced topics
- **Automation Scripts**: PowerShell scripts for common lab tasks
- **Proxmox Integration**: Complete Proxmox VE lab environment setup
- **Security Tools**: Security audit and hardening scripts
- **Documentation**: Comprehensive guides with clear instructions

### Documentation

- Complete learning path from beginner to advanced
- Best practices and common mistakes guide
- Troubleshooting and maintenance procedures
- Security hardening guidelines
- Naming conventions and standards

### Scripts

- Proxmox VE Lab Setup and Management
- Active Directory user and group management
- Group Policy automation
- Security audit and compliance
- Backup and restore management
- System health monitoring
- DHCP server configuration

## [Unreleased]

### Added

- **🔄 Comprehensive Uninstall and Revert System**: Complete lab environment cleanup and restoration
- **Lab-Uninstall.ps1**: Safe component removal with automatic backup creation

- **Selective Component Removal**: Remove individual components (VMs, Switches, Shares, AD, GPOs, Registry, Scheduled Tasks)
**Note**: PowerShell automation module removed during Proxmox VE adaptation
- **Safety Features**: Automatic backups, confirmation prompts, detailed logging, operation manifests
- **Demo Environment Support**: Cleanup for Asgard and Olympus demo environments
- **Tutorial 17**: "Uninstall and Revert Changes" comprehensive documentation
- **Backup Validation**: Integrity checks and manifest tracking for restore operations

### Enhanced

**Note**: PowerShell module removed during Proxmox VE adaptation

- **Module Manifest**: Updated to include new scripts and exported functions
- **README Documentation**: Added uninstall/revert quick start instructions
- **Security**: Comprehensive audit trail and recovery planning guidance

### Added (Previous)

- **🎯 GitHub Templates & Community Standards**: Complete professional template suite
- **Issue Templates**: Structured forms for bug reports, feature requests, and questions
- **Pull Request Template**: Comprehensive checklist with testing and documentation requirements
- **Code of Conduct**: Community standards with educational focus and Norse mythology theme
- **Security Policy**: Vulnerability reporting and security best practices for lab environments
- **Support Documentation**: Multi-tier support with self-help resources and community channels
- **Funding Configuration**: Sponsorship and funding setup for project sustainability
- **Enhanced CI/CD Documentation**: Updated workflows documentation with template information

### Planned

- Automated testing framework
- Additional lab scenarios (DNS, Exchange, SQL Server)
- PowerShell Gallery publication
- Advanced security hardening templates
- Multi-site lab configurations
