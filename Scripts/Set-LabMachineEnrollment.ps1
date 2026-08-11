#Requires -RunAsAdministrator
#Requires -Version 5.1
<#
.SYNOPSIS
    Enrolls, inspects, or disenrolls a physical or virtual Windows machine.
.DESCRIPTION
    Joins any supported Windows machine to a selected lab domain and canonical OU. The
    script is hypervisor-independent. Credentials are accepted only as PSCredential values
    or acquired interactively and are never written to the report or command line.
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)][ValidateSet('Enroll', 'Disenroll', 'Status')][string]$Action,
    [Parameter(Mandatory)][ValidateSet('asgard', 'olympus')][string]$Demo,
    [ValidateSet('Workstation', 'MemberServer')][string]$DeviceType = 'Workstation',
    [ValidatePattern('^(?!-)(?![0-9]+$)[A-Za-z0-9](?:[A-Za-z0-9-]{0,13}[A-Za-z0-9])?$')][string]$ComputerName,
    [switch]$LegacyDomain,
    [Management.Automation.PSCredential]$DomainCredential,
    [switch]$ConfigureDns,
    [string[]]$DnsServer,
    [string[]]$InterfaceAlias,
    [ValidatePattern('^(?!-)[A-Za-z0-9](?:[A-Za-z0-9-]{0,13}[A-Za-z0-9])?$')][string]$WorkgroupName = 'WORKGROUP',
    [ValidateSet('Preserve', 'Disable', 'Delete')][string]$DirectoryDisposition = 'Preserve',
    [switch]$ConfirmLocalAdministratorAccess,
    [string]$ConfirmDirectoryObjectDeletion,
    [switch]$RefreshPolicy,
    [switch]$Restart,
    [string]$DefinitionPath,
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$labRoot = Split-Path -Parent $PSScriptRoot
if (-not $DefinitionPath) { $DefinitionPath = Join-Path $labRoot "LabConfig\demos\$Demo.json" }
if (-not $OutputPath) { $OutputPath = Join-Path $labRoot 'Reports\machine-enrollment.json' }
$moduleCandidates = @(
    (Join-Path $labRoot 'Modules\WindowsServerLab\WindowsServerLab.psd1'),
    (Join-Path $PSScriptRoot 'WindowsServerLab\WindowsServerLab.psd1')
)
$modulePath = $moduleCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
if (-not $modulePath) { throw 'WindowsServerLab module not found beside the repository or installed lab files.' }
Import-Module $modulePath -Force -ErrorAction Stop

function Test-LabDomainConnectivity {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$DomainName)

    $records = @(Resolve-DnsName -Name "_ldap._tcp.dc._msdcs.$DomainName" -Type SRV -DnsOnly -ErrorAction Stop)
    $domainController = $records | Where-Object NameTarget | Sort-Object Priority, Weight | Select-Object -ExpandProperty NameTarget -First 1
    if (-not $domainController) { throw "No LDAP domain-controller SRV record was returned for $DomainName." }
    $domainController = $domainController.TrimEnd('.')
    $ports = [ordered]@{ Kerberos = 88; RPCEndpointMapper = 135; LDAP = 389; SMB = 445 }
    $checks = foreach ($entry in $ports.GetEnumerator()) {
        $reachable = Test-NetConnection -ComputerName $domainController -Port $entry.Value -InformationLevel Quiet -WarningAction Ignore
        [pscustomobject]@{ Service = $entry.Key; Port = $entry.Value; Passed = [bool]$reachable }
    }
    $failed = @($checks | Where-Object { -not $_.Passed })
    if ($failed.Count -gt 0) { throw "Required domain ports are unreachable on ${domainController}: $(($failed.Port -join ', '))." }
    [pscustomobject]@{ DomainController = $domainController; Checks = @($checks) }
}

function Set-LabEnrollmentNameServer {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string[]]$ServerAddress,
        [string[]]$RequestedInterfaceAlias
    )

    foreach ($address in $ServerAddress) {
        $parsedAddress = $null
        if (-not [Net.IPAddress]::TryParse($address, [ref]$parsedAddress)) { throw "Invalid DNS server address '$address'." }
    }
    $adapters = @(Get-NetAdapter -ErrorAction Stop | Where-Object { $_.Status -eq 'Up' -and $_.InterfaceDescription -notmatch 'Loopback|Teredo|isatap' })
    if ($adapters.Count -eq 0) { throw 'No active network adapter is available for DNS configuration.' }
    if ($RequestedInterfaceAlias) {
        $missingAliases = @($RequestedInterfaceAlias | Where-Object { $_ -notin $adapters.Name })
        if ($missingAliases.Count -gt 0) { throw "Requested active network adapters were not found: $($missingAliases -join ', ')." }
        $adapters = @($adapters | Where-Object { $_.Name -in $RequestedInterfaceAlias })
    }
    elseif ($adapters.Count -gt 1) {
        throw "Multiple active network adapters were found. Use -InterfaceAlias with one or more of: $($adapters.Name -join ', ')."
    }
    foreach ($adapter in $adapters) {
        if ($PSCmdlet.ShouldProcess($adapter.Name, "Set DNS servers to $($ServerAddress -join ', ')")) {
            Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses $ServerAddress -ErrorAction Stop
        }
    }
    @($adapters.Name)
}

