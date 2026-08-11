# Client Health Check (HTML Report)
# EXECUTION CONTEXT: Run INSIDE Windows client VMs (Windows 10/11)
# PREREQUISITES: Local Administrator rights

$ts = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$outDir = 'C:\Reports'
$report = Join-Path $outDir "ClientHealth_$ts.html"
New-Item -ItemType Directory -Path $outDir -Force -ErrorAction Stop | Out-Null

function Get-AVStatus {
		try { Get-MpComputerStatus | Select-Object AMServiceEnabled, AntispywareEnabled, AntivirusEnabled, RealTimeProtectionEnabled }
		catch { [PSCustomObject]@{ AMServiceEnabled=$null; AntispywareEnabled=$null; AntivirusEnabled=$null; RealTimeProtectionEnabled=$null } }
}

function Get-FWProfiles { Get-NetFirewallProfile | Select-Object Name, Enabled, DefaultInboundAction, DefaultOutboundAction }

function Get-Disks {
		Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" |
			ForEach-Object {
				$total = [math]::Round($_.Size/1GB,2)
				$free  = [math]::Round($_.FreeSpace/1GB,2)
				[PSCustomObject]@{ Drive=$_.DeviceID; TotalGB=$total; FreeGB=$free; UsedPct = if($total){ [math]::Round((($total-$free)/$total)*100,1) } else { 0 } }
			}
}

function Get-UpdatesPending {
		try {
				$sess = New-Object -ComObject Microsoft.Update.Session
				$searcher = $sess.CreateUpdateSearcher()
				($searcher.Search('IsInstalled=0 and Type="Software"')).Updates | Select-Object Title, MsrcSeverity, IsMandatory, IsDownloaded
		} catch { @() }
}

function Get-Drivers {
		Get-CimInstance Win32_PnPSignedDriver |
			Where-Object { $_.DriverProviderName -and $_.DeviceName } |
			Select-Object DeviceName, DriverVersion, DriverProviderName, DriverDate |
			Sort-Object DeviceName | Select-Object -First 50
}

$html = @"
<html>
<head>
<title>Client Health - $env:COMPUTERNAME - $ts</title>
<style>
body{font-family:Segoe UI,Arial;margin:20px}
table{border-collapse:collapse;width:100%;margin:12px 0}
th,td{border:1px solid #ddd;padding:8px;text-align:left}
th{background:#f2f2f2}
.ok{color:green}.warn{color:darkorange}.bad{color:red}
</style>
</head>
<body>
<h1>Client Health Report</h1>
<p><b>Computer:</b> $env:COMPUTERNAME<br/>
<b>User:</b> $env:USERNAME<br/>
<b>Generated:</b> $ts</p>

<h2>Antivirus</h2>
$(Get-AVStatus | ConvertTo-Html -Fragment)

<h2>Firewall Profiles</h2>
$(Get-FWProfiles | ConvertTo-Html -Fragment)

<h2>Disks</h2>
$(Get-Disks | ConvertTo-Html -Fragment)

<h2>Pending Updates (top)</h2>
$(Get-UpdatesPending | Select-Object -First 30 | ConvertTo-Html -Fragment)

<h2>Drivers (sample)</h2>
$(Get-Drivers | ConvertTo-Html -Fragment)

</body>
</html>
"@

$html | Out-File -FilePath $report -Encoding UTF8
Write-Host "Client health report: $report" -ForegroundColor Green
