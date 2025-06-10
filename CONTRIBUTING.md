# Contributing to Windows Server Lab Environment

Thank you for your interest in contributing to this project! This guide will help you get started with contributing to the Windows Server Lab Environment repository.

## 🎯 Project Overview

This repository provides comprehensive documentation and scripts for setting up and managing Windows Server lab environments. It's designed for educational purposes and development testing.

## 🚀 Getting Started

### Prerequisites

- PowerShell 5.1 or later
- Windows 10/11 Pro/Enterprise or Windows Server
- Hyper-V enabled (for virtualization labs)
- Git for version control

### Local Development Setup

1. **Fork and Clone**

   ```powershell
   git clone https://github.com/yourusername/WindowsServer.git
   cd WindowsServer
   ```

2. **Create a Development Branch**

   ```powershell
   git checkout -b feature/your-feature-name
   ```

## 🛠️ Development Guidelines

### Code Style and Standards

#### PowerShell Scripts

- Use approved PowerShell verbs (`Get-Verb` for reference)
- Follow PowerShell naming conventions (PascalCase for functions, camelCase for variables)
- Include comprehensive error handling with try-catch blocks
- Use `Write-Log` function for consistent logging
- Add parameter validation where appropriate
- Include help documentation for functions

Example:

```powershell
function New-LabVirtualMachine {
    <#
    .SYNOPSIS
        Creates a new virtual machine for the lab environment
    .DESCRIPTION
        This function creates a new Hyper-V virtual machine with standardized settings for lab use
    .PARAMETER VMName
        Name of the virtual machine to create
    .EXAMPLE
        New-LabVirtualMachine -VMName "DC1-LAB"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$VMName
    )
    
    try {
        # Function implementation
    }
    catch {
        Write-Log "Failed to create VM: $($_.Exception.Message)" "ERROR"
        throw
    }
}
```

#### Documentation (Markdown)

- Use consistent heading structure
- Include emoji for section headers (🎯, 🚀, 🛠️, etc.)
- Provide clear step-by-step instructions
- Include code blocks with appropriate syntax highlighting
- Add troubleshooting sections where applicable

### File Structure

```
WindowsServer/
├── LabSetupTutorials/          # Step-by-step guides
├── Scripts/                    # PowerShell automation scripts
├── Tests/                      # Test files (future)
├── Examples/                   # Example configurations
├── CONTRIBUTING.md
├── LICENSE
└── README.md
```

## 📝 Types of Contributions

### 1. Documentation Improvements

- Fix typos or grammatical errors
- Add missing steps or clarifications
- Update outdated information
- Create new tutorials for additional scenarios

### 2. Script Enhancements

- Add new automation scripts
- Improve error handling
- Add new features to existing scripts
- Optimize performance

### 3. Bug Fixes

- Fix issues in existing scripts
- Correct documentation errors
- Resolve compatibility problems

### 4. New Features

- Add support for new Windows Server versions
- Create additional lab scenarios
- Develop new management tools

## 🔄 Pull Request Process

### Before Submitting

1. **Test Your Changes**
   - Test scripts in a lab environment
   - Verify documentation steps work as described
   - Check for breaking changes

2. **Code Quality**
   - Run PowerShell Script Analyzer (if available)
   - Ensure consistent formatting
   - Add logging where appropriate

3. **Documentation**
   - Update relevant documentation
   - Add comments to complex code
   - Update README if needed

### Submitting a Pull Request

1. **Create Descriptive Title**

   ```
   Add: New DHCP setup automation script
   Fix: Correct network configuration in Hyper-V setup
   Update: Add Windows Server 2022 compatibility notes
   ```

2. **Fill Out PR Description**

   ```markdown
   ## Description
   Brief description of changes made
   
   ## Type of Change
   - [ ] Bug fix
   - [ ] New feature
   - [ ] Documentation update
   - [ ] Breaking change
   
   ## Testing
   - [ ] Tested in lab environment
   - [ ] Verified on Windows Server 2019
   - [ ] Verified on Windows Server 2022
   
   ## Checklist
   - [ ] Code follows project style guidelines
   - [ ] Added appropriate logging
   - [ ] Updated documentation
   - [ ] Tested thoroughly
   ```

3. **Link Related Issues**
   Reference any related issues using `Fixes #123` or `Related to #456`

## 🧪 Testing Guidelines

### Manual Testing

- Test all scripts in a clean lab environment
- Verify tutorials work from start to finish
- Test on different Windows versions where applicable

### Documentation Testing

- Follow tutorial steps exactly as written
- Note any missing steps or unclear instructions
- Verify all commands and paths are correct

## 🐛 Reporting Issues

### Bug Reports

Include the following information:

- Operating system and version
- PowerShell version
- Complete error message
- Steps to reproduce
- Expected vs actual behavior

### Feature Requests

- Clear description of the feature
- Use case or business justification
- Potential implementation approach (if known)

## 📋 Code Review Process

### What We Look For

- Code functionality and correctness
- Error handling and logging
- Code readability and documentation
- Security considerations
- Performance implications

### Review Timeline

- Initial review within 7 days
- Follow-up reviews within 3 days
- Approval after all requirements met

## 🏷️ Commit Message Guidelines

Use conventional commit format:

```
type(scope): brief description

Longer description if needed

Fixes #123
```

Types:

- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation changes
- `style:` Code style changes
- `refactor:` Code refactoring
- `test:` Adding tests
- `chore:` Maintenance tasks

Examples:

```
feat(scripts): add DHCP server automation script
fix(hyper-v): resolve network adapter configuration issue
docs(tutorials): update AD setup guide for Server 2022
```

## 🤝 Community Guidelines

### Be Respectful

- Use welcoming and inclusive language
- Respect different viewpoints and experiences
- Accept constructive criticism gracefully

### Be Collaborative

- Help others learn and grow
- Share knowledge and best practices
- Provide constructive feedback

### Be Patient

- Remember this is an educational project
- Help newcomers understand concepts
- Take time to explain complex topics

## 📞 Getting Help

- **GitHub Issues**: For bugs and feature requests
- **Discussions**: For questions and general help
- **Documentation**: Check existing tutorials first

## 🎉 Recognition

Contributors will be acknowledged in:

- README.md contributors section
- Release notes for significant contributions
- Special recognition for major features

Thank you for contributing to the Windows Server Lab Environment project! Your contributions help make Windows Server education more accessible to everyone.
