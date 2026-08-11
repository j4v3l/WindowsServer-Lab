#Requires -RunAsAdministrator
#Requires -Version 5.1
<#
.SYNOPSIS
    Creates and manages group-filtered WindowsServerLab access-control GPOs.
.DESCRIPTION
    Initialize creates one verified GPO and one security-filter group per catalog control.
    Deny adds a user or workstation to that control's group. Allow removes the direct group
    membership; it does not override a denial delivered by another policy.
#>
[CmdletBinding(DefaultParameterSetName = 'Access', SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)][ValidateSet('asgard', 'olympus')][string]$Demo,
    [Parameter(Mandatory, ParameterSetName = 'Initialize')][switch]$Initialize,
    [Parameter(Mandatory, ParameterSetName = 'Access')][ValidateNotNullOrEmpty()][string]$Identity,
    [Parameter(Mandatory, ParameterSetName = 'Access')][ValidateNotNullOrEmpty()][string]$Control,
    [Parameter(Mandatory, ParameterSetName = 'Access')][ValidateSet('Allow', 'Deny')][string]$Access,
    [string]$DefinitionPath,
    [string]$CatalogPath,
    [ValidatePattern('^\\\\[^\\]+\\[^\\]+')][string]$WallpaperPath,
    [switch]$RefreshPolicy,
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = 'C:\ProgramData\WindowsServerLab'
if (-not $DefinitionPath) { $DefinitionPath = Join-Path $root "LabConfig\demos\$Demo.json" }
if (-not $CatalogPath) { $CatalogPath = Join-Path $root 'LabConfig\policies\access-controls.json' }
if (-not $OutputPath) { $OutputPath = Join-Path $root 'Reports\access-control.json' }

Import-Module (Join-Path $root 'Modules\WindowsServerLab\WindowsServerLab.psd1') -Force -ErrorAction Stop
Import-Module ActiveDirectory -ErrorAction Stop
Import-Module GroupPolicy -ErrorAction Stop

function Get-LabAccessCatalog {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Access-control catalog not found: $Path" }
    $loaded = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    if ($loaded.schemaVersion -ne 1) { throw "Unsupported access-control catalog schemaVersion '$($loaded.schemaVersion)'." }
    if (@($loaded.controls).Count -eq 0) { throw 'The access-control catalog is empty.' }

    foreach ($property in @('id', 'groupName', 'gpoName')) {
        $values = @($loaded.controls | ForEach-Object { $_.$property })
        if (@($values | Sort-Object -Unique).Count -ne $values.Count) { throw "Access-control catalog contains duplicate $property values." }
    }
    foreach ($item in $loaded.controls) {
        if ($item.id -notmatch '^[A-Za-z][A-Za-z0-9-]{1,31}$') { throw "Invalid access-control ID '$($item.id)'." }
        if ($item.groupName -notmatch '^[A-Za-z0-9-]{1,20}$') { throw "Invalid access-control group name '$($item.groupName)'." }
        if ($item.gpoName -notmatch '^WSLAB-Access-[A-Za-z0-9-]+$') { throw "Invalid access-control GPO name '$($item.gpoName)'." }
        $expectedPrefix = if ($item.scope -eq 'Computer') { 'HKLM\' } elseif ($item.scope -eq 'User') { 'HKCU\' } else { throw "Unsupported control scope '$($item.scope)'." }
        if (@($item.settings).Count -eq 0) { throw "Control '$($item.id)' has no settings." }
        foreach ($setting in $item.settings) {
            if (-not $setting.key.StartsWith($expectedPrefix, [StringComparison]::OrdinalIgnoreCase)) {
                throw "Control '$($item.id)' has a registry setting outside its $($item.scope) scope: $($setting.key)."
            }
            if ($setting.type -notin @('DWord', 'String') -or -not $setting.name) {
                throw "Control '$($item.id)' has an unsupported registry setting."
            }
            if ($setting.PSObject.Properties.Name -contains 'requiresWallpaperPath' -and $setting.requiresWallpaperPath -and ([string]$setting.value -notlike '*{WALLPAPER_PATH}*')) {
                throw "Control '$($item.id)' marks a setting as wallpaper-dependent without the wallpaper token."
            }
        }
    }
    $loaded
}

function Get-LabDirectoryObject {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Definition,
        [Parameter(Mandatory)]$SelectedControl,
        [Parameter(Mandatory)][string]$RequestedIdentity
    )

    if ($SelectedControl.scope -eq 'User') {
        $user = Get-ADUser -Identity $RequestedIdentity -ErrorAction Stop
        return [pscustomobject]@{ Object = $user; Type = 'User'; Workstation = $null; Resolution = 'direct-user' }
    }

    try {
        $computer = Get-ADComputer -Identity $RequestedIdentity -ErrorAction Stop
        return [pscustomobject]@{ Object = $computer; Type = 'Computer'; Workstation = $computer.Name; Resolution = 'direct-computer' }
    }
    catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
        $user = Get-ADUser -Identity $RequestedIdentity -ErrorAction Stop
        $canonicalMatches = @($Definition.virtualMachines | Where-Object {
            $_.role -in @('client', 'aiml-client') -and $_.user -and $_.user.samAccountName -ieq $user.SamAccountName
        })
        if ($canonicalMatches.Count -ne 1) {
            throw "User '$RequestedIdentity' does not map to exactly one canonical workstation. Supply the computer name instead."
        }
        $computer = Get-ADComputer -Identity $canonicalMatches[0].name -ErrorAction Stop
        return [pscustomobject]@{ Object = $computer; Type = 'Computer'; Workstation = $computer.Name; Resolution = 'canonical-user-to-computer' }
    }
}

