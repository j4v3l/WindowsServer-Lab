[CmdletBinding()]
param(
    [string]$DomainName,
    [switch]$Force,
    [switch]$DryRun
)
Write-Warning 'Lab-Uninstall.ps1 v1 was retired to prevent broad recursive AD and filesystem deletion.'
Write-Output 'Review the plan on the Proxmox host:'
Write-Output './Tools/Proxmox/Remove-Lab.sh --demo <asgard|olympus> --profile <smoke|core|full> --site ./LabConfig/site.json'
Write-Output 'Application requires both --apply and --confirm <demo-profile>, and backs up first by default.'
exit 2
