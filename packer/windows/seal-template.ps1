#Requires -RunAsAdministrator
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[A-Za-z0-9]{5}(?:-[A-Za-z0-9]{5}){4}$')]
    [string]$WindowsSetupKey
)

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
$manifestPath = "$root\TemplateBuild.json"
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw 'TemplateBuild.json is missing.' }
$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
if ($manifest.schemaVersion -ne 1 -or $manifest.os -notin @('server-2025', 'windows-11')) {
    throw 'TemplateBuild.json is invalid.'
}

function Write-SealLog {
    param([Parameter(Mandatory)][string]$Message)
    Add-Content -LiteralPath $sealLog -Value ('{0} {1}' -f (Get-Date).ToUniversalTime().ToString('o'), $Message) -Encoding UTF8
}

Write-SealLog 'Starting template seal and Sysprep shutdown.'
$sealIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
try {
    $sealPrincipal = [string]$sealIdentity.Name
    $sealPrincipalSid = [string]$sealIdentity.User.Value
    $sealRunsAsSystem = [bool]$sealIdentity.IsSystem
}
finally {
    $sealIdentity.Dispose()
}
if ($sealRunsAsSystem -or $sealPrincipalSid -eq 'S-1-5-18') {
    throw 'Refusing to run Sysprep under LocalSystem; use the dedicated LabBootstrap administrator account.'
}
if ($sealPrincipal -notmatch '(?i)\\LabBootstrap$') {
    throw "Refusing to run Sysprep under unexpected account: $sealPrincipal"
}
[ordered]@{
    schemaVersion = 1
    status = 'started'
    timestamp = (Get-Date).ToUniversalTime().ToString('o')
    sysprepPrincipal = $sealPrincipal
    sysprepPrincipalSid = $sealPrincipalSid
} |
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
$firstBootCleanupSettings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 30) -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
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

# Supply a local account to the OOBE answer pass, but do not automatically
# start a Windows 11 desktop session. On Windows 11 25H2, that session can
# crash Explorer while User OOBE is still finalizing and cause
# CloudExperienceHostBroker to launch the "Why did my PC restart?" recovery
# flow. The startup cleanup task does not require an interactive sign-in.
$unattendXml = [xml](Get-Content -LiteralPath $unattend -Raw -Encoding UTF8)
$unattendNamespace = New-Object System.Xml.XmlNamespaceManager($unattendXml.NameTable)
$unattendNamespace.AddNamespace('u', 'urn:schemas-microsoft-com:unattend')
$unattendNamespace.AddNamespace('wcm', 'http://schemas.microsoft.com/WMIConfig/2002/State')
$shellSetup = $unattendXml.SelectSingleNode("//u:settings[@pass='oobeSystem']/u:component[@name='Microsoft-Windows-Shell-Setup']", $unattendNamespace)
if (-not $shellSetup) { throw 'Cloudbase-Init answer file is missing the oobeSystem Shell-Setup component.' }
$oobe = $shellSetup.SelectSingleNode('u:OOBE', $unattendNamespace)
if (-not $oobe) { throw 'Cloudbase-Init answer file is missing the oobeSystem OOBE settings.' }
if ($manifest.os -eq 'server-2025') {
    $hideLocalAccountScreen = $oobe.SelectSingleNode('u:HideLocalAccountScreen', $unattendNamespace)
    if (-not $hideLocalAccountScreen) {
        $hideLocalAccountScreen = $unattendXml.CreateElement('HideLocalAccountScreen', 'urn:schemas-microsoft-com:unattend')
        $oobe.AppendChild($hideLocalAccountScreen) | Out-Null
    }
    $hideLocalAccountScreen.InnerText = 'true'
}

# Server 2025 needs its public setup key in the Sysprep specialize pass to
# suppress the Server licensing-method screen. Windows 11 retains the public
# Education setup key from the ISO installation; reapplying it here causes
# Microsoft-Windows-Shell-Setup to request an extra immediate specialize
# reboot, so remove that redundant setting from the client answer file.
$specializeSettings = $unattendXml.SelectSingleNode("//u:settings[@pass='specialize']", $unattendNamespace)
if (-not $specializeSettings) { throw 'Cloudbase-Init answer file is missing the specialize settings pass.' }
$specializeShellSetup = $specializeSettings.SelectSingleNode("u:component[@name='Microsoft-Windows-Shell-Setup']", $unattendNamespace)
if ($manifest.os -eq 'server-2025') {
    if (-not $specializeShellSetup) {
        $specializeShellSetup = $unattendXml.CreateElement('component', 'urn:schemas-microsoft-com:unattend')
        $specializeShellSetup.SetAttribute('name', 'Microsoft-Windows-Shell-Setup')
        $specializeShellSetup.SetAttribute('processorArchitecture', 'amd64')
        $specializeShellSetup.SetAttribute('publicKeyToken', '31bf3856ad364e35')
        $specializeShellSetup.SetAttribute('language', 'neutral')
        $specializeShellSetup.SetAttribute('versionScope', 'nonSxS')
        $specializeSettings.AppendChild($specializeShellSetup) | Out-Null
    }
    $specializeProductKey = $specializeShellSetup.SelectSingleNode('u:ProductKey', $unattendNamespace)
    if (-not $specializeProductKey) {
        $specializeProductKey = $unattendXml.CreateElement('ProductKey', 'urn:schemas-microsoft-com:unattend')
        $specializeShellSetup.AppendChild($specializeProductKey) | Out-Null
    }
    $specializeProductKey.InnerText = $WindowsSetupKey
}
elseif ($specializeShellSetup) {
    $specializeProductKey = $specializeShellSetup.SelectSingleNode('u:ProductKey', $unattendNamespace)
    if ($specializeProductKey) { $specializeShellSetup.RemoveChild($specializeProductKey) | Out-Null }
}
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
if ($manifest.os -eq 'server-2025') {
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
}
elseif ($autoLogon) {
    $shellSetup.RemoveChild($autoLogon) | Out-Null
}
$unattendXml.Save($unattend)
$randomPasswordPlain.Clear() | Out-Null
$randomPasswordPlain = $null
Write-SealLog 'Build-only access removed; invoking Sysprep shutdown.'
Remove-Item -LiteralPath $PSCommandPath -Force
$bitLockerCommand = Get-Command -Name Get-BitLockerVolume -ErrorAction SilentlyContinue
if ($bitLockerCommand) {
    $osVolume = Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction Stop
    if ([string]$osVolume.VolumeStatus -ne 'FullyDecrypted') {
        Write-SealLog ('Disabling BitLocker on {0} before Sysprep (current state: {1}).' -f $env:SystemDrive, $osVolume.VolumeStatus)
        Disable-BitLocker -MountPoint $env:SystemDrive
        $decryptDeadline = (Get-Date).AddMinutes(45)
        do {
            Start-Sleep -Seconds 10
            $osVolume = Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction Stop
        } while ([string]$osVolume.VolumeStatus -ne 'FullyDecrypted' -and (Get-Date) -lt $decryptDeadline)
        if ([string]$osVolume.VolumeStatus -ne 'FullyDecrypted') { throw 'BitLocker did not finish decrypting the OS volume before the Sysprep deadline.' }
    }
}
else {
    # Windows Server Standard does not install the BitLocker PowerShell
    # feature by default. An absent cmdlet means there is no feature-managed
    # encrypted OS volume to decrypt; Windows 11 retains the stronger check.
    Write-SealLog 'BitLocker PowerShell cmdlets are not installed; continuing with the unencrypted Server OS volume.'
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
