#Requires -RunAsAdministrator
#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)][ValidateSet('asgard', 'olympus')][string]$Demo,
    [Alias('Profile')][ValidateSet('smoke', 'core', 'full')][string]$LabProfile = 'smoke',
    [switch]$LegacyDomain,
    [switch]$CreatePrivilegedAccounts,
    [switch]$Restart
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = 'C:\ProgramData\WindowsServerLab'
$definition = Get-Content -LiteralPath "$root\LabConfig\demos\$Demo.json" -Raw | ConvertFrom-Json
$primary = $definition.virtualMachines | Where-Object role -eq 'primary-dc'
$domainName = if ($LegacyDomain) { $definition.domain.legacyDnsName } else { $definition.domain.dnsName }
$dsrm = if (-not (Get-Service NTDS -ErrorAction Ignore)) { Read-Host 'Enter the DSRM recovery password' -AsSecureString } else { $null }
$userPassword = Read-Host 'Enter the initial demo-user password; users must change it at first logon' -AsSecureString

& "$root\Scripts\Invoke-LabBootstrap.ps1" -Demo $Demo -LabProfile $LabProfile -VmId $primary.id -Role primary-dc -DomainName $domainName -DsrmPassword $dsrm -DefaultUserPassword $userPassword -CreatePrivilegedAccounts:$CreatePrivilegedAccounts -Restart:$Restart -WhatIf:$WhatIfPreference
