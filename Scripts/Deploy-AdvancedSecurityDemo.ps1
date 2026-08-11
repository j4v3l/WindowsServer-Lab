[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('Asgard', 'Olympus')][string]$DemoType,
    [string]$Action = 'Interactive',
    [string]$OutputPath,
    [switch]$Force
)
$demo = $DemoType.ToLowerInvariant()
Write-Warning 'Deploy-AdvancedSecurityDemo.ps1 v1 is deprecated.'
Write-Output "Use .\Scripts\Set-LabDomainPolicy.ps1 -Demo $demo -ConfigureLaps"
Write-Output 'Then apply the role-aware baseline with .\Scripts\Set-LabSecurityBaseline.ps1.'
exit 2
