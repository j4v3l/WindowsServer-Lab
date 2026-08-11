#Requires -RunAsAdministrator
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = 'C:\ProgramData\WindowsServerLab'
$sealLog = "$root\Logs\template-seal.log"
$readySentinel = "$root\finalize.ready"
$sealStartedSentinel = "$root\seal.started"
$sealFailedSentinel = "$root\seal.failed"
trap {
    try {
        $failureRecord = if ($Error.Count -gt 0) { $Error[0] } else { 'Unknown template seal failure.' }
        $failure = ($failureRecord | Out-String).Trim() -replace '\b[A-Z0-9]{5}(?:-[A-Z0-9]{5}){4}\b', '[REDACTED-PRODUCT-KEY]'
        [ordered]@{ schemaVersion = 1; status = 'failed'; error = $failure; timestamp = (Get-Date).ToUniversalTime().ToString('o') } |
            ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $sealFailedSentinel -Encoding UTF8
        Add-Content -LiteralPath $sealLog -Value ('{0} FAILED: {1}' -f (Get-Date).ToUniversalTime().ToString('o'), $failure) -Encoding UTF8
    } catch {
        Write-Warning 'Unable to persist redacted template seal failure evidence.'
    }
    throw
}
if (-not (Test-Path -LiteralPath $readySentinel -PathType Leaf)) { throw 'The template was not marked ready to seal.' }
$ready = Get-Content -LiteralPath $readySentinel -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
if ($ready.status -ne 'ready-to-seal') { throw 'The finalization sentinel is invalid.' }

function Write-SealLog {
    param([Parameter(Mandatory)][string]$Message)
    Add-Content -LiteralPath $sealLog -Value ('{0} {1}' -f (Get-Date).ToUniversalTime().ToString('o'), $Message) -Encoding UTF8
}

Write-SealLog 'Starting template seal and Sysprep shutdown.'
[ordered]@{ schemaVersion = 1; status = 'started'; timestamp = (Get-Date).ToUniversalTime().ToString('o') } |
    ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $sealStartedSentinel -Encoding UTF8
Unregister-ScheduledTask -TaskName 'WindowsServerLab-TemplateSeal' -Confirm:$false -ErrorAction SilentlyContinue
Set-Service WinRM -StartupType Disabled
$winRmServiceRegistry = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WSMAN\Service'
New-ItemProperty -LiteralPath $winRmServiceRegistry -Name auth_basic -PropertyType DWord -Value 0 -Force | Out-Null
New-ItemProperty -LiteralPath $winRmServiceRegistry -Name allow_unencrypted -PropertyType DWord -Value 0 -Force | Out-Null
try {
    if (Test-Path -LiteralPath WSMan:\localhost\Service) {
        Set-Item -Path WSMan:\localhost\Service\Auth\Basic -Value $false -ErrorAction SilentlyContinue
        Set-Item -Path WSMan:\localhost\Service\AllowUnencrypted -Value $false -ErrorAction SilentlyContinue
    }
} catch { Write-SealLog 'WSMan provider was unavailable after disabling WinRM; registry policy was applied.' }
Remove-NetFirewallRule -Name 'WSLAB-WinRM-HTTPS' -ErrorAction SilentlyContinue
Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name LocalAccountTokenFilterPolicy -ErrorAction SilentlyContinue
$winlogonPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
foreach ($autoLogonValue in @('AutoAdminLogon', 'DefaultDomainName', 'DefaultPassword', 'DefaultUserName')) {
    Remove-ItemProperty -Path $winlogonPath -Name $autoLogonValue -ErrorAction SilentlyContinue
}

