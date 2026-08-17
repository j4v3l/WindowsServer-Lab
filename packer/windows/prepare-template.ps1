#Requires -RunAsAdministrator
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = 'C:\ProgramData\WindowsServerLab'
foreach ($path in @($root, "$root\Scripts", "$root\Modules", "$root\LabConfig", "$root\Logs", "$root\Reports")) {
    if (-not (Test-Path -LiteralPath $path)) {
        New-Item -Path $path -ItemType Directory -Force | Out-Null
    }
}

$bootstrapComplete = "$root\bootstrap.complete"
$bootstrapFailed = "$root\bootstrap.failed"
$bootstrapDeadline = (Get-Date).AddMinutes(30)
while (-not (Test-Path -LiteralPath $bootstrapComplete)) {
    if (Test-Path -LiteralPath $bootstrapFailed) {
        $bootstrapError = Get-Content -LiteralPath $bootstrapFailed -Raw
        throw "Template bootstrap failed: $bootstrapError"
    }
    if ((Get-Date) -ge $bootstrapDeadline) { throw 'Template bootstrap did not complete within 30 minutes.' }
    Start-Sleep -Seconds 5
}
$bootstrapResult = Get-Content -LiteralPath $bootstrapComplete -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
if ($bootstrapResult.status -ne 'complete') { throw 'The template bootstrap completion sentinel is invalid.' }

$cloudbaseConfig = 'C:\Program Files\Cloudbase Solutions\Cloudbase-Init\conf\cloudbase-init.conf'
$cloudbaseUnattendConfig = 'C:\Program Files\Cloudbase Solutions\Cloudbase-Init\conf\cloudbase-init-unattend.conf'
foreach ($requiredConfig in @($cloudbaseConfig, $cloudbaseUnattendConfig)) {
    if (-not (Test-Path -LiteralPath $requiredConfig -PathType Leaf)) {
        throw "Cloudbase-Init configuration is missing: $requiredConfig"
    }
}

function ConvertTo-IniValue {
    param([Parameter(Mandatory)][string[]]$Content, [Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][string]$Value)
    $replacement = "$Name=$Value"
    if (@($Content | Where-Object { $_ -match "^$([Regex]::Escape($Name))\s*=" }).Count -gt 0) {
        return @($Content | ForEach-Object { if ($_ -match "^$([Regex]::Escape($Name))\s*=") { $replacement } else { $_ } })
    }
    return @($Content) + $replacement
}

