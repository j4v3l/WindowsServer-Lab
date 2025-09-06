# Point all active network adapters to specified DNS servers
[CmdletBinding()]param(
  [Parameter(Mandatory=$true)][string[]]$Servers
)

Get-NetAdapter -Physical | Where-Object Status -eq 'Up' | ForEach-Object {
  Set-DnsClientServerAddress -InterfaceAlias $_.Name -ServerAddresses $Servers -ErrorAction Stop
  Write-Host "Set DNS on '$($_.Name)' -> $($Servers -join ', ')" -ForegroundColor Green
}
