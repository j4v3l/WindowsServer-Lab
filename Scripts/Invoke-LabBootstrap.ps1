#Requires -RunAsAdministrator
#Requires -Version 5.1
<#
.SYNOPSIS
    Reconciles one WindowsServerLab v2 guest from its canonical demo definition.
.DESCRIPTION
    The first Cloudbase-Init run installs prerequisites and records pending steps. Domain
    promotion and joins require an interactive SecureString/PSCredential or an offline-domain-
    join blob; credentials are never accepted as plaintext strings.
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)][ValidateSet('asgard', 'olympus')][string]$Demo,
    [Parameter(Mandatory)][Alias('Profile')][ValidateSet('smoke', 'core', 'full')][string]$LabProfile,
    [Parameter(Mandatory)][int]$VmId,
    [Parameter(Mandatory)][ValidateSet('primary-dc', 'secondary-dc', 'file-server', 'web-server', 'management-server', 'client', 'aiml-client')][string]$Role,
    [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9.-]+$')][string]$DomainName,
    [Security.SecureString]$DsrmPassword,
    [Security.SecureString]$DefaultUserPassword,
    [Management.Automation.PSCredential]$DomainCredential,
    [string]$OfflineDomainJoinFile,
    [switch]$CreatePrivilegedAccounts,
    [switch]$ApplySecurityBaseline,
    [string]$SctBaselinePath,
    [string]$SctBaselineSha256,
    [switch]$Restart
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = 'C:\ProgramData\WindowsServerLab'
$modulePath = Join-Path $root 'Modules\WindowsServerLab\WindowsServerLab.psd1'
$definitionPath = Join-Path $root "LabConfig\demos\$Demo.json"
$reportPath = Join-Path $root "Reports\bootstrap-$VmId.json"
$continuationTask = "WindowsServerLab-Bootstrap-$VmId"
Import-Module $modulePath -Force -ErrorAction Stop
$definition = Import-LabDefinition -Path $definitionPath
Test-LabConfiguration -Definition $definition -LabProfile $LabProfile -ThrowOnFailure | Out-Null

$vm = @($definition.virtualMachines | Where-Object { $_.id -eq $VmId })
if ($vm.Count -ne 1) { throw "VM ID $VmId is not unique in the $Demo definition." }
if ($vm[0].role -ne $Role) { throw "Role mismatch for VM ${VmId}: expected $($vm[0].role), received $Role." }
if ($DomainName -notin @($definition.domain.dnsName, $definition.domain.legacyDnsName)) { throw "Domain $DomainName is not allowed by the definition." }

$state = [ordered]@{
    schemaVersion = 2
    demo          = $Demo
    profile       = $LabProfile
    vmId          = $VmId
    computerName  = $env:COMPUTERNAME
    role          = $Role
    domain        = $DomainName
    timestamp     = (Get-Date).ToUniversalTime().ToString('o')
    status        = 'configuring'
    pending       = @()
}

