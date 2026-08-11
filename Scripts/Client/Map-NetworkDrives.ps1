# Map standard network drives for lab users
# EXECUTION CONTEXT: Windows client (domain-joined)

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory=$true)]
    [string]$FileServer,  # e.g. FILE1 or its definition-derived FQDN

    [string]$ToolsShare = 'Tools',
    [string]$DeptShare = 'Departments'
)

function Map-Drive($letter, $unc) {
    if (Get-PSDrive -Name $letter -ErrorAction Ignore) { Remove-PSDrive -Name $letter -Force -ErrorAction Stop }
    New-PSDrive -Name $letter -PSProvider FileSystem -Root $unc -Persist | Out-Null
    Write-Host "Mapped ${letter}: -> $unc" -ForegroundColor Green
}

Map-Drive -letter 'T' -unc "\\\\$FileServer\\$ToolsShare"
Map-Drive -letter 'D' -unc "\\\\$FileServer\\$DeptShare"