$definition = Import-LabDefinition -Path $DefinitionPath
$domainName = if ($LegacyDomain) { $definition.domain.legacyDnsName } else { $definition.domain.dnsName }
$domainDn = ConvertTo-LabDistinguishedName -DomainName $domainName
$baseOu = "OU=$($definition.domain.baseOrganizationalUnit),$domainDn"
$targetOu = if ($DeviceType -eq 'Workstation') { "OU=Workstations,$baseOu" } else { "OU=Servers,$baseOu" }
$desiredName = if ($ComputerName) { $ComputerName.ToUpperInvariant() } else { $env:COMPUTERNAME.ToUpperInvariant() }
$computerSystem = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
$operatingSystem = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
$currentDomain = if ($computerSystem.PartOfDomain) { [string]$computerSystem.Domain } else { $null }

$result = [ordered]@{
    schemaVersion = 1
    timestamp = (Get-Date).ToUniversalTime().ToString('o')
    action = $Action
    demo = $Demo
    deviceType = $DeviceType
    originalComputerName = $env:COMPUTERNAME
    desiredComputerName = $desiredName
    targetDomain = $domainName
    targetOu = $targetOu
    operatingSystem = $operatingSystem.Caption
    virtualMachine = [bool]($computerSystem.Model -match 'Virtual|VMware|KVM|HVM|Hyper-V')
    status = 'planned'
    restartRequired = $false
    dnsAdaptersChanged = @()
    connectivity = $null
    directoryDisposition = $DirectoryDisposition
    localChangeCompleted = $false
    secureChannel = $null
    warnings = @()
}