try {
    if ($env:COMPUTERNAME -eq $vm[0].name -and (Get-ScheduledTask -TaskName $continuationTask -ErrorAction Ignore) -and $PSCmdlet.ShouldProcess($continuationTask, 'Remove completed rename continuation task')) {
        Unregister-ScheduledTask -TaskName $continuationTask -Confirm:$false -ErrorAction Stop
    }
    if ($env:COMPUTERNAME -ne $vm[0].name) {
        if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, "Rename computer to $($vm[0].name)")) {
            Rename-Computer -NewName $vm[0].name -Force -ErrorAction Stop
            $state.pending += 'restart-after-rename'
            if ($Restart) {
                $arguments = '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy RemoteSigned -File "{0}" -Demo {1} -LabProfile {2} -VmId {3} -Role {4} -DomainName {5}' -f $PSCommandPath, $Demo, $LabProfile, $VmId, $Role, $DomainName
                $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arguments
                $trigger = New-ScheduledTaskTrigger -AtStartup
                $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
                Register-ScheduledTask -TaskName $continuationTask -Action $action -Trigger $trigger -Principal $principal -Force | Out-Null
            }
        }
    }

    & (Join-Path $root 'Scripts\Initialize-LabDataDisks.ps1') -Demo $Demo -LabProfile $LabProfile -VmId $VmId -DefinitionPath $definitionPath -Confirm:$false | Out-Null

    Install-LabRole -Role $Role -Definition $definition -Confirm:$false
    $computerSystem = Get-CimInstance Win32_ComputerSystem

    if ($state.pending -notcontains 'restart-after-rename') {
      if ($Role -eq 'primary-dc' -and -not (Get-Service NTDS -ErrorAction Ignore)) {
        if (-not $DsrmPassword) {
            $state.pending += 'interactive-primary-domain-promotion'
        }
        elseif ($PSCmdlet.ShouldProcess($DomainName, 'Create new AD DS forest')) {
            Import-Module ADDSDeployment -ErrorAction Stop
            Install-ADDSForest -DomainName $DomainName -DomainNetbiosName $definition.domain.netbiosName -SafeModeAdministratorPassword $DsrmPassword -InstallDNS -NoRebootOnCompletion -Force -ErrorAction Stop
            $state.pending += 'restart-after-primary-domain-promotion'
        }
    }
    elseif ($Role -eq 'secondary-dc' -and -not (Get-Service NTDS -ErrorAction Ignore)) {
        if (-not $computerSystem.PartOfDomain) {
            if ($OfflineDomainJoinFile) {
                if (-not (Test-Path -LiteralPath $OfflineDomainJoinFile)) { throw "Offline domain join file not found: $OfflineDomainJoinFile" }
                & djoin.exe /requestODJ /loadfile $OfflineDomainJoinFile /windowspath $env:SystemRoot /localos
                if ($LASTEXITCODE -ne 0) { throw "djoin request failed with exit code $LASTEXITCODE" }
                Remove-Item -LiteralPath $OfflineDomainJoinFile -Force
                $state.pending += 'restart-after-offline-domain-join'
            }
            elseif ($DomainCredential) {
                Add-Computer -DomainName $DomainName -Credential $DomainCredential -ErrorAction Stop
                $state.pending += 'restart-after-domain-join'
            }
            else { $state.pending += 'domain-credential-or-offline-join-required' }
        }
        elseif (-not $DsrmPassword -or -not $DomainCredential) {
            $state.pending += 'interactive-secondary-domain-promotion'
        }
        elseif ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, 'Promote replica domain controller')) {
            Import-Module ADDSDeployment -ErrorAction Stop
            Install-ADDSDomainController -DomainName $DomainName -Credential $DomainCredential -SafeModeAdministratorPassword $DsrmPassword -InstallDNS -NoRebootOnCompletion -Force -ErrorAction Stop
            $state.pending += 'restart-after-secondary-domain-promotion'
        }
    }
    elseif ($Role -notin @('primary-dc', 'secondary-dc') -and -not $computerSystem.PartOfDomain) {
        if ($OfflineDomainJoinFile) {
            if (-not (Test-Path -LiteralPath $OfflineDomainJoinFile)) { throw "Offline domain join file not found: $OfflineDomainJoinFile" }
            & djoin.exe /requestODJ /loadfile $OfflineDomainJoinFile /windowspath $env:SystemRoot /localos
            if ($LASTEXITCODE -ne 0) { throw "djoin request failed with exit code $LASTEXITCODE" }
            Remove-Item -LiteralPath $OfflineDomainJoinFile -Force
            $state.pending += 'restart-after-offline-domain-join'
        }
        elseif ($DomainCredential) {
            $domainDn = ConvertTo-LabDistinguishedName -DomainName $DomainName
            $baseOu = "OU=$($definition.domain.baseOrganizationalUnit),$domainDn"
            $joinOu = if ($Role -in @('client', 'aiml-client')) { "OU=Workstations,$baseOu" } else { "OU=Servers,$baseOu" }
            Add-Computer -DomainName $DomainName -Credential $DomainCredential -OUPath $joinOu -ErrorAction Stop
            $state.pending += 'restart-after-domain-join'
        }
        else { $state.pending += 'domain-credential-or-offline-join-required' }
    }
    }

    if ($Role -eq 'management-server' -and $computerSystem.PartOfDomain) {
        & (Join-Path $root 'Scripts\Enable-LabEventForwarding.ps1') -Confirm:$false
    }

    if ($computerSystem.PartOfDomain) {
        & (Join-Path $root 'Scripts\Enable-LabPowerShellRemoting.ps1') -Confirm:$false
    }

    if ((Get-Service NTDS -ErrorAction Ignore) -and $DefaultUserPassword) {
        Initialize-LabDirectory -Definition $definition -DefaultUserPassword $DefaultUserPassword -CreatePrivilegedAccounts:$CreatePrivilegedAccounts -Confirm:$false
        if ($Role -eq 'primary-dc') { Set-LabDhcpService -Definition $definition -Confirm:$false }
    }

    if ($ApplySecurityBaseline -and $Role -notin @('client', 'aiml-client')) {
        $baselineRole = if ($Role -in @('primary-dc', 'secondary-dc')) { 'DomainController' } else { 'MemberServer' }
        Set-LabSecurityBaseline -ServerRole $baselineRole -SctBaselinePath $SctBaselinePath -SctBaselineSha256 $SctBaselineSha256 -EnableAppControl -Confirm:$false
        $state.pending += 'restart-after-security-baseline'
    }

    $state.status = if ($state.pending.Count -eq 0) { 'configured' } else { 'pending' }
}
catch {
    $state.status = 'failed'
    $state.error = $_.Exception.Message
    throw
}
finally {
    $directory = Split-Path -Parent $reportPath
    if (-not (Test-Path -LiteralPath $directory)) { New-Item -Path $directory -ItemType Directory -Force | Out-Null }
    $state | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $reportPath -Encoding UTF8
    $level = if ($state.status -eq 'failed') { 'Error' } elseif ($state.status -eq 'pending') { 'Warning' } else { 'Info' }
    Write-LabLog -Level $level -Message "Bootstrap $($state.status) for VM $VmId" -Data @{ Role = $Role; Pending = @($state.pending) }
}

if ($Restart -and @($state.pending | Where-Object { $_ -like 'restart-*' }).Count -gt 0) {
    Restart-Computer -Force
}
