#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('infrastructure', 'domain', 'services', 'security', 'full')][string]$Phase,
    [Parameter(Mandatory)][ValidateSet('primary-dc', 'secondary-dc', 'file-server', 'web-server', 'management-server', 'member-server', 'client')][string]$Role,
    [string]$OutputPath = "C:\ProgramData\WindowsServerLab\Reports\compliance-$env:COMPUTERNAME.json"
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Import-Module 'C:\ProgramData\WindowsServerLab\Modules\WindowsServerLab\WindowsServerLab.psd1' -Force
$results = @(Test-LabGuestCompliance -Role $Role -Phase $Phase)
$failed = @($results | Where-Object { $_.required -and -not $_.passed })
$report = [ordered]@{
    schemaVersion = 2
    computerName  = $env:COMPUTERNAME
    role          = $Role
    phase         = $Phase
    timestamp     = (Get-Date).ToUniversalTime().ToString('o')
    passed        = ($failed.Count -eq 0)
    results       = $results
}
$directory = Split-Path -Parent $OutputPath
if (-not (Test-Path -LiteralPath $directory)) { New-Item -Path $directory -ItemType Directory -Force | Out-Null }
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
$report | ConvertTo-Json -Depth 8
if ($failed.Count -gt 0) { exit 1 }
