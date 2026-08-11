[CmdletBinding()]
param([switch]$Detailed, [switch]$FixIssues, [switch]$AIMLValidation)
Write-Warning 'Test-OlympusNetwork.ps1 is deprecated; simulated bridge and AI/ML checks were removed.'
Write-Output 'Run on the Proxmox host: ./Tools/Proxmox/Test-Lab.sh --demo olympus --profile smoke --site ./LabConfig/site.json --phase infrastructure'
if ($FixIssues) { Write-Warning 'The v2 validator is read-only and never changes host networking.' }
exit 2
