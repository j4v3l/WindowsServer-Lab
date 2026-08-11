[CmdletBinding()]
param()
Write-Warning 'BackupRestoreManager.ps1 v1 was retired because it could report success without verifying wbadmin or ntdsutil results.'
Write-Output 'Domain controller: .\Scripts\Start-LabSystemStateBackup.ps1 -BackupTarget <separate-volume-or-UNC>'
Write-Output 'File server:       .\Scripts\Start-LabFileBackup.ps1 -SourcePath <path> -DestinationPath <path>'
Write-Output 'Proxmox host:      ./Tools/Proxmox/Backup-Lab.sh --demo <name> --profile <profile> --site <file>'
exit 2
