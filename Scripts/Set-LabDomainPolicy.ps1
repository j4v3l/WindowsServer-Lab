#Requires -RunAsAdministrator
#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [string]$DefinitionPath,
    [switch]$ConfigureLaps,
    [switch]$ConfigureAccessControls,
    [switch]$ConfigurePrintPolicy,
    [ValidatePattern('^\\\\[^\\]+\\[^\\]+')][string]$WallpaperPath,
    [ValidateRange(15, 1440)][int]$GroupPolicyRefreshMinutes = 30,
    [ValidateRange(0, 60)][int]$GroupPolicyRandomOffsetMinutes = 10
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = 'C:\ProgramData\WindowsServerLab'
if (-not $DefinitionPath) { $DefinitionPath = "$root\LabConfig\lab.json" }
Import-Module "$root\Modules\WindowsServerLab\WindowsServerLab.psd1" -Force
Import-Module ActiveDirectory -ErrorAction Stop
Import-Module GroupPolicy -ErrorAction Stop
$definition = Import-LabDefinition -Path $DefinitionPath
$domain = Get-ADDomain -ErrorAction Stop
if ($domain.DNSRoot -notin @($definition.domain.dnsName, $definition.domain.legacyDnsName)) { throw 'Current domain does not match the lab definition.' }
$domainDn = ConvertTo-LabDistinguishedName -DomainName $domain.DNSRoot
$baseOu = "OU=$($definition.domain.baseOrganizationalUnit),$domainDn"
$management = $definition.virtualMachines | Where-Object role -eq 'management-server'
$subscriptionManager = "Server=http://$($management.name).$($domain.DNSRoot):5985/wsman/SubscriptionManager/WEC,Refresh=60"

$gpoName = 'WSLAB-v2-Security-Baseline'
$settings = @(
    @{ Key = 'HKLM\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient'; Name = 'EnableMulticast'; Type = 'DWord'; Value = 0 },
    @{ Key = 'HKLM\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging'; Name = 'EnableScriptBlockLogging'; Type = 'DWord'; Value = 1 },
    @{ Key = 'HKLM\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription'; Name = 'EnableTranscripting'; Type = 'DWord'; Value = 1 },
    @{ Key = 'HKLM\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging'; Name = 'EnableModuleLogging'; Type = 'DWord'; Value = 1 },
    @{ Key = 'HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest'; Name = 'UseLogonCredential'; Type = 'DWord'; Value = 0 },
    @{ Key = 'HKLM\SOFTWARE\Policies\Microsoft\Windows\LanmanWorkstation'; Name = 'AllowInsecureGuestAuth'; Type = 'DWord'; Value = 0 },
    @{ Key = 'HKLM\SOFTWARE\Policies\Microsoft\Windows Defender'; Name = 'PUAProtection'; Type = 'DWord'; Value = 1 },
    @{ Key = 'HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services'; Name = 'UserAuthentication'; Type = 'DWord'; Value = 1 },
    @{ Key = 'HKLM\SYSTEM\CurrentControlSet\Services\NTDS\Parameters'; Name = 'LDAPServerIntegrity'; Type = 'DWord'; Value = 2 },
    @{ Key = 'HKLM\SYSTEM\CurrentControlSet\Services\NTDS\Parameters'; Name = 'LdapEnforceChannelBinding'; Type = 'DWord'; Value = 2 },
    @{ Key = 'HKLM\SYSTEM\CurrentControlSet\Services\LDAP'; Name = 'LdapClientIntegrity'; Type = 'DWord'; Value = 2 },
    @{ Key = 'HKLM\SOFTWARE\Microsoft\.NETFramework\v4.0.30319'; Name = 'SchUseStrongCrypto'; Type = 'DWord'; Value = 1 },
    @{ Key = 'HKLM\SOFTWARE\Microsoft\.NETFramework\v4.0.30319'; Name = 'SystemDefaultTlsVersions'; Type = 'DWord'; Value = 1 },
    @{ Key = 'HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server'; Name = 'Enabled'; Type = 'DWord'; Value = 0 },
    @{ Key = 'HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server'; Name = 'DisabledByDefault'; Type = 'DWord'; Value = 1 },
    @{ Key = 'HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Client'; Name = 'Enabled'; Type = 'DWord'; Value = 0 },
    @{ Key = 'HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Client'; Name = 'DisabledByDefault'; Type = 'DWord'; Value = 1 },
    @{ Key = 'HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server'; Name = 'Enabled'; Type = 'DWord'; Value = 1 },
    @{ Key = 'HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server'; Name = 'DisabledByDefault'; Type = 'DWord'; Value = 0 },
    @{ Key = 'HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client'; Name = 'Enabled'; Type = 'DWord'; Value = 1 },
    @{ Key = 'HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client'; Name = 'DisabledByDefault'; Type = 'DWord'; Value = 0 },
    @{ Key = 'HKLM\SOFTWARE\Policies\Microsoft\Windows\EventLog\EventForwarding\SubscriptionManager'; Name = '1'; Type = 'String'; Value = $subscriptionManager }
)

