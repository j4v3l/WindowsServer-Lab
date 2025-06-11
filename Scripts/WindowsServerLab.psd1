#
# Module manifest for module 'WindowsServerLab'
#

@{

    # Script module or binary module file associated with this manifest.
    RootModule        = 'WindowsServerLab.psm1'

    # Version number of this module.
    ModuleVersion     = '1.2.0'

    # Supported PSEditions
    # CompatiblePSEditions = @()

    # ID used to uniquely identify this module
    GUID              = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'

    # Author of this module
    Author            = 'Windows Server Lab Environment'

    # Company or vendor of this module
    CompanyName       = 'Windows Server Lab Environment'

    # Copyright statement for this module
    Copyright         = '(c) 2025 Windows Server Lab Environment. All rights reserved.'

    # Description of the functionality provided by this module
    Description       = 'PowerShell module for Windows Server lab environment management, including Hyper-V setup, Active Directory management, advanced security features, and comprehensive auditing tools.'

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Name of the Windows PowerShell host required by this module
    # PowerShellHostName = ''

    # Minimum version of the Windows PowerShell host required by this module
    # PowerShellHostVersion = ''

    # Minimum version of Microsoft .NET Framework required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
    # DotNetFrameworkVersion = ''

    # Minimum version of the common language runtime (CLR) required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
    # CLRVersion = ''

    # Processor architecture (None, X86, Amd64) required by this module
    # ProcessorArchitecture = ''

    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules   = @('Hyper-V')

    # Assemblies that must be loaded prior to importing this module
    # RequiredAssemblies = @()

    # Script files (.ps1) that are run in the caller's environment prior to importing this module.
    # ScriptsToProcess = @()

    # Type files (.ps1xml) to be loaded when importing this module
    # TypesToProcess = @()

    # Format files (.ps1xml) to be loaded when importing this module
    # FormatsToProcess = @()

    # Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
    # NestedModules = @()

    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    FunctionsToExport = @(
        'New-LabEnvironment',
        'Test-LabEnvironment', 
        'Start-LabVMs',
        'Stop-LabVMs',
        'Get-LabStatus',
        'Set-LabConfiguration',
        'Get-LabConfiguration',
        'Invoke-LabSecurityAudit',
        'New-LabUsers',
        'Set-LabGroupPolicy',
        'Remove-LabEnvironment',
        'Restore-LabEnvironment'
    )

    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
    CmdletsToExport   = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
    AliasesToExport   = @()

    # DSC resources to export from this module
    # DscResourcesToExport = @()

    # List of all modules packaged with this module
    # ModuleList = @()

    # List of all files packaged with this module
    FileList          = @(
        'WindowsServerLab.psm1',
        'AdvancedGroupPolicyManager.ps1',
        'AdvancedSecurityAudit.ps1',
        'BackupRestoreManager.ps1',
        'Create-LabUsers.ps1',
        'DHCP_Setup.ps1',
        'GroupPolicyManager.ps1',
        'Hyper-V_Lab_Setup.ps1',
        'Hyper-V_Management.ps1',
        'Lab_Setup.ps1',
        'Lab-FinishSetup.ps1',
        'Lab-Restore.ps1',
        'Lab-Uninstall.ps1',
        'SecurityAudit.ps1',
        'SystemHealthMonitor.ps1',
        'Test-LabEnvironment.ps1',
        'Test-ModuleIntegrity.ps1'
    )

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData       = @{

        PSData = @{

            # Tags applied to this module. These help with module discovery in online galleries.
            Tags                       = @('Windows', 'Server', 'Lab', 'Hyper-V', 'ActiveDirectory', 'Education', 'Testing', 'Security', 'GPO', 'Audit')

            # A URL to the license for this module.
            LicenseUri                 = 'https://github.com/j4v3l/WindowsServer-Lab/blob/main/LICENSE'

            # A URL to the main website for this project.
            ProjectUri                 = 'https://github.com/j4v3l/WindowsServer-Lab'

            # A URL to an icon representing this module.
            # IconUri = ''

            # ReleaseNotes of this module
            ReleaseNotes               = @'
# Windows Server Lab Environment v1.2.0

## Major Features
- Complete Hyper-V lab setup and management
- Active Directory automation and management
- **NEW**: Advanced Security Suite with 100+ policies across 8 categories
- **NEW**: Comprehensive security auditing with scoring and HTML reports
- Group Policy management automation
- System monitoring and health checks
- Comprehensive validation and testing tools
- Demo environments: Asgard Technologies and Olympus Systems
- Complete uninstall and revert functionality

## Advanced Security Features (NEW in v1.2.0)
- Camera & Microphone Security: Application access controls, privacy protection
- USB & Removable Storage Control: Granular device restrictions, installation prevention
- Device Control: Bluetooth, WiFi, printer, CD/DVD, external display management
- Personalization Policies: Desktop, Start menu, taskbar, Windows Store controls
- Application Control: PowerShell policies, AppLocker, software installation restrictions
- Network Security: Advanced firewall, Remote Desktop, SMB signing configurations
- Data Protection: Telemetry, OneDrive, Cortana, privacy settings
- Security Auditing: Comprehensive scoring (0-100%) with improvement recommendations

## Demo Environments
- **Asgard Technologies**: Norse mythology-themed enterprise (25 VMs)
- **Olympus Systems**: Greek mythology-themed with cloud integration (25 VMs)
- Interactive security demos with hands-on testing scenarios
- Professional HTML reporting and analytics
- Environment-specific policy deployment

## Advanced Scripts
- AdvancedGroupPolicyManager.ps1: 100+ security policies with interactive deployment
- AdvancedSecurityAudit.ps1: Comprehensive security assessment and reporting
- Enhanced demo deployment scripts with security integration

## Uninstall and Revert
- Safe component removal with automatic backup creation
- Selective uninstall (VMs, Switches, Shares, AD, GPOs, Registry, Scheduled Tasks)
- Complete backup and restore system with integrity validation
- PowerShell module integration (Remove-LabEnvironment, Restore-LabEnvironment)
- Detailed logging and operation tracking
- Support for demo environment cleanup

## Requirements
- Windows 10/11 Pro/Enterprise or Windows Server
- PowerShell 5.1 or later
- Hyper-V enabled
- Administrator privileges
- Group Policy Management Tools (for advanced security features)

## Getting Started
1. Import the module: Import-Module WindowsServerLab
2. Create lab environment: New-LabEnvironment
3. Deploy advanced security: .\Scripts\AdvancedGroupPolicyManager.ps1
4. Run security audit: .\Scripts\AdvancedSecurityAudit.ps1
5. Validate setup: Test-LabEnvironment
6. Start lab VMs: Start-LabVMs
7. Remove when needed: Remove-LabEnvironment
8. Restore if needed: Restore-LabEnvironment
'@

            # Prerelease string of this module
            # Prerelease = ''

            # Flag to indicate whether the module requires explicit user acceptance for install/update/save
            # RequireLicenseAcceptance = $false

            # External dependent modules of this module
            ExternalModuleDependencies = @('Hyper-V')

        } # End of PSData hashtable

    } # End of PrivateData hashtable

    # HelpInfo URI of this module
    # HelpInfoURI = ''

    # Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
    # DefaultCommandPrefix = ''

} 