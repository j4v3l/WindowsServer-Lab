#Requires -RunAsAdministrator
#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)][ValidatePattern('^[A-Za-z]:\\|^\\\\')][string]$BackupTarget
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (-not (Get-Service NTDS -ErrorAction Ignore)) { throw 'System State backup script must run on a domain controller.' }
$systemDrive = [IO.Path]::GetPathRoot($env:SystemRoot)
if ([IO.Path]::GetPathRoot($BackupTarget) -eq $systemDrive) { throw 'BackupTarget must not be on the Windows system volume.' }
if (-not $PSCmdlet.ShouldProcess($env:COMPUTERNAME, "Create System State backup at $BackupTarget")) { return }

$feature = Get-WindowsFeature Windows-Server-Backup -ErrorAction Stop
if (-not $feature.Installed) { Install-WindowsFeature Windows-Server-Backup -ErrorAction Stop | Out-Null }
& wbadmin.exe start systemstatebackup "-backupTarget:$BackupTarget" -quiet
if ($LASTEXITCODE -ne 0) { throw "wbadmin failed with exit code $LASTEXITCODE" }
& wbadmin.exe get versions "-backupTarget:$BackupTarget"
if ($LASTEXITCODE -ne 0) { throw 'Backup completed but could not be enumerated for verification.' }
