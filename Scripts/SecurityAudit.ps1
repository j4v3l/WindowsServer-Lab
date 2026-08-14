[CmdletBinding()]
param(
    [ValidateSet('infrastructure', 'domain', 'services', 'security', 'full')][string]$Phase = 'security',
    [ValidateSet('primary-dc', 'secondary-dc', 'file-server', 'web-server', 'management-server', 'member-server', 'client')][string]$Role = 'management-server'
)
Write-Warning 'SecurityAudit.ps1 v1 is deprecated.'
& (Join-Path $PSScriptRoot 'Test-LabCompliance.ps1') -Phase $Phase -Role $Role
exit $LASTEXITCODE
