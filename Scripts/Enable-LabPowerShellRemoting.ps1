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
    if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, 'Enable domain-scoped Kerberos PowerShell remoting')) {
        Enable-PSRemoting -Force -ErrorAction Stop
        Set-Service -Name WinRM -StartupType Automatic -ErrorAction Stop
        Start-Service -Name WinRM -ErrorAction Stop
        Set-Item -Path WSMan:\localhost\Service\AllowUnencrypted -Value $false -Force -ErrorAction Stop
        Set-Item -Path WSMan:\localhost\Service\Auth\Basic -Value $false -Force -ErrorAction Stop
        Set-Item -Path WSMan:\localhost\Service\Auth\Certificate -Value $false -Force -ErrorAction Stop
        Set-Item -Path WSMan:\localhost\Service\Auth\CredSSP -Value $false -Force -ErrorAction Stop
        Set-Item -Path WSMan:\localhost\Service\Auth\Kerberos -Value $true -Force -ErrorAction Stop
        Set-Item -Path WSMan:\localhost\Service\Auth\Negotiate -Value $false -Force -ErrorAction Stop

        $rules = @(Get-NetFirewallRule -PolicyStore ActiveStore -ErrorAction Stop | Where-Object { $_.Service -eq 'WinRM' })
        if ($rules.Count -eq 0) { throw 'No WinRM firewall rules were created.' }
        $rules | Set-NetFirewallRule -Enabled True -Profile Domain -Action Allow -Direction Inbound -ErrorAction Stop
        $rules | Get-NetFirewallAddressFilter -ErrorAction Stop | Set-NetFirewallAddressFilter -RemoteAddress LocalSubnet -ErrorAction Stop

        $service = Get-Service -Name WinRM -ErrorAction Stop
        $listener = @(Get-ChildItem -Path WSMan:\localhost\Listener -ErrorAction Stop)
        if ($service.Status -ne 'Running' -or $service.StartType -ne 'Automatic' -or $listener.Count -eq 0) { throw 'WinRM service or listener verification failed.' }
        if ([bool](Get-Item WSMan:\localhost\Service\AllowUnencrypted).Value -or [bool](Get-Item WSMan:\localhost\Service\Auth\Basic).Value -or -not [bool](Get-Item WSMan:\localhost\Service\Auth\Kerberos).Value) {
            throw 'WinRM authentication verification failed.'
        }
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
