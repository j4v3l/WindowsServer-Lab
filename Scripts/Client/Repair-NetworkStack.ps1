# Reset network stack (DNS cache, Winsock, TCP/IP) - requires reboot
[CmdletBinding()]param([switch]$Reboot)

ipconfig /flushdns | Out-Null
netsh winsock reset | Out-Null
netsh int ip reset | Out-Null
Write-Host 'Network stack reset complete.' -ForegroundColor Green
if ($Reboot) { Restart-Computer -Force }
