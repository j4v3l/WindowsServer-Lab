#Requires -RunAsAdministrator
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = 'C:\ProgramData\WindowsServerLab'
$logPath = "$root\Logs\first-boot-cleanup.log"
$completionPath = "$root\first-boot-cleanup.complete"
$cloudbaseLog = 'C:\Program Files\Cloudbase Solutions\Cloudbase-Init\log\cloudbase-init.log'
$cloudbaseUnattend = 'C:\Program Files\Cloudbase Solutions\Cloudbase-Init\conf\Unattend.xml'
$taskName = 'WindowsServerLab-FirstBootCleanup'

function Write-CleanupLog {
    param([Parameter(Mandatory)][string]$Message)
    Add-Content -LiteralPath $logPath -Value ('{0} {1}' -f (Get-Date).ToUniversalTime().ToString('o'), $Message) -Encoding UTF8
}

function Get-ConfigDriveHostname {
    $configDriveVolumes = @(Get-Volume -FileSystemLabel 'config-2' -ErrorAction SilentlyContinue | Where-Object DriveLetter)
    if ($configDriveVolumes.Count -ne 1) {
        throw "Expected exactly one config-2 volume, found $($configDriveVolumes.Count)."
    }

    $userDataPath = '{0}:\openstack\latest\user_data' -f $configDriveVolumes[0].DriveLetter
    if (-not (Test-Path -LiteralPath $userDataPath -PathType Leaf)) {
        throw "ConfigDrive user data is missing at $userDataPath."
    }

    $userData = Get-Content -LiteralPath $userDataPath -Raw -Encoding UTF8 -ErrorAction Stop
    $hostnameMatch = [Regex]::Match($userData, '(?m)^\s*hostname:\s*["'']?([A-Za-z0-9][A-Za-z0-9-]{0,14})["'']?\s*$')
    if (-not $hostnameMatch.Success) {
        throw 'ConfigDrive user data does not contain a valid hostname setting.'
    }

    $hostname = $hostnameMatch.Groups[1].Value.ToUpperInvariant()
    if ($hostname -notmatch '^(?!-)(?![0-9]+$)[A-Z0-9](?:[A-Z0-9-]{0,13}[A-Z0-9])?$') {
        throw "ConfigDrive hostname '$hostname' is not a valid Windows computer name."
    }
    return $hostname
}

