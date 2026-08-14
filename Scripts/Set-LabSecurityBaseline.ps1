#Requires -RunAsAdministrator
#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)][ValidateSet('DomainController', 'MemberServer', 'WorkgroupMember')][string]$ServerRole,
    [switch]$EnableAppControlAudit
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Import-Module 'C:\ProgramData\WindowsServerLab\Modules\WindowsServerLab\WindowsServerLab.psd1' -Force
Set-LabSecurityBaseline -ServerRole $ServerRole -EnableAppControl:$EnableAppControlAudit -WhatIf:$WhatIfPreference -Confirm:$false
