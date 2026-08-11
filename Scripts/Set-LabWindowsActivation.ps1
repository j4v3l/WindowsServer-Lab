#Requires -RunAsAdministrator
#Requires -Version 5.1
<#
.SYNOPSIS
    Installs and activates the runtime-supplied Windows product key on one lab machine.
.DESCRIPTION
    Accepts activation material only as a SecureString or through an interactive secure
    prompt. The full key is never written to a file, report, log, or child-process command
    line. The key is removed from the registry after the activation attempt.
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)][ValidateSet('Activate', 'Status')][string]$Action,
    [Security.SecureString]$ProductKey,
    [string]$ProductKeySecretName,
    [string]$SecretVaultName,
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = 'C:\ProgramData\WindowsServerLab'
if (-not $OutputPath) { $OutputPath = Join-Path $root "Reports\windows-activation-$env:COMPUTERNAME.json" }
$moduleCandidates = @(
    (Join-Path $root 'Modules\WindowsServerLab\WindowsServerLab.psd1'),
    (Join-Path $PSScriptRoot 'WindowsServerLab\WindowsServerLab.psd1')
)
$modulePath = $moduleCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
if (-not $modulePath) { throw 'WindowsServerLab module was not found.' }
Import-Module $modulePath -Force -ErrorAction Stop

$windowsApplicationId = '55c92734-d682-4d71-983e-d6ec3f16059f'
$licenseStatusNames = @('Unlicensed', 'Licensed', 'OOBGrace', 'OOTGrace', 'NonGenuineGrace', 'Notification', 'ExtendedGrace')
$operatingSystem = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
$caption = [string]$operatingSystem.Caption
$productClass = if ($caption -match '^Microsoft Windows Server (2022|2025)') {
    'Server'
}
elseif ($caption -match '^Microsoft Windows 11 Education$') {
    'Windows11Education'
}
elseif ($caption -match '^Microsoft Windows 11 Education N$') {
    throw 'Windows 11 Education N requires a different product key and is not a supported lab image.'
}
else {
    throw "Unsupported activation target edition: $caption"
}

function Get-LabWindowsLicense {
    $products = @(Get-CimInstance -ClassName SoftwareLicensingProduct -Filter "ApplicationID='$windowsApplicationId'" -ErrorAction Stop |
        Where-Object { $_.Name -like 'Windows*' -and $_.PartialProductKey })
    $licensed = @($products | Where-Object LicenseStatus -eq 1 | Select-Object -First 1)
    $selected = if ($licensed.Count -gt 0) { $licensed[0] } else { $products | Select-Object -First 1 }
    if (-not $selected) {
        return [pscustomobject]@{ Name = $caption; Description = $null; LicenseStatus = 0 }
    }
    $selected
}

$initialLicense = Get-LabWindowsLicense
$result = [ordered]@{
    schemaVersion = 1
    timestamp = (Get-Date).ToUniversalTime().ToString('o')
    computerName = $env:COMPUTERNAME
    operatingSystem = $caption
    productClass = $productClass
    action = $Action
    initialLicenseStatus = $licenseStatusNames[[Math]::Min([int]$initialLicense.LicenseStatus, $licenseStatusNames.Count - 1)]
    finalLicenseStatus = $null
    productKeyRetained = $false
    status = 'planned'
}

