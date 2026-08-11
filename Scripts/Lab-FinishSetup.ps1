#Requires -RunAsAdministrator
#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)][ValidateSet('asgard', 'olympus')][string]$Demo,
    [ValidateSet('smoke', 'core', 'full')][string]$Profile = 'smoke',
    [Security.SecureString]$DefaultUserPassword,
    [switch]$CreatePrivilegedAccounts
)

Write-Warning 'Lab-FinishSetup.ps1 is retained as a v2 compatibility wrapper.'
& (Join-Path $PSScriptRoot 'Create-LabUsers.ps1') -Demo $Demo -Profile $Profile -DefaultUserPassword $DefaultUserPassword -CreatePrivilegedAccounts:$CreatePrivilegedAccounts -WhatIf:$WhatIfPreference
