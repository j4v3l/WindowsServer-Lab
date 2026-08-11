[CmdletBinding()]
param()
Write-Warning 'This v1 script is deprecated because it did not verify most claimed GPO settings.'
Write-Output 'On the domain controller run:'
Write-Output '.\Scripts\Set-LabDomainPolicy.ps1 -Demo asgard -ConfigureLaps'
Write-Output '.\Scripts\Set-LabSecurityBaseline.ps1 -ServerRole DomainController -EnableAppControlAudit'
exit 2
