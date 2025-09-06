.# Wrapper delegates to top-level script if present; keeping a single implementation here
.
Set-Location -Path (Split-Path -Parent $MyInvocation.MyCommand.Path)
.
# Implementation moved here for clarity
# Client Onboarding Script (Join Domain, Rename, DNS)
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$DomainName,
    [string]$ComputerName,
    [string]$OUPath,
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$DomainJoinUser,
    [Parameter(Mandatory=$true)][System.Security.SecureString]$DomainJoinPassword,
    [string]$DNSServer,
    [switch]$Reboot
)

function Test-IsAdmin { $id=[Security.Principal.WindowsIdentity]::GetCurrent(); $p=New-Object Security.Principal.WindowsPrincipal($id); $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) }
if (-not (Test-IsAdmin)) { Write-Error 'Run as Administrator.'; exit 1 }

try {
    if ($DNSServer) {
        Get-NetAdapter -Physical | Where-Object Status -eq 'Up' | ForEach-Object { Set-DnsClientServerAddress -InterfaceAlias $_.Name -ServerAddresses $DNSServer -ErrorAction Stop }
    }
    if ($ComputerName -and ($env:COMPUTERNAME -ne $ComputerName)) { Rename-Computer -NewName $ComputerName -Force -ErrorAction Stop; $renameDone=$true }
    $cred = New-Object System.Management.Automation.PSCredential($DomainJoinUser, $DomainJoinPassword)
    $joinParams = @{ DomainName=$DomainName; Credential=$cred; ErrorAction='Stop' }
    if ($OUPath) { $joinParams.OUPath = $OUPath }
    Add-Computer @joinParams
    if ($Reboot -or $renameDone) { Restart-Computer -Force } else { Write-Host 'Domain join complete. Reboot required.' -ForegroundColor Green }
}
catch { Write-Error "Client onboarding failed: $_"; exit 2 }
