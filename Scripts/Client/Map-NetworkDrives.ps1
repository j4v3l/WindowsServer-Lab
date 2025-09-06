# Map standard network drives for lab users
# EXECUTION CONTEXT: Windows client (domain-joined)

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory=$true)]
    [string]$FileServer,  # e.g. FILE1 or file1.lab.local

    [string]$ToolsShare = 'Tools',
    [string]$DeptShare = 'Departments'
)

function Map-Drive($letter, $unc) {
    if (Get-PSDrive -Name $letter -ErrorAction SilentlyContinue) { Remove-PSDrive -Name $letter -Force -ErrorAction SilentlyContinue }
    New-PSDrive -Name $letter -PSProvider FileSystem -Root $unc -Persist | Out-Null
    Write-Host "Mapped $letter: -> $unc" -ForegroundColor Green
}

Map-Drive -letter 'T' -unc "\\\\$FileServer\\$ToolsShare"
Map-Drive -letter 'D' -unc "\\\\$FileServer\\$DeptShare"
