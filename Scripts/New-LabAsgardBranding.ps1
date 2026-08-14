#Requires -RunAsAdministrator
#Requires -Version 5.1
<#
.SYNOPSIS
    Creates and publishes the deterministic Asgard lab wallpaper.
.DESCRIPTION
    Runs only on the canonical Asgard file server. The Branding share is encrypted,
    read-only for Domain Users, and writable only by local administrators and SYSTEM.
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [string]$Path = 'D:\Shares\Branding\asgard-wallpaper.bmp',
    [string]$ShareName = 'Branding',
    [string]$OutputPath = 'C:\ProgramData\WindowsServerLab\Reports\asgard-branding.json'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = 'C:\ProgramData\WindowsServerLab'
$definition = Get-Content -LiteralPath "$root\LabConfig\lab.json" -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
$fileServer = @($definition.virtualMachines | Where-Object role -eq 'file-server')
if ($fileServer.Count -ne 1 -or $env:COMPUTERNAME -ine $fileServer[0].name) { throw "Run this script on $($fileServer[0].name)." }
$computerSystem = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
if (-not $computerSystem.PartOfDomain -or $computerSystem.Domain -ine $definition.domain.dnsName) { throw 'The file server is not joined to the Asgard domain.' }

$directory = Split-Path -Parent $Path
$result = [ordered]@{
    schemaVersion = 1
    timestamp = (Get-Date).ToUniversalTime().ToString('o')
    server = $env:COMPUTERNAME
    shareName = $ShareName
    path = $Path
    uncPath = "\\$env:COMPUTERNAME.$($computerSystem.Domain)\$ShareName\$(Split-Path -Leaf $Path)"
    status = 'planned'
    shareEncrypted = $false
    readOnlyVerified = $false
}

try {
    if ($PSCmdlet.ShouldProcess($Path, 'Create Asgard wallpaper and publish the hardened Branding share')) {
        Add-Type -AssemblyName System.Drawing -ErrorAction Stop
        if (-not (Test-Path -LiteralPath $directory)) { New-Item -Path $directory -ItemType Directory -Force -ErrorAction Stop | Out-Null }
        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
            $bitmap = [Drawing.Bitmap]::new(1920, 1080)
            $graphics = [Drawing.Graphics]::FromImage($bitmap)
            try {
                $graphics.Clear([Drawing.Color]::FromArgb(15, 23, 42))
                $gold = [Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(226, 183, 75))
                $muted = [Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(148, 163, 184))
                $titleFont = [Drawing.Font]::new('Segoe UI Semibold', 72, [Drawing.FontStyle]::Bold)
                $subtitleFont = [Drawing.Font]::new('Segoe UI', 30, [Drawing.FontStyle]::Regular)
                try {
                    $graphics.DrawString('ASGARD TECHNOLOGIES', $titleFont, $gold, 150, 395)
                    $graphics.DrawString('ad.asgard.test  |  Authorized lab systems only', $subtitleFont, $muted, 155, 520)
                }
                finally { $titleFont.Dispose(); $subtitleFont.Dispose(); $gold.Dispose(); $muted.Dispose() }
                $bitmap.Save($Path, [Drawing.Imaging.ImageFormat]::Bmp)
            }
            finally { $graphics.Dispose(); $bitmap.Dispose() }
        }

        $domainUsers = "$($definition.domain.netbiosName)\Domain Users"
        & icacls.exe $directory /inheritance:r /grant:r 'SYSTEM:(OI)(CI)F' 'BUILTIN\Administrators:(OI)(CI)F' "$($domainUsers):(OI)(CI)RX" | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Unable to secure the Branding directory; icacls exited $LASTEXITCODE." }
        $share = Get-SmbShare -Name $ShareName -ErrorAction Ignore
        if ($share -and $share.Path -ine $directory) { throw "Share $ShareName already points to $($share.Path)." }
        if (-not $share) {
            New-SmbShare -Name $ShareName -Path $directory -Description 'Asgard managed branding' -FullAccess 'BUILTIN\Administrators' -ReadAccess $domainUsers -EncryptData $true -CachingMode None -ErrorAction Stop | Out-Null
        }
        else {
            Set-SmbShare -Name $ShareName -EncryptData $true -CachingMode None -Force -ErrorAction Stop | Out-Null
            Revoke-SmbShareAccess -Name $ShareName -AccountName Everyone -Force -ErrorAction Ignore | Out-Null
            Grant-SmbShareAccess -Name $ShareName -AccountName $domainUsers -AccessRight Read -Force -ErrorAction Stop | Out-Null
        }
        $share = Get-SmbShare -Name $ShareName -ErrorAction Stop
        $readAccess = Get-SmbShareAccess -Name $ShareName -ErrorAction Stop | Where-Object { $_.AccountName -eq $domainUsers -and $_.AccessControlType -eq 'Allow' -and $_.AccessRight -eq 'Read' }
        if (-not $share.EncryptData -or -not $readAccess) { throw 'Branding share verification failed.' }
        $result.shareEncrypted = $true
        $result.readOnlyVerified = $true
        $result.status = 'configured'
    }
}
catch {
    $result.status = 'failed'
    $result.error = $_.Exception.Message
    throw
}
finally {
    $reportDirectory = Split-Path -Parent $OutputPath
    if (-not (Test-Path -LiteralPath $reportDirectory)) { New-Item -Path $reportDirectory -ItemType Directory -Force | Out-Null }
    $result | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
}

$result
