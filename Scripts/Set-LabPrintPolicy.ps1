#Requires -RunAsAdministrator
#Requires -Version 5.1
<#
.SYNOPSIS
    Configures trusted print-server policy and group-based printer permissions.
#>
[CmdletBinding(DefaultParameterSetName = 'Access', SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory, ParameterSetName = 'Initialize')][switch]$Initialize,
    [Parameter(Mandatory, ParameterSetName = 'Access')][string]$Identity,
    [Parameter(Mandatory, ParameterSetName = 'Access')][ValidateSet('Print', 'Manage')][string]$Permission,
    [Parameter(Mandatory, ParameterSetName = 'Access')][ValidateSet('Allow', 'Deny')][string]$Access,
    [string]$DefinitionPath,
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = 'C:\ProgramData\WindowsServerLab'
if (-not $DefinitionPath) { $DefinitionPath = Join-Path $root 'LabConfig\lab.json' }
if (-not $OutputPath) { $OutputPath = Join-Path $root 'Reports\print-policy.json' }
Import-Module (Join-Path $root 'Modules\WindowsServerLab\WindowsServerLab.psd1') -Force -ErrorAction Stop
Import-Module ActiveDirectory -ErrorAction Stop
Import-Module GroupPolicy -ErrorAction Stop

$definition = Import-LabDefinition -Path $DefinitionPath
$domain = Get-ADDomain -ErrorAction Stop
if ($domain.DNSRoot -notin @($definition.domain.dnsName, $definition.domain.legacyDnsName)) { throw 'Current domain does not match the lab definition.' }
$domainDn = ConvertTo-LabDistinguishedName -DomainName $domain.DNSRoot
$baseOu = "OU=$($definition.domain.baseOrganizationalUnit),$domainDn"
$groupsOu = "OU=Groups,$baseOu"
$printServer = @($definition.virtualMachines | Where-Object role -eq 'file-server')
if ($printServer.Count -ne 1) { throw 'The definition must contain exactly one file/print server.' }
$approvedServer = "$($printServer[0].name).$($domain.DNSRoot)"
$denyGroupName = 'ACL-Print-Deny'
$adminGroupName = 'ACL-Print-Admin'
$gpoName = 'WSLAB-v2-Print-Policy'

foreach ($requiredOu in @($baseOu, $groupsOu)) { Get-ADOrganizationalUnit -Identity $requiredOu -ErrorAction Stop | Out-Null }
$result = [ordered]@{
    schemaVersion = 1
    timestamp = (Get-Date).ToUniversalTime().ToString('o')
    lab = $definition.name
    mode = $PSCmdlet.ParameterSetName
    approvedPrintServer = $approvedServer
    status = 'planned'
    evidence = @()
}