function Test-LabDirectGroupMembership {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$GroupName,
        [Parameter(Mandatory)][string]$DistinguishedName
    )

    [bool](Get-ADGroupMember -Identity $GroupName -ErrorAction Stop | Where-Object DistinguishedName -eq $DistinguishedName)
}

function Resolve-LabSettingValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Setting,
        [string]$ApprovedWallpaperPath
    )

    if ($Setting.PSObject.Properties.Name -contains 'requiresWallpaperPath' -and $Setting.requiresWallpaperPath) {
        if (-not $ApprovedWallpaperPath) { return $null }
        return ([string]$Setting.value).Replace('{WALLPAPER_PATH}', $ApprovedWallpaperPath)
    }
    $Setting.value
}

$definition = Import-LabDefinition -Path $DefinitionPath
$catalog = Get-LabAccessCatalog -Path $CatalogPath
$domain = Get-ADDomain -ErrorAction Stop
if ($domain.DNSRoot -notin @($definition.domain.dnsName, $definition.domain.legacyDnsName)) {
    throw "Current domain '$($domain.DNSRoot)' does not match the selected demo."
}
$domainDn = ConvertTo-LabDistinguishedName -DomainName $domain.DNSRoot
$baseOu = "OU=$($definition.domain.baseOrganizationalUnit),$domainDn"
$groupsOu = "OU=Groups,$baseOu"
$workstationsOu = "OU=Workstations,$baseOu"
foreach ($requiredOu in @($baseOu, $groupsOu, $workstationsOu)) {
    Get-ADOrganizationalUnit -Identity $requiredOu -ErrorAction Stop | Out-Null
}

$result = [ordered]@{
    schemaVersion = 1
    timestamp = (Get-Date).ToUniversalTime().ToString('o')
    demo = $Demo
    domain = $domain.DNSRoot
    mode = $PSCmdlet.ParameterSetName
    status = 'planned'
    controls = @()
}

