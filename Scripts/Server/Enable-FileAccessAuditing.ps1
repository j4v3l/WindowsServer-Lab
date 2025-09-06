# Enable file access auditing on a path and set recommended audit policy
[CmdletBinding()]param(
  [Parameter(Mandatory=$true)][string]$Path
)

if (-not (Test-Path $Path)) { throw "Path not found: $Path" }

Write-Host 'Enabling advanced audit categories...' -ForegroundColor Cyan
auditpol /set /subcategory:"File System" /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"Handle Manipulation" /success:disable /failure:enable | Out-Null

Write-Host "Configuring SACL on: $Path" -ForegroundColor Cyan
$acl = Get-Acl $Path
$id = New-Object System.Security.Principal.SecurityIdentifier('S-1-1-0') # Everyone
$rule = New-Object System.Security.AccessControl.FileSystemAuditRule($id,'CreateFiles,CreateDirectories,AppendData,WriteData,ReadData,ReadAttributes,ReadExtendedAttributes,WriteAttributes,WriteExtendedAttributes,Delete','ContainerInherit, ObjectInherit','None','Success,Failure')
$acl.SetAuditRule($rule)
Set-Acl -Path $Path -AclObject $acl
Write-Host 'File access auditing enabled.' -ForegroundColor Green