try {
    if ($Initialize) {
        foreach ($groupDefinition in @(
            @{ Name = $denyGroupName; Description = 'Users denied access to WindowsServerLab shared printers' },
            @{ Name = $adminGroupName; Description = 'Delegated WindowsServerLab print queue administrators' }
        )) {
            $group = Get-ADGroup -LDAPFilter "(sAMAccountName=$($groupDefinition.Name))" -Properties Description -ErrorAction Stop
            if (-not $group -and $PSCmdlet.ShouldProcess($groupDefinition.Name, 'Create print-policy security group')) {
                $group = New-ADGroup -Name $groupDefinition.Name -SamAccountName $groupDefinition.Name -GroupScope Global -GroupCategory Security -Path $groupsOu -Description $groupDefinition.Description -PassThru -ErrorAction Stop
            }
            if ($group -and ($group.GroupScope -ne 'Global' -or $group.GroupCategory -ne 'Security' -or $group.DistinguishedName -notlike "*,$groupsOu" -or $group.Description -ne $groupDefinition.Description)) { throw "Existing group '$($groupDefinition.Name)' is not the expected lab security group in $groupsOu." }
            $result.evidence += "group:$($groupDefinition.Name)"
        }

        if ($PSCmdlet.ShouldProcess($gpoName, "Restrict Point and Print to $approvedServer")) {
            $gpo = Get-GPO -Name $gpoName -ErrorAction Ignore
            if (-not $gpo) { $gpo = New-GPO -Name $gpoName -Comment 'Trusted, package-aware WindowsServerLab print server policy.' -ErrorAction Stop }
            $pointKey = 'HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Printers\PointAndPrint'
            $packageKey = 'HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Printers\PackagePointAndPrint'
            $settings = @(
                @{ Key = $pointKey; Name = 'Restricted'; Type = 'DWord'; Value = 1 },
                @{ Key = $pointKey; Name = 'TrustedServers'; Type = 'DWord'; Value = 1 },
                @{ Key = $pointKey; Name = 'ServerList'; Type = 'String'; Value = $approvedServer },
                @{ Key = $pointKey; Name = 'InForest'; Type = 'DWord'; Value = 1 },
                @{ Key = $pointKey; Name = 'NoWarningNoElevationOnInstall'; Type = 'DWord'; Value = 0 },
                @{ Key = $pointKey; Name = 'UpdatePromptSettings'; Type = 'DWord'; Value = 0 },
                @{ Key = $pointKey; Name = 'RestrictDriverInstallationToAdministrators'; Type = 'DWord'; Value = 1 },
                @{ Key = $packageKey; Name = 'PackagePointAndPrintOnly'; Type = 'DWord'; Value = 1 },
                @{ Key = $packageKey; Name = 'PackagePointAndPrintServerList'; Type = 'String'; Value = $approvedServer }
            )
            foreach ($setting in $settings) {
                Set-GPRegistryValue -Name $gpoName -Key $setting.Key -ValueName $setting.Name -Type $setting.Type -Value $setting.Value -ErrorAction Stop
                $actual = Get-GPRegistryValue -Name $gpoName -Key $setting.Key -ValueName $setting.Name -ErrorAction Stop
                if ($actual.Value -ne $setting.Value) { throw "Print GPO read-back failed for $($setting.Key)\$($setting.Name)." }
                $result.evidence += "gpo:$($setting.Key)\$($setting.Name)"
            }
            $link = (Get-GPInheritance -Target $baseOu -ErrorAction Stop).GpoLinks | Where-Object DisplayName -eq $gpoName
            if (-not $link) { New-GPLink -Name $gpoName -Target $baseOu -LinkEnabled Yes -ErrorAction Stop | Out-Null }
            elseif (-not $link.Enabled) { Set-GPLink -Name $gpoName -Target $baseOu -LinkEnabled Yes -ErrorAction Stop | Out-Null }
            $link = (Get-GPInheritance -Target $baseOu -ErrorAction Stop).GpoLinks | Where-Object DisplayName -eq $gpoName
            if (-not $link -or -not $link.Enabled) { throw 'Print GPO link verification failed.' }
        }
        $result.status = if ($WhatIfPreference) { 'planned' } else { 'configured' }
    }
    else {
        $user = Get-ADUser -Identity $Identity -ErrorAction Stop
        $targetGroup = if ($Permission -eq 'Manage') { $adminGroupName } else { $denyGroupName }
        Get-ADGroup -Identity $targetGroup -ErrorAction Stop | Out-Null
        $member = [bool](Get-ADGroupMember -Identity $targetGroup -ErrorAction Stop | Where-Object DistinguishedName -eq $user.DistinguishedName)
        $shouldBeMember = if ($Permission -eq 'Manage') { $Access -eq 'Allow' } else { $Access -eq 'Deny' }
        if ($shouldBeMember -and -not $member -and $PSCmdlet.ShouldProcess($user.SamAccountName, "Add to $targetGroup")) {
            Add-ADGroupMember -Identity $targetGroup -Members $user -ErrorAction Stop
        }
        elseif (-not $shouldBeMember -and $member -and $PSCmdlet.ShouldProcess($user.SamAccountName, "Remove from $targetGroup")) {
            Remove-ADGroupMember -Identity $targetGroup -Members $user -Confirm:$false -ErrorAction Stop
        }
        $member = [bool](Get-ADGroupMember -Identity $targetGroup -ErrorAction Stop | Where-Object DistinguishedName -eq $user.DistinguishedName)
        if (-not $WhatIfPreference -and $member -ne $shouldBeMember) { throw 'Print-policy membership verification failed.' }
        $result.identity = $user.SamAccountName
        $result.permission = $Permission
        $result.access = $Access
        $result.group = $targetGroup
        $result.directMembership = $member
        $result.status = if ($WhatIfPreference) { 'planned' } else { 'configured' }
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
    $result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
    Write-LabLog -Level $(if ($result.status -eq 'failed') { 'Error' } else { 'Info' }) -Message "Print policy $($result.status)" -Data @{ Lab = $definition.name; Report = $OutputPath }
}

$result
