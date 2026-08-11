#Requires -RunAsAdministrator
#Requires -Version 5.1
<#
.SYNOPSIS
    Adds or removes a canonical shared-printer connection on any domain endpoint.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][ValidateSet('Add', 'Remove')][string]$Action,
    [Parameter(Mandatory)][ValidateSet('asgard', 'olympus')][string]$Demo,
    [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9][A-Za-z0-9_-]{0,30}[A-Za-z0-9]$')][string]$ShareName,
    [string]$DefinitionPath,
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$labRoot = Split-Path -Parent $PSScriptRoot
if (-not $DefinitionPath) { $DefinitionPath = Join-Path $labRoot "LabConfig\demos\$Demo.json" }
if (-not $OutputPath) { $OutputPath = Join-Path $labRoot "Reports\printer-connection-$ShareName.json" }
$definition = Get-Content -LiteralPath $DefinitionPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
if ($definition.schemaVersion -ne 2 -or $definition.demo -ne $Demo) { throw 'Invalid or mismatched lab definition.' }
$computerSystem = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
if (-not $computerSystem.PartOfDomain -or $computerSystem.Domain -notin @($definition.domain.dnsName, $definition.domain.legacyDnsName)) { throw 'This endpoint is not joined to the selected demo domain.' }
$printServer = @($definition.virtualMachines | Where-Object role -eq 'file-server')
if ($printServer.Count -ne 1) { throw 'The definition must contain exactly one file/print server.' }
$printServerFqdn = "$($printServer[0].name).$($computerSystem.Domain)"
$connectionName = "\\$printServerFqdn\$ShareName"

$result = [ordered]@{
    schemaVersion = 1
    timestamp = (Get-Date).ToUniversalTime().ToString('o')
    action = $Action
    demo = $Demo
    computer = $env:COMPUTERNAME
    connectionName = $connectionName
    status = 'planned'
}
try {
    if (-not (Test-NetConnection -ComputerName $printServerFqdn -Port 445 -InformationLevel Quiet -WarningAction Ignore)) { throw "The print server is unreachable on TCP 445: $printServerFqdn" }
    Import-Module PrintManagement -ErrorAction Stop
    $existing = Get-Printer -ErrorAction Stop | Where-Object Name -ieq $connectionName
    if ($Action -eq 'Add' -and -not $existing -and $PSCmdlet.ShouldProcess($connectionName, 'Add shared-printer connection')) {
        Add-Printer -ConnectionName $connectionName -ErrorAction Stop
    }
    elseif ($Action -eq 'Remove' -and $existing -and $PSCmdlet.ShouldProcess($connectionName, 'Remove shared-printer connection')) {
        Remove-Printer -Name $connectionName -ErrorAction Stop
    }
    $existing = Get-Printer -ErrorAction Stop | Where-Object Name -ieq $connectionName
    if (-not $WhatIfPreference -and (($Action -eq 'Add') -ne [bool]$existing)) { throw 'Printer connection verification failed.' }
    $result.status = if ($WhatIfPreference) { 'planned' } elseif ($existing) { 'connected' } else { 'removed' }
}
catch {
    $result.status = 'failed'
    $result.error = $_.Exception.Message
    throw
}
finally {
    $reportDirectory = Split-Path -Parent $OutputPath
    if ($reportDirectory -and -not (Test-Path -LiteralPath $reportDirectory)) { New-Item -Path $reportDirectory -ItemType Directory -Force | Out-Null }
    $result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
}
$result
