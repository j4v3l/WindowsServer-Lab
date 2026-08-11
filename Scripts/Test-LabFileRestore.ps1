#Requires -RunAsAdministrator
#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)][ValidatePattern('^\\\\')][string]$BackupTarget,
    [Parameter(Mandatory)][ValidatePattern('^\d{2}/\d{2}/\d{4}-\d{2}:\d{2}$')][string]$Version,
    [Parameter(Mandatory)][ValidatePattern('^[A-Za-z]:\\')][string]$Item,
    [Parameter(Mandatory)][ValidatePattern('^[A-Za-z]:\\')][string]$AlternatePath,
    [string]$ReportPath = "C:\ProgramData\WindowsServerLab\Reports\restore-$env:COMPUTERNAME.json"
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ((Resolve-Path -LiteralPath $AlternatePath -ErrorAction Ignore) -and (Resolve-Path -LiteralPath $Item -ErrorAction Ignore) -eq (Resolve-Path -LiteralPath $AlternatePath -ErrorAction Ignore)) {
    throw 'Recovery must use an alternate path; overwriting the source is forbidden for a drill.'
}
if (-not $PSCmdlet.ShouldProcess($AlternatePath, "Restore $Item from $BackupTarget version $Version")) { return }
if (-not (Test-Path -LiteralPath $AlternatePath)) { New-Item -Path $AlternatePath -ItemType Directory -Force | Out-Null }

$started = Get-Date
& wbadmin.exe start recovery -version:$Version -backupTarget:$BackupTarget -itemType:File -items:$Item -recoveryTarget:$AlternatePath -recursive -quiet
if ($LASTEXITCODE -ne 0) { throw "wbadmin recovery failed with exit code $LASTEXITCODE." }
$restored = @(Get-ChildItem -LiteralPath $AlternatePath -File -Recurse -ErrorAction Stop)
if ($restored.Count -eq 0) { throw 'The recovery command completed but no restored files were found.' }
$report = [ordered]@{ schemaVersion = 2; computerName = $env:COMPUTERNAME; backupTarget = $BackupTarget; version = $Version; sourceItem = $Item; alternatePath = $AlternatePath; restoredFileCount = $restored.Count; started = $started.ToUniversalTime().ToString('o'); completed = (Get-Date).ToUniversalTime().ToString('o'); passed = $true }
$directory = Split-Path -Parent $ReportPath
if (-not (Test-Path -LiteralPath $directory)) { New-Item -Path $directory -ItemType Directory -Force | Out-Null }
$report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
$report | ConvertTo-Json -Depth 6
