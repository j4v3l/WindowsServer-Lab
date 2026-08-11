#Requires -RunAsAdministrator
#Requires -Version 5.1
<#
.SYNOPSIS
    Activates or audits Windows licensing across a canonical lab profile.
.DESCRIPTION
    Prompts once for each required product key and transmits SecureString objects over
    authenticated PowerShell remoting. Keys are never persisted or placed in process
    arguments. Run this after domain enrollment from an administrative machine.
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)][ValidateSet('Activate', 'Status')][string]$Action,
    [Parameter(Mandatory)][ValidateSet('asgard', 'olympus')][string]$Demo,
    [Parameter(Mandatory)][Alias('Profile')][ValidateSet('smoke', 'core', 'full')][string]$LabProfile,
    [ValidateSet('Servers', 'All')][string]$Scope = 'All',
    [Security.SecureString]$ServerProductKey,
    [Security.SecureString]$Windows11EducationProductKey,
    [string]$ServerProductKeySecretName,
    [string]$Windows11EducationProductKeySecretName,
    [string]$SecretVaultName,
    [Management.Automation.PSCredential]$Credential,
    [string]$DefinitionPath,
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = 'C:\ProgramData\WindowsServerLab'
if (-not $DefinitionPath) { $DefinitionPath = Join-Path $root "LabConfig\demos\$Demo.json" }
if (-not $OutputPath) { $OutputPath = Join-Path $root 'Reports\windows-activation-fleet.json' }
$moduleCandidates = @(
    (Join-Path $root 'Modules\WindowsServerLab\WindowsServerLab.psd1'),
    (Join-Path $PSScriptRoot 'WindowsServerLab\WindowsServerLab.psd1')
)
$modulePath = $moduleCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
if (-not $modulePath) { throw 'WindowsServerLab module was not found.' }
Import-Module $modulePath -Force -ErrorAction Stop

$definition = Import-LabDefinition -Path $DefinitionPath
$targets = @(Get-LabProfileVirtualMachine -Definition $definition -LabProfile $LabProfile)
if ($Scope -eq 'Servers') { $targets = @($targets | Where-Object role -notin @('client', 'aiml-client')) }
if ($targets.Count -eq 0) { throw 'The requested activation scope contains no machines.' }

if ($Action -eq 'Activate' -and -not $WhatIfPreference) {
    if (($ServerProductKey -and $ServerProductKeySecretName) -or ($Windows11EducationProductKey -and $Windows11EducationProductKeySecretName)) {
        throw 'Use either a SecureString parameter or a secret name for each product class, not both.'
    }
    if ($ServerProductKeySecretName -or $Windows11EducationProductKeySecretName) {
        Import-Module Microsoft.PowerShell.SecretManagement -ErrorAction Stop
    }
    if ($ServerProductKeySecretName) {
        $secretParameters = @{ Name = $ServerProductKeySecretName; ErrorAction = 'Stop' }
        if ($SecretVaultName) { $secretParameters.Vault = $SecretVaultName }
        $ServerProductKey = Get-Secret @secretParameters
        if ($ServerProductKey -isnot [Security.SecureString]) { throw 'The server activation secret must be returned as a SecureString.' }
    }
    if ($Windows11EducationProductKeySecretName) {
        $secretParameters = @{ Name = $Windows11EducationProductKeySecretName; ErrorAction = 'Stop' }
        if ($SecretVaultName) { $secretParameters.Vault = $SecretVaultName }
        $Windows11EducationProductKey = Get-Secret @secretParameters
        if ($Windows11EducationProductKey -isnot [Security.SecureString]) { throw 'The Windows 11 Education activation secret must be returned as a SecureString.' }
    }
    if (@($targets | Where-Object role -notin @('client', 'aiml-client')).Count -gt 0 -and -not $ServerProductKey) {
        $ServerProductKey = Read-Host -Prompt 'Enter the Windows Server product key for this activation run' -AsSecureString
    }
    if (@($targets | Where-Object role -in @('client', 'aiml-client')).Count -gt 0 -and -not $Windows11EducationProductKey) {
        $Windows11EducationProductKey = Read-Host -Prompt 'Enter the Windows 11 Education product key for this activation run' -AsSecureString
    }
}

$result = [ordered]@{
    schemaVersion = 1
    timestamp = (Get-Date).ToUniversalTime().ToString('o')
    demo = $Demo
    profile = $LabProfile
    scope = $Scope
    action = $Action
    targetCount = $targets.Count
    status = 'planned'
    machines = @()
}
$remoteScript = {
    param([string]$RequestedAction, [Security.SecureString]$RuntimeProductKey)
    $activationScript = 'C:\ProgramData\WindowsServerLab\Scripts\Set-LabWindowsActivation.ps1'
    if (-not (Test-Path -LiteralPath $activationScript -PathType Leaf)) { throw 'The local activation script is missing from the lab payload.' }
    if ($RequestedAction -eq 'Activate') {
        & $activationScript -Action Activate -ProductKey $RuntimeProductKey -Confirm:$false
    }
    else {
        & $activationScript -Action Status
    }
}

try {
    foreach ($target in $targets) {
        $productClass = if ($target.role -in @('client', 'aiml-client')) { 'Windows11Education' } else { 'Server' }
        $machineResult = [ordered]@{ computerName = $target.name; productClass = $productClass; status = 'planned' }
        try {
            if ($PSCmdlet.ShouldProcess($target.name, "$Action Windows licensing")) {
                $runtimeKey = if ($productClass -eq 'Server') { $ServerProductKey } else { $Windows11EducationProductKey }
                $invokeParameters = @{
                    ComputerName = "$($target.name).$($definition.domain.dnsName)"
                    ScriptBlock = $remoteScript
                    ArgumentList = @($Action, $runtimeKey)
                    Authentication = 'Kerberos'
                    ErrorAction = 'Stop'
                }
                if ($Credential) { $invokeParameters.Credential = $Credential }
                $remoteResult = Invoke-Command @invokeParameters | Select-Object -Last 1
                $machineResult.status = [string]$remoteResult.status
                $machineResult.operatingSystem = [string]$remoteResult.operatingSystem
                $machineResult.licenseStatus = [string]$remoteResult.finalLicenseStatus
            }
        }
        catch {
            $machineResult.status = 'failed'
            $machineResult.error = $_.Exception.Message -replace '\b[A-Z0-9]{5}(?:-[A-Z0-9]{5}){4}\b', '[REDACTED-PRODUCT-KEY]'
        }
        $result.machines += [pscustomobject]$machineResult
    }
    $failed = @($result.machines | Where-Object status -notin @('licensed', 'planned'))
    $result.status = if ($WhatIfPreference) { 'planned' } elseif ($failed.Count -eq 0) { 'licensed' } else { 'failed' }
}
finally {
    $ServerProductKey = $null
    $Windows11EducationProductKey = $null
    $reportDirectory = Split-Path -Parent $OutputPath
    if ($reportDirectory -and -not (Test-Path -LiteralPath $reportDirectory)) { New-Item -Path $reportDirectory -ItemType Directory -Force | Out-Null }
    $result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
    Write-LabLog -Level $(if ($result.status -eq 'failed') { 'Error' } else { 'Info' }) -Message "Fleet activation state: $($result.status)" -Data @{ Demo = $Demo; Profile = $LabProfile; Scope = $Scope; TargetCount = $targets.Count }
}

$result
if ($result.status -eq 'failed') { exit 1 }
