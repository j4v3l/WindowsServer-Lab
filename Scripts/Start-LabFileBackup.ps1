#Requires -RunAsAdministrator
#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)][ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })][string]$SourcePath,
    [Parameter(Mandatory)][string]$DestinationPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ((Resolve-Path -LiteralPath $SourcePath).Path -eq $DestinationPath) { throw 'Source and destination must differ.' }
if (-not $PSCmdlet.ShouldProcess($DestinationPath, "Mirror files from $SourcePath")) { return }
if (-not (Test-Path -LiteralPath $DestinationPath)) { New-Item -Path $DestinationPath -ItemType Directory -Force | Out-Null }

& robocopy.exe $SourcePath $DestinationPath /MIR /COPYALL /DCOPY:DAT /R:2 /W:5 /XJ /NP
if ($LASTEXITCODE -ge 8) { throw "robocopy failed with exit code $LASTEXITCODE" }
$manifest = Get-ChildItem -LiteralPath $DestinationPath -File -Recurse | Get-FileHash -Algorithm SHA256
$manifest | Export-Csv -LiteralPath (Join-Path $DestinationPath 'wslab-backup-manifest.csv') -NoTypeInformation -Encoding UTF8
