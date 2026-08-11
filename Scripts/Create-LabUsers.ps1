#Requires -RunAsAdministrator
#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)][ValidateSet('asgard', 'olympus')][string]$Demo,
    [ValidateSet('smoke', 'core', 'full')][string]$Profile = 'smoke',
    [Security.SecureString]$DefaultUserPassword,
    [switch]$CreatePrivilegedAccounts
)

$ErrorActionPreference = 'Stop'
if (-not $DefaultUserPassword) { $DefaultUserPassword = Read-Host 'Enter the initial user password' -AsSecureString }
$modulePath = Join-Path $PSScriptRoot 'WindowsServerLab\WindowsServerLab.psd1'
$definitionPath = Join-Path $PSScriptRoot "..\LabConfig\demos\$Demo.json"
Import-Module $modulePath -Force
$definition = Import-LabDefinition -Path $definitionPath
Test-LabConfiguration -Definition $definition -Profile $Profile -ThrowOnFailure | Out-Null
Initialize-LabDirectory -Definition $definition -DefaultUserPassword $DefaultUserPassword -CreatePrivilegedAccounts:$CreatePrivilegedAccounts -WhatIf:$WhatIfPreference -Confirm:$false
