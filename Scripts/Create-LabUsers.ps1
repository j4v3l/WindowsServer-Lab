# Configuration
$domainDN = 'DC=lab,DC=local'
$domainName = 'lab.local'
$defaultPassword = ConvertTo-SecureString 'P@ssw0rd123' -AsPlainText -Force
$cleanup = $false  # Set to $true to delete all created lab objects

# Lab objects
$ous = @('IT', 'HR', 'Interns')

$users = @(
    @{ OU = 'IT'; UserName = 'thor'; Name = 'Thor Odinson'; IsAdmin = $false },
    @{ OU = 'Interns'; UserName = 'loki'; Name = 'Loki Laufeyson'; IsAdmin = $false }
)

$computers = @(
    @{ Name = 'CL-THOR'; OU = 'IT' },
    @{ Name = 'CL-LOKI'; OU = 'Interns' }
)

$groupMap = @{
    'IT' = @('thor')
    'Interns' = @('loki')
}

Import-Module ActiveDirectory
Import-Module GroupPolicy

if ($cleanup) {
    Write-Host "`n🧹 Cleanup mode enabled..."

    # Remove users
    foreach ($user in $users) {
        if (Get-ADUser -Filter "SamAccountName -eq '$($user.UserName)'" -ErrorAction SilentlyContinue) {
            Remove-ADUser -Identity $user.UserName -Confirm:$false
            Write-Host ("Deleted user {0}" -f $user.UserName)
        }
    }

    # Remove groups
    foreach ($group in $groupMap.Keys) {
        $gname = "GRP-$group"
        if (Get-ADGroup -Filter "Name -eq '$gname'" -ErrorAction SilentlyContinue) {
            Remove-ADGroup -Identity $gname -Confirm:$false
            Write-Host ("Deleted group {0}" -f $gname)
        }
    }

    # Remove computers
    foreach ($comp in $computers) {
        if (Get-ADComputer -Filter "SamAccountName -eq '$($comp.Name)$'" -ErrorAction SilentlyContinue) {
            Remove-ADComputer -Identity $comp.Name -Confirm:$false
            Write-Host ("Deleted computer {0}" -f $comp.Name)
        }
    }

    # Remove linked GPOs
    foreach ($ou in $ous) {
        $gpoName = "GPO_$ou"
        if (Get-GPO -Name $gpoName -ErrorAction SilentlyContinue) {
            Remove-GPO -Name $gpoName
            Write-Host ("Deleted GPO {0}" -f $gpoName)
        }
    }

    # Remove OUs - remove protection first
    foreach ($ou in $ous) {
        $ouDN = "OU=$ou,$domainDN"
        try {
            Set-ADOrganizationalUnit -Identity $ouDN -ProtectedFromAccidentalDeletion $false
            Remove-ADOrganizationalUnit -Identity $ouDN -Recursive -Confirm:$false
            Write-Host ("Deleted OU {0}" -f $ou)
        }
        catch {
            Write-Warning ("Couldn't delete OU {0} - check for lingering objects" -f $ou)
        }
    }

    return
}

# Create OUs
foreach ($ou in $ous) {
    $ouPath = "OU=$ou,$domainDN"
    if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$ou'" -SearchBase $domainDN -ErrorAction SilentlyContinue)) {
        New-ADOrganizationalUnit -Name $ou -Path $domainDN
        Write-Host ("Created OU {0}" -f $ou)
    }
}

# Create users
foreach ($user in $users) {
    $ouPath = "OU=$($user.OU),$domainDN"
    $sam = $user.UserName
    $upn = "$sam@$domainName"

    if (-not (Get-ADUser -Filter "SamAccountName -eq '$sam'" -ErrorAction SilentlyContinue)) {
        New-ADUser -SamAccountName $sam `
                   -Name $user.Name `
                   -UserPrincipalName $upn `
                   -DisplayName $user.Name `
                   -Path $ouPath `
                   -AccountPassword $defaultPassword `
                   -Enabled $true `
                   -ChangePasswordAtLogon $false
        Write-Host ("Created user {0}" -f $sam)
    }
}

# Create computers
foreach ($comp in $computers) {
    $compPath = "OU=$($comp.OU),$domainDN"
    if (-not (Get-ADComputer -Filter "SamAccountName -eq '$($comp.Name)$'" -ErrorAction SilentlyContinue)) {
        New-ADComputer -Name $comp.Name -SamAccountName $comp.Name -Path $compPath -Enabled $true
        Write-Host ("Created computer {0}" -f $comp.Name)
    }
}

# Create groups and add members
foreach ($ou in $groupMap.Keys) {
    $groupName = "GRP-$ou"
    $groupPath = "OU=$ou,$domainDN"

    if (-not (Get-ADGroup -Filter "Name -eq '$groupName'" -SearchBase $groupPath -ErrorAction SilentlyContinue)) {
        New-ADGroup -Name $groupName -GroupScope Global -GroupCategory Security -Path $groupPath
        Write-Host ("Created group {0}" -f $groupName)
    }

    foreach ($user in $groupMap[$ou]) {
        try {
            Add-ADGroupMember -Identity $groupName -Members $user
            Write-Host ("Added {0} to {1}" -f $user, $groupName)
        }
        catch {
            Write-Warning ("Failed to add {0} to {1}" -f $user, $groupName)
        }
    }
}
