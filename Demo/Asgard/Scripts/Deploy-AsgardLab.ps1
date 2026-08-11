<#
.SYNOPSIS
    Compatibility entry point for WindowsServerLab v1 Asgard deployment.
.DESCRIPTION
    Proxmox lifecycle operations now run on the Linux Proxmox host. This shim is
    intentionally non-mutating and prints the exact v2 replacement command.
#>
[CmdletBinding()]
param(
    [string]$VMPath,
    [string]$ServerISOPath,
    [string]$ClientISOPath,
    [string]$ISOPath,
    [string]$DomainName = 'asgard.local',
    [switch]$SkipVMs,
    [switch]$NetworkOnly
)

Write-Warning 'Deploy-AsgardLab.ps1 is deprecated and no longer performs partial deployment.'
Write-Output 'Run on the Proxmox host:'
Write-Output './Tools/Proxmox/Deploy-Lab.sh --demo asgard --profile smoke --site ./LabConfig/site.json'
Write-Output 'Add --legacy-domain to retain asgard.local, and add --apply only after reviewing the plan.'
exit 2
