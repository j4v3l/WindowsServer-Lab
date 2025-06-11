# Create Lab Users Script
# This script creates users for the Windows Server lab environment

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [System.Security.SecureString]$DefaultUserPassword,
    
    [Parameter(Mandatory = $false)]
    [switch]$Force
)

# Import Active Directory module
Import-Module ActiveDirectory

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

# Define the domain
$domain = "lab.local"
$domainDN = "DC=lab,DC=local"

# Create OUs if they don't exist
$ous = @("IT", "HR", "Sales", "Marketing", "Finance")

Write-Information "Creating organizational units..." -InformationAction Continue
foreach ($ou in $ous) {
    try {
        $ouPath = "OU=$ou,$domainDN"
        if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$ou'" -SearchBase $domainDN -ErrorAction SilentlyContinue)) {
            New-ADOrganizationalUnit -Name $ou -Path $domainDN -ErrorAction Stop
            Write-Information "Created OU: $ou" -InformationAction Continue
        }
        else {
            Write-Information "OU already exists: $ou" -InformationAction Continue
        }
    }
    catch {
        Write-Warning "Failed to create OU $ou : $($_.Exception.Message)"
    }
}

# Define users to create
$users = @(
    @{
        FirstName   = "Thor"
        LastName    = "Odinson"
        Username    = "thor"
        Department  = "IT"
        Title       = "System Administrator"
        Description = "Senior System Administrator"
    },
    @{
        FirstName   = "Freya"
        LastName    = "Njord"
        Username    = "freya"
        Department  = "HR"
        Title       = "HR Manager"
        Description = "Human Resources Manager"
    },
    @{
        FirstName   = "Sif"
        LastName    = "Thorsdottir"
        Username    = "sif"
        Department  = "Sales"
        Title       = "Sales Representative"
        Description = "Senior Sales Representative"
    },
    @{
        FirstName   = "Heimdall"
        LastName    = "Bifrost"
        Username    = "heimdall"
        Department  = "Marketing"
        Title       = "Marketing Specialist"
        Description = "Digital Marketing Specialist"
    },
    @{
        FirstName   = "Frigg"
        LastName    = "Fjorgyn"
        Username    = "frigg"
        Department  = "Finance"
        Title       = "Financial Analyst"
        Description = "Senior Financial Analyst"
    }
)

Write-Information "Creating user accounts..." -InformationAction Continue

foreach ($user in $users) {
    $ouPath = "OU=$($user.Department),$domainDN"
    $upn = "$($user.Username)@$domain"
    $displayName = "$($user.FirstName) $($user.LastName)"
    
    try {
        # Check if user already exists
        if (Get-ADUser -Filter "SamAccountName -eq '$($user.Username)'" -ErrorAction SilentlyContinue) {
            Write-Information "User already exists: $($user.Username)" -InformationAction Continue
            continue
        }
        
        # Create the user
        New-ADUser -Name $displayName `
            -GivenName $user.FirstName `
            -Surname $user.LastName `
            -SamAccountName $user.Username `
            -UserPrincipalName $upn `
            -DisplayName $displayName `
            -Description $user.Description `
            -Department $user.Department `
            -Title $user.Title `
            -Path $ouPath `
            -AccountPassword $DefaultUserPassword `
            -Enabled $true `
            -ChangePasswordAtLogon $false `
            -ErrorAction Stop
        
        Write-Information "Created user: $($user.Username) ($displayName)" -InformationAction Continue
        
    }
    catch {
        Write-Warning "Failed to create user $($user.Username) : $($_.Exception.Message)"
    }
}

# Create department groups
Write-Information "Creating department groups..." -InformationAction Continue
foreach ($ou in $ous) {
    $groupName = "GRP-$ou"
    $ouPath = "OU=$ou,$domainDN"
    
    try {
        # Check if group already exists
        if (Get-ADGroup -Filter "Name -eq '$groupName'" -ErrorAction SilentlyContinue) {
            Write-Information "Group already exists: $groupName" -InformationAction Continue
            continue
        }
        
        # Create the group
        New-ADGroup -Name $groupName `
            -GroupScope Global `
            -GroupCategory Security `
            -Description "Security group for $ou department" `
            -Path $ouPath `
            -ErrorAction Stop
        
        Write-Information "Created group: $groupName" -InformationAction Continue
        
    }
    catch {
        Write-Warning "Failed to create group $groupName : $($_.Exception.Message)"
    }
}

# Add users to their respective department groups
Write-Information "Adding users to department groups..." -InformationAction Continue
foreach ($user in $users) {
    $groupName = "GRP-$($user.Department)"
    
    try {
        Add-ADGroupMember -Identity $groupName -Members $user.Username -ErrorAction Stop
        Write-Information "Added $($user.Username) to $groupName" -InformationAction Continue
    }
    catch {
        Write-Warning "Failed to add $($user.Username) to $groupName : $($_.Exception.Message)"
    }
}

Write-Output "Lab users creation completed successfully!"
Write-Information "Created $($users.Count) users and $($ous.Count) department groups." -InformationAction Continue
