# Expanded Lab Environment Setup Script
# This script helps set up an expanded Windows Server lab environment

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [System.Security.SecureString]$DefaultUserPassword,
    
    [Parameter(Mandatory = $false)]
    [switch]$Force
)

# Import required modules
Import-Module ActiveDirectory
Import-Module DnsServer

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

# Create OUs for different departments
$departments = @("IT", "HR", "Sales", "Finance", "Marketing")
foreach ($dept in $departments) {
    try {
        New-ADOrganizationalUnit -Name $dept -Path "DC=lab,DC=local" -ErrorAction Stop
        Write-Information "Created OU: $dept" -InformationAction Continue
    }
    catch {
        if ($_.Exception.Message -notlike "*already exists*") {
            Write-Warning "Failed to create OU $dept : $($_.Exception.Message)"
        }
    }
}

# Create department groups
foreach ($dept in $departments) {
    $groupName = "GRP-$dept"
    $ouPath = "OU=$dept,DC=lab,DC=local"
    
    try {
        # Create the group
        New-ADGroup -Name $groupName `
            -GroupScope Global `
            -GroupCategory Security `
            -Path $ouPath `
            -ErrorAction Stop
        Write-Information "Created group: $groupName" -InformationAction Continue
    }
    catch {
        if ($_.Exception.Message -notlike "*already exists*") {
            Write-Warning "Failed to create group $groupName : $($_.Exception.Message)"
        }
    }
}

# Create users for each department
$userData = @(
    @{Department = "IT"; FirstName = "Thor"; LastName = "Odinson"; Username = "thor" },
    @{Department = "HR"; FirstName = "Freya"; LastName = "Njord"; Username = "freya" },
    @{Department = "Sales"; FirstName = "Sif"; LastName = "Thorsdottir"; Username = "sif" },
    @{Department = "Finance"; FirstName = "Heimdall"; LastName = "Bifrost"; Username = "heimdall" },
    @{Department = "Marketing"; FirstName = "Frigg"; LastName = "Fjorgyn"; Username = "frigg" }
)

foreach ($user in $userData) {
    $ouPath = "OU=$($user.Department),DC=lab,DC=local"
    $upn = "$($user.Username)@lab.local"
    
    try {
        New-ADUser -Name "$($user.FirstName) $($user.LastName)" `
            -GivenName $user.FirstName `
            -Surname $user.LastName `
            -SamAccountName $user.Username `
            -UserPrincipalName $upn `
            -Path $ouPath `
            -AccountPassword $DefaultUserPassword `
            -Enabled $true `
            -ChangePasswordAtLogon $true `
            -ErrorAction Stop
        
        Write-Information "Created user: $($user.Username)" -InformationAction Continue
        
        # Add user to department group
        Add-ADGroupMember -Identity "GRP-$($user.Department)" -Members $user.Username -ErrorAction Stop
        Write-Information "Added $($user.Username) to group GRP-$($user.Department)" -InformationAction Continue
    }
    catch {
        if ($_.Exception.Message -notlike "*already exists*") {
            Write-Warning "Failed to create user $($user.Username) : $($_.Exception.Message)"
        }
    }
}

# Create computer accounts
$computers = @(
    @{Name = "CL-IT-001"; IP = "192.168.1.201"; Department = "IT" },
    @{Name = "CL-HR-001"; IP = "192.168.1.202"; Department = "HR" },
    @{Name = "CL-SALES-001"; IP = "192.168.1.203"; Department = "Sales" },
    @{Name = "CL-FIN-001"; IP = "192.168.1.204"; Department = "Finance" },
    @{Name = "CL-MKT-001"; IP = "192.168.1.205"; Department = "Marketing" }
)

foreach ($computer in $computers) {
    $ouPath = "OU=$($computer.Department),DC=lab,DC=local"
    
    try {
        New-ADComputer -Name $computer.Name `
            -Path $ouPath `
            -Enabled $true `
            -ErrorAction Stop
        Write-Information "Created computer: $($computer.Name)" -InformationAction Continue
    }
    catch {
        if ($_.Exception.Message -notlike "*already exists*") {
            Write-Warning "Failed to create computer $($computer.Name) : $($_.Exception.Message)"
        }
    }
}

# Create file shares on FS1
$shares = @(
    @{Name = "IT"; Path = "C:\Shares\IT"; Group = "GRP-IT" },
    @{Name = "HR"; Path = "C:\Shares\HR"; Group = "GRP-HR" },
    @{Name = "Sales"; Path = "C:\Shares\Sales"; Group = "GRP-Sales" },
    @{Name = "Finance"; Path = "C:\Shares\Finance"; Group = "GRP-Finance" },
    @{Name = "Marketing"; Path = "C:\Shares\Marketing"; Group = "GRP-Marketing" }
)

foreach ($share in $shares) {
    try {
        # Create directory if it doesn't exist
        New-Item -Path $share.Path -ItemType Directory -Force -ErrorAction Stop
        
        # Create share
        New-SmbShare -Name $share.Name `
            -Path $share.Path `
            -FullAccess "LAB\$($share.Group)" `
            -ErrorAction Stop
        Write-Information "Created share: $($share.Name)" -InformationAction Continue
    }
    catch {
        Write-Warning "Failed to create share $($share.Name) : $($_.Exception.Message)"
    }
}

# Configure security settings
try {
    # Password Policy
    Set-ADDefaultDomainPasswordPolicy -MinPasswordLength 12 `
        -ComplexityEnabled $true `
        -MaxPasswordAge 90 `
        -MinPasswordAge 1 `
        -PasswordHistoryCount 24
    Write-Information "Configured password policy" -InformationAction Continue

    # Account Lockout
    Set-ADDefaultDomainPasswordPolicy -LockoutThreshold 5 `
        -LockoutDuration 30 `
        -LockoutObservationWindow 30
    Write-Information "Configured account lockout policy" -InformationAction Continue
}
catch {
    Write-Warning "Failed to configure password policies: $($_.Exception.Message)"
}

try {
    # Enable Windows Defender
    Set-MpPreference -DisableRealtimeMonitoring $false
    Set-MpPreference -DisableIOAVProtection $false
    Write-Information "Configured Windows Defender" -InformationAction Continue
}
catch {
    Write-Warning "Failed to configure Windows Defender: $($_.Exception.Message)"
}

try {
    # Configure Firewall
    Set-NetFirewallProfile -Profile Domain, Public, Private -Enabled True
    Set-NetFirewallProfile -DefaultInboundAction Block
    Write-Information "Configured Windows Firewall" -InformationAction Continue
}
catch {
    Write-Warning "Failed to configure firewall: $($_.Exception.Message)"
}

Write-Output "Expanded lab environment setup completed successfully!"
Write-Information "Please verify all settings and test access to resources." -InformationAction Continue 