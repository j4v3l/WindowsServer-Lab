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

$moduleSource = "$root\Scripts\WindowsServerLab"
$moduleTarget = "$root\Modules\WindowsServerLab"
if (-not (Test-Path -LiteralPath $moduleSource)) { throw "Module payload is missing: $moduleSource" }
if (Test-Path -LiteralPath $moduleTarget) { Remove-Item -LiteralPath $moduleTarget -Recurse -Force }
Copy-Item -LiteralPath $moduleSource -Destination $moduleTarget -Recurse -Force

$cloudbaseConfig = 'C:\Program Files\Cloudbase Solutions\Cloudbase-Init\conf\cloudbase-init.conf'
if (-not (Test-Path -LiteralPath $cloudbaseConfig)) {
    throw 'Cloudbase-Init was not installed by bootstrap.ps1.'
}

function ConvertTo-IniValue {
    param([Parameter(Mandatory)][string[]]$Content, [Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][string]$Value)
    $replacement = "$Name=$Value"
    if (@($Content | Where-Object { $_ -match "^$([Regex]::Escape($Name))=" }).Count -gt 0) {
        return @($Content | ForEach-Object { if ($_ -match "^$([Regex]::Escape($Name))=") { $replacement } else { $_ } })
    }
    return @($Content) + $replacement
}

$config = @(Get-Content -LiteralPath $cloudbaseConfig)
$config = ConvertTo-IniValue -Content $config -Name metadata_services -Value 'cloudbaseinit.metadata.services.configdrive.ConfigDriveService'
$config = ConvertTo-IniValue -Content $config -Name username -Value 'LabBootstrap'
$config = ConvertTo-IniValue -Content $config -Name first_logon_behaviour -Value 'no'
Set-Content -LiteralPath $cloudbaseConfig -Value $config -Encoding Ascii

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
