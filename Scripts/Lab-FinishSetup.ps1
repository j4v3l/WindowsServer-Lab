# Lab Finish Setup Script
# This script completes the lab environment setup with users, computers, and groups

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [System.Security.SecureString]$DefaultUserPassword,
    
    [Parameter(Mandatory = $false)]
    [switch]$Force
)

# ---------------------------------------------------
# CONFIGURATION
# ---------------------------------------------------
$domainDN = "DC=lab,DC=local"
$domainName = "lab.local"

# Get secure password if not provided
if (-not $DefaultUserPassword) {
    # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "Please enter the default password for new user accounts:" -ForegroundColor Yellow
    $DefaultUserPassword = Read-Host -AsSecureString
}

# Validate password is provided
if (-not $DefaultUserPassword) {
    Write-Error "Default user password is required. Exiting."
    exit 1
}

# ---------------------------------------------------
# 0) CREATE USERS (needed before groups)
# ---------------------------------------------------
# Define users with required properties (simplified)
$users = @(
    @{SamAccountName = "admin.odin"; Name = "Odin Admin"; OU = "IT" },
    @{SamAccountName = "thor"; Name = "Thor"; OU = "IT" },
    @{SamAccountName = "freya"; Name = "Freya"; OU = "HR" },
    @{SamAccountName = "sif"; Name = "Sif"; OU = "Sales" },
    @{SamAccountName = "loki"; Name = "Loki"; OU = "Interns" }
)

foreach ($user in $users) {
    $userDN = "OU=$($user.OU),$domainDN"
    if (-not (Get-ADUser -Filter "SamAccountName -eq '$($user.SamAccountName)'" -ErrorAction SilentlyContinue)) {
        try {
            New-ADUser -Name $user.Name `
                -SamAccountName $user.SamAccountName `
                -AccountPassword $DefaultUserPassword `
                -Enabled $true `
                -Path $userDN `
                -PasswordNeverExpires $true `
                -ErrorAction Stop
            Write-Information "Created user $($user.SamAccountName) in OU $($user.OU)" -InformationAction Continue
        }
        catch {
            Write-Warning "Failed to create user $($user.SamAccountName): $($_.Exception.Message)"
        }
    }
    else {
        Write-Information "User $($user.SamAccountName) already exists" -InformationAction Continue
    }
}

# ---------------------------------------------------
# 1) COMPUTER ACCOUNTS
# ---------------------------------------------------
$computers = @(
    @{Name = "CL-THOR"; OU = "IT" },
    @{Name = "CL-LOKI"; OU = "Interns" },
    @{Name = "CL-FREYA"; OU = "HR" },
    @{Name = "CL-SIF"; OU = "Sales" }
)

foreach ($c in $computers) {
    $compDN = "OU=$($c.OU),$domainDN"
    # SamAccountName for computer must end with $
    $samAccountName = "$($c.Name)$"

    # Check if computer exists by SamAccountName
    if (-not (Get-ADComputer -Filter "SamAccountName -eq '$samAccountName'" -ErrorAction SilentlyContinue)) {
        try {
            New-ADComputer -Name $c.Name `
                -SamAccountName $samAccountName `
                -Path $compDN `
                -Enabled $true `
                -ErrorAction Stop
            Write-Information "Created computer account $($c.Name) in $($c.OU)" -InformationAction Continue
        }
        catch {
            Write-Warning "Failed to create computer $($c.Name): $($_.Exception.Message)"
        }
    }
    else {
        # Move existing account into correct OU (if needed)
        try {
            $compObj = Get-ADComputer -Identity $c.Name
            if ($compObj.DistinguishedName -notlike "*$compDN*") {
                Move-ADObject -Identity $compObj.DistinguishedName -TargetPath $compDN
                Write-Information "Moved computer $($c.Name) into $($c.OU)" -InformationAction Continue
            }
            else {
                Write-Information "Computer $($c.Name) already in $($c.OU)" -InformationAction Continue
            }
        }
        catch {
            Write-Warning "Failed to move computer $($c.Name): $($_.Exception.Message)"
        }
    }
}

# ---------------------------------------------------
# 2) SECURITY GROUPS & USER ASSIGNMENTS
# ---------------------------------------------------
$groupMap = @{
    "IT"      = @("admin.odin", "thor")
    "HR"      = @("freya")
    "Sales"   = @("sif")
    "Interns" = @("loki")
}

foreach ($ou in $groupMap.Keys) {
    $groupName = "GRP-$ou"
    if (-not (Get-ADGroup -Filter "Name -eq '$groupName'" -ErrorAction SilentlyContinue)) {
        try {
            New-ADGroup -Name $groupName `
                -GroupScope Global `
                -GroupCategory Security `
                -Path "OU=$ou,$domainDN" `
                -ErrorAction Stop
            Write-Information "Created group $groupName" -InformationAction Continue
        }
        catch {
            Write-Warning "Failed to create group $groupName : $($_.Exception.Message)"
        }
    }

    foreach ($user in $groupMap[$ou]) {
        try {
            Add-ADGroupMember -Identity $groupName -Members $user -ErrorAction Stop
            Write-Information "Added user $user to group $groupName" -InformationAction Continue
        }
        catch {
            Write-Warning "Failed to add user $user to group $groupName : $($_.Exception.Message)"
        }
    }
}

Write-Output "Lab finish setup completed successfully!"
Write-Information "All users, computers, and groups have been configured." -InformationAction Continue

# ---------------------------------------------------
# 3) GPO CREATION & LINKING
# ---------------------------------------------------
Import-Module GroupPolicy

foreach ($ou in @("IT", "HR", "Sales", "Interns", "ServiceAccounts")) {
    $gpoName = "GPO_$ou"
    $ouDN = "OU=$ou,$domainDN"

    if (-not (Get-GPO -Name $gpoName -ErrorAction SilentlyContinue)) {
        New-GPO -Name $gpoName -Domain $domainName | Out-Null
        Write-Information "Created GPO $gpoName" -InformationAction Continue
    }

    $links = (Get-GPInheritance -Target $ouDN).GpoLinks | Where-Object { $_.DisplayName -eq $gpoName }
    if (-not $links) {
        New-GPLink -Name $gpoName -Target $ouDN -LinkEnabled Yes -Enforced No
        Write-Information "Linked $gpoName to $ou" -InformationAction Continue
    }
    else {
        Write-Information "$gpoName is already linked to $ou" -InformationAction Continue
    }
}