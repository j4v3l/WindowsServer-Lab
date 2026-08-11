@{
    RootModule        = 'WindowsServerLab.psm1'
    ModuleVersion     = '2.0.0'
    GUID              = 'f28dca4f-3de4-4daf-b8f7-69f63f80cf7b'
    Author            = 'Windows Server Lab Project'
    CompanyName       = 'Windows Server Lab Project'
    Copyright         = '(c) Windows Server Lab Project. MIT licensed.'
    Description       = 'Data-driven configuration and validation for Windows Server Lab v2 guests.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @(
        'ConvertTo-LabDistinguishedName',
        'Get-LabProfileVirtualMachine',
        'Import-LabDefinition',
        'Initialize-LabDirectory',
        'Install-LabRole',
        'Set-LabDhcpService',
        'Set-LabSecurityBaseline',
        'Test-LabConfiguration',
        'Test-LabGuestCompliance',
        'Write-LabLog'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags       = @('WindowsServer', 'Proxmox', 'ActiveDirectory', 'Lab')
            LicenseUri = 'https://opensource.org/license/mit'
            ProjectUri = 'https://github.com/j4v3l/WindowsServer-Lab'
        }
    }
}