try {
    Write-CleanupLog 'Waiting for Cloudbase-Init specialization to complete.'
    $deadline = (Get-Date).AddMinutes(20)
    $specialized = $false
    $specializedStableSince = $null

    do {
        $imageState = (Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State' -Name ImageState -ErrorAction Stop).ImageState
        $setupState = Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\Setup' -ErrorAction Stop
        $oobeComplete =
            [int]$setupState.OOBEInProgress -eq 0 -and
            [int]$setupState.SystemSetupInProgress -eq 0 -and
            [int]$setupState.SetupType -eq 0 -and
            [string]::IsNullOrWhiteSpace([string]$setupState.CmdLine)
        $lastBootUtc = (Get-CimInstance Win32_OperatingSystem -ErrorAction Stop).LastBootUpTime.ToUniversalTime()
        $cloudbaseService = Get-CimInstance Win32_Service -Filter "Name='cloudbase-init'" -ErrorAction Stop
        $cloudbaseComplete = (Test-Path -LiteralPath $cloudbaseLog -PathType Leaf) -and (Get-Item -LiteralPath $cloudbaseLog -ErrorAction Stop).LastWriteTimeUtc -ge $lastBootUtc -and [bool](Select-String -LiteralPath $cloudbaseLog -SimpleMatch 'Plugins execution done' -Quiet)

        $specializationCandidate = $env:COMPUTERNAME -ne 'WSLAB-BUILD' -and $imageState -eq 'IMAGE_STATE_COMPLETE' -and $oobeComplete -and $cloudbaseService.State -eq 'Stopped' -and $cloudbaseComplete
        if ($specializationCandidate) {
            if ($null -eq $specializedStableSince) {
                $specializedStableSince = Get-Date
                Write-CleanupLog 'OOBE and Cloudbase-Init reached completed state; waiting two minutes for late OOBE finalizers.'
            }
            $specialized = ((Get-Date) - $specializedStableSince).TotalSeconds -ge 120
        }
        else {
            $specializedStableSince = $null
            $specialized = $false
        }
        if (-not $specialized) { Start-Sleep -Seconds 5 }
    } while (-not $specialized -and (Get-Date) -lt $deadline)

if (-not $specialized) { throw 'Cloudbase-Init specialization did not reach a completed, stopped state within 20 minutes.' }

# On current Windows 11 builds the final OOBE Computer Name plugin can run
# after Cloudbase-Init and replace its ConfigDrive hostname with DESKTOP-*.
# Apply the declared identity only after OOBE is genuinely complete, then let
# this startup task resume hardening after the required rename reboot. Server
# builds that already retained the declared name take the no-op path.
$desiredHostname = Get-ConfigDriveHostname
if ($env:COMPUTERNAME -ne $desiredHostname) {
    Write-CleanupLog "Applying post-OOBE ConfigDrive hostname '$desiredHostname' over '$env:COMPUTERNAME'."
    Rename-Computer -NewName $desiredHostname -Force -ErrorAction Stop
    Write-CleanupLog 'Restarting to commit the post-OOBE computer name.'
    Restart-Computer -Force -ErrorAction Stop
    return
}

Write-CleanupLog 'Cloudbase-Init completed; removing first-boot WinRM and answer-file artifacts.'
$winRm = Get-Service -Name WinRM -ErrorAction Stop
Set-Service -Name WinRM -StartupType Manual
# Cloudbase-Init may have stopped WinRM before this task runs.  Starting it on
# a Public profile raises a terminating firewall exception on Windows 11, so
# make the temporary build NIC private first and treat a still-unavailable
# service as a recoverable cleanup condition.
try {
    Get-NetConnectionProfile -ErrorAction Stop | ForEach-Object {
        if ($_.NetworkCategory -ne 'Private') {
            Set-NetConnectionProfile -InterfaceIndex $_.InterfaceIndex -NetworkCategory Private -ErrorAction Stop
        }
    }
} catch {
    Write-CleanupLog ('Could not change the build network profile to Private: {0}' -f $_.Exception.Message)
}
if ($winRm.Status -ne 'Running') {
    try { Start-Service -Name WinRM -ErrorAction Stop }
    catch {
        Write-CleanupLog ('WinRM was not startable during cleanup; continuing with registry and native listener cleanup: {0}' -f $_.Exception.Message)
    }
}
$httpsListeners = @()
try {
    if (Test-Path -LiteralPath WSMan:\localhost\Listener) {
        $httpsListeners = @(Get-ChildItem -Path WSMan:\localhost\Listener -ErrorAction Stop | Where-Object { $_.Keys -contains 'Transport=HTTPS' })
    }
} catch {
    Write-CleanupLog ('WSMan listener provider was unavailable during cleanup: {0}' -f $_.Exception.Message)
}
$listenerCertificateThumbprints = @($httpsListeners | ForEach-Object {
    [string](Get-Item -LiteralPath (Join-Path $_.PSPath 'CertificateThumbprint') -ErrorAction Stop).Value
} | Where-Object { $_ -match '^[A-Fa-f0-9]{40}$' } | Select-Object -Unique)

try {
    if (Test-Path -LiteralPath WSMan:\localhost\Service) {
        Set-Item -Path WSMan:\localhost\Service\Auth\Basic -Value $false
        Set-Item -Path WSMan:\localhost\Service\AllowUnencrypted -Value $false
    }
} catch {
    Write-CleanupLog ('WSMan provider settings could not be updated directly: {0}' -f $_.Exception.Message)
}
$winRmRegistryPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WSMAN\Service'
if (Test-Path -LiteralPath $winRmRegistryPath) {
    Set-ItemProperty -LiteralPath $winRmRegistryPath -Name auth_basic -Type DWord -Value 0
    Set-ItemProperty -LiteralPath $winRmRegistryPath -Name allow_unencrypted -Type DWord -Value 0
}
if ($httpsListeners.Count -gt 0) { $httpsListeners | Remove-Item -Recurse -Force -Confirm:$false }
foreach ($thumbprint in $listenerCertificateThumbprints) {
    $certificatePath = "Cert:\LocalMachine\My\$thumbprint"
    if (Test-Path -LiteralPath $certificatePath) { Remove-Item -LiteralPath $certificatePath -Force }
}
$remainingHttpsListeners = @()
try {
    if (Test-Path -LiteralPath WSMan:\localhost\Listener) {
        $remainingHttpsListeners = @(Get-ChildItem -Path WSMan:\localhost\Listener -ErrorAction Stop | Where-Object { $_.Keys -contains 'Transport=HTTPS' })
    }
} catch {
    Write-CleanupLog ('WSMan listener provider remained unavailable after cleanup: {0}' -f $_.Exception.Message)
}
if ($remainingHttpsListeners.Count -ne 0) { throw 'Cloudbase-Init HTTPS WinRM listeners remain after first-boot cleanup.' }

Stop-Service -Name WinRM -Force -ErrorAction SilentlyContinue
Set-Service -Name WinRM -StartupType Disabled
Remove-NetFirewallRule -Name 'WSLAB-WinRM-HTTPS' -ErrorAction SilentlyContinue
Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name LocalAccountTokenFilterPolicy -ErrorAction SilentlyContinue
$winlogonPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
foreach ($autoLogonValue in @('AutoAdminLogon', 'DefaultDomainName', 'DefaultPassword', 'DefaultUserName')) {
    Remove-ItemProperty -Path $winlogonPath -Name $autoLogonValue -ErrorAction SilentlyContinue
}
Remove-ItemProperty -Path $winlogonPath -Name AutoLogonCount -ErrorAction SilentlyContinue

$builtInAdministrator = Get-LocalUser | Where-Object { $_.SID.Value -match '-500$' } | Select-Object -First 1
if ($builtInAdministrator -and $builtInAdministrator.Enabled) {
    Disable-LocalUser -Name $builtInAdministrator.Name
}

# The seal step adds a random, one-use autologon credential so Windows 11 can
# finish OOBE. Remove both the autologon and local-account password nodes from
# Cloudbase-Init's answer file after OOBE has completed; leaving them in the
# reusable image would retain a build credential.
if (Test-Path -LiteralPath $cloudbaseUnattend -PathType Leaf) {
    $unattendXml = [xml](Get-Content -LiteralPath $cloudbaseUnattend -Raw -Encoding UTF8)
    $unattendNamespace = New-Object System.Xml.XmlNamespaceManager($unattendXml.NameTable)
    $unattendNamespace.AddNamespace('u', 'urn:schemas-microsoft-com:unattend')
    $shellSetup = $unattendXml.SelectSingleNode("//u:settings[@pass='oobeSystem']/u:component[@name='Microsoft-Windows-Shell-Setup']", $unattendNamespace)
    if ($shellSetup) {
        foreach ($sensitiveNodeName in @('AutoLogon', 'UserAccounts')) {
            $sensitiveNode = $shellSetup.SelectSingleNode("u:$sensitiveNodeName", $unattendNamespace)
            if ($sensitiveNode) { $shellSetup.RemoveChild($sensitiveNode) | Out-Null }
        }
        $unattendXml.Save($cloudbaseUnattend)
    }
}
foreach ($cachedAnswerFile in @(
    "$env:SystemRoot\Panther\Unattend.xml",
    "$env:SystemRoot\Panther\Unattend\Unattend.xml",
    "$env:SystemRoot\System32\Sysprep\unattend.xml"
)) {
    if (Test-Path -LiteralPath $cachedAnswerFile) { Remove-Item -LiteralPath $cachedAnswerFile -Force }
}
$winRmService = Get-CimInstance Win32_Service -Filter "Name='WinRM'" -ErrorAction Stop
$cachedAnswersRemain = @(@(
    "$env:SystemRoot\Panther\Unattend.xml",
    "$env:SystemRoot\Panther\Unattend\Unattend.xml",
    "$env:SystemRoot\System32\Sysprep\unattend.xml"
) | Where-Object { Test-Path -LiteralPath $_ })
$cloudbaseCredentialNodesRemain = $false
if (Test-Path -LiteralPath $cloudbaseUnattend -PathType Leaf) {
    $cloudbaseCredentialNodesRemain = [bool](Select-String -LiteralPath $cloudbaseUnattend -Pattern '<(AutoLogon|UserAccounts|DefaultPassword|PlainText)>' -Quiet)
}
if ($winRmService.StartMode -ne 'Disabled' -or $cachedAnswersRemain.Count -ne 0 -or $cloudbaseCredentialNodesRemain) {
    throw 'First-boot cleanup verification failed.'
}

[ordered]@{
    schemaVersion = 1
    status = 'complete'
    timestamp = (Get-Date).ToUniversalTime().ToString('o')
    removedHttpsListenerCount = $httpsListeners.Count
    removedListenerCertificateCount = $listenerCertificateThumbprints.Count
} | ConvertTo-Json | Set-Content -LiteralPath $completionPath -Encoding UTF8

Write-CleanupLog 'First-boot hardening is complete.'
Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction Stop
Remove-Item -LiteralPath $PSCommandPath -Force
}
catch {
    Write-CleanupLog ('FAILED: {0}' -f $_.Exception.Message)
    throw
}