# Preserve one enabled local administrator for Windows/Cloudbase-Init, but make
# the media-build credential unusable before the reusable image is sealed.
$alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@$%*-_'
$randomBytes = [byte[]]::new(48)
$randomGenerator = [Security.Cryptography.RandomNumberGenerator]::Create()
try {
    $randomGenerator.GetBytes($randomBytes)
}
finally {
    $randomGenerator.Dispose()
}
$randomPassword = [Security.SecureString]::new()
$randomPasswordPlain = [Text.StringBuilder]::new()
try {
    foreach ($randomByte in $randomBytes) {
        $character = $alphabet[$randomByte % $alphabet.Length]
        $randomPassword.AppendChar($character)
        [void]$randomPasswordPlain.Append($character)
    }
    $randomPassword.MakeReadOnly()
    Set-LocalUser -Name LabBootstrap -Password $randomPassword
    Enable-LocalUser -Name LabBootstrap
    $builtInAdministrator = Get-LocalUser | Where-Object { $_.SID.Value -match '-500$' } | Select-Object -First 1
    if ($builtInAdministrator) {
        $builtInAdministrator | Set-LocalUser -Password $randomPassword
        if ($builtInAdministrator.Enabled) { $builtInAdministrator | Disable-LocalUser }
    }
}
finally {
    $randomBytes = $null
    $randomPassword.Dispose()
}

Set-Service QEMU-GA -StartupType Automatic
Set-Service cloudbase-init -StartupType Automatic
$firstBootCleanupTaskName = 'WindowsServerLab-FirstBootCleanup'
Unregister-ScheduledTask -TaskName $firstBootCleanupTaskName -Confirm:$false -ErrorAction SilentlyContinue
$firstBootCleanupAction = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:\ProgramData\WindowsServerLab\first-boot-cleanup.ps1'
$firstBootCleanupTrigger = New-ScheduledTaskTrigger -AtStartup
$firstBootCleanupSettings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 30) -StartWhenAvailable
Register-ScheduledTask -TaskName $firstBootCleanupTaskName -Action $firstBootCleanupAction -Trigger $firstBootCleanupTrigger -Settings $firstBootCleanupSettings -User SYSTEM -RunLevel Highest -Force | Out-Null
foreach ($cachedAnswerFile in @(
    "$env:SystemRoot\Panther\Unattend.xml",
    "$env:SystemRoot\Panther\Unattend\Unattend.xml",
    "$env:SystemRoot\System32\Sysprep\unattend.xml"
)) {
    if (Test-Path -LiteralPath $cachedAnswerFile) { Remove-Item -LiteralPath $cachedAnswerFile -Force }
}
foreach ($temporaryFile in @("$root\bootstrap.complete", "$root\bootstrap.failed", $readySentinel)) {
    if (Test-Path -LiteralPath $temporaryFile) { Remove-Item -LiteralPath $temporaryFile -Force }
}
Clear-EventLog -LogName Application, System -ErrorAction SilentlyContinue

$certificateMarker = "$root\build-winrm-cert.thumbprint"
$certificateThumbprint = $null
if (Test-Path -LiteralPath $certificateMarker) {
    $certificateThumbprint = (Get-Content -LiteralPath $certificateMarker -Raw).Trim()
}
$httpsListeners = @()
try {
    if (Test-Path -LiteralPath WSMan:\localhost\Listener) {
        $httpsListeners = @(Get-ChildItem -Path WSMan:\localhost\Listener -ErrorAction Stop | Where-Object { $_.Keys -contains 'Transport=HTTPS' })
        $httpsListeners | Remove-Item -Recurse -Force -Confirm:$false
    }
} catch { Write-SealLog 'WSMan listener provider was unavailable; no HTTPS listener could remain active.' }
if ($certificateThumbprint -and $certificateThumbprint -match '^[A-Fa-f0-9]{40}$') {
    Remove-Item -LiteralPath "Cert:\LocalMachine\My\$certificateThumbprint" -Force -ErrorAction SilentlyContinue
}
if (Test-Path -LiteralPath $certificateMarker) { Remove-Item -LiteralPath $certificateMarker -Force }
try {
    if ((Test-Path -LiteralPath WSMan:\localhost\Listener) -and
        (@(Get-ChildItem -Path WSMan:\localhost\Listener | Where-Object { $_.Keys -contains 'Transport=HTTPS' }).Count -ne 0)) {
        throw 'The temporary HTTPS WinRM listener could not be removed.'
    }
} catch {
    if ($_.Exception.Message -like '*could not be removed*') { throw }
}

