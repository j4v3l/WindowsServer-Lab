# Expanded Lab Environment Setup Script
# This script helps set up an expanded Windows Server lab environment

# Import required modules
Import-Module ActiveDirectory
Import-Module DnsServer

# Create OUs for different departments
$departments = @("IT", "HR", "Sales", "Finance", "Marketing")
foreach ($dept in $departments) {
    New-ADOrganizationalUnit -Name $dept -Path "DC=lab,DC=local" -ErrorAction SilentlyContinue
}

# Create department groups
foreach ($dept in $departments) {
    $groupName = "GRP-$dept"
    $ouPath = "OU=$dept,DC=lab,DC=local"
    
    # Create the group
    New-ADGroup -Name $groupName `
                -GroupScope Global `
                -GroupCategory Security `
                -Path $ouPath `
                -ErrorAction SilentlyContinue
}

# Create users for each department
$userData = @(
    @{Department="IT"; FirstName="Thor"; LastName="Odinson"; Username="thor"},
    @{Department="HR"; FirstName="Freya"; LastName="Njord"; Username="freya"},
    @{Department="Sales"; FirstName="Sif"; LastName="Thorsdottir"; Username="sif"},
    @{Department="Finance"; FirstName="Heimdall"; LastName="Bifrost"; Username="heimdall"},
    @{Department="Marketing"; FirstName="Frigg"; LastName="Fjorgyn"; Username="frigg"}
)

foreach ($user in $userData) {
    $ouPath = "OU=$($user.Department),DC=lab,DC=local"
    $upn = "$($user.Username)@lab.local"
    
    New-ADUser -Name "$($user.FirstName) $($user.LastName)" `
                -GivenName $user.FirstName `
                -Surname $user.LastName `
                -SamAccountName $user.Username `
                -UserPrincipalName $upn `
                -Path $ouPath `
                -AccountPassword (ConvertTo-SecureString "P@ssw0rd123" -AsPlainText -Force) `
                -Enabled $true `
                -ChangePasswordAtLogon $true `
                -ErrorAction SilentlyContinue
    
    # Add user to department group
    Add-ADGroupMember -Identity "GRP-$($user.Department)" -Members $user.Username -ErrorAction SilentlyContinue
}

# Create computer accounts
$computers = @(
    @{Name="CL-IT-001"; IP="192.168.1.201"; Department="IT"},
    @{Name="CL-HR-001"; IP="192.168.1.202"; Department="HR"},
    @{Name="CL-SALES-001"; IP="192.168.1.203"; Department="Sales"},
    @{Name="CL-FIN-001"; IP="192.168.1.204"; Department="Finance"},
    @{Name="CL-MKT-001"; IP="192.168.1.205"; Department="Marketing"}
)

foreach ($computer in $computers) {
    $ouPath = "OU=$($computer.Department),DC=lab,DC=local"
    
    New-ADComputer -Name $computer.Name `
                   -Path $ouPath `
                   -Enabled $true `
                   -ErrorAction SilentlyContinue
}

# Create file shares on FS1
$shares = @(
    @{Name="IT"; Path="C:\Shares\IT"; Group="GRP-IT"},
    @{Name="HR"; Path="C:\Shares\HR"; Group="GRP-HR"},
    @{Name="Sales"; Path="C:\Shares\Sales"; Group="GRP-Sales"},
    @{Name="Finance"; Path="C:\Shares\Finance"; Group="GRP-Finance"},
    @{Name="Marketing"; Path="C:\Shares\Marketing"; Group="GRP-Marketing"}
)

foreach ($share in $shares) {
    # Create directory if it doesn't exist
    New-Item -Path $share.Path -ItemType Directory -Force -ErrorAction SilentlyContinue
    
    # Create share
    New-SmbShare -Name $share.Name `
                 -Path $share.Path `
                 -FullAccess "LAB\$($share.Group)" `
                 -ErrorAction SilentlyContinue
}

# Configure security settings
# Password Policy
Set-ADDefaultDomainPasswordPolicy -MinPasswordLength 12 `
                                 -ComplexityEnabled $true `
                                 -MaxPasswordAge 90 `
                                 -MinPasswordAge 1 `
                                 -PasswordHistoryCount 24

# Account Lockout
Set-ADDefaultDomainPasswordPolicy -LockoutThreshold 5 `
                                 -LockoutDuration 30 `
                                 -LockoutObservationWindow 30

# Enable Windows Defender
Set-MpPreference -DisableRealtimeMonitoring $false
Set-MpPreference -DisableIOAVProtection $false

# Configure Firewall
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True
Set-NetFirewallProfile -DefaultInboundAction Block

Write-Host "Expanded lab environment setup completed successfully!" -ForegroundColor Green
Write-Host "Please verify all settings and test access to resources." -ForegroundColor Yellow 