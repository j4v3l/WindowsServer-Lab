#Requires -RunAsAdministrator
#Requires -Version 5.1
<#
.SYNOPSIS
    Creates or reconciles an AD-published shared printer on the canonical file/print server.
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)][ValidateSet('asgard', 'olympus')][string]$Demo,
    [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9][A-Za-z0-9 ._-]{0,62}[A-Za-z0-9]$')][string]$PrinterName,
    [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9][A-Za-z0-9_-]{0,30}[A-Za-z0-9]$')][string]$ShareName,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$DriverName,
    [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9.-]+$')][string]$PrinterAddress,
    [ValidatePattern('^[A-Za-z0-9._-]+$')][string]$PortName,
    [string]$Location = 'WindowsServerLab',
    [string]$Comment = 'AD-published WindowsServerLab shared printer',
    [string]$DriverInfPath,
    [ValidatePattern('^[A-Fa-f0-9]{64}$')][string]$DriverInfSha256,
    [string]$DefinitionPath,
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = 'C:\ProgramData\WindowsServerLab'
if (-not $DefinitionPath) { $DefinitionPath = Join-Path $root "LabConfig\demos\$Demo.json" }
if (-not $OutputPath) { $OutputPath = Join-Path $root "Reports\shared-printer-$ShareName.json" }
if (-not $PortName) { $PortName = "IP_$PrinterAddress" }
if (($DriverInfPath -and -not $DriverInfSha256) -or ($DriverInfSha256 -and -not $DriverInfPath)) { throw 'DriverInfPath and DriverInfSha256 must be supplied together.' }

Import-Module (Join-Path $root 'Modules\WindowsServerLab\WindowsServerLab.psd1') -Force -ErrorAction Stop
$definition = Import-LabDefinition -Path $DefinitionPath
$fileServer = @($definition.virtualMachines | Where-Object role -eq 'file-server')
if ($fileServer.Count -ne 1 -or $env:COMPUTERNAME -ine $fileServer[0].name) { throw "Run this command on the canonical file/print server '$($fileServer[0].name)'." }
$computerSystem = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
if (-not $computerSystem.PartOfDomain -or $computerSystem.Domain -notin @($definition.domain.dnsName, $definition.domain.legacyDnsName)) { throw 'The print server is not joined to the selected demo domain.' }
$domain = $computerSystem.Domain
$denyAccount = "$($definition.domain.netbiosName)\ACL-Print-Deny"
$adminAccount = "$($definition.domain.netbiosName)\ACL-Print-Admin"
$denySid = [Security.Principal.NTAccount]::new($denyAccount).Translate([Security.Principal.SecurityIdentifier]).Value
$adminSid = [Security.Principal.NTAccount]::new($adminAccount).Translate([Security.Principal.SecurityIdentifier]).Value
$permissionSddl = "O:BAG:BAD:P(D;;0x20008;;;$denySid)(A;;0xF000C;;;BA)(A;;0xF000C;;;$adminSid)(A;;0x20008;;;AU)(A;OIIO;0xF0030;;;CO)"

$result = [ordered]@{
    schemaVersion = 1
    timestamp = (Get-Date).ToUniversalTime().ToString('o')
    demo = $Demo
    server = $env:COMPUTERNAME
    printer = $PrinterName
    shareName = $ShareName
    connectionName = "\\$env:COMPUTERNAME.$domain\$ShareName"
    address = $PrinterAddress
    driver = $DriverName
    published = $false
    aclVerified = $false
    status = 'planned'
}

try {
    if ($PSCmdlet.ShouldProcess($PrinterName, "Create or reconcile shared printer $ShareName")) {
        Import-Module ServerManager -ErrorAction Stop
        if (-not (Get-WindowsFeature Print-Server -ErrorAction Stop).Installed) {
            Install-WindowsFeature Print-Server -IncludeManagementTools -ErrorAction Stop | Out-Null
        }
        Import-Module PrintManagement -ErrorAction Stop
        Set-Service Spooler -StartupType Automatic -ErrorAction Stop
        Start-Service Spooler -ErrorAction Stop

        if (-not (Get-PrinterDriver -Name $DriverName -ErrorAction Ignore)) {
            if (-not $DriverInfPath) { throw "Printer driver '$DriverName' is not installed. Supply a signed INF and SHA-256 digest." }
            if (-not (Test-Path -LiteralPath $DriverInfPath -PathType Leaf)) { throw "Driver INF not found: $DriverInfPath" }
            $actualHash = (Get-FileHash -LiteralPath $DriverInfPath -Algorithm SHA256 -ErrorAction Stop).Hash
            if ($actualHash -ine $DriverInfSha256) { throw 'Printer driver INF checksum verification failed.' }
            & pnputil.exe /add-driver $DriverInfPath /install | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "pnputil failed with exit code $LASTEXITCODE." }
            Add-PrinterDriver -Name $DriverName -ErrorAction Stop
        }
        $driver = Get-PrinterDriver -Name $DriverName -ErrorAction Stop
        if ($driver.PSObject.Properties.Name -contains 'IsPackageAware' -and -not $driver.IsPackageAware) { throw 'The selected driver is not package-aware and is rejected by the lab print policy.' }

        if (-not (Get-PrinterPort -Name $PortName -ErrorAction Ignore)) {
            Add-PrinterPort -Name $PortName -PrinterHostAddress $PrinterAddress -ErrorAction Stop
        }
        $printer = Get-Printer -Name $PrinterName -ErrorAction Ignore
        if (-not $printer) {
            Add-Printer -Name $PrinterName -DriverName $DriverName -PortName $PortName -Shared -ShareName $ShareName -Published -Location $Location -Comment $Comment -PermissionSDDL $permissionSddl -ErrorAction Stop
        }
        else {
            Set-Printer -Name $PrinterName -DriverName $DriverName -PortName $PortName -Shared $true -ShareName $ShareName -Published $true -Location $Location -Comment $Comment -PermissionSDDL $permissionSddl -ErrorAction Stop
        }

        $printer = Get-Printer -Name $PrinterName -Full -ErrorAction Stop
        if (-not $printer.Shared -or -not $printer.Published -or $printer.ShareName -ne $ShareName -or $printer.PortName -ne $PortName -or $printer.DriverName -ne $DriverName) {
            throw 'Shared printer configuration verification failed.'
        }
        $descriptor = [Security.AccessControl.RawSecurityDescriptor]::new($printer.PermissionSDDL)
        $denyAce = $descriptor.DiscretionaryAcl | Where-Object { $_.SecurityIdentifier.Value -eq $denySid -and $_.AceType -eq 'AccessDenied' -and ($_.AccessMask -band 0x20008) -eq 0x20008 }
        $adminAce = $descriptor.DiscretionaryAcl | Where-Object { $_.SecurityIdentifier.Value -eq $adminSid -and $_.AceType -eq 'AccessAllowed' -and ($_.AccessMask -band 0xF000C) -eq 0xF000C }
        if (-not $denyAce -or -not $adminAce) { throw 'Printer permission verification failed.' }
        $result.published = $true
        $result.aclVerified = $true
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
    Write-LabLog -Level $(if ($result.status -eq 'failed') { 'Error' } else { 'Info' }) -Message "Shared printer $($result.status)" -Data @{ Demo = $Demo; Printer = $PrinterName; Report = $OutputPath }
}

$result
