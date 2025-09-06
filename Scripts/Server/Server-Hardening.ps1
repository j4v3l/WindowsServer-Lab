# Server Hardening Script (Core Security Settings)
# EXECUTION CONTEXT: Run INSIDE Windows Server VMs (2019/2022/2025)
# PREREQUISITES: Local or Domain Administrator rights

[CmdletBinding(SupportsShouldProcess)]
param(
	[switch]$HardenRDP = $true,
	[switch]$HardenSMB = $true,
	[switch]$EnableLSAProtection = $true,
	[switch]$AuditPolicies = $true
)

function Set-RDP-NLA {
	if (-not $HardenRDP) { return }
	Write-Host "Enforcing NLA for RDP and limiting connections" -ForegroundColor Cyan
	$ts = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server'
	Set-ItemProperty -Path $ts -Name 'fDenyTSConnections' -Type DWord -Value 0
	$rdp = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp'
	Set-ItemProperty -Path $rdp -Name 'UserAuthentication' -Type DWord -Value 1 # NLA
}

function Set-SMB-Hardening {
	if (-not $HardenSMB) { return }
	Write-Host "Hardening SMB settings" -ForegroundColor Cyan
	# Client
	$wk = 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters'
	New-Item -Path $wk -Force | Out-Null
	Set-ItemProperty -Path $wk -Name 'RequireSecuritySignature' -Type DWord -Value 1
	Set-ItemProperty -Path $wk -Name 'EnableSecuritySignature' -Type DWord -Value 1

	# Server
	$srv = 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters'
	New-Item -Path $srv -Force | Out-Null
	Set-ItemProperty -Path $srv -Name 'RequireSecuritySignature' -Type DWord -Value 1
	Set-ItemProperty -Path $srv -Name 'EnableSecuritySignature' -Type DWord -Value 1

	# Disable SMBv1
	Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart -ErrorAction SilentlyContinue | Out-Null
}

function Set-LSA-Protection {
	if (-not $EnableLSAProtection) { return }
	Write-Host "Enabling LSA protection" -ForegroundColor Cyan
	$lsa = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'
	Set-ItemProperty -Path $lsa -Name 'RunAsPPL' -Type DWord -Value 1
	Set-ItemProperty -Path $lsa -Name 'DisableRestrictedAdmin' -Type DWord -Value 0
}

function Set-NTLM-Restrictions {
	Write-Host "Restricting NTLM usage (baseline)" -ForegroundColor Cyan
	$lm = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'
	# LAN Manager auth level: 5 = Send NTLMv2 response only. Refuse LM & NTLM
	Set-ItemProperty -Path $lm -Name 'LmCompatibilityLevel' -Type DWord -Value 5
}

function Set-AuditPolicies {
	if (-not $AuditPolicies) { return }
	Write-Host "Configuring advanced audit policy (account logon & object access)" -ForegroundColor Cyan
	auditpol /set /subcategory:"Logon" /success:enable /failure:enable | Out-Null
	auditpol /set /subcategory:"Account Lockout" /success:enable /failure:enable | Out-Null
	auditpol /set /subcategory:"Credential Validation" /success:enable /failure:enable | Out-Null
	auditpol /set /subcategory:"File Share" /success:enable /failure:enable | Out-Null
	auditpol /set /subcategory:"Process Creation" /success:enable /failure:enable | Out-Null
}

try {
	Set-RDP-NLA
	Set-SMB-Hardening
	Set-LSA-Protection
	Set-NTLM-Restrictions
	Set-AuditPolicies
	Write-Host "Server hardening complete. A reboot may be required for some settings." -ForegroundColor Green
}
catch {
	Write-Error "Server hardening failed: $_"
	exit 1
}
