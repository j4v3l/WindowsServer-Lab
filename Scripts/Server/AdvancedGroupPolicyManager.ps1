[CmdletBinding()]
param()
Write-Warning 'AdvancedGroupPolicyManager.ps1 v1 is retired because administrative-template labels were logged without being applied.'
Write-Output 'Use .\Scripts\Set-LabDomainPolicy.ps1 -Demo <asgard|olympus> -ConfigureLaps.'
exit 2
