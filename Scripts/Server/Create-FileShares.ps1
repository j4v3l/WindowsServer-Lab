# Create standard lab SMB shares with NTFS and Share permissions
# EXECUTION CONTEXT: Windows Server file server (Domain-joined)

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$RootPath = 'D:\Shares',
    [string]$DomainName = $env:USERDNSDOMAIN,
    [switch]$CreateExampleFolders
)

$shares = @(
    @{ Name='Tools';     Path=Join-Path $RootPath 'Tools';     ReadGroup='Domain Users';    ChangeGroup='IT Admins' },
    @{ Name='Profiles';  Path=Join-Path $RootPath 'Profiles';  ReadGroup=$null;              ChangeGroup='Domain Admins' },
    @{ Name='Departments'; Path=Join-Path $RootPath 'Departments'; ReadGroup='Domain Users'; ChangeGroup='Dept Leads' }
)

function Ensure-Folder($path) {
    if (-not (Test-Path $path)) { New-Item -ItemType Directory -Path $path -Force | Out-Null }
}

function Grant-NTFSPerms($path, $readGroup, $changeGroup) {
    $acl = Get-Acl $path
    if ($readGroup) {
        $ar = New-Object System.Security.AccessControl.FileSystemAccessRule("$DomainName\\$readGroup", 'ReadAndExecute', 'ContainerInherit, ObjectInherit', 'None', 'Allow')
        $acl.SetAccessRule($ar)
    }
    if ($changeGroup) {
        $ar2 = New-Object System.Security.AccessControl.FileSystemAccessRule("$DomainName\\$changeGroup", 'Modify', 'ContainerInherit, ObjectInherit', 'None', 'Allow')
        $acl.SetAccessRule($ar2)
    }
    Set-Acl -Path $path -AclObject $acl
}

foreach ($s in $shares) {
    Ensure-Folder $s.Path
    Grant-NTFSPerms -path $s.Path -readGroup $s.ReadGroup -changeGroup $s.ChangeGroup
    if (-not (Get-SmbShare -Name $s.Name -ErrorAction Ignore)) {
        $params = @{ Name=$s.Name; Path=$s.Path; FullAccess="${DomainName}\\Domain Admins" }
        if ($s.ChangeGroup) { $params.ChangeAccess = "${DomainName}\\$($s.ChangeGroup)" }
        if ($s.ReadGroup)   { $params.ReadAccess   = "${DomainName}\\$($s.ReadGroup)" }
        New-SmbShare @params | Out-Null
        Write-Host "Created share '$($s.Name)' -> $($s.Path)" -ForegroundColor Green
    } else {
        Write-Host "Share '$($s.Name)' already exists" -ForegroundColor Yellow
    }
}

if ($CreateExampleFolders) {
    Ensure-Folder (Join-Path $RootPath 'Departments/HR')
    Ensure-Folder (Join-Path $RootPath 'Departments/Finance')
    Ensure-Folder (Join-Path $RootPath 'Departments/IT')
}
