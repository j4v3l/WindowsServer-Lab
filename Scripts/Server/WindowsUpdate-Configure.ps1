# Windows Update Configuration Helper
# EXECUTION CONTEXT: Run INSIDE Windows Server or Client
# PREREQUISITES: Administrator rights

[CmdletBinding(SupportsShouldProcess)]
param(
	[ValidateSet('Notify','AutoDownload','AutoInstall','Manual')]
	[string]$Mode = 'AutoDownload',

	[int]$InstallDay = 0,  # 0 = Every day, 1-7 = Sunday..Saturday
	[int]$InstallTime = 3, # 0-23

	[switch]$DeferFeatureUpdates,
	[int]$FeatureDeferralDays = 30,

	[switch]$DeferQualityUpdates,
	[int]$QualityDeferralDays = 7,

	[switch]$ScanNow,
	[switch]$DownloadNow,
	[switch]$InstallNow,
	[switch]$RestartIfNeeded
)

function Set-AUPolicy {
	$au = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'
	New-Item -Path $au -Force | Out-Null

	$option = switch ($Mode) {
		'Notify' { 2 }
		'AutoDownload' { 3 }
		'AutoInstall' { 4 }
		'Manual' { 5 }
	}
	Set-ItemProperty -Path $au -Name 'AUOptions' -Type DWord -Value $option
	Set-ItemProperty -Path $au -Name 'ScheduledInstallDay' -Type DWord -Value $InstallDay
	Set-ItemProperty -Path $au -Name 'ScheduledInstallTime' -Type DWord -Value $InstallTime
	Set-ItemProperty -Path $au -Name 'NoAutoRebootWithLoggedOnUsers' -Type DWord -Value 1
}

function Set-Deferrals {
	$wu = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
	New-Item -Path $wu -Force | Out-Null
	if ($DeferFeatureUpdates) {
		Set-ItemProperty -Path $wu -Name 'DeferFeatureUpdates' -Type DWord -Value 1
		Set-ItemProperty -Path $wu -Name 'DeferFeatureUpdatesPeriodInDays' -Type DWord -Value $FeatureDeferralDays
	}
	if ($DeferQualityUpdates) {
		Set-ItemProperty -Path $wu -Name 'DeferQualityUpdates' -Type DWord -Value 1
		Set-ItemProperty -Path $wu -Name 'DeferQualityUpdatesPeriodInDays' -Type DWord -Value $QualityDeferralDays
	}
}

function Invoke-WUActions {
	try {
		$session = New-Object -ComObject Microsoft.Update.Session
		$searcher = $session.CreateUpdateSearcher()
		if ($ScanNow) {
			Write-Host 'Scanning for updates...' -ForegroundColor Cyan
			$null = $searcher.Search('IsInstalled=0 and Type="Software"')
		}
		if ($DownloadNow -or $InstallNow) {
			$result = $searcher.Search('IsInstalled=0 and IsHidden=0')
			if ($result.Updates.Count -gt 0) {
				$updates = New-Object -ComObject Microsoft.Update.UpdateColl
				for ($i=0; $i -lt $result.Updates.Count; $i++) { $updates.Add($result.Updates.Item($i)) | Out-Null }
				if ($DownloadNow) {
					Write-Host 'Downloading updates...' -ForegroundColor Cyan
					$downloader = $session.CreateUpdateDownloader(); $downloader.Updates = $updates; $downloader.Download() | Out-Null
				}
				if ($InstallNow) {
					Write-Host 'Installing updates...' -ForegroundColor Cyan
					$installer = $session.CreateUpdateInstaller(); $installer.Updates = $updates; $installResult = $installer.Install()
					if ($RestartIfNeeded -and $installResult.RebootRequired) {
						Write-Host 'Restart required. Rebooting now...' -ForegroundColor Yellow
						Restart-Computer -Force
					}
				}
			} else {
				Write-Host 'No applicable updates found.' -ForegroundColor Green
			}
		}
	} catch {
		Write-Warning "Windows Update actions failed: $_"
	}
}

try {
	Set-AUPolicy
	Set-Deferrals
	Invoke-WUActions
	Write-Host "Windows Update configuration complete (Mode=$Mode)." -ForegroundColor Green
}
catch {
	Write-Error "Windows Update configuration failed: $_"
	exit 1
}
