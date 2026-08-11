#Requires -RunAsAdministrator
#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)][ValidateSet('asgard', 'olympus')][string]$Demo,
    [Parameter(Mandatory)][Alias('Profile')][ValidateSet('smoke', 'core', 'full')][string]$LabProfile,
    [Parameter(Mandatory)][ValidatePattern('^[A-Z0-9-]{1,15}$')][string]$ComputerName,
    [Parameter(Mandatory)][string]$OutputPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = 'C:\ProgramData\WindowsServerLab'
Import-Module "$root\Modules\WindowsServerLab\WindowsServerLab.psd1" -Force
$definition = Import-LabDefinition -Path "$root\LabConfig\demos\$Demo.json"
$vm = @(Get-LabProfileVirtualMachine -Definition $definition -LabProfile $LabProfile | Where-Object name -eq $ComputerName)
if ($vm.Count -ne 1) { throw "$ComputerName is not a unique member of $Demo/$LabProfile." }
$domain = Get-ADDomain -ErrorAction Stop
$domainDn = ConvertTo-LabDistinguishedName -DomainName $domain.DNSRoot
$baseOu = "OU=$($definition.domain.baseOrganizationalUnit),$domainDn"
$targetOu = if ($vm[0].role -in @('client', 'aiml-client')) { "OU=Workstations,$baseOu" } else { "OU=Servers,$baseOu" }

if ($PSCmdlet.ShouldProcess($ComputerName, "Provision offline join blob for $($domain.DNSRoot)")) {
    $directory = Split-Path -Parent $OutputPath
    if (-not (Test-Path -LiteralPath $directory)) { New-Item -Path $directory -ItemType Directory -Force | Out-Null }
    & djoin.exe /provision /domain $domain.DNSRoot /machine $ComputerName /machineou $targetOu /savefile $OutputPath /reuse
    if ($LASTEXITCODE -ne 0) { throw "djoin provision failed with exit code $LASTEXITCODE" }
    $acl = Get-Acl -LiteralPath $OutputPath
    $acl.SetAccessRuleProtection($true, $false)
    $rule = [Security.AccessControl.FileSystemAccessRule]::new([Security.Principal.WindowsIdentity]::GetCurrent().Name, 'FullControl', 'Allow')
    $acl.SetAccessRule($rule)
    Set-Acl -LiteralPath $OutputPath -AclObject $acl
}
