# Getting Support

Welcome to the Windows Server Lab Environment support guide! We're here to help you get the most out of your lab setup.

## 📚 Self-Help Resources

Before reaching out for support, please check these resources:

### 🔍 Documentation

- **[README.md](../README.md)**: Project overview and quick start guide
- **[Tutorial Guides](../LabSetupTutorials/)**: Step-by-step setup instructions
- **[Demo Environment](../Demo/)**: Complete Asgard Technologies demo setup
- **[Contributing Guidelines](../CONTRIBUTING.md)**: How to contribute to the project
- **[CI/CD Documentation](CI/CD_README.md)**: Workflow and automation information

### 🎯 Common Solutions

- **[Hardware Performance Guide](../Demo/Asgard/Documentation/HARDWARE_PERFORMANCE_GUIDE.md)**: System requirements and optimization
- **[PowerShell Module Documentation](../Scripts/)**: Module usage and functions
- **[Security Best Practices](SECURITY.md)**: Security guidelines and checklist

## 🤝 Community Support

### 💬 GitHub Discussions

For general questions, discussions, and community interaction:

- **[Issue tracker](https://github.com/j4v3l/WindowsServer-Lab/issues)** for questions, defects, examples, and feature requests

### 🐛 Issue Reporting

For bugs, feature requests, or specific problems:

- **[Bug Reports](https://github.com/j4v3l/WindowsServer-Lab/issues/new?template=bug_report.yml)**
- **[Feature Requests](https://github.com/j4v3l/WindowsServer-Lab/issues/new?template=feature_request.yml)**
- **[Questions](https://github.com/j4v3l/WindowsServer-Lab/issues/new?template=question.yml)**

## 🚀 Getting Started

### 🔧 Quick Setup Issues

If you're having trouble with initial setup:

1. **Check Prerequisites**: Ensure you meet system requirements
2. **Verify Proxmox**: Confirm Proxmox VE is running and accessible
3. **PowerShell Version**: Use PowerShell 5.1 or later
4. **Network Configuration**: Verify network adapter settings

### 💻 Common Problems

#### PowerShell Execution Policy

```powershell
# If scripts won't run
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

#### Proxmox VE Issues

- Verify Proxmox VE is properly installed and running
- Check BIOS/UEFI virtualization settings
- Ensure Windows features are enabled

#### Network Connectivity Issues

- Check virtual switch configuration
- Verify DHCP scope settings
- Confirm DNS resolution

## 📋 When Requesting Support

### 📝 Information to Include

When asking for help, please provide:

1. **Environment Details**:

   - Operating System (Windows 11, Windows Server 2022, etc.)
   - PowerShell version (`$PSVersionTable`)
   - Proxmox VE version
   - Hardware specifications

2. **Problem Description**:

   - What you were trying to do
   - What happened instead
   - Complete error messages
   - Steps to reproduce

3. **Context**:
   - Which script or tutorial you were following
   - Any modifications you made
   - Screenshots (if helpful)

### 📊 Log Collection

For troubleshooting, collect relevant logs:

```powershell
# PowerShell transcript
Start-Transcript -Path "C:\Support\PowerShell-Log.txt"
# Your commands here
Stop-Transcript

# Event logs
# Check Proxmox logs (on Proxmox host)
journalctl -u pve-daemon --since "1 hour ago" > /tmp/proxmox-events.log
```

## ⏱️ Response Times

Support response times vary based on the channel:

- **Community Discussions**: Community-driven, typically within 24-48 hours
- **Bug Reports**: Acknowledged within 2-3 business days
- **Feature Requests**: Reviewed weekly, prioritized based on impact
- **Security Issues**: See [Security Policy](SECURITY.md) for expedited handling

## 🌟 Premium Support

While this is an open-source project, we offer several support tiers:

### 🆓 Community Support (Free)

- GitHub Discussions and Issues
- Community-driven help
- Documentation and guides
- Best-effort response times

### 💼 Professional Consulting

For organizations needing dedicated support:

- Custom lab environment design
- One-on-one training sessions
- Priority issue resolution
- Custom script development

_Contact us for professional support options_

## 📞 Contact Information

### 🎯 Direct Contact

- **General Questions**: [support@windowsserver-lab.com]
- **Security Issues**: [security@windowsserver-lab.com]
- **Partnerships**: [partnerships@windowsserver-lab.com]

### 🌐 Social Media

- **GitHub**: [Windows Server Lab Environment](https://github.com/j4v3l/WindowsServer-Lab)
- **LinkedIn**: [Windows Server Lab Community]
- **YouTube**: [Windows Server Lab Tutorials]

## 🤖 Automated Support

### 🔍 Issue Templates

We provide structured issue templates to help you provide the right information:

- **Bug Report**: Structured form for reporting issues
- **Feature Request**: Template for suggesting enhancements
- **Question**: Format for asking questions

### 🏷️ Labels and Triage

Issues are automatically labeled and triaged:

- **Priority**: Critical, High, Medium, Low
- **Component**: AD, DNS, DHCP, Proxmox VE, etc.
- **Status**: Triage, In Progress, Needs Info, etc.

## 📈 Contributing Back

### 🎁 Help Others

Consider helping other community members:

- Answer questions in Discussions
- Share your lab configurations
- Contribute documentation improvements
- Report and help fix bugs

### 💝 Recognition

Active community contributors may receive:

- Recognition in project documentation
- Contributor badges
- Early access to new features
- Invitation to maintainer team

## 📚 Learning Resources

### 🎓 Educational Content

- **Microsoft Learn**: Official Windows Server training
- **PowerShell Documentation**: Comprehensive PowerShell guides
- **Proxmox Documentation**: Virtualization best practices
- **Community Blogs**: Real-world lab scenarios

### 🛠️ Tools and Utilities

- **PowerShell ISE/VS Code**: Development environments
- **Proxmox Web UI**: GUI management interface
- **Windows Admin Center**: Modern management interface
- **Sysinternals Suite**: Advanced troubleshooting tools

## 🔄 Feedback Loop

### 📊 Continuous Improvement

We regularly review support patterns to improve:

- **Documentation Updates**: Based on common questions
- **Script Improvements**: Addressing frequent issues
- **New Features**: Driven by user requests
- **Better Error Messages**: Clearer guidance when things go wrong

### 📝 Support Analytics

We track (anonymously):

- Most common issues
- Popular documentation sections
- Feature request patterns
- Community engagement metrics

---

## 🙏 Thank You

Thank you for being part of our community! Your questions, feedback, and contributions help make this project better for everyone.

**Remember**: Every expert was once a beginner. Don't hesitate to ask questions – that's how we all learn and grow together!

---

**Last Updated**: December 28, 2024
**Support Policy Version**: 1.0
