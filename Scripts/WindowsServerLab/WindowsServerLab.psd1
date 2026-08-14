@{
    RootModule        = 'WindowsServerLab.psm1'
    ModuleVersion     = '3.0.0'
    GUID              = 'f28dca4f-3de4-4daf-b8f7-69f63f80cf7b'
    Author            = 'Windows Server Lab Project'
    CompanyName       = 'Windows Server Lab Project'
    Copyright         = '(c) Windows Server Lab Project. MIT licensed.'
    Description       = 'Single-inventory configuration and validation for the Terraform-managed Windows Server Lab.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @(
        'ConvertTo-LabDistinguishedName',
        'Get-LabVirtualMachine',
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
