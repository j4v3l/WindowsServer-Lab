# Configure NTP settings (DCs and Member Servers)
[CmdletBinding()]param(
  [string[]]$NtpServers = @('time.windows.com,0x9'),
  [switch]$SyncNow
)

function Is-DC { (Get-CimInstance Win32_ComputerSystem).DomainRole -in 4,5 }

if (Is-DC) {
  Write-Host 'Configuring PDC/Domain Controller time source' -ForegroundColor Cyan
  w32tm /config /manualpeerlist:(($NtpServers -join ' ')) /syncfromflags:MANUAL /reliable:YES /update | Out-Null
} else {
  Write-Host 'Configuring member server to sync from domain hierarchy' -ForegroundColor Cyan
  w32tm /config /syncfromflags:DOMHIER /update | Out-Null
}

Restart-Service w32time -Force
if ($SyncNow) { w32tm /resync /force | Out-Null }
Write-Host 'NTP configuration complete.' -ForegroundColor Green
