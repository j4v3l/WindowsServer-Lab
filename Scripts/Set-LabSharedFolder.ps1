#Requires -RunAsAdministrator
#Requires -Version 5.1
<#
.SYNOPSIS
    Creates or reconciles an encrypted SMB share with matching share and NTFS policy.
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)][ValidateSet('asgard', 'olympus')][string]$Demo,
    [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9][A-Za-z0-9_-]{0,30}[A-Za-z0-9]$')][string]$ShareName,
    [Parameter(Mandatory)][ValidatePattern('^[A-Za-z]:\\')][string]$Path,
    [string]$Description = 'WindowsServerLab managed file share',
    [ValidatePattern('^[A-Za-z0-9-]{1,20}$')][string]$ReadGroupName,
    [ValidatePattern('^[A-Za-z0-9-]{1,20}$')][string]$ChangeGroupName,
    [ValidatePattern('^[A-Za-z0-9-]{1,20}$')][string]$DenyGroupName,
    [switch]$AdoptExistingPath,
    [string]$DefinitionPath,
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = 'C:\ProgramData\WindowsServerLab'
if (-not $DefinitionPath) { $DefinitionPath = Join-Path $root "LabConfig\demos\$Demo.json" }
if (-not $OutputPath) { $OutputPath = Join-Path $root "Reports\shared-folder-$ShareName.json" }
$groupToken = ($ShareName -replace '[^A-Za-z0-9]', '').ToUpperInvariant()
if ($groupToken.Length -gt 10) { $groupToken = $groupToken.Substring(0, 10) }
if (-not $ReadGroupName) { $ReadGroupName = "FS-$groupToken-R" }
if (-not $ChangeGroupName) { $ChangeGroupName = "FS-$groupToken-RW" }
if (-not $DenyGroupName) { $DenyGroupName = "FS-$groupToken-D" }

Import-Module (Join-Path $root 'Modules\WindowsServerLab\WindowsServerLab.psd1') -Force -ErrorAction Stop
$definition = Import-LabDefinition -Path $DefinitionPath
$fileServer = @($definition.virtualMachines | Where-Object role -eq 'file-server')
if ($fileServer.Count -ne 1 -or $env:COMPUTERNAME -ine $fileServer[0].name) { throw "Run this command on the canonical file server '$($fileServer[0].name)'." }
$computerSystem = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
if (-not $computerSystem.PartOfDomain -or $computerSystem.Domain -notin @($definition.domain.dnsName, $definition.domain.legacyDnsName)) { throw 'The file server is not joined to the selected demo domain.' }
$domainPrefix = $definition.domain.netbiosName
$accounts = [ordered]@{
    Read = "$domainPrefix\$ReadGroupName"
    Change = "$domainPrefix\$ChangeGroupName"
    Deny = "$domainPrefix\$DenyGroupName"
}
foreach ($account in $accounts.Values) { $null = [Security.Principal.NTAccount]::new($account).Translate([Security.Principal.SecurityIdentifier]) }

$result = [ordered]@{
    schemaVersion = 1
    timestamp = (Get-Date).ToUniversalTime().ToString('o')
    demo = $Demo
    server = $env:COMPUTERNAME
    shareName = $ShareName
    path = $Path
    uncPath = "\\$env:COMPUTERNAME.$($computerSystem.Domain)\$ShareName"
    groups = $accounts
    shareAclVerified = $false
    ntfsAclVerified = $false
    status = 'planned'
    warnings = @()
}

