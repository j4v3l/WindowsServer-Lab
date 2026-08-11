# Client Baseline Hardening Script (Safe Defaults)
# EXECUTION CONTEXT: Run INSIDE Windows client VMs (Windows 10/11) or member servers
# PREREQUISITES: Local Administrator rights

[CmdletBinding(SupportsShouldProcess)]
param(
	[switch]$SkipFirewall,
	[switch]$SkipPSLogging
)

function Ensure-FirewallProfiles {
	if ($SkipFirewall) { return }
	$profiles = Get-NetFirewallProfile
	foreach ($p in $profiles) {
		if (-not $p.Enabled) {
			Write-Host "Enabling Windows Firewall on profile: $($p.Name)" -ForegroundColor Cyan
			Set-NetFirewallProfile -Name $p.Name -Enabled True -DefaultInboundAction Block -DefaultOutboundAction Allow
		}
	}
}

function Ensure-SMBSigning {
	$wkSvc = 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters'
	New-Item -Path $wkSvc -Force | Out-Null
	Set-ItemProperty -Path $wkSvc -Name 'RequireSecuritySignature' -Type DWord -Value 1
	Write-Host "SMB client signing required" -ForegroundColor Green
}

function Ensure-PowerShellLogging {
	if ($SkipPSLogging) { return }
	$sb = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging'
	New-Item -Path $sb -Force | Out-Null
	Set-ItemProperty -Path $sb -Name 'EnableScriptBlockLogging' -Type DWord -Value 1
	$mod = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging'
	New-Item -Path $mod -Force | Out-Null
	Set-ItemProperty -Path $mod -Name 'EnableModuleLogging' -Type DWord -Value 1
	Write-Host "PowerShell logging enabled (script block + module)" -ForegroundColor Green
}

function Ensure-ExecutionPolicy {
	$current = Get-ExecutionPolicy -Scope LocalMachine
	if ($current -notin 'AllSigned','RemoteSigned') {
		Write-Host "Setting execution policy to RemoteSigned (LocalMachine)" -ForegroundColor Cyan
		Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force
	}
}

function Ensure-LocalPolicies {
	# Disable AutoRun/AutoPlay
	$expl = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'
	New-Item -Path $expl -Force | Out-Null
	Set-ItemProperty -Path $expl -Name 'NoDriveTypeAutoRun' -Type DWord -Value 255

	# Disable anonymous SID/Name translation and restrict anonymous enumeration
	$lsa = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'
	Set-ItemProperty -Path $lsa -Name 'restrictanonymous' -Type DWord -Value 1
	Set-ItemProperty -Path $lsa -Name 'restrictanonymoussam' -Type DWord -Value 1

	# Disable legacy SMBv1
	Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart -ErrorAction Stop | Out-Null

	Write-Host "Applied local security policy tweaks" -ForegroundColor Green
}

function Check-BitLockerStatus {
	try {
		$osVol = Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction Stop
		if ($osVol -and $osVol.ProtectionStatus -eq 'On') {
			Write-Host "BitLocker: Enabled on $($env:SystemDrive)" -ForegroundColor Green
		} else {
			Write-Host "BitLocker: Not enabled on $($env:SystemDrive)" -ForegroundColor Yellow
		}
	} catch {
		Write-Host "BitLocker: Not available or not installed" -ForegroundColor Yellow
	}
}

try {
	Ensure-FirewallProfiles
	Ensure-SMBSigning
	Ensure-PowerShellLogging
	Ensure-ExecutionPolicy
	Ensure-LocalPolicies
	Check-BitLockerStatus
	Write-Host "Client baseline hardening completed." -ForegroundColor Green
}
catch {
	Write-Error "Baseline hardening failed: $_"
	exit 1
}