try {
    if ($Action -eq 'Status') {
        $result.status = if ($computerSystem.PartOfDomain -and $currentDomain -ieq $domainName) { 'enrolled' } elseif ($computerSystem.PartOfDomain) { 'other-domain' } else { 'workgroup' }
        $result.currentDomain = $currentDomain
        if ($result.status -eq 'enrolled') {
            $result.secureChannel = Test-ComputerSecureChannel -ErrorAction Stop
            if (-not $result.secureChannel) { $result.status = 'secure-channel-failed' }
        }
    }
    elseif ($Action -eq 'Enroll') {
        if ($operatingSystem.Caption -match 'Windows .* Home') { throw 'Windows Home editions cannot join an Active Directory domain.' }
        if ($computerSystem.PartOfDomain -and $currentDomain -ine $domainName) {
            throw "This machine already belongs to '$currentDomain'. Explicitly disenroll it before joining '$domainName'."
        }

        if ($ConfigureDns) {
            if (-not $DnsServer) {
                $networkName = if ($DeviceType -eq 'Workstation') { 'client' } else { 'production' }
                $DnsServer = @($definition.networks.$networkName.dnsServers)
            }
            if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, 'Configure lab DNS client servers')) {
                $result.dnsAdaptersChanged = @(Set-LabEnrollmentNameServer -ServerAddress $DnsServer -RequestedInterfaceAlias $InterfaceAlias -Confirm:$false)
                Clear-DnsClientCache -ErrorAction Stop
            }
        }

        if (-not $WhatIfPreference) { $result.connectivity = Test-LabDomainConnectivity -DomainName $domainName }
        $alreadyEnrolled = $computerSystem.PartOfDomain -and $currentDomain -ieq $domainName -and $env:COMPUTERNAME -ieq $desiredName
        if ($alreadyEnrolled) {
            $result.secureChannel = Test-ComputerSecureChannel -ErrorAction Stop
            if (-not $result.secureChannel) { throw 'The machine is joined to the selected domain but its secure channel is unhealthy.' }
            $result.status = 'enrolled'
        }
        elseif ($PSCmdlet.ShouldProcess($desiredName, "Join $domainName in $targetOu")) {
            if (-not $DomainCredential) { $DomainCredential = Get-Credential -Message "Enter a delegated domain-join credential for $domainName" }
            if ($computerSystem.PartOfDomain) {
                Rename-Computer -NewName $desiredName -DomainCredential $DomainCredential -Force -ErrorAction Stop
            }
            else {
                $joinParameters = @{
                    DomainName = $domainName
                    OUPath = $targetOu
                    Credential = $DomainCredential
                    Force = $true
                    PassThru = $true
                    ErrorAction = 'Stop'
                }
                if ($env:COMPUTERNAME -ine $desiredName) { $joinParameters.NewName = $desiredName }
                Add-Computer @joinParameters | Out-Null
            }
            $result.status = 'enrolled-pending-restart'
            $result.restartRequired = $true
        }

        if ($RefreshPolicy -and $result.status -eq 'enrolled' -and $PSCmdlet.ShouldProcess($env:COMPUTERNAME, 'Refresh computer and user Group Policy')) {
            & gpupdate.exe /force /wait:120
            if ($LASTEXITCODE -ne 0) { throw "gpupdate failed with exit code $LASTEXITCODE." }
        }
    }
    else {
        if (-not $ConfirmLocalAdministratorAccess) {
            throw 'Disenrollment requires -ConfirmLocalAdministratorAccess after verifying a working local administrator account.'
        }
        if (-not $computerSystem.PartOfDomain) {
            $result.status = 'already-disenrolled'
        }
        else {
            if ($currentDomain -notin @($definition.domain.dnsName, $definition.domain.legacyDnsName)) {
                throw "Current domain '$currentDomain' is not owned by the selected demo; refusing to disenroll it."
            }
            if ($DirectoryDisposition -eq 'Delete' -and $ConfirmDirectoryObjectDeletion -cne $env:COMPUTERNAME) {
                throw "Deleting the directory object requires -ConfirmDirectoryObjectDeletion '$env:COMPUTERNAME'."
            }
            if ($DirectoryDisposition -ne 'Preserve' -and -not (Get-Module -ListAvailable ActiveDirectory)) {
                throw 'The ActiveDirectory module (RSAT) is required for Disable or Delete directory disposition. No changes were made.'
            }
            if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, "Leave $currentDomain and join workgroup $WorkgroupName")) {
                if (-not $DomainCredential) { $DomainCredential = Get-Credential -Message "Enter a delegated unjoin credential for $currentDomain" }
                $directoryObject = $null
                if ($DirectoryDisposition -ne 'Preserve') {
                    Import-Module ActiveDirectory -ErrorAction Stop
                    $directoryObject = Get-ADComputer -Identity $env:COMPUTERNAME -Server $currentDomain -Credential $DomainCredential -ErrorAction Stop
                }
                Remove-Computer -UnjoinDomainCredential $DomainCredential -WorkgroupName $WorkgroupName -Force -PassThru -ErrorAction Stop | Out-Null
                $result.localChangeCompleted = $true
                $result.restartRequired = $true
                if ($DirectoryDisposition -eq 'Disable') {
                    Disable-ADAccount -Identity $directoryObject.DistinguishedName -Server $currentDomain -Credential $DomainCredential -ErrorAction Stop
                    $disabledObject = Get-ADComputer -Identity $directoryObject.DistinguishedName -Properties Enabled -Server $currentDomain -Credential $DomainCredential -ErrorAction Stop
                    if ($disabledObject.Enabled) { throw 'The AD computer object remained enabled after the disable request.' }
                }
                elseif ($DirectoryDisposition -eq 'Delete') {
                    Remove-ADComputer -Identity $directoryObject.DistinguishedName -Server $currentDomain -Credential $DomainCredential -Confirm:$false -ErrorAction Stop
                    if (Get-ADComputer -Identity $directoryObject.DistinguishedName -Server $currentDomain -Credential $DomainCredential -ErrorAction Ignore) {
                        throw 'The AD computer object still exists after the delete request.'
                    }
                }
                else {
                    $result.warnings += 'The AD computer object was preserved. Disable or delete it from an RSAT-equipped administrative system when retention is no longer required.'
                }
                $result.status = 'disenrolled-pending-restart'
            }
        }
    }
}
catch {
    $result.status = if ($result.localChangeCompleted) { 'failed-after-local-change' } else { 'failed' }
    $result.error = $_.Exception.Message
    throw
}
finally {
    $reportDirectory = Split-Path -Parent $OutputPath
    if ($reportDirectory -and -not (Test-Path -LiteralPath $reportDirectory)) { New-Item -Path $reportDirectory -ItemType Directory -Force | Out-Null }
    $result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
    Write-LabLog -Level $(if ($result.status -like 'failed*') { 'Error' } else { 'Info' }) -Message "Machine enrollment $($result.status)" -Data @{ Action = $Action; Demo = $Demo; Report = $OutputPath }
}

$result
if ($Restart -and $result.restartRequired -and $PSCmdlet.ShouldProcess($env:COMPUTERNAME, 'Restart to complete the enrollment change')) {
    Restart-Computer -Force
}
if ($result.status -eq 'secure-channel-failed') { exit 1 }