function Set-IniListWithoutEntry {
    param(
        [Parameter(Mandatory)][string[]]$Content,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Entry,
        [string[]]$FallbackEntries = @()
    )

    $startIndexes = @(0..($Content.Count - 1) | Where-Object { $Content[$_] -match "^$([Regex]::Escape($Name))\s*=" })
    if ($startIndexes.Count -gt 1) {
        throw "Expected no more than one '$Name' setting, found $($startIndexes.Count)."
    }
    if ($startIndexes.Count -eq 0) {
        $filteredFallback = @($FallbackEntries | Where-Object { $_ -and $_ -ne $Entry } | Select-Object -Unique)
        if ($filteredFallback.Count -eq 0) {
            throw "Cloudbase-Init '$Name' is absent and no safe explicit fallback was supplied."
        }
        return @($Content) + "$Name=$($filteredFallback -join ',')"
    }

    $start = $startIndexes[0]
    $end = $start + 1
    while ($end -lt $Content.Count -and $Content[$end] -match '^\s+\S') { $end++ }

    $firstValue = $Content[$start] -replace "^$([Regex]::Escape($Name))\s*=\s*", ''
    $rawValues = @($firstValue)
    if ($end -gt ($start + 1)) {
        $rawValues += @($Content[($start + 1)..($end - 1)])
    }
    $combinedValues = $rawValues -join ','
    $values = @($combinedValues -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    $filteredValues = @($values | Where-Object { $_ -ne $Entry })
    if ($filteredValues.Count -eq 0) { throw "Removing '$Entry' would leave '$Name' empty." }

    $result = [System.Collections.Generic.List[string]]::new()
    for ($index = 0; $index -lt $Content.Count; $index++) {
        if ($index -eq $start) {
            $result.Add("$Name=$($filteredValues -join ',')")
            $index = $end - 1
        }
        else {
            $result.Add($Content[$index])
        }
    }
    return $result.ToArray()
}

$hostnamePlugin = 'cloudbaseinit.plugins.common.sethostname.SetHostNamePlugin'
# Cloudbase-Init 1.1.8 defaults to this list when a config omits `plugins`.
# Make it explicit so removing SetHostNamePlugin cannot silently fall back to
# the default list and request a disruptive reboot during Windows OOBE.
$cloudbaseDefaultPlugins = @(
    'cloudbaseinit.plugins.common.mtu.MTUPlugin',
    'cloudbaseinit.plugins.windows.ntpclient.NTPClientPlugin',
    $hostnamePlugin,
    'cloudbaseinit.plugins.windows.createuser.CreateUserPlugin',
    'cloudbaseinit.plugins.common.networkconfig.NetworkConfigPlugin',
    'cloudbaseinit.plugins.windows.licensing.WindowsLicensingPlugin',
    'cloudbaseinit.plugins.common.sshpublickeys.SetUserSSHPublicKeysPlugin',
    'cloudbaseinit.plugins.windows.extendvolumes.ExtendVolumesPlugin',
    'cloudbaseinit.plugins.common.userdata.UserDataPlugin',
    'cloudbaseinit.plugins.common.setuserpassword.SetUserPasswordPlugin',
    'cloudbaseinit.plugins.windows.winrmlistener.ConfigWinRMListenerPlugin',
    'cloudbaseinit.plugins.windows.winrmcertificateauth.ConfigWinRMCertificateAuthPlugin',
    'cloudbaseinit.plugins.common.localscripts.LocalScriptsPlugin'
)

$config = @(Get-Content -LiteralPath $cloudbaseConfig)
$config = ConvertTo-IniValue -Content $config -Name metadata_services -Value 'cloudbaseinit.metadata.services.configdrive.ConfigDriveService'
$config = ConvertTo-IniValue -Content $config -Name username -Value 'LabBootstrap'
$config = ConvertTo-IniValue -Content $config -Name first_logon_behaviour -Value 'no'
$config = ConvertTo-IniValue -Content $config -Name allow_reboot -Value 'false'
$config = Set-IniListWithoutEntry -Content $config -Name plugins -Entry $hostnamePlugin -FallbackEntries $cloudbaseDefaultPlugins
Set-Content -LiteralPath $cloudbaseConfig -Value $config -Encoding Ascii

$explicitPluginSettings = @($config | Where-Object { $_ -match '^plugins\s*=' })
if ($explicitPluginSettings.Count -ne 1) {
    throw "Expected one normalized Cloudbase-Init plugins setting, found $($explicitPluginSettings.Count)."
}
$safePluginDefaults = @(
    ($explicitPluginSettings[0] -replace '^plugins\s*=\s*', '') -split ',' |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -and $_ -ne $hostnamePlugin }
)
if ($safePluginDefaults.Count -eq 0) { throw 'The safe Cloudbase-Init plugin list is empty.' }

$unattendConfig = @(Get-Content -LiteralPath $cloudbaseUnattendConfig)
$unattendConfig = ConvertTo-IniValue -Content $unattendConfig -Name allow_reboot -Value 'false'
$unattendConfig = Set-IniListWithoutEntry -Content $unattendConfig -Name plugins -Entry $hostnamePlugin -FallbackEntries $safePluginDefaults
Set-Content -LiteralPath $cloudbaseUnattendConfig -Value $unattendConfig -Encoding Ascii