try {
    if ($Action -eq 'Activate' -and $initialLicense.LicenseStatus -ne 1) {
        if ($ProductKey -and $ProductKeySecretName) { throw 'Use either ProductKey or ProductKeySecretName, not both.' }
        if ($ProductKeySecretName) {
            Import-Module Microsoft.PowerShell.SecretManagement -ErrorAction Stop
            $secretParameters = @{ Name = $ProductKeySecretName; ErrorAction = 'Stop' }
            if ($SecretVaultName) { $secretParameters.Vault = $SecretVaultName }
            $ProductKey = Get-Secret @secretParameters
            if ($ProductKey -isnot [Security.SecureString]) { throw 'The activation secret must be returned as a SecureString.' }
        }
        if (-not $ProductKey) {
            $prompt = if ($productClass -eq 'Server') { 'Enter the Windows Server product key' } else { 'Enter the Windows 11 Education product key' }
            $ProductKey = Read-Host -Prompt $prompt -AsSecureString
        }

        if ($PSCmdlet.ShouldProcess("$env:COMPUTERNAME ($caption)", 'Install the runtime product key and activate Windows')) {
            $service = Get-CimInstance -ClassName SoftwareLicensingService -ErrorAction Stop
            $keyPointer = [IntPtr]::Zero
            $plainProductKey = $null
            $keyInstalled = $false
            try {
                $keyPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($ProductKey)
                $plainProductKey = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($keyPointer)
                if ($plainProductKey -cnotmatch '^[A-Z0-9]{5}(?:-[A-Z0-9]{5}){4}$') {
                    throw 'The supplied activation material is not a valid 25-character product-key format.'
                }
                $installResult = Invoke-CimMethod -InputObject $service -MethodName InstallProductKey -Arguments @{ ProductKey = $plainProductKey } -ErrorAction Stop
                if ($installResult.ReturnValue -ne 0) { throw "Windows rejected the product key with result code $($installResult.ReturnValue)." }
                $keyInstalled = $true
            }
            finally {
                $plainProductKey = $null
                if ($keyPointer -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($keyPointer) }
            }

            try {
                $refreshResult = Invoke-CimMethod -InputObject $service -MethodName RefreshLicenseStatus -ErrorAction Stop
                if ($refreshResult.ReturnValue -ne 0) { throw "License refresh failed with result code $($refreshResult.ReturnValue)." }
                $targetProduct = Get-LabWindowsLicense
                $activationResult = Invoke-CimMethod -InputObject $targetProduct -MethodName Activate -ErrorAction Stop
                if ($activationResult.ReturnValue -ne 0) { throw "Windows activation failed with result code $($activationResult.ReturnValue)." }
            }
            finally {
                if ($keyInstalled) {
                    $clearResult = Invoke-CimMethod -InputObject $service -MethodName ClearProductKeyFromRegistry -ErrorAction Stop
                    if ($clearResult.ReturnValue -ne 0) { throw "Product-key registry cleanup failed with result code $($clearResult.ReturnValue)." }
                }
            }
        }
    }

    $finalLicense = Get-LabWindowsLicense
    $finalStatusIndex = [Math]::Min([int]$finalLicense.LicenseStatus, $licenseStatusNames.Count - 1)
    $result.finalLicenseStatus = $licenseStatusNames[$finalStatusIndex]
    $result.status = if ($WhatIfPreference) { 'planned' } elseif ($finalLicense.LicenseStatus -eq 1) { 'licensed' } else { 'not-licensed' }
}
catch {
    $result.status = 'failed'
    $result.error = $_.Exception.Message -replace '\b[A-Z0-9]{5}(?:-[A-Z0-9]{5}){4}\b', '[REDACTED-PRODUCT-KEY]'
    throw $result.error
}
finally {
    $ProductKey = $null
    $reportDirectory = Split-Path -Parent $OutputPath
    if ($reportDirectory -and -not (Test-Path -LiteralPath $reportDirectory)) { New-Item -Path $reportDirectory -ItemType Directory -Force | Out-Null }
    $result | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
    Write-LabLog -Level $(if ($result.status -eq 'failed') { 'Error' } elseif ($result.status -eq 'licensed') { 'Info' } else { 'Warning' }) -Message "Windows activation state: $($result.status)" -Data @{ ProductClass = $productClass; LicenseStatus = $result.finalLicenseStatus }
}

$result
if (-not $WhatIfPreference -and $result.status -notin @('licensed', 'planned')) { exit 1 }
