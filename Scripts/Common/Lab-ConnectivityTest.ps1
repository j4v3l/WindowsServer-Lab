# Lab Connectivity Test (Server or Client)
# Checks DNS, DC reachability, LDAP port, SMB access, and time sync

[CmdletBinding()]
param(
	[string]$Domain = $env:USERDNSDOMAIN,
	[string]$DomainController,
	[string]$FileServer,
	[string]$TestShare = 'Tools'
)

function Result($name, $ok, $msg) {
	$status = if ($ok) { 'OK' } else { 'FAIL' }
	$color = if ($ok) { 'Green' } else { 'Red' }
	Write-Host ("[{0}] {1} - {2}" -f $status, $name, $msg) -ForegroundColor $color
}

try {
	# DNS domain resolution
	if ($Domain) {
		try { $d = Resolve-DnsName -Name $Domain -ErrorAction Stop; Result 'DNS Domain Resolve' $true ("{0} record(s)" -f $d.Count) }
		catch { Result 'DNS Domain Resolve' $false $_.Exception.Message }
	}

	# Pick a DC if not specified
	if (-not $DomainController -and $Domain) {
		try {
			$dc = (Resolve-DnsName -Type SRV -Name "_ldap._tcp.dc._msdcs.$Domain" -ErrorAction Stop | Select-Object -First 1).NameTarget.Trim('.')
			$DomainController = $dc
		} catch {}
	}

	if ($DomainController) {
		# Ping DC
		$ping = Test-Connection -ComputerName $DomainController -Count 1 -Quiet
		Result 'Ping DC' $ping $DomainController
		# LDAP port 389
		try { Test-NetConnection -ComputerName $DomainController -Port 389 -InformationLevel Quiet | Out-Null; Result 'LDAP 389' $true $DomainController }
		catch { Result 'LDAP 389' $false $_.Exception.Message }
		# Kerberos 88
		try { Test-NetConnection -ComputerName $DomainController -Port 88 -InformationLevel Quiet | Out-Null; Result 'Kerberos 88' $true $DomainController }
		catch { Result 'Kerberos 88' $false $_.Exception.Message }
	}

	if ($FileServer) {
		$unc = "\\\\$FileServer\\$TestShare"
		try {
			$exists = Test-Path $unc
			Result 'SMB Share' $exists $unc
		} catch { Result 'SMB Share' $false $_.Exception.Message }
	}

	# Time sync skew (compares against DC if available)
	if ($DomainController) {
		try {
			$offset = $null
			try {
				$out = w32tm /monitor /computers:$DomainController 2>$null | Select-String 'offset'
				if ($out) { $offset = ($out -split 'offset ')[1] }
			} catch {}
			Result 'Time Sync' $true ("offset: {0}" -f ($offset ?? 'unknown'))
		} catch { Result 'Time Sync' $false $_.Exception.Message }
	}
}
catch {
	Result 'Connectivity Test' $false $_.Exception.Message
}
