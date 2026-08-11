#Requires -RunAsAdministrator
#Requires -Version 5.1
<#
.SYNOPSIS
    Deprecated compatibility entry point for workstation domain enrollment.
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$DomainName,
    [ValidatePattern('^[A-Za-z0-9-]{1,15}$')][string]$ComputerName,
    [string]$OUPath,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$DomainJoinUser,
    [Parameter(Mandatory)][Security.SecureString]$DomainJoinPassword,
    [string]$DNSServer,
    [switch]$Reboot
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$domainLookup = @{
    'ad.asgard.test' = @{ Demo = 'asgard'; Legacy = $false }
    'asgard.local' = @{ Demo = 'asgard'; Legacy = $true }
    'ad.olympus.test' = @{ Demo = 'olympus'; Legacy = $false }
    'olympus.local' = @{ Demo = 'olympus'; Legacy = $true }
}
$selection = $domainLookup[$DomainName.ToLowerInvariant()]
if (-not $selection) { throw "Domain '$DomainName' is not a WindowsServerLab v2 demo domain." }
if ($OUPath) { Write-Warning 'The deprecated -OUPath value is ignored; v2 safely selects the canonical Workstations OU.' }
Write-Warning 'Client-Onboarding.ps1 is deprecated and will be removed in v3. Use Scripts/Set-LabMachineEnrollment.ps1 -Action Enroll.'

$credential = [Management.Automation.PSCredential]::new($DomainJoinUser, $DomainJoinPassword)
$parameters = @{
    Action = 'Enroll'
    Demo = $selection.Demo
    DeviceType = 'Workstation'
    DomainCredential = $credential
    Confirm = $false
}
if ($selection.Legacy) { $parameters.LegacyDomain = $true }
if ($ComputerName) { $parameters.ComputerName = $ComputerName }
if ($DNSServer) {
    $parameters.ConfigureDns = $true
    $parameters.DnsServer = @($DNSServer)
}
if ($Reboot) { $parameters.Restart = $true }

if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, 'Invoke the v2 machine-enrollment workflow')) {
    & (Join-Path (Split-Path -Parent $PSScriptRoot) 'Set-LabMachineEnrollment.ps1') @parameters
}
