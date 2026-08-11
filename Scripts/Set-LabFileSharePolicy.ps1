#Requires -RunAsAdministrator
#Requires -Version 5.1
<#
.SYNOPSIS
    Creates file-share access groups, SMB client/server policy, and manages user access.
#>
[CmdletBinding(DefaultParameterSetName = 'Access', SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)][ValidateSet('asgard', 'olympus')][string]$Demo,
    [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9][A-Za-z0-9_-]{0,30}[A-Za-z0-9]$')][string]$ShareName,
    [Parameter(Mandatory, ParameterSetName = 'Initialize')][switch]$Initialize,
    [Parameter(Mandatory, ParameterSetName = 'Access')][string]$Identity,
    [Parameter(Mandatory, ParameterSetName = 'Access')][ValidateSet('Read', 'Change', 'Deny', 'Remove')][string]$Permission,
    [switch]$DefaultReadForDomainUsers,
    [ValidatePattern('^[A-Za-z0-9-]{1,20}$')][string]$ReadGroupName,
    [ValidatePattern('^[A-Za-z0-9-]{1,20}$')][string]$ChangeGroupName,
    [ValidatePattern('^[A-Za-z0-9-]{1,20}$')][string]$DenyGroupName,
    [string]$DefinitionPath,
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = 'C:\ProgramData\WindowsServerLab'
if (-not $DefinitionPath) { $DefinitionPath = Join-Path $root "LabConfig\demos\$Demo.json" }
if (-not $OutputPath) { $OutputPath = Join-Path $root "Reports\file-share-policy-$ShareName.json" }
$groupToken = ($ShareName -replace '[^A-Za-z0-9]', '').ToUpperInvariant()
if ($groupToken.Length -gt 10) { $groupToken = $groupToken.Substring(0, 10) }
if (-not $ReadGroupName) { $ReadGroupName = "FS-$groupToken-R" }
if (-not $ChangeGroupName) { $ChangeGroupName = "FS-$groupToken-RW" }
if (-not $DenyGroupName) { $DenyGroupName = "FS-$groupToken-D" }
$uniqueGroupNames = @(@($ReadGroupName, $ChangeGroupName, $DenyGroupName) | Sort-Object -Unique)
if ($uniqueGroupNames.Count -ne 3) { throw 'File-share group names must be unique.' }

Import-Module (Join-Path $root 'Modules\WindowsServerLab\WindowsServerLab.psd1') -Force -ErrorAction Stop
Import-Module ActiveDirectory -ErrorAction Stop
Import-Module GroupPolicy -ErrorAction Stop
$definition = Import-LabDefinition -Path $DefinitionPath
$domain = Get-ADDomain -ErrorAction Stop
if ($domain.DNSRoot -notin @($definition.domain.dnsName, $definition.domain.legacyDnsName)) { throw 'Current domain does not match the selected demo.' }
$domainDn = ConvertTo-LabDistinguishedName -DomainName $domain.DNSRoot
$baseOu = "OU=$($definition.domain.baseOrganizationalUnit),$domainDn"
$groupsOu = "OU=Groups,$baseOu"
$gpoName = 'WSLAB-v2-FileShare-Policy'
$groups = [ordered]@{ Read = $ReadGroupName; Change = $ChangeGroupName; Deny = $DenyGroupName }
$result = [ordered]@{
    schemaVersion = 1
    timestamp = (Get-Date).ToUniversalTime().ToString('o')
    demo = $Demo
    shareName = $ShareName
    mode = $PSCmdlet.ParameterSetName
    groups = $groups
    status = 'planned'
    evidence = @()
}