try {
    if ($Initialize) {
        foreach ($selected in $catalog.controls) {
            $targetOu = if ($selected.scope -eq 'Computer') { $workstationsOu } else { $baseOu }
            $group = Get-ADGroup -LDAPFilter "(sAMAccountName=$($selected.groupName))" -ErrorAction Stop
            if (-not $group -and $PSCmdlet.ShouldProcess($selected.groupName, "Create $($selected.scope.ToLowerInvariant()) access-control group")) {
                $group = New-ADGroup -Name $selected.groupName -SamAccountName $selected.groupName -GroupScope Global -GroupCategory Security -Path $groupsOu -Description $selected.description -PassThru -ErrorAction Stop
            }
            if ($group -and ($group.GroupScope -ne 'Global' -or $group.GroupCategory -ne 'Security' -or $group.DistinguishedName -notlike "*,$groupsOu")) {
                throw "Existing group '$($selected.groupName)' is not a global security group in $groupsOu; refusing to reuse it."
            }

            $gpo = Get-GPO -Name $selected.gpoName -ErrorAction Ignore
            if (-not $gpo -and $PSCmdlet.ShouldProcess($selected.gpoName, 'Create access-control GPO')) {
                $gpo = New-GPO -Name $selected.gpoName -Comment "WindowsServerLab access control: $($selected.description)" -ErrorAction Stop
            }

            $verifiedSettings = @()
            if ($gpo -and $PSCmdlet.ShouldProcess($selected.gpoName, 'Reconcile registry settings and security filtering')) {
                foreach ($setting in $selected.settings) {
                    $value = Resolve-LabSettingValue -Setting $setting -ApprovedWallpaperPath $WallpaperPath
                    if ($null -eq $value) { continue }
                    Set-GPRegistryValue -Name $selected.gpoName -Key $setting.key -ValueName $setting.name -Type $setting.type -Value $value -ErrorAction Stop
                    $actual = Get-GPRegistryValue -Name $selected.gpoName -Key $setting.key -ValueName $setting.name -ErrorAction Stop
                    if ($actual.Value -ne $value) { throw "GPO read-back failed for $($selected.id): $($setting.key)\$($setting.name)." }
                    $verifiedSettings += "$($setting.key)\$($setting.name)"
                }
                Set-GPPermission -Name $selected.gpoName -TargetName 'Authenticated Users' -TargetType Group -PermissionLevel GpoRead -Replace -ErrorAction Stop
                Set-GPPermission -Name $selected.gpoName -TargetName $selected.groupName -TargetType Group -PermissionLevel GpoApply -Replace -ErrorAction Stop
                $link = (Get-GPInheritance -Target $targetOu -ErrorAction Stop).GpoLinks | Where-Object DisplayName -eq $selected.gpoName
                if (-not $link) { New-GPLink -Name $selected.gpoName -Target $targetOu -LinkEnabled Yes -ErrorAction Stop | Out-Null }
                elseif (-not $link.Enabled) { Set-GPLink -Name $selected.gpoName -Target $targetOu -LinkEnabled Yes -ErrorAction Stop | Out-Null }

                $permission = Get-GPPermission -Name $selected.gpoName -TargetName $selected.groupName -TargetType Group -ErrorAction Stop
                if ($permission.Permission -ne 'GpoApply') { throw "Security filtering verification failed for $($selected.gpoName)." }
                $link = (Get-GPInheritance -Target $targetOu -ErrorAction Stop).GpoLinks | Where-Object DisplayName -eq $selected.gpoName
                if (-not $link -or -not $link.Enabled) { throw "GPO link verification failed for $($selected.gpoName) on $targetOu." }
            }
            $result.controls += [ordered]@{
                id = $selected.id
                scope = $selected.scope
                group = $selected.groupName
                gpo = $selected.gpoName
                targetOu = $targetOu
                verifiedSettings = $verifiedSettings
            }
        }
        $result.status = if ($WhatIfPreference) { 'planned' } else { 'configured' }
    }
    else {
        $controlMatches = @($catalog.controls | Where-Object id -ieq $Control)
        if ($controlMatches.Count -ne 1) {
            $valid = @($catalog.controls.id) -join ', '
            throw "Unknown control '$Control'. Valid controls: $valid"
        }
        $selected = $controlMatches[0]
        Get-ADGroup -Identity $selected.groupName -ErrorAction Stop | Out-Null
        $target = Get-LabDirectoryObject -Definition $definition -SelectedControl $selected -RequestedIdentity $Identity
        $isMember = Test-LabDirectGroupMembership -GroupName $selected.groupName -DistinguishedName $target.Object.DistinguishedName

        if ($Access -eq 'Deny' -and -not $isMember -and $PSCmdlet.ShouldProcess($target.Object.Name, "Add to $($selected.groupName) and deny $($selected.displayName)")) {
            Add-ADGroupMember -Identity $selected.groupName -Members $target.Object -ErrorAction Stop
        }
        elseif ($Access -eq 'Allow' -and $isMember -and $PSCmdlet.ShouldProcess($target.Object.Name, "Remove from $($selected.groupName) and stop this lab GPO denial")) {
            Remove-ADGroupMember -Identity $selected.groupName -Members $target.Object -Confirm:$false -ErrorAction Stop
        }

        $isMember = Test-LabDirectGroupMembership -GroupName $selected.groupName -DistinguishedName $target.Object.DistinguishedName
        if (-not $WhatIfPreference -and (($Access -eq 'Deny') -ne $isMember)) {
            throw "Membership verification failed for $($target.Object.Name) in $($selected.groupName)."
        }

        $refreshTarget = $target.Workstation
        if (-not $refreshTarget -and $selected.scope -eq 'User') {
            $mappedVm = @($definition.virtualMachines | Where-Object { $_.user -and $_.user.samAccountName -ieq $target.Object.SamAccountName })
            if ($mappedVm.Count -eq 1) { $refreshTarget = $mappedVm[0].name }
        }
        $refreshResult = 'not-requested'
        if ($RefreshPolicy -and $refreshTarget -and $PSCmdlet.ShouldProcess($refreshTarget, 'Run remote Group Policy refresh')) {
            Invoke-GPUpdate -Computer $refreshTarget -RandomDelayInMinutes 0 -Force -ErrorAction Stop | Out-Null
            $refreshResult = 'requested'
        }
        elseif ($RefreshPolicy -and -not $refreshTarget) { $refreshResult = 'no-canonical-workstation' }

        $result.controls = @([ordered]@{
            id = $selected.id
            displayName = $selected.displayName
            scope = $selected.scope
            requestedIdentity = $Identity
            resolvedObject = $target.Object.Name
            resolution = $target.Resolution
            group = $selected.groupName
            access = $Access
            directDenyMembership = $isMember
            refresh = $refreshResult
            sessionAction = $selected.refresh
        })
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
    Write-LabLog -Level $(if ($result.status -eq 'failed') { 'Error' } else { 'Info' }) -Message "Access control $($result.status)" -Data @{ Demo = $Demo; Mode = $result.mode; Report = $OutputPath }
}

$result
