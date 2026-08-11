#Requires -RunAsAdministrator
#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)][ValidateSet('asgard', 'olympus')][string]$Demo,
    [Parameter(Mandatory)][ValidateSet('DomainController', 'MemberServer')][string]$ServerRole,
    [Parameter(Mandatory)][ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })][string]$PackagePath,
    [Parameter(Mandatory)][ValidatePattern('^[A-Fa-f0-9]{64}$')][string]$PackageSha256
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$actualHash = (Get-FileHash -LiteralPath $PackagePath -Algorithm SHA256).Hash
if ($actualHash -ne $PackageSha256.ToUpperInvariant()) { throw 'Security Compliance Toolkit package checksum mismatch.' }

$root = 'C:\ProgramData\WindowsServerLab'
Import-Module "$root\Modules\WindowsServerLab\WindowsServerLab.psd1" -Force
Import-Module ActiveDirectory -ErrorAction Stop
Import-Module GroupPolicy -ErrorAction Stop
$definition = Import-LabDefinition -Path "$root\LabConfig\demos\$Demo.json"
$domain = Get-ADDomain -ErrorAction Stop
$domainDn = ConvertTo-LabDistinguishedName -DomainName $domain.DNSRoot
$baseOu = "OU=$($definition.domain.baseOrganizationalUnit),$domainDn"
$target = if ($ServerRole -eq 'DomainController') { "OU=Domain Controllers,$domainDn" } else { "OU=Servers,$baseOu" }
$namePattern = if ($ServerRole -eq 'DomainController') { 'Domain Controller|Domain Security' } else { 'Member Server' }
$staging = Join-Path $env:TEMP "wslab-sct-$PID"

try {
    Expand-Archive -LiteralPath $PackagePath -DestinationPath $staging -Force
    $backups = foreach ($infoFile in Get-ChildItem -LiteralPath $staging -Filter bkupInfo.xml -File -Recurse) {
        $content = Get-Content -LiteralPath $infoFile.FullName -Raw
        $idMatch = [regex]::Match($content, '<ID>\s*\{?([0-9A-Fa-f-]{36})\}?\s*</ID>')
        $nameMatch = [regex]::Match($content, '<(?:DisplayName|GPODisplayName)>\s*([^<]+)\s*</(?:DisplayName|GPODisplayName)>')
        if ($idMatch.Success -and $nameMatch.Success -and $nameMatch.Groups[1].Value -match $namePattern) {
            [pscustomobject]@{
                Id          = [guid]$idMatch.Groups[1].Value
                DisplayName = [Net.WebUtility]::HtmlDecode($nameMatch.Groups[1].Value)
                BackupRoot  = $infoFile.Directory.Parent.FullName
            }
        }
    }
    if (@($backups).Count -eq 0) { throw "No $ServerRole GPO backups were found in the verified package." }

    $index = 0
    foreach ($backup in $backups) {
        $index++
        $targetName = "WSLAB-SCT-2022-$ServerRole-$index"
        if ($PSCmdlet.ShouldProcess($target, "Import and link $($backup.DisplayName) as $targetName")) {
            Import-GPO -BackupId $backup.Id -Path $backup.BackupRoot -TargetName $targetName -CreateIfNeeded -ErrorAction Stop | Out-Null
            Get-GPO -Name $targetName -ErrorAction Stop | Out-Null
            $link = (Get-GPInheritance -Target $target -ErrorAction Stop).GpoLinks | Where-Object DisplayName -eq $targetName
            if (-not $link) { New-GPLink -Name $targetName -Target $target -LinkEnabled Yes -ErrorAction Stop | Out-Null }
        }
    }
}
finally {
    Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction Ignore
}
