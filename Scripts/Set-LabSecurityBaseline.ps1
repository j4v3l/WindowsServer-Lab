#Requires -RunAsAdministrator
#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)][ValidateSet('DomainController', 'MemberServer', 'WorkgroupMember')][string]$ServerRole,
    [string]$SctBaselinePath,
    [string]$SctBaselineSha256,
    [switch]$EnableAppControlAudit
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Import-Module 'C:\ProgramData\WindowsServerLab\Modules\WindowsServerLab\WindowsServerLab.psd1' -Force
Set-LabSecurityBaseline -ServerRole $ServerRole -SctBaselinePath $SctBaselinePath -SctBaselineSha256 $SctBaselineSha256 -EnableAppControl:$EnableAppControlAudit -WhatIf:$WhatIfPreference -Confirm:$false
