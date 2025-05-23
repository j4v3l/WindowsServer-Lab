# ---------------------------------------------------
# CONFIGURATION
# ---------------------------------------------------
$domainDN        = "DC=lab,DC=local"
$domainName      = "lab.local"
$defaultPassword = ConvertTo-SecureString "P@ssw0rd123" -AsPlainText -Force

# ---------------------------------------------------
# 0) CREATE USERS (needed before groups)
# ---------------------------------------------------
# Define users with required properties (simplified)
$users = @(
    @{SamAccountName="admin.odin"; Name="Odin Admin"; OU="IT"},
    @{SamAccountName="thor";       Name="Thor";       OU="IT"},
    @{SamAccountName="freya";      Name="Freya";      OU="HR"},
    @{SamAccountName="sif";        Name="Sif";        OU="Sales"},
    @{SamAccountName="loki";       Name="Loki";       OU="Interns"}
)

foreach ($user in $users) {
    $userDN = "OU=$($user.OU),$domainDN"
    if (-not (Get-ADUser -Filter "SamAccountName -eq '$($user.SamAccountName)'" -ErrorAction SilentlyContinue)) {
        New-ADUser -Name $user.Name `
                   -SamAccountName $user.SamAccountName `
                   -AccountPassword $defaultPassword `
                   -Enabled $true `
                   -Path $userDN `
                   -PasswordNeverExpires $true
        Write-Host "Created user $($user.SamAccountName) in OU $($user.OU)"
    }
    else {
        Write-Host "User $($user.SamAccountName) already exists"
    }
}

# ---------------------------------------------------
# 1) COMPUTER ACCOUNTS
# ---------------------------------------------------
$computers = @(
    @{Name="CL-THOR"; OU="IT"},
    @{Name="CL-LOKI"; OU="Interns"},
    @{Name="CL-FREYA"; OU="HR"},
    @{Name="CL-SIF";  OU="Sales"}
)

foreach ($c in $computers) {
    $compDN = "OU=$($c.OU),$domainDN"
    # SamAccountName for computer must end with $
    $samAccountName = "$($c.Name)$"

    # Check if computer exists by SamAccountName
    if (-not (Get-ADComputer -Filter "SamAccountName -eq '$samAccountName'" -ErrorAction SilentlyContinue)) {
        New-ADComputer -Name $c.Name `
                       -SamAccountName $samAccountName `
                       -Path $compDN `
                       -Enabled $true
        Write-Host "Created computer account $($c.Name) in $($c.OU)"
    }
    else {
        # Move existing account into correct OU (if needed)
        $compObj = Get-ADComputer -Identity $c.Name
        if ($compObj.DistinguishedName -notlike "*$compDN*") {
            Move-ADObject -Identity $compObj.DistinguishedName -TargetPath $compDN
            Write-Host "Moved computer $($c.Name) into $($c.OU)"
        }
        else {
            Write-Host "Computer $($c.Name) already in $($c.OU)"
        }
    }
}

# ---------------------------------------------------
# 2) SECURITY GROUPS & USER ASSIGNMENTS
# ---------------------------------------------------
$groupMap = @{
    "IT"      = @("admin.odin","thor")
    "HR"      = @("freya")
    "Sales"   = @("sif")
    "Interns" = @("loki")
}

foreach ($ou in $groupMap.Keys) {
    $groupName = "GRP-$ou"
    if (-not (Get-ADGroup -Filter "Name -eq '$groupName'" -ErrorAction SilentlyContinue)) {
        New-ADGroup -Name $groupName `
                    -GroupScope Global `
                    -GroupCategory Security `
                    -Path "OU=$ou,$domainDN"
        Write-Host "Created group $groupName"
    }

    foreach ($user in $groupMap[$ou]) {
        try {
            Add-ADGroupMember -Identity $groupName -Members $user -ErrorAction Stop
            Write-Host ("Added user {0} to group {1}" -f $user, $groupName)
        }
        catch {
            Write-Warning ("Failed to add user {0} to group {1}: {2}" -f $user, $groupName, $_.Exception.Message)
        }
    }

    Write-Host ("Added users to {0}: {1}" -f $groupName, ($groupMap[$ou] -join ', '))
}

# ---------------------------------------------------
# 3) GPO CREATION & LINKING
# ---------------------------------------------------
Import-Module GroupPolicy

foreach ($ou in @("IT","HR","Sales","Interns","ServiceAccounts")) {
    $gpoName  = "GPO_$ou"
    $ouDN     = "OU=$ou,$domainDN"

    if (-not (Get-GPO -Name $gpoName -ErrorAction SilentlyContinue)) {
        New-GPO -Name $gpoName -Domain $domainName | Out-Null
        Write-Host "Created GPO $gpoName"
    }

    $links = (Get-GPInheritance -Target $ouDN).GpoLinks | Where-Object {$_.DisplayName -eq $gpoName}
    if (-not $links) {
        New-GPLink -Name $gpoName -Target $ouDN -LinkEnabled Yes -Enforced No
        Write-Host "Linked $gpoName to $ou"
    }
    else {
        Write-Host "$gpoName is already linked to $ou"
    }
}