if ($ConfigureLaps) {
    $settings += @(
        @{ Key = 'HKLM\SOFTWARE\Microsoft\Policies\LAPS'; Name = 'BackupDirectory'; Type = 'DWord'; Value = 2 },
        @{ Key = 'HKLM\SOFTWARE\Microsoft\Policies\LAPS'; Name = 'PasswordAgeDays'; Type = 'DWord'; Value = 30 },
        @{ Key = 'HKLM\SOFTWARE\Microsoft\Policies\LAPS'; Name = 'PasswordLength'; Type = 'DWord'; Value = 18 },
        @{ Key = 'HKLM\SOFTWARE\Microsoft\Policies\LAPS'; Name = 'PasswordComplexity'; Type = 'DWord'; Value = 4 },
        @{ Key = 'HKLM\SOFTWARE\Microsoft\Policies\LAPS'; Name = 'ADPasswordEncryptionEnabled'; Type = 'DWord'; Value = 1 }
    )
}

if ($PSCmdlet.ShouldProcess($baseOu, "Create, configure, verify, and link $gpoName")) {
    $gpo = Get-GPO -Name $gpoName -ErrorAction Ignore
    if (-not $gpo) { $gpo = New-GPO -Name $gpoName -Comment 'WindowsServerLab v2 explicit security settings; role baselines are applied separately.' -ErrorAction Stop }
    foreach ($setting in $settings) {
        Set-GPRegistryValue -Name $gpoName -Key $setting.Key -ValueName $setting.Name -Type $setting.Type -Value $setting.Value -ErrorAction Stop
        $actual = Get-GPRegistryValue -Name $gpoName -Key $setting.Key -ValueName $setting.Name -ErrorAction Stop
        if ($actual.Value -ne $setting.Value) { throw "GPO verification failed for $($setting.Key)\$($setting.Name)." }
    }
    $link = (Get-GPInheritance -Target $baseOu -ErrorAction Stop).GpoLinks | Where-Object DisplayName -eq $gpoName
    if (-not $link) { New-GPLink -Name $gpoName -Target $baseOu -LinkEnabled Yes -ErrorAction Stop | Out-Null }
}

if ($ConfigureLaps -and $PSCmdlet.ShouldProcess($domain.DNSRoot, 'Prepare Windows LAPS schema and permissions')) {
    $commands = @('Update-LapsADSchema', 'Set-LapsADComputerSelfPermission')
    foreach ($command in $commands) {
        if (-not (Get-Command $command -ErrorAction Ignore)) { throw "Windows LAPS command is unavailable: $command" }
    }
    Update-LapsADSchema -Confirm:$false -ErrorAction Stop
    Set-LapsADComputerSelfPermission -Identity "OU=Servers,$baseOu" -ErrorAction Stop
    Set-LapsADComputerSelfPermission -Identity "OU=Workstations,$baseOu" -ErrorAction Stop
}

if ($PSCmdlet.ShouldProcess($baseOu, 'Configure native background Group Policy refresh')) {
    & (Join-Path $root 'Scripts\Set-LabGroupPolicyRefresh.ps1') -DefinitionPath $DefinitionPath -ComputerIntervalMinutes $GroupPolicyRefreshMinutes -ComputerRandomOffsetMinutes $GroupPolicyRandomOffsetMinutes -UserIntervalMinutes $GroupPolicyRefreshMinutes -UserRandomOffsetMinutes $GroupPolicyRandomOffsetMinutes -Confirm:$false
}

if ($ConfigureAccessControls -and $PSCmdlet.ShouldProcess($domain.DNSRoot, 'Initialize group-filtered endpoint access controls')) {
    $accessParameters = @{
        Initialize = $true
        DefinitionPath = $DefinitionPath
        Confirm = $false
    }
    if ($WallpaperPath) { $accessParameters.WallpaperPath = $WallpaperPath }
    & (Join-Path $root 'Scripts\Set-LabAccessControl.ps1') @accessParameters
}

if ($ConfigurePrintPolicy -and $PSCmdlet.ShouldProcess($domain.DNSRoot, 'Initialize trusted print-server policy and access groups')) {
    & (Join-Path $root 'Scripts\Set-LabPrintPolicy.ps1') -Initialize -DefinitionPath $DefinitionPath -Confirm:$false
}

Write-LabLog -Level Info -Message "Verified domain policy $gpoName" -Data @{ Lab = $definition.name; Target = $baseOu; SettingCount = $settings.Count }
