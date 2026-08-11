[CmdletBinding()]
param(
    [ValidateSet('infrastructure', 'domain', 'services', 'security', 'full')][string]$Phase = 'security',
    [ValidateSet('primary-dc', 'secondary-dc', 'file-server', 'web-server', 'management-server')][string]$Role = 'management-server'
)
Write-Warning 'AdvancedSecurityAudit.ps1 v1 scoring is retired. Required controls now fail with a nonzero exit code.'
& (Join-Path $PSScriptRoot '..\Test-LabCompliance.ps1') -Phase $Phase -Role $Role
exit $LASTEXITCODE