# Windows 11's inbox OneDriveSync AppX package can block Sysprep/OOBE and
# leave Cloudbase-Init waiting forever at GeneralizationState 4.  Remove both
# installed and provisioned copies before sealing the reusable image.  The
# package is optional, so an absent package is a successful no-op.
if ((Get-CimInstance Win32_OperatingSystem -ErrorAction Stop).Caption -like 'Microsoft Windows 11*') {
    Get-AppxPackage -AllUsers -Name 'Microsoft.OneDriveSync' -ErrorAction SilentlyContinue |
        Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
    Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -eq 'Microsoft.OneDriveSync' } |
        Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Out-Null
}

# Cloudbase-Init's Windows specialize pass expects an enabled local
# Administrator on client editions.  Re-enable it only for that pass; the
# first-boot cleanup task disables it again after specialization and records
# the result in its completion sentinel.
$unattendPath = 'C:\Program Files\Cloudbase Solutions\Cloudbase-Init\conf\Unattend.xml'
$unattendXml = [xml](Get-Content -LiteralPath $unattendPath -Raw -Encoding UTF8)
$namespace = New-Object System.Xml.XmlNamespaceManager($unattendXml.NameTable)
$namespace.AddNamespace('u', 'urn:schemas-microsoft-com:unattend')
$namespace.AddNamespace('wcm', 'http://schemas.microsoft.com/WMIConfig/2002/State')
$specializeComponent = $unattendXml.SelectSingleNode("//u:settings[@pass='specialize']/u:component[@name='Microsoft-Windows-Deployment']", $namespace)
if (-not $specializeComponent) { throw 'Cloudbase-Init Sysprep answer file is missing the specialize deployment component.' }
$runSynchronous = $specializeComponent.SelectSingleNode('u:RunSynchronous', $namespace)
if (-not $runSynchronous) { throw 'Cloudbase-Init Sysprep answer file is missing RunSynchronous commands.' }
$cloudbaseCommand = $runSynchronous.SelectSingleNode("u:RunSynchronousCommand[u:Path[contains(., 'cloudbase-init.exe')]]", $namespace)
if ($cloudbaseCommand -and $cloudbaseCommand.SelectSingleNode('u:Order', $namespace)) {
    $cloudbaseCommand.SelectSingleNode('u:Order', $namespace).InnerText = '2'
}
$existingAdministratorCommand = $runSynchronous.SelectSingleNode("u:RunSynchronousCommand[u:Path='net user administrator /active:yes']", $namespace)
if (-not $existingAdministratorCommand) {
    $enableAdministrator = $unattendXml.CreateElement('RunSynchronousCommand', 'urn:schemas-microsoft-com:unattend')
    $enableAdministrator.SetAttribute('action', 'http://schemas.microsoft.com/WMIConfig/2002/State', 'add')
    foreach ($entry in @(
        @{ Name = 'Order'; Value = '1' },
        @{ Name = 'Path'; Value = 'net user administrator /active:yes' },
        @{ Name = 'Description'; Value = 'Enable the built-in administrator for Cloudbase-Init specialization' },
        @{ Name = 'WillReboot'; Value = 'Never' }
    )) {
        $node = $unattendXml.CreateElement($entry.Name, 'urn:schemas-microsoft-com:unattend')
        $node.InnerText = $entry.Value
        $enableAdministrator.AppendChild($node) | Out-Null
    }
    $runSynchronous.AppendChild($enableAdministrator) | Out-Null
}