$sysprep = "$env:SystemRoot\System32\Sysprep\Sysprep.exe"
$unattend = 'C:\Program Files\Cloudbase Solutions\Cloudbase-Init\conf\Unattend.xml'

# Windows 11 client editions stop at the lock screen after Sysprep unless an
# account is available for the first OOBE sign-in. Add a one-use autologon
# using the random build password above. first-boot-cleanup.ps1 removes these
# XML nodes and registry values immediately after Cloudbase-Init completes, so
# no build credential survives into the reusable image.
$unattendXml = [xml](Get-Content -LiteralPath $unattend -Raw -Encoding UTF8)
$unattendNamespace = New-Object System.Xml.XmlNamespaceManager($unattendXml.NameTable)
$unattendNamespace.AddNamespace('u', 'urn:schemas-microsoft-com:unattend')
$unattendNamespace.AddNamespace('wcm', 'http://schemas.microsoft.com/WMIConfig/2002/State')
$shellSetup = $unattendXml.SelectSingleNode("//u:settings[@pass='oobeSystem']/u:component[@name='Microsoft-Windows-Shell-Setup']", $unattendNamespace)
if (-not $shellSetup) { throw 'Cloudbase-Init answer file is missing the oobeSystem Shell-Setup component.' }
$userAccounts = $shellSetup.SelectSingleNode('u:UserAccounts', $unattendNamespace)
if (-not $userAccounts) {
    $userAccounts = $unattendXml.CreateElement('UserAccounts', 'urn:schemas-microsoft-com:unattend')
    $shellSetup.AppendChild($userAccounts) | Out-Null
}
$localAccounts = $userAccounts.SelectSingleNode('u:LocalAccounts', $unattendNamespace)
if (-not $localAccounts) {
    $localAccounts = $unattendXml.CreateElement('LocalAccounts', 'urn:schemas-microsoft-com:unattend')
    $userAccounts.AppendChild($localAccounts) | Out-Null
}
$localAccount = $localAccounts.SelectSingleNode("u:LocalAccount[u:Name='LabBootstrap']", $unattendNamespace)
if (-not $localAccount) {
    $localAccount = $unattendXml.CreateElement('LocalAccount', 'urn:schemas-microsoft-com:unattend')
    $localAccount.SetAttribute('action', 'http://schemas.microsoft.com/WMIConfig/2002/State', 'add')
    $localAccounts.AppendChild($localAccount) | Out-Null
}
foreach ($entry in @(
    @{ Name = 'Name'; Value = 'LabBootstrap' },
    @{ Name = 'Group'; Value = 'Administrators' }
)) {
    $node = $localAccount.SelectSingleNode("u:$($entry.Name)", $unattendNamespace)
    if (-not $node) {
        $node = $unattendXml.CreateElement($entry.Name, 'urn:schemas-microsoft-com:unattend')
        $localAccount.AppendChild($node) | Out-Null
    }
    $node.InnerText = $entry.Value
}
$accountPassword = $localAccount.SelectSingleNode('u:Password', $unattendNamespace)
if (-not $accountPassword) {
    $accountPassword = $unattendXml.CreateElement('Password', 'urn:schemas-microsoft-com:unattend')
    $localAccount.AppendChild($accountPassword) | Out-Null
}
$passwordValue = $accountPassword.SelectSingleNode('u:Value', $unattendNamespace)
if (-not $passwordValue) {
    $passwordValue = $unattendXml.CreateElement('Value', 'urn:schemas-microsoft-com:unattend')
    $accountPassword.AppendChild($passwordValue) | Out-Null
}
$passwordValue.InnerText = $randomPasswordPlain.ToString()
$plainText = $accountPassword.SelectSingleNode('u:PlainText', $unattendNamespace)
if (-not $plainText) {
    $plainText = $unattendXml.CreateElement('PlainText', 'urn:schemas-microsoft-com:unattend')
    $accountPassword.AppendChild($plainText) | Out-Null
}
$plainText.InnerText = 'true'
$displayName = $localAccount.SelectSingleNode('u:DisplayName', $unattendNamespace)
if (-not $displayName) {
    $displayName = $unattendXml.CreateElement('DisplayName', 'urn:schemas-microsoft-com:unattend')
    $localAccount.AppendChild($displayName) | Out-Null
}
$displayName.InnerText = 'Lab Bootstrap'
$autoLogon = $shellSetup.SelectSingleNode('u:AutoLogon', $unattendNamespace)
if (-not $autoLogon) {
    $autoLogon = $unattendXml.CreateElement('AutoLogon', 'urn:schemas-microsoft-com:unattend')
    $shellSetup.AppendChild($autoLogon) | Out-Null
}
$autoPassword = $autoLogon.SelectSingleNode('u:Password', $unattendNamespace)
if (-not $autoPassword) {
    $autoPassword = $unattendXml.CreateElement('Password', 'urn:schemas-microsoft-com:unattend')
    $autoLogon.AppendChild($autoPassword) | Out-Null
}
$autoPasswordValue = $autoPassword.SelectSingleNode('u:Value', $unattendNamespace)
if (-not $autoPasswordValue) {
    $autoPasswordValue = $unattendXml.CreateElement('Value', 'urn:schemas-microsoft-com:unattend')
    $autoPassword.AppendChild($autoPasswordValue) | Out-Null
}
$autoPasswordValue.InnerText = $randomPasswordPlain.ToString()
$autoPlainText = $autoPassword.SelectSingleNode('u:PlainText', $unattendNamespace)
if (-not $autoPlainText) {
    $autoPlainText = $unattendXml.CreateElement('PlainText', 'urn:schemas-microsoft-com:unattend')
    $autoPassword.AppendChild($autoPlainText) | Out-Null
}
$autoPlainText.InnerText = 'true'
foreach ($entry in @(
    @{ Name = 'Enabled'; Value = 'true' },
    @{ Name = 'LogonCount'; Value = '1' },
    @{ Name = 'Username'; Value = 'LabBootstrap' }
)) {
    $node = $autoLogon.SelectSingleNode("u:$($entry.Name)", $unattendNamespace)
    if (-not $node) {
        $node = $unattendXml.CreateElement($entry.Name, 'urn:schemas-microsoft-com:unattend')
        $autoLogon.AppendChild($node) | Out-Null
    }
    $node.InnerText = $entry.Value
}
$unattendXml.Save($unattend)
$randomPasswordPlain.Clear() | Out-Null
$randomPasswordPlain = $null
Write-SealLog 'Build-only access removed; invoking Sysprep shutdown.'
Remove-Item -LiteralPath $PSCommandPath -Force
$osVolume = Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction SilentlyContinue
if ($osVolume -and [string]$osVolume.VolumeStatus -ne 'FullyDecrypted') {
    Write-SealLog ('Disabling BitLocker on {0} before Sysprep (current state: {1}).' -f $env:SystemDrive, $osVolume.VolumeStatus)
    Disable-BitLocker -MountPoint $env:SystemDrive
    $decryptDeadline = (Get-Date).AddMinutes(45)
    do {
        Start-Sleep -Seconds 10
        $osVolume = Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction Stop
    } while ([string]$osVolume.VolumeStatus -ne 'FullyDecrypted' -and (Get-Date) -lt $decryptDeadline)
    if ([string]$osVolume.VolumeStatus -ne 'FullyDecrypted') { throw 'BitLocker did not finish decrypting the OS volume before the Sysprep deadline.' }
}
$LASTEXITCODE = 0
& $sysprep /generalize /oobe /shutdown "/unattend:$unattend"
$sysprepExitCode = [int]$LASTEXITCODE
if ($sysprepExitCode -ne 0) { throw "Sysprep failed with exit code $sysprepExitCode" }

# Sysprep may return before its asynchronous generalization and ACPI shutdown
# finish. Never issue a competing forced shutdown here: doing so can seal a
# clone before its machine SID and MachineGuid are generalized. The host-side
# shutdown gate waits for Sysprep itself to power off the builder and fails the
# build if that never happens.
Write-SealLog 'Sysprep accepted the generalize request; waiting for Sysprep-owned shutdown.'
