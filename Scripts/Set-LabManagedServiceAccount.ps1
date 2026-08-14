#Requires -RunAsAdministrator
#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)][ValidateSet('CreateDirectoryObjects', 'InstallWebService')][string]$Mode,
    [switch]$LabImmediateKdsRoot
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = 'C:\ProgramData\WindowsServerLab'
Import-Module "$root\Modules\WindowsServerLab\WindowsServerLab.psd1" -Force -ErrorAction Stop
$definition = Import-LabDefinition -Path "$root\LabConfig\lab.json"

if ($Mode -eq 'CreateDirectoryObjects') {
    Import-Module ActiveDirectory -ErrorAction Stop
    $domain = Get-ADDomain -ErrorAction Stop
    if ($domain.DNSRoot -notin @($definition.domain.dnsName, $definition.domain.legacyDnsName)) { throw 'Current domain does not match the lab definition.' }
    if (-not $PSCmdlet.ShouldProcess($domain.DNSRoot, 'Create the web-host authorization group and gMSA')) { return }

    if (-not (Get-KdsRootKey -ErrorAction Stop)) {
        if ($LabImmediateKdsRoot) {
            Add-KdsRootKey -EffectiveTime (Get-Date).AddHours(-10) -ErrorAction Stop | Out-Null
        }
        else {
            Add-KdsRootKey -EffectiveImmediately -ErrorAction Stop | Out-Null
            throw 'The KDS root key was created. Allow Active Directory replication time (normally 10 hours), then rerun without creating another key.'
        }
    }

    $domainDn = ConvertTo-LabDistinguishedName -DomainName $domain.DNSRoot
    $groupsOu = "OU=Groups,OU=$($definition.domain.baseOrganizationalUnit),$domainDn"
    $serviceAccountsOu = "OU=Service Accounts,OU=$($definition.domain.baseOrganizationalUnit),$domainDn"
    $groupName = 'GG-gMSA-WebHosts'
    $group = Get-ADGroup -LDAPFilter "(sAMAccountName=$groupName)" -ErrorAction Stop
    if (-not $group) {
        $group = New-ADGroup -Name $groupName -SamAccountName $groupName -GroupScope Global -GroupCategory Security -Path $groupsOu -PassThru -ErrorAction Stop
    }
    $webComputer = $definition.virtualMachines | Where-Object role -eq 'web-server'
    if (-not (Get-ADGroupMember -Identity $group -ErrorAction Stop | Where-Object SamAccountName -eq "$($webComputer.name)$")) {
        Add-ADGroupMember -Identity $group -Members "$($webComputer.name)$" -ErrorAction Stop
    }
    if (-not (Get-ADServiceAccount -Identity 'gmsa-web' -ErrorAction Ignore)) {
        New-ADServiceAccount -Name 'gmsa-web' -DNSHostName "gmsa-web.$($domain.DNSRoot)" -PrincipalsAllowedToRetrieveManagedPassword $group -Path $serviceAccountsOu -KerberosEncryptionType AES128, AES256 -ErrorAction Stop
    }
    Write-LabLog -Level Info -Message 'Reconciled the web gMSA directory objects' -Data @{ Group = $groupName; ServiceAccount = 'gmsa-web' }
    return
}

Import-Module ActiveDirectory -ErrorAction Stop
Import-Module WebAdministration -ErrorAction Stop
if (-not $PSCmdlet.ShouldProcess($env:COMPUTERNAME, 'Install gmsa-web and assign it to the default IIS application pool')) { return }
Install-ADServiceAccount -Identity 'gmsa-web' -ErrorAction Stop
if (-not (Test-ADServiceAccount -Identity 'gmsa-web' -ErrorAction Stop)) { throw 'The gMSA password could not be retrieved on this web server.' }
$domain = Get-ADDomain -ErrorAction Stop
Set-ItemProperty -Path 'IIS:\AppPools\DefaultAppPool' -Name processModel -Value @{ identityType = 3; userName = "$($domain.NetBIOSName)\gmsa-web$"; password = '' }
Restart-WebAppPool -Name DefaultAppPool
Write-LabLog -Level Info -Message 'Assigned gmsa-web to the default IIS application pool' -Data @{ ApplicationPool = 'DefaultAppPool' }
