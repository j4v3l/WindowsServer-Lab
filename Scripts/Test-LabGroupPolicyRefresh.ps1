#Requires -Version 5.1
<#
.SYNOPSIS
    Verifies effective background Group Policy refresh settings on an endpoint.
#>
[CmdletBinding()]
param(
    [ValidateSet('Computer', 'User', 'Both')][string]$Scope = 'Both',
    [ValidateRange(15, 1440)][int]$ComputerIntervalMinutes = 30,
    [ValidateRange(0, 60)][int]$ComputerRandomOffsetMinutes = 10,
    [ValidateRange(15, 1440)][int]$UserIntervalMinutes = 30,
    [ValidateRange(0, 60)][int]$UserRandomOffsetMinutes = 10,
    [string]$OutputPath = 'C:\ProgramData\WindowsServerLab\Reports\group-policy-refresh-effective.json'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$checks = @()

function Add-LabRegistryEvidence {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][int]$ExpectedValue,
        [Parameter(Mandatory)][string]$Control
    )

    $actualValue = $null
    if (Test-Path -LiteralPath $Path) {
        $properties = Get-ItemProperty -LiteralPath $Path -ErrorAction Stop
        if ($properties.PSObject.Properties.Name -contains $Name) { $actualValue = $properties.$Name }
    }
    [pscustomobject]@{
        control = $Control
        evidence = "$Path\$Name=$actualValue"
        expected = $ExpectedValue
        actual = $actualValue
        passed = $null -ne $actualValue -and $actualValue -eq $ExpectedValue
    }
}

if ($Scope -in @('Computer', 'Both')) {
    $checks += Add-LabRegistryEvidence -Path 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\System' -Name GroupPolicyRefreshTime -ExpectedValue $ComputerIntervalMinutes -Control 'ComputerRefreshInterval'
    $checks += Add-LabRegistryEvidence -Path 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\System' -Name GroupPolicyRefreshTimeOffset -ExpectedValue $ComputerRandomOffsetMinutes -Control 'ComputerRefreshOffset'
    $checks += Add-LabRegistryEvidence -Path 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name DisableBkGndGroupPolicy -ExpectedValue 0 -Control 'BackgroundRefreshEnabled'
    $checks += Add-LabRegistryEvidence -Path 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows NT\CurrentVersion\Winlogon' -Name SyncForegroundPolicy -ExpectedValue 1 -Control 'SynchronousForegroundPolicy'
    $service = Get-Service gpsvc -ErrorAction Stop
    $checks += [pscustomobject]@{ control = 'GroupPolicyClientService'; evidence = [string]$service.Status; expected = 'Running'; actual = [string]$service.Status; passed = $service.Status -eq 'Running' }
    & gpresult.exe /scope computer /r | Out-Null
    $gpResultExitCode = $LASTEXITCODE
    $checks += [pscustomobject]@{ control = 'ComputerResultantSet'; evidence = "gpresult exit code $gpResultExitCode"; expected = 0; actual = $gpResultExitCode; passed = $gpResultExitCode -eq 0 }
}

if ($Scope -in @('User', 'Both')) {
    $checks += Add-LabRegistryEvidence -Path 'Registry::HKEY_CURRENT_USER\SOFTWARE\Policies\Microsoft\Windows\System' -Name GroupPolicyRefreshTime -ExpectedValue $UserIntervalMinutes -Control 'UserRefreshInterval'
    $checks += Add-LabRegistryEvidence -Path 'Registry::HKEY_CURRENT_USER\SOFTWARE\Policies\Microsoft\Windows\System' -Name GroupPolicyRefreshTimeOffset -ExpectedValue $UserRandomOffsetMinutes -Control 'UserRefreshOffset'
    & gpresult.exe /scope user /r | Out-Null
    $gpResultExitCode = $LASTEXITCODE
    $checks += [pscustomobject]@{ control = 'UserResultantSet'; evidence = "gpresult exit code $gpResultExitCode"; expected = 0; actual = $gpResultExitCode; passed = $gpResultExitCode -eq 0 }
}

$failed = @($checks | Where-Object { -not $_.passed })
$result = [ordered]@{
    schemaVersion = 1
    timestamp = (Get-Date).ToUniversalTime().ToString('o')
    computer = $env:COMPUTERNAME
    user = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    scope = $Scope
    passed = $failed.Count -eq 0
    checks = $checks
    remediation = if ($failed.Count -eq 0) { $null } else { 'Run gpupdate /force, restart or sign out as required, then inspect gpresult /h and the GroupPolicy operational event log.' }
}
$reportDirectory = Split-Path -Parent $OutputPath
if ($reportDirectory -and -not (Test-Path -LiteralPath $reportDirectory)) { New-Item -Path $reportDirectory -ItemType Directory -Force | Out-Null }
$result | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
$result
if ($failed.Count -gt 0) { exit 1 }