try {
    $existingShare = Get-SmbShare -Name $ShareName -ErrorAction Ignore
    if ($existingShare -and $existingShare.Path -ine $Path) { throw "Share '$ShareName' already points to '$($existingShare.Path)'; refusing to repoint it." }
    if (Test-Path -LiteralPath $Path) {
        $existingItems = @(Get-ChildItem -LiteralPath $Path -Force -ErrorAction Stop | Select-Object -First 1)
        if ($existingItems.Count -gt 0 -and -not $AdoptExistingPath) {
            throw 'The target directory contains data. Use -AdoptExistingPath only after reviewing its existing permissions and backup.'
        }
    }

    if ($PSCmdlet.ShouldProcess("$ShareName ($Path)", 'Create or reconcile encrypted SMB share and NTFS ACL')) {
        Import-Module ServerManager -ErrorAction Stop
        if (-not (Get-WindowsFeature FS-FileServer -ErrorAction Stop).Installed) { Install-WindowsFeature FS-FileServer -IncludeManagementTools -ErrorAction Stop | Out-Null }
        if (-not (Test-Path -LiteralPath $Path)) { New-Item -Path $Path -ItemType Directory -Force -ErrorAction Stop | Out-Null }

        $acl = [Security.AccessControl.DirectorySecurity]::new()
        $acl.SetOwner([Security.Principal.NTAccount]::new('BUILTIN\Administrators'))
        $acl.SetAccessRuleProtection($true, $false)
        $inheritance = [Security.AccessControl.InheritanceFlags]'ContainerInherit, ObjectInherit'
        $propagation = [Security.AccessControl.PropagationFlags]::None
        $allow = [Security.AccessControl.AccessControlType]::Allow
        $deny = [Security.AccessControl.AccessControlType]::Deny
        $rules = @(
            [Security.AccessControl.FileSystemAccessRule]::new('NT AUTHORITY\SYSTEM', 'FullControl', $inheritance, $propagation, $allow),
            [Security.AccessControl.FileSystemAccessRule]::new('BUILTIN\Administrators', 'FullControl', $inheritance, $propagation, $allow),
            [Security.AccessControl.FileSystemAccessRule]::new($accounts.Change, 'Modify', $inheritance, $propagation, $allow),
            [Security.AccessControl.FileSystemAccessRule]::new($accounts.Read, 'ReadAndExecute', $inheritance, $propagation, $allow),
            [Security.AccessControl.FileSystemAccessRule]::new($accounts.Deny, 'FullControl', $inheritance, $propagation, $deny)
        )
        foreach ($rule in $rules) { $acl.AddAccessRule($rule) | Out-Null }
        Set-Acl -LiteralPath $Path -AclObject $acl -ErrorAction Stop
        if ($AdoptExistingPath) { $result.warnings += 'Root and inheriting-child ACLs were reconciled. Existing children with inheritance disabled require a separately reviewed remediation.' }

        if (-not $existingShare) {
            New-SmbShare -Name $ShareName -Path $Path -Description $Description -FullAccess 'BUILTIN\Administrators' -ChangeAccess $accounts.Change -ReadAccess $accounts.Read -EncryptData $true -FolderEnumerationMode AccessBased -CachingMode None -ErrorAction Stop | Out-Null
        }
        else {
            Set-SmbShare -Name $ShareName -Description $Description -EncryptData $true -FolderEnumerationMode AccessBased -CachingMode None -Force -ErrorAction Stop | Out-Null
            foreach ($account in @('Everyone', 'Authenticated Users', $accounts.Read, $accounts.Change, $accounts.Deny)) {
                Revoke-SmbShareAccess -Name $ShareName -AccountName $account -Force -ErrorAction Ignore | Out-Null
                Unblock-SmbShareAccess -Name $ShareName -AccountName $account -Force -ErrorAction Ignore | Out-Null
            }
            Grant-SmbShareAccess -Name $ShareName -AccountName $accounts.Read -AccessRight Read -Force -ErrorAction Stop | Out-Null
            Grant-SmbShareAccess -Name $ShareName -AccountName $accounts.Change -AccessRight Change -Force -ErrorAction Stop | Out-Null
        }
        Block-SmbShareAccess -Name $ShareName -AccountName $accounts.Deny -Force -ErrorAction Stop | Out-Null

        $share = Get-SmbShare -Name $ShareName -ErrorAction Stop
        if (-not $share.EncryptData -or $share.FolderEnumerationMode -ne 'AccessBased' -or $share.Path -ine $Path) { throw 'SMB share configuration verification failed.' }
        $shareAccess = @(Get-SmbShareAccess -Name $ShareName -ErrorAction Stop)
        $readAccess = $shareAccess | Where-Object { $_.AccountName -eq $accounts.Read -and $_.AccessControlType -eq 'Allow' -and $_.AccessRight -eq 'Read' }
        $changeAccess = $shareAccess | Where-Object { $_.AccountName -eq $accounts.Change -and $_.AccessControlType -eq 'Allow' -and $_.AccessRight -in @('Change', 'Full') }
        $denyAccess = $shareAccess | Where-Object { $_.AccountName -eq $accounts.Deny -and $_.AccessControlType -eq 'Deny' }
        if (-not $readAccess -or -not $changeAccess -or -not $denyAccess) { throw 'SMB share permission verification failed.' }
        $result.shareAclVerified = $true

        $actualAcl = Get-Acl -LiteralPath $Path -ErrorAction Stop
        $readMask = [Security.AccessControl.FileSystemRights]::ReadAndExecute
        $changeMask = [Security.AccessControl.FileSystemRights]::Modify
        $readRule = $actualAcl.Access | Where-Object { $_.IdentityReference.Value -eq $accounts.Read -and $_.AccessControlType -eq 'Allow' -and ($_.FileSystemRights -band $readMask) -eq $readMask }
        $changeRule = $actualAcl.Access | Where-Object { $_.IdentityReference.Value -eq $accounts.Change -and $_.AccessControlType -eq 'Allow' -and ($_.FileSystemRights -band $changeMask) -eq $changeMask }
        $denyRule = $actualAcl.Access | Where-Object { $_.IdentityReference.Value -eq $accounts.Deny -and $_.AccessControlType -eq 'Deny' }
        if (-not $readRule -or -not $changeRule -or -not $denyRule) { throw 'NTFS permission verification failed.' }
        $result.ntfsAclVerified = $true
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
    $result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
    Write-LabLog -Level $(if ($result.status -eq 'failed') { 'Error' } else { 'Info' }) -Message "Shared folder $($result.status)" -Data @{ Demo = $Demo; Share = $ShareName; Report = $OutputPath }
}

$result
