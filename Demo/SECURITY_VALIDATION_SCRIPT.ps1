#Requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('Asgard', 'Olympus', 'Auto')][string]$Environment = 'Auto',
    [ValidateSet('infrastructure', 'domain', 'services', 'security', 'full')][string]$Phase = 'security',
    [string]$OutputPath = "C:\ProgramData\WindowsServerLab\Reports\security-$env:COMPUTERNAME.json"
)

$ErrorActionPreference = 'Stop'
$installedModule = 'C:\ProgramData\WindowsServerLab\Modules\WindowsServerLab\WindowsServerLab.psd1'
$repositoryModule = Join-Path $PSScriptRoot '..\Scripts\WindowsServerLab\WindowsServerLab.psd1'
$modulePath = if (Test-Path -LiteralPath $installedModule) { $installedModule } else { $repositoryModule }
Import-Module $modulePath -Force

$role = if (Get-Service NTDS -ErrorAction Ignore) {
    if ((Get-ADDomainController -Identity $env:COMPUTERNAME).OperationMasterRoles.Count -gt 0) { 'primary-dc' } else { 'secondary-dc' }
}
elseif ((Get-Command Get-WindowsFeature -ErrorAction Ignore) -and (Get-WindowsFeature FS-FileServer -ErrorAction Ignore | Where-Object Installed)) { 'file-server' }
elseif ((Get-Command Get-WindowsFeature -ErrorAction Ignore) -and (Get-WindowsFeature Web-Server -ErrorAction Ignore | Where-Object Installed)) { 'web-server' }
elseif ((Get-CimInstance Win32_OperatingSystem).ProductType -eq 1) { 'client' }
else { 'management-server' }

$results = @(Test-LabGuestCompliance -Role $role -Phase $Phase)
$failed = @($results | Where-Object { $_.required -and -not $_.passed })
$report = [ordered]@{
    schemaVersion = 2
    environment   = $Environment
    computerName  = $env:COMPUTERNAME
    role          = $role
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
