#Requires -RunAsAdministrator
#Requires -Version 5.1
<#
.SYNOPSIS
    Enables domain-scoped, Kerberos-only Windows PowerShell remoting for lab operations.
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [string]$OutputPath = 'C:\ProgramData\WindowsServerLab\Reports\powershell-remoting.json'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-RegistryBooleanValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$RegistryItem,
        [Parameter(Mandatory)][string]$Name,
        [bool]$Default = $false
    )

    $property = $RegistryItem.PSObject.Properties[$Name]
    if ($null -eq $property) { return $Default }
    return [bool]$property.Value
}

$computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
if (-not $computerSystem.PartOfDomain) { throw 'PowerShell remoting is enabled only after the machine has joined the lab domain.' }

$result = [ordered]@{
    schemaVersion = 1
    timestamp = (Get-Date).ToUniversalTime().ToString('o')
    computerName = $env:COMPUTERNAME
    domain = [string]$computerSystem.Domain
    authentication = 'Kerberos'
    remoteAddress = 'LocalSubnet'
    status = 'planned'
}

try {
    $winRmServiceRegistryPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WSMAN\Service'
    $winRmListenerRegistryPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WSMAN\Listener'
    $currentService = Get-Service -Name WinRM -ErrorAction Stop
    $currentPolicy = Get-ItemProperty -LiteralPath $winRmServiceRegistryPath -ErrorAction Stop
    $currentListeners = @(Get-ChildItem -LiteralPath $winRmListenerRegistryPath -ErrorAction SilentlyContinue)
    $currentDomainRule = Get-NetFirewallRule -Name 'WINRM-HTTP-In-TCP' -ErrorAction SilentlyContinue
    $currentDomainRuleProfile = if ($currentDomainRule) { [string]$currentDomainRule.Profile } else { '' }
    # Domain-joined guests can briefly report the Private profile while NLA
    # finishes establishing the domain trust. WEC validates the effective
    # firewall exception rather than the rule's profile bitmask, so the
    # narrowly scoped LocalSubnet rule uses Any profile to remain reliable
    # across reboots and first-boot timing.
    $currentDomainRuleCoversLabProfiles =
        $currentDomainRuleProfile -match 'Any' -or
        ($currentDomainRuleProfile -match 'Domain' -and $currentDomainRuleProfile -match 'Private')
    $currentRemoteAddresses = @($currentDomainRule |
        Get-NetFirewallAddressFilter -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty RemoteAddress)
    $currentHttpsRules = @(Get-NetFirewallRule -PolicyStore ActiveStore -ErrorAction Stop |
        Get-NetFirewallPortFilter -ErrorAction Stop |
        Where-Object { $_.LocalPort -eq '5986' } |
        Get-NetFirewallRule -ErrorAction Stop)
    $enabledCurrentHttpsRules = @($currentHttpsRules | Where-Object Enabled -eq 'True')
    $allowUnencrypted = Get-RegistryBooleanValue -RegistryItem $currentPolicy -Name 'allow_unencrypted'
    $authBasic = Get-RegistryBooleanValue -RegistryItem $currentPolicy -Name 'auth_basic'
    $authCertificate = Get-RegistryBooleanValue -RegistryItem $currentPolicy -Name 'auth_certificate'
    $authCredSsp = Get-RegistryBooleanValue -RegistryItem $currentPolicy -Name 'auth_credssp'
    $authKerberos = Get-RegistryBooleanValue -RegistryItem $currentPolicy -Name 'auth_kerberos' -Default $true
    $authNegotiate = Get-RegistryBooleanValue -RegistryItem $currentPolicy -Name 'auth_negotiate' -Default $true
    $alreadyConfigured =
        $currentService.Status -eq 'Running' -and
        $currentService.StartType -eq 'Automatic' -and
        $currentListeners.Count -gt 0 -and
        -not $allowUnencrypted -and
        -not $authBasic -and
        -not $authCertificate -and
        -not $authCredSsp -and
        $authKerberos -and
        -not $authNegotiate -and
        $currentDomainRule -and
        $currentDomainRule.Enabled -eq 'True' -and
        $currentDomainRuleCoversLabProfiles -and
        $currentDomainRule.Action -eq 'Allow' -and
        $currentDomainRule.Direction -eq 'Inbound' -and
        $currentRemoteAddresses.Count -eq 1 -and
        $currentRemoteAddresses[0] -eq 'LocalSubnet' -and
        $enabledCurrentHttpsRules.Count -eq 0

    if ($alreadyConfigured) {
        $result.status = 'configured'
    }
    elseif ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, 'Enable domain-scoped Kerberos PowerShell remoting')) {
        # A previous idempotent pass may already have disabled Negotiate. The
        # local WSMan provider requires it while configuring localhost, so
        # enable it only for this setup window and close it again below.
        Set-ItemProperty -LiteralPath $winRmServiceRegistryPath -Name auth_negotiate -Type DWord -Value 1 -Force -ErrorAction Stop
        Set-Service -Name WinRM -StartupType Automatic -ErrorAction Stop
        Restart-Service -Name WinRM -Force -ErrorAction Stop
        Enable-PSRemoting -Force -ErrorAction Stop
        Start-Service -Name WinRM -ErrorAction Stop
        Set-Item -Path WSMan:\localhost\Service\AllowUnencrypted -Value $false -Force -ErrorAction Stop
        Set-Item -Path WSMan:\localhost\Service\Auth\Basic -Value $false -Force -ErrorAction Stop
        Set-Item -Path WSMan:\localhost\Service\Auth\Certificate -Value $false -Force -ErrorAction Stop
        Set-Item -Path WSMan:\localhost\Service\Auth\CredSSP -Value $false -Force -ErrorAction Stop
        Set-Item -Path WSMan:\localhost\Service\Auth\Kerberos -Value $true -Force -ErrorAction Stop

        $domainRule = Get-NetFirewallRule -Name 'WINRM-HTTP-In-TCP' -ErrorAction Stop
        Set-NetFirewallRule -Name $domainRule.Name -Enabled True -Profile Any -Action Allow -Direction Inbound -ErrorAction Stop
        Get-NetFirewallRule -Name $domainRule.Name -ErrorAction Stop |
            Get-NetFirewallAddressFilter -ErrorAction Stop |
            Set-NetFirewallAddressFilter -RemoteAddress LocalSubnet -ErrorAction Stop
        if (Get-NetFirewallRule -Name 'WINRM-HTTP-In-TCP-PUBLIC' -ErrorAction SilentlyContinue) {
            Disable-NetFirewallRule -Name 'WINRM-HTTP-In-TCP-PUBLIC' -ErrorAction Stop
        }

        $httpsRules = @(Get-NetFirewallRule -PolicyStore ActiveStore -ErrorAction Stop |
            Get-NetFirewallPortFilter -ErrorAction Stop |
            Where-Object { $_.LocalPort -eq '5986' } |
            Get-NetFirewallRule -ErrorAction Stop)
        foreach ($httpsRule in $httpsRules) {
            Disable-NetFirewallRule -Name $httpsRule.Name -ErrorAction Stop
        }

        $listener = @(Get-ChildItem -Path WSMan:\localhost\Listener -ErrorAction Stop)

        # The WSMan provider itself connects to localhost with Negotiate. Make
        # its final change only after all provider-backed configuration is done.
        Set-Item -Path WSMan:\localhost\Service\Auth\Negotiate -Value $false -Force -ErrorAction Stop

        $service = Get-Service -Name WinRM -ErrorAction Stop
        if ($service.Status -ne 'Running' -or $service.StartType -ne 'Automatic' -or $listener.Count -eq 0) { throw 'WinRM service or listener verification failed.' }
        $effectiveDomainRule = Get-NetFirewallRule -PolicyStore ActiveStore -Name $domainRule.Name -ErrorAction Stop
        $effectiveProfile = [string]$effectiveDomainRule.Profile
        $effectiveCoversLabProfiles =
            $effectiveProfile -match 'Any' -or
            ($effectiveProfile -match 'Domain' -and $effectiveProfile -match 'Private')
        if ($effectiveDomainRule.Enabled -ne 'True' -or $effectiveDomainRule.Action -ne 'Allow' -or $effectiveDomainRule.Direction -ne 'Inbound' -or -not $effectiveCoversLabProfiles) {
            throw 'The effective WinRM firewall rule does not cover all profiles.'
        }
        $winRmServicePolicy = Get-ItemProperty -LiteralPath $winRmServiceRegistryPath -ErrorAction Stop
        $verifiedAllowUnencrypted = Get-RegistryBooleanValue -RegistryItem $winRmServicePolicy -Name 'allow_unencrypted'
        $verifiedAuthBasic = Get-RegistryBooleanValue -RegistryItem $winRmServicePolicy -Name 'auth_basic'
        $verifiedAuthKerberos = Get-RegistryBooleanValue -RegistryItem $winRmServicePolicy -Name 'auth_kerberos' -Default $true
        $verifiedAuthNegotiate = Get-RegistryBooleanValue -RegistryItem $winRmServicePolicy -Name 'auth_negotiate' -Default $true
        $enabledHttpsRules = @($httpsRules |
            ForEach-Object { Get-NetFirewallRule -PolicyStore ActiveStore -Name $_.Name -ErrorAction SilentlyContinue } |
            Where-Object Enabled -eq 'True')
        if ($verifiedAllowUnencrypted -or $verifiedAuthBasic -or -not $verifiedAuthKerberos -or $verifiedAuthNegotiate) {
            throw 'WinRM authentication verification failed.'
        }
        if ($enabledHttpsRules.Count -ne 0) { throw 'A WinRM HTTPS firewall rule remains enabled.' }
        $result.status = 'configured'
    }
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
