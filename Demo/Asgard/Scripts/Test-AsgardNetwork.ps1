[CmdletBinding()]
param([switch]$Detailed, [switch]$FixIssues)
Write-Warning 'Test-AsgardNetwork.ps1 is deprecated; simulated bridge checks were removed.'
Write-Output 'Run on the Proxmox host: ./Tools/Proxmox/Test-Lab.sh --demo asgard --profile smoke --site ./LabConfig/site.json --phase infrastructure'
if ($FixIssues) { Write-Warning 'The v2 validator is read-only and never changes host networking.' }
exit 2
