#Requires -RunAsAdministrator
#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [string]$ReportPath = "C:\ProgramData\WindowsServerLab\Reports\patch-$env:COMPUTERNAME.json",
    [switch]$IncludeDrivers,
    [switch]$Restart
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$session = New-Object -ComObject Microsoft.Update.Session
$searcher = $session.CreateUpdateSearcher()
$criteria = if ($IncludeDrivers) { 'IsInstalled=0 and IsHidden=0' } else { "IsInstalled=0 and IsHidden=0 and Type='Software'" }
$search = $searcher.Search($criteria)
$updates = @($search.Updates | ForEach-Object {
    [pscustomobject]@{ title = $_.Title; kb = @($_.KBArticleIDs); downloaded = [bool]$_.IsDownloaded; mandatory = [bool]$_.IsMandatory }
})
$report = [ordered]@{ schemaVersion = 2; computerName = $env:COMPUTERNAME; timestamp = (Get-Date).ToUniversalTime().ToString('o'); mode = 'plan'; updateCount = $updates.Count; updates = $updates; resultCode = $null; rebootRequired = $false }

if ($updates.Count -gt 0 -and $PSCmdlet.ShouldProcess($env:COMPUTERNAME, "Download and install $($updates.Count) approved Windows updates")) {
    $collection = New-Object -ComObject Microsoft.Update.UpdateColl
    foreach ($update in $search.Updates) {
        if (-not $update.EulaAccepted) { $update.AcceptEula() }
        [void]$collection.Add($update)
    }
    $downloader = $session.CreateUpdateDownloader()
    $downloader.Updates = $collection
    $downloadResult = $downloader.Download()
    if ($downloadResult.ResultCode -notin @(2, 3)) { throw "Windows Update download failed with result code $($downloadResult.ResultCode)." }
    $installer = $session.CreateUpdateInstaller()
    $installer.Updates = $collection
    $installResult = $installer.Install()
    $report.mode = 'apply'
    $report.resultCode = [int]$installResult.ResultCode
    $report.rebootRequired = [bool]$installResult.RebootRequired
    if ($installResult.ResultCode -notin @(2, 3)) { throw "Windows Update installation failed with result code $($installResult.ResultCode)." }
}

$directory = Split-Path -Parent $ReportPath
if (-not (Test-Path -LiteralPath $directory)) { New-Item -Path $directory -ItemType Directory -Force | Out-Null }
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
$report | ConvertTo-Json -Depth 8
if ($Restart -and $report.rebootRequired) { Restart-Computer -Force }
elseif ($report.rebootRequired) { exit 3010 }
