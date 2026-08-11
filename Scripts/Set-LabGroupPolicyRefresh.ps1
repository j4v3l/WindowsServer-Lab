#Requires -RunAsAdministrator
#Requires -Version 5.1
<#
.SYNOPSIS
    Configures and verifies native background Group Policy refresh for lab OUs.
.DESCRIPTION
    Uses Windows Group Policy refresh settings instead of a polling script or stored
    credential. Random offset prevents every endpoint from contacting a domain controller
    simultaneously. Domain controllers retain their native five-minute refresh behavior.
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)][ValidateSet('asgard', 'olympus')][string]$Demo,
    [ValidateRange(15, 1440)][int]$ComputerIntervalMinutes = 30,
    [ValidateRange(0, 60)][int]$ComputerRandomOffsetMinutes = 10,
    [ValidateRange(15, 1440)][int]$UserIntervalMinutes = 30,
    [ValidateRange(0, 60)][int]$UserRandomOffsetMinutes = 10,
    [string]$DefinitionPath,
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = 'C:\ProgramData\WindowsServerLab'
if (-not $DefinitionPath) { $DefinitionPath = Join-Path $root "LabConfig\demos\$Demo.json" }
if (-not $OutputPath) { $OutputPath = Join-Path $root 'Reports\group-policy-refresh.json' }

Import-Module (Join-Path $root 'Modules\WindowsServerLab\WindowsServerLab.psd1') -Force -ErrorAction Stop
Import-Module ActiveDirectory -ErrorAction Stop
Import-Module GroupPolicy -ErrorAction Stop
$definition = Import-LabDefinition -Path $DefinitionPath
$domain = Get-ADDomain -ErrorAction Stop
if ($domain.DNSRoot -notin @($definition.domain.dnsName, $definition.domain.legacyDnsName)) {
    throw "Current domain '$($domain.DNSRoot)' does not match the selected demo."
}
$domainDn = ConvertTo-LabDistinguishedName -DomainName $domain.DNSRoot
$baseOu = "OU=$($definition.domain.baseOrganizationalUnit),$domainDn"
Get-ADOrganizationalUnit -Identity $baseOu -ErrorAction Stop | Out-Null

$gpoName = 'WSLAB-v2-GroupPolicy-Refresh'
$computerRefreshKey = 'HKLM\SOFTWARE\Policies\Microsoft\Windows\System'
$userRefreshKey = 'HKCU\SOFTWARE\Policies\Microsoft\Windows\System'
$backgroundPolicyKey = 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
$foregroundPolicyKey = 'HKLM\SOFTWARE\Policies\Microsoft\Windows NT\CurrentVersion\Winlogon'
$settings = @(
    @{ Key = $computerRefreshKey; Name = 'GroupPolicyRefreshTime'; Type = 'DWord'; Value = $ComputerIntervalMinutes },
    @{ Key = $computerRefreshKey; Name = 'GroupPolicyRefreshTimeOffset'; Type = 'DWord'; Value = $ComputerRandomOffsetMinutes },
    @{ Key = $userRefreshKey; Name = 'GroupPolicyRefreshTime'; Type = 'DWord'; Value = $UserIntervalMinutes },
    @{ Key = $userRefreshKey; Name = 'GroupPolicyRefreshTimeOffset'; Type = 'DWord'; Value = $UserRandomOffsetMinutes },
    @{ Key = $backgroundPolicyKey; Name = 'DisableBkGndGroupPolicy'; Type = 'DWord'; Value = 0 },
    @{ Key = $foregroundPolicyKey; Name = 'SyncForegroundPolicy'; Type = 'DWord'; Value = 1 }
)

$result = [ordered]@{
    schemaVersion = 1
    timestamp = (Get-Date).ToUniversalTime().ToString('o')
    demo = $Demo
    domain = $domain.DNSRoot
    gpo = $gpoName
    targetOu = $baseOu
    computerIntervalMinutes = $ComputerIntervalMinutes
    computerRandomOffsetMinutes = $ComputerRandomOffsetMinutes
    userIntervalMinutes = $UserIntervalMinutes
    userRandomOffsetMinutes = $UserRandomOffsetMinutes
    status = 'planned'
    verifiedSettings = @()
}

try {
    if ($PSCmdlet.ShouldProcess($baseOu, "Configure and verify $gpoName")) {
        $gpo = Get-GPO -Name $gpoName -ErrorAction Ignore
        if (-not $gpo) {
            $gpo = New-GPO -Name $gpoName -Comment 'Native background Group Policy refresh cadence for WindowsServerLab endpoints and users.' -ErrorAction Stop
        }
        foreach ($setting in $settings) {
            Set-GPRegistryValue -Name $gpoName -Key $setting.Key -ValueName $setting.Name -Type $setting.Type -Value $setting.Value -ErrorAction Stop
            $actual = Get-GPRegistryValue -Name $gpoName -Key $setting.Key -ValueName $setting.Name -ErrorAction Stop
            if ($actual.Value -ne $setting.Value) { throw "GPO read-back failed for $($setting.Key)\$($setting.Name)." }
            $result.verifiedSettings += "$($setting.Key)\$($setting.Name)"
        }

        $link = (Get-GPInheritance -Target $baseOu -ErrorAction Stop).GpoLinks | Where-Object DisplayName -eq $gpoName
        if (-not $link) { New-GPLink -Name $gpoName -Target $baseOu -LinkEnabled Yes -ErrorAction Stop | Out-Null }
        elseif (-not $link.Enabled) { Set-GPLink -Name $gpoName -Target $baseOu -LinkEnabled Yes -ErrorAction Stop | Out-Null }
        $link = (Get-GPInheritance -Target $baseOu -ErrorAction Stop).GpoLinks | Where-Object DisplayName -eq $gpoName
        if (-not $link -or -not $link.Enabled) { throw "GPO link verification failed for $gpoName on $baseOu." }
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
    if ($reportDirectory -and -not (Test-Path -LiteralPath $reportDirectory)) { New-Item -Path $reportDirectory -ItemType Directory -Force | Out-Null }
    $result | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
    Write-LabLog -Level $(if ($result.status -eq 'failed') { 'Error' } else { 'Info' }) -Message "Group Policy refresh $($result.status)" -Data @{ Demo = $Demo; Gpo = $gpoName; Report = $OutputPath }
}

$result
