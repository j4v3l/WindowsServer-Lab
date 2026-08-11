#Requires -RunAsAdministrator
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = 'C:\ProgramData\WindowsServerLab'
$sealStartedSentinel = "$root\seal.started"
$sealFailedSentinel = "$root\seal.failed"
foreach ($requiredPath in @(
    "$root\Scripts\Invoke-LabBootstrap.ps1",
    "$root\Modules\WindowsServerLab\WindowsServerLab.psd1",
    "$root\LabConfig\demos\asgard.json",
    "$root\LabConfig\demos\olympus.json",
    "$root\TemplateBuild.json",
    "$root\seal-template.ps1",
    "$root\first-boot-cleanup.ps1"
)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) { throw "Required template payload is missing: $requiredPath" }
}

$manifest = Get-Content -LiteralPath "$root\TemplateBuild.json" -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
if ($manifest.schemaVersion -ne 1 -or $manifest.os -notin @('server-2025', 'server-2022', 'windows-11')) {
    throw 'TemplateBuild.json is invalid.'
}
if (Test-Path -LiteralPath "$root\bootstrap.failed") {
    throw "Bootstrap failure sentinel remains: $(Get-Content -LiteralPath "$root\bootstrap.failed" -Raw)"
}

$qemuService = Get-Service QEMU-GA -ErrorAction Stop
Set-Service QEMU-GA -StartupType Automatic
if ($qemuService.Status -ne 'Running') { Start-Service QEMU-GA }
Set-Service cloudbase-init -StartupType Automatic

$cloudbaseConfig = 'C:\Program Files\Cloudbase Solutions\Cloudbase-Init\conf\cloudbase-init.conf'
$cloudbaseUnattend = 'C:\Program Files\Cloudbase Solutions\Cloudbase-Init\conf\Unattend.xml'
if (-not (Test-Path -LiteralPath $cloudbaseConfig -PathType Leaf) -or -not (Test-Path -LiteralPath $cloudbaseUnattend -PathType Leaf)) {
    throw 'Cloudbase-Init configuration or Sysprep answer file is missing.'
}
if ((Get-Content -LiteralPath $cloudbaseConfig -Raw) -notmatch 'ConfigDriveService') {
    throw 'Cloudbase-Init is not pinned to the ConfigDrive metadata service.'
}

[ordered]@{
    schemaVersion = 1
    status = 'ready-to-seal'
    timestamp = (Get-Date).ToUniversalTime().ToString('o')
} | ConvertTo-Json | Set-Content -LiteralPath "$root\finalize.ready" -Encoding UTF8

$taskName = 'WindowsServerLab-TemplateSeal'
Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
$sealStartedSentinel, $sealFailedSentinel | ForEach-Object {
    if (Test-Path -LiteralPath $_) { Remove-Item -LiteralPath $_ -Force }
}
$taskAction = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:\ProgramData\WindowsServerLab\seal-template.ps1'
$taskTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddSeconds(15)
$taskSettings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 45) -StartWhenAvailable
Register-ScheduledTask -TaskName $taskName -Action $taskAction -Trigger $taskTrigger -Settings $taskSettings -User SYSTEM -RunLevel Highest -Force | Out-Null
Start-ScheduledTask -TaskName $taskName
$sealDeadline = (Get-Date).AddMinutes(5)
while (-not (Test-Path -LiteralPath $sealStartedSentinel -PathType Leaf)) {
    if (Test-Path -LiteralPath $sealFailedSentinel -PathType Leaf) {
        throw "Template seal task failed: $(Get-Content -LiteralPath $sealFailedSentinel -Raw -Encoding UTF8)"
    }
    if ((Get-Date) -ge $sealDeadline) { throw 'Template seal task did not start within 5 minutes.' }
    Start-Sleep -Seconds 2
}
