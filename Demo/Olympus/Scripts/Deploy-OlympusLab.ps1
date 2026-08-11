<#
.SYNOPSIS
    Compatibility entry point for WindowsServerLab v1 Olympus deployment.
#>
[CmdletBinding()]
param(
    [string]$VMPath,
    [string]$ServerISOPath,
    [string]$ClientISOPath,
    [string]$ISOPath,
    [string]$DomainName = 'olympus.local',
    [switch]$SkipVMs,
    [switch]$NetworkOnly
)

Write-Warning 'Deploy-OlympusLab.ps1 is deprecated and no longer performs partial deployment.'
Write-Output 'Run on the Proxmox host:'
Write-Output './Tools/Proxmox/Deploy-Lab.sh --demo olympus --profile smoke --site ./LabConfig/site.json'
Write-Output 'Add --legacy-domain to retain olympus.local, and add --apply only after reviewing the plan.'
exit 2
