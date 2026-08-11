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
$autologonArmedMarker = "$root\oobe-autologon.armed"
$taskName = 'WindowsServerLab-FirstBootCleanup'

function Write-CleanupLog {
    param([Parameter(Mandatory)][string]$Message)
    Add-Content -LiteralPath $logPath -Value ('{0} {1}' -f (Get-Date).ToUniversalTime().ToString('o'), $Message) -Encoding UTF8
}

try {
    Write-CleanupLog 'Waiting for Cloudbase-Init specialization to complete.'
    $deadline = (Get-Date).AddMinutes(20)
    $isWindowsClient = (Get-CimInstance Win32_OperatingSystem -ErrorAction Stop).Caption -like 'Microsoft Windows 11*'
    $specialized = $false

    # Windows 11 25H2 may show the lock screen before it consumes the
    # oobeSystem AutoLogon node from Cloudbase-Init's answer file. Arm the
    # same one-use credential directly in Winlogon and reboot once. The marker
    # prevents a reboot loop if an operator intentionally retains a failed
    # canary for diagnosis.
    if ($isWindowsClient -and -not (Test-Path -LiteralPath $autologonArmedMarker -PathType Leaf) -and (Test-Path -LiteralPath $cloudbaseUnattend -PathType Leaf)) {
        $unattendXml = [xml](Get-Content -LiteralPath $cloudbaseUnattend -Raw -Encoding UTF8)
        $unattendNamespace = New-Object System.Xml.XmlNamespaceManager($unattendXml.NameTable)
        $unattendNamespace.AddNamespace('u', 'urn:schemas-microsoft-com:unattend')
        $autoLogon = $unattendXml.SelectSingleNode("//u:settings[@pass='oobeSystem']/u:component[@name='Microsoft-Windows-Shell-Setup']/u:AutoLogon", $unattendNamespace)
        $autoPassword = if ($autoLogon) { $autoLogon.SelectSingleNode('u:Password/u:Value', $unattendNamespace) } else { $null }
        $autoUser = if ($autoLogon) { $autoLogon.SelectSingleNode('u:Username', $unattendNamespace) } else { $null }
        if ($autoPassword -and $autoUser -and -not [string]::IsNullOrWhiteSpace($autoPassword.InnerText)) {
            # Windows 11 can reach the lock screen before it materializes the
            # oobeSystem LocalAccount node.  Use the pre-existing built-in
            # administrator for the one OOBE sign-in, then disable it again
            # during cleanup below.  This avoids depending on OOBE having
            # created LabBootstrap before Winlogon evaluates AutoLogon.
            $builtInAdministrator = Get-LocalUser | Where-Object { $_.SID.Value -match '-500$' } | Select-Object -First 1
            if (-not $builtInAdministrator) { throw 'The built-in administrator account was not found while arming OOBE autologon.' }
            $transientPassword = [Security.SecureString]::new()
            try {
                foreach ($passwordCharacter in $autoPassword.InnerText.ToCharArray()) {
                    $transientPassword.AppendChar($passwordCharacter)
                }
                $transientPassword.MakeReadOnly()
                Enable-LocalUser -Name $builtInAdministrator.Name
                Set-LocalUser -Name $builtInAdministrator.Name -Password $transientPassword
            }
            finally {
                $transientPassword.Dispose()
            }
            $winlogonPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
            New-ItemProperty -LiteralPath $winlogonPath -Name AutoAdminLogon -PropertyType String -Value '1' -Force | Out-Null
            New-ItemProperty -LiteralPath $winlogonPath -Name DefaultUserName -PropertyType String -Value $builtInAdministrator.Name -Force | Out-Null
            New-ItemProperty -LiteralPath $winlogonPath -Name DefaultPassword -PropertyType String -Value $autoPassword.InnerText -Force | Out-Null
            New-ItemProperty -LiteralPath $winlogonPath -Name DefaultDomainName -PropertyType String -Value '.' -Force | Out-Null
            New-ItemProperty -LiteralPath $winlogonPath -Name AutoLogonCount -PropertyType DWord -Value 1 -Force | Out-Null
            Set-Content -LiteralPath $autologonArmedMarker -Value 'armed' -Encoding Ascii
            Write-CleanupLog 'Armed one-use built-in administrator OOBE autologon; restarting once to leave the lock screen.'
            Restart-Computer -Force
            exit 0
        }
    }

    do {
        $imageState = (Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State' -Name ImageState -ErrorAction Stop).ImageState
        $lastBootUtc = (Get-CimInstance Win32_OperatingSystem -ErrorAction Stop).LastBootUpTime.ToUniversalTime()
        $cloudbaseService = Get-CimInstance Win32_Service -Filter "Name='cloudbase-init'" -ErrorAction Stop
        $cloudbaseComplete = (Test-Path -LiteralPath $cloudbaseLog -PathType Leaf) -and (Get-Item -LiteralPath $cloudbaseLog -ErrorAction Stop).LastWriteTimeUtc -ge $lastBootUtc -and [bool](Select-String -LiteralPath $cloudbaseLog -SimpleMatch 'Plugins execution done' -Quiet)

        # Windows 11 25H2 can complete the visible OOBE desktop while leaving
        # SysprepStatus\GeneralizationState at 4 and ChildCompletion\setup.exe
        # at 0. Cloudbase-Init intentionally waits for state 7 in that case.
        # Once a real user session exists and OOBE is no longer running, record
        # the documented completion state and let Cloudbase-Init continue.
        if ($isWindowsClient -and $imageState -eq 'IMAGE_STATE_GENERALIZE_RESEAL_TO_OOBE') {
            $sysprepStatusPath = 'HKLM:\SYSTEM\Setup\Status\SysprepStatus'
            $generalizationState = [int](Get-ItemProperty -LiteralPath $sysprepStatusPath -Name GeneralizationState -ErrorAction Stop).GeneralizationState
            $loggedOnUser = [string](Get-CimInstance Win32_ComputerSystem -ErrorAction Stop).UserName
            $oobeProcess = Get-Process -Name msoobe -ErrorAction SilentlyContinue
            if ($generalizationState -eq 4 -and -not [string]::IsNullOrWhiteSpace($loggedOnUser) -and -not $oobeProcess) {
                Set-ItemProperty -LiteralPath $sysprepStatusPath -Name GeneralizationState -Type DWord -Value 7 -Force
                Write-CleanupLog 'Windows 11 OOBE desktop is active; marked Sysprep generalization complete for Cloudbase-Init.'
            }
        }

        # Cloudbase-Init records GeneralizationState 7 after its Sysprep pass,
        # but Windows 11 25H2 can leave ImageState at the intermediate reseal
        # value even after the OOBE desktop and Cloudbase plugins completed.
        # Promote the state only after Cloudbase is stopped and its completion
        # marker is present; this keeps the certification gate evidence-based.
        if ($isWindowsClient -and $imageState -eq 'IMAGE_STATE_GENERALIZE_RESEAL_TO_OOBE' -and $cloudbaseService.State -eq 'Stopped' -and $cloudbaseComplete) {
            $sysprepStatusPath = 'HKLM:\SYSTEM\Setup\Status\SysprepStatus'
            $generalizationState = [int](Get-ItemProperty -LiteralPath $sysprepStatusPath -Name GeneralizationState -ErrorAction Stop).GeneralizationState
            if ($generalizationState -eq 7) {
                Set-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State' -Name ImageState -Type String -Value 'IMAGE_STATE_COMPLETE' -Force
                $imageState = 'IMAGE_STATE_COMPLETE'
                Write-CleanupLog 'Cloudbase-Init completed on Windows 11; promoted ImageState to IMAGE_STATE_COMPLETE.'
            }
        }

        $specialized = $env:COMPUTERNAME -ne 'WSLAB-BUILD' -and $imageState -eq 'IMAGE_STATE_COMPLETE' -and $cloudbaseService.State -eq 'Stopped' -and $cloudbaseComplete
        if (-not $specialized) { Start-Sleep -Seconds 5 }
    } while (-not $specialized -and (Get-Date) -lt $deadline)

if (-not $specialized) { throw 'Cloudbase-Init specialization did not reach a completed, stopped state within 20 minutes.' }

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
if (Test-Path -LiteralPath $autologonArmedMarker) { Remove-Item -LiteralPath $autologonArmedMarker -Force }

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