# Windows 11 24H2/25H2 no longer reliably honors the legacy Skip*OOBE
# switches.  Configure the supported OOBE controls explicitly so a fresh
# clone can finish setup without an interactive desktop session.  Existing
# local accounts (including LabBootstrap, whose password is replaced during
# sealing) remain available for the first-boot cleanup task.
$oobeComponent = $unattendXml.SelectSingleNode("//u:settings[@pass='oobeSystem']/u:component[@name='Microsoft-Windows-Shell-Setup']", $namespace)
if (-not $oobeComponent) {
    throw 'Cloudbase-Init Sysprep answer file is missing the oobeSystem Shell-Setup component.'
}
$oobeSettings = $oobeComponent.ParentNode
$internationalCore = $oobeSettings.SelectSingleNode("u:component[@name='Microsoft-Windows-International-Core']", $namespace)
if (-not $internationalCore) {
    $internationalCore = $unattendXml.CreateElement('component', 'urn:schemas-microsoft-com:unattend')
    $internationalCore.SetAttribute('name', 'Microsoft-Windows-International-Core')
    $internationalCore.SetAttribute('processorArchitecture', 'amd64')
    $internationalCore.SetAttribute('publicKeyToken', '31bf3856ad364e35')
    $internationalCore.SetAttribute('language', 'neutral')
    $internationalCore.SetAttribute('versionScope', 'nonSxS')
    $oobeSettings.InsertBefore($internationalCore, $oobeComponent) | Out-Null
}
foreach ($localeSetting in @('InputLocale', 'SystemLocale', 'UILanguage', 'UILanguageFallback', 'UserLocale')) {
    $localeNode = $internationalCore.SelectSingleNode("u:$localeSetting", $namespace)
    if (-not $localeNode) {
        $localeNode = $unattendXml.CreateElement($localeSetting, 'urn:schemas-microsoft-com:unattend')
        $internationalCore.AppendChild($localeNode) | Out-Null
    }
    $localeNode.InnerText = 'en-US'
}
$oobe = $oobeComponent.SelectSingleNode('u:OOBE', $namespace)
if (-not $oobe) {
    $oobe = $unattendXml.CreateElement('OOBE', 'urn:schemas-microsoft-com:unattend')
    $oobeComponent.AppendChild($oobe) | Out-Null
}
foreach ($obsoleteName in @('SkipMachineOOBE', 'SkipUserOOBE')) {
    $obsolete = $oobe.SelectSingleNode("u:$obsoleteName", $namespace)
    if ($obsolete) { $oobe.RemoveChild($obsolete) | Out-Null }
}
foreach ($setting in @(
    @{ Name = 'HideOnlineAccountScreens'; Value = 'true' },
    @{ Name = 'HideWirelessSetupInOOBE'; Value = 'true' },
    @{ Name = 'HideOEMRegistrationScreen'; Value = 'true' },
    @{ Name = 'ProtectYourPC'; Value = '3' }
)) {
    $node = $oobe.SelectSingleNode("u:$($setting.Name)", $namespace)
    if (-not $node) {
        $node = $unattendXml.CreateElement($setting.Name, 'urn:schemas-microsoft-com:unattend')
        $oobe.AppendChild($node) | Out-Null
    }
    $node.InnerText = $setting.Value
}
$unattendXml.Save($unattendPath)

Set-Service QEMU-GA -StartupType Automatic
Set-Service cloudbase-init -StartupType Automatic
if ((Get-Service QEMU-GA -ErrorAction Stop).Status -ne 'Running') { Start-Service QEMU-GA }

$sshdConfig = Join-Path $env:ProgramData 'ssh\sshd_config'
if ((Get-Service sshd -ErrorAction SilentlyContinue) -and (Test-Path -LiteralPath $sshdConfig)) {
    Set-Service sshd -StartupType Automatic
    $sshdContent = Get-Content -LiteralPath $sshdConfig
    $sshdContent = $sshdContent -replace '^\s*#?\s*PasswordAuthentication\s+.*$', 'PasswordAuthentication no'
    if (@($sshdContent | Where-Object { $_ -eq 'PasswordAuthentication no' }).Count -eq 0) { $sshdContent += 'PasswordAuthentication no' }
    Set-Content -LiteralPath $sshdConfig -Value $sshdContent -Encoding Ascii
}
