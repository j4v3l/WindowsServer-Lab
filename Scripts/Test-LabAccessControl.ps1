#Requires -Version 5.1
<#
.SYNOPSIS
    Verifies an access-control policy in the effective registry of a workstation.
.DESCRIPTION
    Run this script locally on the affected workstation. User-scoped controls must be
    tested in the affected user's session. The command returns JSON and exits nonzero
    when the requested effective state is not present.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Control,
    [Parameter(Mandatory)][ValidateSet('Allow', 'Deny')][string]$ExpectedAccess,
    [string]$CatalogPath = 'C:\ProgramData\WindowsServerLab\LabConfig\policies\access-controls.json',
    [ValidatePattern('^\\\\[^\\]+\\[^\\]+')][string]$WallpaperPath,
    [string]$OutputPath = 'C:\ProgramData\WindowsServerLab\Reports\access-control-effective.json'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (-not (Test-Path -LiteralPath $CatalogPath -PathType Leaf)) { throw "Access-control catalog not found: $CatalogPath" }
$catalog = Get-Content -LiteralPath $CatalogPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
$controlMatches = @($catalog.controls | Where-Object id -ieq $Control)
if ($controlMatches.Count -ne 1) { throw "Unknown or duplicate access control '$Control'." }
$selected = $controlMatches[0]

$evidence = @()
foreach ($setting in $selected.settings) {
    if ($setting.PSObject.Properties.Name -contains 'requiresWallpaperPath' -and $setting.requiresWallpaperPath -and -not $WallpaperPath) { continue }
    $expectedValue = if ($setting.PSObject.Properties.Name -contains 'requiresWallpaperPath' -and $setting.requiresWallpaperPath) {
        ([string]$setting.value).Replace('{WALLPAPER_PATH}', $WallpaperPath)
    }
    else { $setting.value }
    $registryPath = $setting.key -replace '^HKLM\\', 'Registry::HKEY_LOCAL_MACHINE\' -replace '^HKCU\\', 'Registry::HKEY_CURRENT_USER\'
    $present = Test-Path -LiteralPath $registryPath
    $actualValue = $null
    if ($present) {
        $properties = Get-ItemProperty -LiteralPath $registryPath -ErrorAction Stop
        if ($properties.PSObject.Properties.Name -contains $setting.name) { $actualValue = $properties.($setting.name) }
    }
    $isDenyValue = $null -ne $actualValue -and $actualValue -eq $expectedValue
    $passed = if ($ExpectedAccess -eq 'Deny') { $isDenyValue } else { -not $isDenyValue }
    $evidence += [ordered]@{
        key = $setting.key
        name = $setting.name
        expectedDenyValue = $expectedValue
        actualValue = $actualValue
        passed = $passed
    }
}
if ($evidence.Count -eq 0) { throw "No testable settings were found for control '$Control'. Supply -WallpaperPath when testing an enforced wallpaper path." }

$passed = @($evidence | Where-Object { -not $_.passed }).Count -eq 0
$result = [ordered]@{
    schemaVersion = 1
    timestamp = (Get-Date).ToUniversalTime().ToString('o')
    computer = $env:COMPUTERNAME
    user = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    control = $selected.id
    scope = $selected.scope
    expectedAccess = $ExpectedAccess
    passed = $passed
    evidence = $evidence
    remediation = if ($passed) { $null } else { "Run gpupdate /force, complete the required $($selected.refresh), and inspect gpresult /h. Another higher-precedence GPO may also control this setting." }
}

$reportDirectory = Split-Path -Parent $OutputPath
if ($reportDirectory -and -not (Test-Path -LiteralPath $reportDirectory)) { New-Item -Path $reportDirectory -ItemType Directory -Force | Out-Null }
$result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
$result
if (-not $passed) { exit 1 }