try {
    if ($Initialize) {
        foreach ($entry in $groups.GetEnumerator()) {
            $description = "WindowsServerLab $($entry.Key) access for share $ShareName"
            $group = Get-ADGroup -LDAPFilter "(sAMAccountName=$($entry.Value))" -Properties Description -ErrorAction Stop
            if (-not $group -and $PSCmdlet.ShouldProcess($entry.Value, "Create $($entry.Key) file-share group")) {
                $group = New-ADGroup -Name $entry.Value -SamAccountName $entry.Value -GroupScope DomainLocal -GroupCategory Security -Path $groupsOu -Description $description -PassThru -ErrorAction Stop
            }
            if ($group -and ($group.GroupScope -ne 'DomainLocal' -or $group.GroupCategory -ne 'Security' -or $group.Description -ne $description)) {
                throw "Existing group '$($entry.Value)' belongs to another resource or has an incompatible type. Supply explicit unique group names."
            }
            $result.evidence += "group:$($entry.Value)"
        }
        if (-not $WhatIfPreference) {
            $domainUsers = Get-ADGroup -Identity "$($domain.DomainSID)-513" -ErrorAction Stop
            $domainUsersMember = [bool](Get-ADGroupMember -Identity $ReadGroupName -ErrorAction Stop | Where-Object DistinguishedName -eq $domainUsers.DistinguishedName)
            if ($DefaultReadForDomainUsers -and -not $domainUsersMember -and $PSCmdlet.ShouldProcess($ReadGroupName, 'Grant Domain Users default read membership')) {
                Add-ADGroupMember -Identity $ReadGroupName -Members $domainUsers -ErrorAction Stop
            }
            elseif (-not $DefaultReadForDomainUsers -and $domainUsersMember -and $PSCmdlet.ShouldProcess($ReadGroupName, 'Remove Domain Users default read membership')) {
                Remove-ADGroupMember -Identity $ReadGroupName -Members $domainUsers -Confirm:$false -ErrorAction Stop
            }
        }

        if ($PSCmdlet.ShouldProcess($gpoName, 'Configure and verify hardened SMB policy')) {
            $gpo = Get-GPO -Name $gpoName -ErrorAction Ignore
            if (-not $gpo) { $gpo = New-GPO -Name $gpoName -Comment 'WindowsServerLab SMB signing, guest-access, and discovery policy.' -ErrorAction Stop }
            $settings = @(
                @{ Key = 'HKLM\SOFTWARE\Policies\Microsoft\Windows\LanmanWorkstation'; Name = 'AllowInsecureGuestAuth'; Type = 'DWord'; Value = 0 },
                @{ Key = 'HKLM\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters'; Name = 'EnableSecuritySignature'; Type = 'DWord'; Value = 1 },
                @{ Key = 'HKLM\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters'; Name = 'RequireSecuritySignature'; Type = 'DWord'; Value = 1 },
                @{ Key = 'HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters'; Name = 'EnableSecuritySignature'; Type = 'DWord'; Value = 1 },
                @{ Key = 'HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters'; Name = 'RequireSecuritySignature'; Type = 'DWord'; Value = 1 }
            )
            foreach ($setting in $settings) {
                Set-GPRegistryValue -Name $gpoName -Key $setting.Key -ValueName $setting.Name -Type $setting.Type -Value $setting.Value -ErrorAction Stop
                $actual = Get-GPRegistryValue -Name $gpoName -Key $setting.Key -ValueName $setting.Name -ErrorAction Stop
                if ($actual.Value -ne $setting.Value) { throw "File-share GPO read-back failed for $($setting.Key)\$($setting.Name)." }
                $result.evidence += "gpo:$($setting.Key)\$($setting.Name)"
            }
            $link = (Get-GPInheritance -Target $baseOu -ErrorAction Stop).GpoLinks | Where-Object DisplayName -eq $gpoName
            if (-not $link) { New-GPLink -Name $gpoName -Target $baseOu -LinkEnabled Yes -ErrorAction Stop | Out-Null }
            elseif (-not $link.Enabled) { Set-GPLink -Name $gpoName -Target $baseOu -LinkEnabled Yes -ErrorAction Stop | Out-Null }
            $link = (Get-GPInheritance -Target $baseOu -ErrorAction Stop).GpoLinks | Where-Object DisplayName -eq $gpoName
            if (-not $link -or -not $link.Enabled) { throw 'File-share GPO link verification failed.' }
        }
        $result.status = if ($WhatIfPreference) { 'planned' } else { 'configured' }
    }
    else {
        $user = Get-ADUser -Identity $Identity -ErrorAction Stop
        foreach ($entry in $groups.GetEnumerator()) { Get-ADGroup -Identity $entry.Value -ErrorAction Stop | Out-Null }
        $desiredGroups = switch ($Permission) {
            'Read' { @($ReadGroupName) }
            'Change' { @($ChangeGroupName) }
            'Deny' { @($DenyGroupName) }
            default { @() }
        }
        foreach ($groupName in @($groups.Values)) {
            $member = [bool](Get-ADGroupMember -Identity $groupName -ErrorAction Stop | Where-Object DistinguishedName -eq $user.DistinguishedName)
            $shouldBeMember = $groupName -in $desiredGroups
            if ($shouldBeMember -and -not $member -and $PSCmdlet.ShouldProcess($user.SamAccountName, "Add to $groupName")) {
                Add-ADGroupMember -Identity $groupName -Members $user -ErrorAction Stop
            }
            elseif (-not $shouldBeMember -and $member -and $PSCmdlet.ShouldProcess($user.SamAccountName, "Remove from $groupName")) {
                Remove-ADGroupMember -Identity $groupName -Members $user -Confirm:$false -ErrorAction Stop
            }
        }
        $verifiedMemberships = @($groups.Values | Where-Object { Get-ADGroupMember -Identity $_ -ErrorAction Stop | Where-Object DistinguishedName -eq $user.DistinguishedName })
        $verifiedMembershipText = (@($verifiedMemberships | Sort-Object) -join '|')
        $desiredMembershipText = (@($desiredGroups | Sort-Object) -join '|')
        if (-not $WhatIfPreference -and $verifiedMembershipText -ne $desiredMembershipText) { throw 'File-share membership verification failed.' }
        $result.identity = $user.SamAccountName
        $result.permission = $Permission
        $result.directMemberships = $verifiedMemberships
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
    Write-LabLog -Level $(if ($result.status -eq 'failed') { 'Error' } else { 'Info' }) -Message "File-share policy $($result.status)" -Data @{ Demo = $Demo; Share = $ShareName; Report = $OutputPath }
}

$result
