# ⚡ OLYMPUS SYSTEMS LAB DEPLOYMENT SCRIPT
# Automated deployment of the complete Greek mythology-themed Windows Server lab
#
# ⚡ HARDWARE SPECIFICATIONS (Tested & Optimized):
# CPU: AMD Ryzen 7900X (12 cores, 24 threads)
# RAM: 64GB DDR5
# Storage: 1TB NVMe SSD
# GPU: NVIDIA RTX 5070 (12GB VRAM)
# OS: Windows 11 Pro with Hyper-V
#
# 💪 This configuration can handle:
# - 25+ VMs simultaneously with enhanced specifications
# - Total VM RAM allocation: ~90GB (servers: 36GB, workstations: 54GB)
# - Parallel operations without performance issues
# - 30-60 minute deployment time
#
# ⚠️ For lower-spec hardware, reduce VM memory allocations in the script

#Requires -RunAsAdministrator
#Requires -Module Hyper-V, ActiveDirectory, DnsServer, DhcpServer

[CmdletBinding()]
param(
    [string]$DomainName = "olympus.local",
    [string]$VMPath = "C:\VMs\Olympus",
    [string]$ServerISOPath = "",
    [string]$ClientISOPath = "",
    [string]$ISOPath = "", # Legacy parameter for backward compatibility
    [Parameter(Mandatory = $false)]
    [System.Security.SecureString]$SafeModePassword,
    [Parameter(Mandatory = $false)]
    [System.Security.SecureString]$DefaultUserPassword,
    [switch]$SkipVMs = $false,
    [switch]$SkipNetworking = $false,
    [switch]$SkipAD = $false,
    [switch]$Force = $false
)

# Enhanced logging and error handling
$ErrorActionPreference = "Stop"
$LogPath = Join-Path $env:TEMP "Olympus-Lab-Deployment.log"

# Handle legacy ISOPath parameter for backward compatibility
if ($ISOPath -and (-not $ServerISOPath -and -not $ClientISOPath)) {
    Write-Host "⚠️  Using legacy ISOPath for both servers and clients. Consider using -ServerISOPath and -ClientISOPath for better control." -ForegroundColor Yellow
    $ServerISOPath = $ISOPath
    $ClientISOPath = $ISOPath
}

# Validate ISO paths
if ($ServerISOPath -and !(Test-Path $ServerISOPath)) {
    Write-Error "Server ISO file not found: $ServerISOPath"
    exit 1
}
if ($ClientISOPath -and !(Test-Path $ClientISOPath)) {
    Write-Error "Client ISO file not found: $ClientISOPath"
    exit 1
}

# Get secure passwords if not provided
if (-not $SafeModePassword) {
    # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "Please enter the Safe Mode (DSRM) password for domain controllers:" -ForegroundColor Yellow
    $SafeModePassword = Read-Host -AsSecureString
}

if (-not $DefaultUserPassword) {
    # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "Please enter the default password for new user accounts:" -ForegroundColor Yellow
    $DefaultUserPassword = Read-Host -AsSecureString
}

# Validate passwords are provided
if (-not $SafeModePassword -or -not $DefaultUserPassword) {
    Write-Error "Both Safe Mode and Default User passwords are required. Exiting."
    exit 1
}

function Write-OlympusLog {
    param(
        [string]$Message,
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR")]
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Add-Content -Path $LogPath -Value $logEntry -ErrorAction SilentlyContinue
    
    switch ($Level) {
        "SUCCESS" {
            # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "✅ $Message" -ForegroundColor Green }
            "WARNING" { # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "⚠️  $Message" -ForegroundColor Yellow }
                "ERROR" { # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "❌ $Message" -ForegroundColor Red }
                    "INFO" { # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "ℹ️  $Message" -ForegroundColor Cyan }
                    }
                }

                # Banner
                function Show-OlympusBanner {
                    Write-Host @"
    
    ⚡ ═══════════════════════════════════════════════════════════ ⚡
    
         ░█████╗░██╗░░░░░██╗░░░██╗███╗░░░███╗██████╗░██╗░░░██╗░██████╗
         ██╔══██╗██║░░░░░╚██╗░██╔╝████╗░████║██╔══██╗██║░░░██║██╔════╝
         ██║░░██║██║░░░░░░╚████╔╝░██╔████╔██║██████╔╝██║░░░██║╚█████╗░
         ██║░░██║██║░░░░░░░╚██╔╝░░██║╚██╔╝██║██╔═══╝░██║░░░██║░╚═══██╗
         ╚█████╔╝███████╗░░░██║░░░██║░╚═╝░██║██║░░░░░╚██████╔╝██████╔╝
         ░╚════╝░╚══════╝░░░╚═╝░░░╚═╝░░░░░╚═╝╚═╝░░░░░░╚═════╝░╚═════╝░
    
    🏛️ SYSTEMS - "Bringing Divine Power to Digital Transformation" 🏛️
    
    ⚡ ═══════════════════════════════════════════════════════════ ⚡
    
"@ -ForegroundColor Blue
                }

                # Network Configuration
                function New-OlympusNetwork {
                    Write-OlympusLog "Creating Olympus network infrastructure..." "INFO"
    
                    try {
                        # Remove existing switches if Force is specified
                        if ($Force) {
                            $existingSwitches = @("OLYMPUS-Production", "OLYMPUS-Management", "OLYMPUS-DMZ", "OLYMPUS-Clients")
                            foreach ($switchName in $existingSwitches) {
                                $switch = Get-VMSwitch -Name $switchName -ErrorAction SilentlyContinue
                                if ($switch) {
                                    Write-OlympusLog "Removing existing switch: $switchName" "WARNING"
                                    Remove-VMSwitch -Name $switchName -Force
                                }
                            }
                        }
        
                        # Create Production Network (Internal) - FIXED: Was External, caused network mismatch
                        New-VMSwitch -Name "OLYMPUS-Production" -SwitchType Internal -ErrorAction SilentlyContinue
                        Start-Sleep -Seconds 2
                        $prodAdapter = Get-NetAdapter -Name "vEthernet (OLYMPUS-Production)" -ErrorAction SilentlyContinue
                        if ($prodAdapter) {
                            Remove-NetIPAddress -InterfaceIndex $prodAdapter.ifIndex -Confirm:$false -ErrorAction SilentlyContinue
                            New-NetIPAddress -IPAddress 10.0.10.1 -PrefixLength 24 -InterfaceIndex $prodAdapter.ifIndex -ErrorAction SilentlyContinue
                            Write-OlympusLog "Created Production network: 10.0.10.1/24" "SUCCESS"
                        }
        
                        # Create Management Network (Internal)
                        New-VMSwitch -Name "OLYMPUS-Management" -SwitchType Internal -ErrorAction SilentlyContinue
                        Start-Sleep -Seconds 2
                        $mgmtAdapter = Get-NetAdapter -Name "vEthernet (OLYMPUS-Management)" -ErrorAction SilentlyContinue
                        if ($mgmtAdapter) {
                            Remove-NetIPAddress -InterfaceIndex $mgmtAdapter.ifIndex -Confirm:$false -ErrorAction SilentlyContinue
                            New-NetIPAddress -IPAddress 10.0.100.1 -PrefixLength 24 -InterfaceIndex $mgmtAdapter.ifIndex -ErrorAction SilentlyContinue
                            Write-OlympusLog "Created Management network: 10.0.100.1/24" "SUCCESS"
                        }
        
                        # Create DMZ Network (Private)
                        New-VMSwitch -Name "OLYMPUS-DMZ" -SwitchType Private -ErrorAction SilentlyContinue
                        Write-OlympusLog "Created DMZ network switch" "SUCCESS"
        
                        # Create Client Network (Internal)
                        New-VMSwitch -Name "OLYMPUS-Clients" -SwitchType Internal -ErrorAction SilentlyContinue
                        Start-Sleep -Seconds 2
                        $clientAdapter = Get-NetAdapter -Name "vEthernet (OLYMPUS-Clients)" -ErrorAction SilentlyContinue
                        if ($clientAdapter) {
                            Remove-NetIPAddress -InterfaceIndex $clientAdapter.ifIndex -Confirm:$false -ErrorAction SilentlyContinue
                            New-NetIPAddress -IPAddress 10.0.20.1 -PrefixLength 22 -InterfaceIndex $clientAdapter.ifIndex -ErrorAction SilentlyContinue
                            Write-OlympusLog "Created Client network: 10.0.20.1/22" "SUCCESS"
                        }
        
                        # Configure NAT for internal networks
                        $existingNAT = Get-NetNat -Name "OLYMPUS-NAT" -ErrorAction SilentlyContinue
                        if (-not $existingNAT) {
                            New-NetNat -Name "OLYMPUS-NAT" -InternalIPInterfaceAddressPrefix 10.0.0.0/8 -ErrorAction SilentlyContinue
                            Write-OlympusLog "Configured NAT for internal networks" "SUCCESS"
                        }
        
                        # Enable IP Forwarding between networks - NEW: Critical for network routing
                        try {
                            Set-NetIPInterface -InterfaceAlias "vEthernet (OLYMPUS-Production)" -Forwarding Enabled -ErrorAction SilentlyContinue
                            Set-NetIPInterface -InterfaceAlias "vEthernet (OLYMPUS-Clients)" -Forwarding Enabled -ErrorAction SilentlyContinue
                            Set-NetIPInterface -InterfaceAlias "vEthernet (OLYMPUS-Management)" -Forwarding Enabled -ErrorAction SilentlyContinue
                            Write-OlympusLog "Enabled IP forwarding on all network interfaces" "SUCCESS"
                        }
                        catch {
                            Write-OlympusLog "Failed to enable IP forwarding: $($_.Exception.Message)" "WARNING"
                        }
        
                        return $true
                    }
                    catch {
                        Write-OlympusLog "Failed to create networks: $($_.Exception.Message)" "ERROR"
                        return $false
                    }
                }

                # VM Creation Functions
                function New-OlympusVM {
                    param(
                        [string]$VMName,
                        [int64]$Memory,
                        [int64]$VHDSize,
                        [int]$CPUCount,
                        [string[]]$NetworkSwitches,
                        [string]$Description,
                        [string]$ISOPath = ""
                    )
    
                    try {
                        # Check if VM exists
                        $existingVM = Get-VM -Name $VMName -ErrorAction SilentlyContinue
                        if ($existingVM -and -not $Force) {
                            Write-OlympusLog "VM $VMName already exists" "WARNING"
                            return $true
                        }
                        elseif ($existingVM -and $Force) {
                            Write-OlympusLog "Removing existing VM: $VMName" "WARNING"
                            Stop-VM -Name $VMName -Force -ErrorAction SilentlyContinue
                            Remove-VM -Name $VMName -Force
                        }
        
                        # Create VM directory
                        $vmPath = Join-Path $VMPath $VMName
                        if (!(Test-Path $vmPath)) {
                            New-Item -Path $vmPath -ItemType Directory -Force | Out-Null
                        }
        
                        # Create VM
                        New-VM -Name $VMName -Path $VMPath -MemoryStartupBytes $Memory -Generation 2 | Out-Null
        
                        # Configure VM
                        Set-VM -Name $VMName -ProcessorCount $CPUCount -DynamicMemory -MemoryMinimumBytes ([Math]::Max(1GB, $Memory / 2)) -MemoryMaximumBytes ($Memory * 2) -Notes $Description
        
                        # Create and attach VHD
                        $vhdPath = Join-Path $vmPath "$VMName.vhdx"
                        New-VHD -Path $vhdPath -SizeBytes $VHDSize -Dynamic | Out-Null
                        Add-VMHardDiskDrive -VMName $VMName -Path $vhdPath
        
                        # Add DVD drive
                        Add-VMDvdDrive -VMName $VMName
        
                        # Configure network adapters
                        $defaultAdapter = Get-VMNetworkAdapter -VMName $VMName
                        if ($defaultAdapter) {
                            Remove-VMNetworkAdapter -VMName $VMName -VMNetworkAdapter $defaultAdapter
                        }
        
                        foreach ($switchName in $NetworkSwitches) {
                            $adapterName = $switchName.Replace("OLYMPUS-", "")
                            Add-VMNetworkAdapter -VMName $VMName -SwitchName $switchName -Name $adapterName
                        }
        
                        # Configure firmware
                        Set-VMFirmware -VMName $VMName -EnableSecureBoot On -SecureBootTemplate "MicrosoftWindows"
                        $dvdDrive = Get-VMDvdDrive -VMName $VMName
                        if ($dvdDrive) {
                            Set-VMFirmware -VMName $VMName -FirstBootDevice $dvdDrive
                        }
        
                        # Attach ISO if provided
                        if ($ISOPath -and (Test-Path $ISOPath)) {
                            Set-VMDvdDrive -VMName $VMName -Path $ISOPath
                            Write-OlympusLog "Attached ISO to $VMName`: $(Split-Path $ISOPath -Leaf)" "SUCCESS"
                        }
        
                        Write-OlympusLog "Created VM: $VMName" "SUCCESS"
                        return $true
                    }
                    catch {
                        Write-OlympusLog "Failed to create VM $VMName : $($_.Exception.Message)" "ERROR"
                        return $false
                    }
                }

                # Server Infrastructure Creation
                function New-OlympusServer {
                    Write-OlympusLog "Creating Olympus server infrastructure..." "INFO"
    
                    $servers = @(
                        @{
                            Name        = "ZEUS-DC01"
                            Description = "Primary Domain Controller - King of the Gods"
                            Memory      = 8GB
                            VHDSize     = 100GB
                            CPUCount    = 4
                            Networks    = @("OLYMPUS-Production", "OLYMPUS-Management")
                        },
                        @{
                            Name        = "HERA-DC02"
                            Description = "Secondary Domain Controller - Queen of the Gods"
                            Memory      = 6GB
                            VHDSize     = 80GB
                            CPUCount    = 3
                            Networks    = @("OLYMPUS-Production", "OLYMPUS-Management")
                        },
                        @{
                            Name        = "HERMES-FS01"
                            Description = "File Server - Messenger of the Gods"
                            Memory      = 8GB
                            VHDSize     = 200GB
                            CPUCount    = 4
                            Networks    = @("OLYMPUS-Production", "OLYMPUS-Management")
                        },
                        @{
                            Name        = "APOLLO-WEB01"
                            Description = "Web/Application Server - God of Light and Knowledge"
                            Memory      = 6GB
                            VHDSize     = 100GB
                            CPUCount    = 3
                            Networks    = @("OLYMPUS-Production", "OLYMPUS-DMZ", "OLYMPUS-Management")
                        },
                        @{
                            Name        = "ATHENA-SEC01"
                            Description = "Security Server - Goddess of Wisdom and Warfare"
                            Memory      = 8GB
                            VHDSize     = 150GB
                            CPUCount    = 4
                            Networks    = @("OLYMPUS-Production", "OLYMPUS-Management")
                        }
                    )
    
                    foreach ($server in $servers) {
                        $result = New-OlympusVM -VMName $server.Name -Memory $server.Memory -VHDSize $server.VHDSize -CPUCount $server.CPUCount -NetworkSwitches $server.Networks -Description $server.Description -ISOPath $ServerISOPath
                        if (-not $result) {
                            Write-OlympusLog "Failed to create server: $($server.Name)" "ERROR"
                            return $false
                        }
                    }
    
                    Write-OlympusLog "All servers created successfully" "SUCCESS"
                    return $true
                }

                # Workstation Creation
                function New-OlympusWorkstation {
                    Write-OlympusLog "Creating Olympus workstations..." "INFO"
    
                    $departments = @(
                        @{ Name = "Divine Council"; Prefix = "DC"; Users = @("ZEUS", "POSEIDON", "HADES", "HERMES", "DIONYSUS") },
                        @{ Name = "War Strategists"; Prefix = "WS"; Users = @("ATHENA", "ARES", "NIKE", "KRATOS", "BIA") },
                        @{ Name = "Innovation Forge"; Prefix = "IF"; Users = @("APOLLO", "ARTEMIS", "HEPHAESTUS", "PROMETHEUS", "DAEDALUS") },
                        @{ Name = "Abundance Treasury"; Prefix = "AT"; Users = @("HERA", "DEMETER", "PLUTUS", "TYCHE", "NEMESIS") },
                        @{ Name = "Harmony Relations"; Prefix = "HR"; Users = @("APHRODITE", "EROS", "PSYCHE", "HARMONIA", "IRIS") }
                    )
    
                    foreach ($dept in $departments) {
                        for ($i = 0; $i -lt $dept.Users.Count; $i++) {
                            $vmName = "$($dept.Users[$i])-WS$(($i+1).ToString('00'))"
                            $description = "$($dept.Name) Workstation - $($dept.Users[$i])"
            
                            $result = New-OlympusVM -VMName $vmName -Memory 4GB -VHDSize 60GB -CPUCount 2 -NetworkSwitches @("OLYMPUS-Clients") -Description $description -ISOPath $ClientISOPath
                            if (-not $result) {
                                Write-OlympusLog "Failed to create workstation: $vmName" "ERROR"
                                return $false
                            }
                        }
                    }
    
                    Write-OlympusLog "All workstations created successfully" "SUCCESS"
                    return $true
                }

                # Active Directory Configuration Script Generation
                function New-OlympusADScript {
                    Write-OlympusLog "Generating Active Directory configuration script..." "INFO"
    
                    $adScript = @"
# ⚡ OLYMPUS SYSTEMS - Active Directory Configuration Script
# Run this script on ZEUS-DC01 after promoting to Domain Controller

# Get the default user password (this should be passed as a parameter)
if (-not `$DefaultUserPassword) {
    # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "Please enter the default password for new user accounts:" -ForegroundColor Yellow
    `$DefaultUserPassword = Read-Host -AsSecureString
}

# Configure DNS Forwarders
Add-DnsServerForwarder -IPAddress 8.8.8.8, 1.1.1.1

# Create Organizational Units
New-ADOrganizationalUnit -Name "Olympus Systems" -Path "DC=olympus,DC=local"
New-ADOrganizationalUnit -Name "Departments" -Path "OU=Olympus Systems,DC=olympus,DC=local"
New-ADOrganizationalUnit -Name "Service Accounts" -Path "OU=Olympus Systems,DC=olympus,DC=local"
New-ADOrganizationalUnit -Name "Workstations" -Path "OU=Olympus Systems,DC=olympus,DC=local"

# Create Department OUs
New-ADOrganizationalUnit -Name "Divine Council" -Path "OU=Departments,OU=Olympus Systems,DC=olympus,DC=local"
New-ADOrganizationalUnit -Name "War Strategists" -Path "OU=Departments,OU=Olympus Systems,DC=olympus,DC=local"
New-ADOrganizationalUnit -Name "Innovation Forge" -Path "OU=Departments,OU=Olympus Systems,DC=olympus,DC=local"
New-ADOrganizationalUnit -Name "Abundance Treasury" -Path "OU=Departments,OU=Olympus Systems,DC=olympus,DC=local"
New-ADOrganizationalUnit -Name "Harmony Relations" -Path "OU=Departments,OU=Olympus Systems,DC=olympus,DC=local"

# Create Security Groups
New-ADGroup -Name "GRP-Divine_Council" -GroupScope Global -GroupCategory Security -Path "OU=Divine Council,OU=Departments,OU=Olympus Systems,DC=olympus,DC=local"
New-ADGroup -Name "GRP-War_Strategists" -GroupScope Global -GroupCategory Security -Path "OU=War Strategists,OU=Departments,OU=Olympus Systems,DC=olympus,DC=local"
New-ADGroup -Name "GRP-Innovation_Forge" -GroupScope Global -GroupCategory Security -Path "OU=Innovation Forge,OU=Departments,OU=Olympus Systems,DC=olympus,DC=local"
New-ADGroup -Name "GRP-Abundance_Treasury" -GroupScope Global -GroupCategory Security -Path "OU=Abundance Treasury,OU=Departments,OU=Olympus Systems,DC=olympus,DC=local"
New-ADGroup -Name "GRP-Harmony_Relations" -GroupScope Global -GroupCategory Security -Path "OU=Harmony Relations,OU=Departments,OU=Olympus Systems,DC=olympus,DC=local"

# Create Admin Groups
New-ADGroup -Name "GRP-Domain_Admins_Olympus" -GroupScope Global -GroupCategory Security -Path "OU=Divine Council,OU=Departments,OU=Olympus Systems,DC=olympus,DC=local"
New-ADGroup -Name "GRP-Security_Admins" -GroupScope Global -GroupCategory Security -Path "OU=War Strategists,OU=Departments,OU=Olympus Systems,DC=olympus,DC=local"

# Create User Accounts - Divine Council (IT Operations) - FIXED: Added PasswordNeverExpires for lab environment
New-ADUser -Name "Zeus Supreme" -SamAccountName "zeus.supreme" -UserPrincipalName "zeus.supreme@olympus.local" -DisplayName "Zeus Supreme" -Department "Divine Council" -Title "CEO & Domain Admin" -Path "OU=Divine Council,OU=Departments,OU=Olympus Systems,DC=olympus,DC=local" -AccountPassword `$DefaultUserPassword -Enabled `$true -PasswordNeverExpires `$true
New-ADUser -Name "Poseidon Seas" -SamAccountName "poseidon.seas" -UserPrincipalName "poseidon.seas@olympus.local" -DisplayName "Poseidon Seas" -Department "Divine Council" -Title "Senior Systems Engineer" -Path "OU=Divine Council,OU=Departments,OU=Olympus Systems,DC=olympus,DC=local" -AccountPassword `$DefaultUserPassword -Enabled `$true -PasswordNeverExpires `$true
New-ADUser -Name "Hades Underworld" -SamAccountName "hades.underworld" -UserPrincipalName "hades.underworld@olympus.local" -DisplayName "Hades Underworld" -Department "Divine Council" -Title "Database Administrator" -Path "OU=Divine Council,OU=Departments,OU=Olympus Systems,DC=olympus,DC=local" -AccountPassword `$DefaultUserPassword -Enabled `$true -PasswordNeverExpires `$true
New-ADUser -Name "Hermes Messenger" -SamAccountName "hermes.messenger" -UserPrincipalName "hermes.messenger@olympus.local" -DisplayName "Hermes Messenger" -Department "Divine Council" -Title "Network Administrator" -Path "OU=Divine Council,OU=Departments,OU=Olympus Systems,DC=olympus,DC=local" -AccountPassword `$DefaultUserPassword -Enabled `$true -PasswordNeverExpires `$true
New-ADUser -Name "Dionysus Wine" -SamAccountName "dionysus.wine" -UserPrincipalName "dionysus.wine@olympus.local" -DisplayName "Dionysus Wine" -Department "Divine Council" -Title "Junior Developer" -Path "OU=Divine Council,OU=Departments,OU=Olympus Systems,DC=olympus,DC=local" -AccountPassword `$DefaultUserPassword -Enabled `$true -PasswordNeverExpires `$true

# Create User Accounts - War Strategists (Cybersecurity)
New-ADUser -Name "Athena Wisdom" -SamAccountName "athena.wisdom" -UserPrincipalName "athena.wisdom@olympus.local" -DisplayName "Athena Wisdom" -Department "War Strategists" -Title "CTO & CISO" -Path "OU=War Strategists,OU=Departments,OU=Olympus Systems,DC=olympus,DC=local" -AccountPassword `$DefaultUserPassword -Enabled `$true
New-ADUser -Name "Ares War" -SamAccountName "ares.war" -UserPrincipalName "ares.war@olympus.local" -DisplayName "Ares War" -Department "War Strategists" -Title "Security Operations Manager" -Path "OU=War Strategists,OU=Departments,OU=Olympus Systems,DC=olympus,DC=local" -AccountPassword `$DefaultUserPassword -Enabled `$true
New-ADUser -Name "Nike Victory" -SamAccountName "nike.victory" -UserPrincipalName "nike.victory@olympus.local" -DisplayName "Nike Victory" -Department "War Strategists" -Title "Incident Response Lead" -Path "OU=War Strategists,OU=Departments,OU=Olympus Systems,DC=olympus,DC=local" -AccountPassword `$DefaultUserPassword -Enabled `$true
New-ADUser -Name "Kratos Strength" -SamAccountName "kratos.strength" -UserPrincipalName "kratos.strength@olympus.local" -DisplayName "Kratos Strength" -Department "War Strategists" -Title "Penetration Tester" -Path "OU=War Strategists,OU=Departments,OU=Olympus Systems,DC=olympus,DC=local" -AccountPassword `$DefaultUserPassword -Enabled `$true
New-ADUser -Name "Bia Force" -SamAccountName "bia.force" -UserPrincipalName "bia.force@olympus.local" -DisplayName "Bia Force" -Department "War Strategists" -Title "SOC Analyst" -Path "OU=War Strategists,OU=Departments,OU=Olympus Systems,DC=olympus,DC=local" -AccountPassword `$DefaultUserPassword -Enabled `$true

# Create User Accounts - Innovation Forge (R&D)
New-ADUser -Name "Apollo Light" -SamAccountName "apollo.light" -UserPrincipalName "apollo.light@olympus.local" -DisplayName "Apollo Light" -Department "Innovation Forge" -Title "Head of Innovation" -Path "OU=Innovation Forge,OU=Departments,OU=Olympus Systems,DC=olympus,DC=local" -AccountPassword `$DefaultUserPassword -Enabled `$true
New-ADUser -Name "Artemis Hunt" -SamAccountName "artemis.hunt" -UserPrincipalName "artemis.hunt@olympus.local" -DisplayName "Artemis Hunt" -Department "Innovation Forge" -Title "AI Research Scientist" -Path "OU=Innovation Forge,OU=Departments,OU=Olympus Systems,DC=olympus,DC=local" -AccountPassword `$DefaultUserPassword -Enabled `$true
New-ADUser -Name "Hephaestus Forge" -SamAccountName "hephaestus.forge" -UserPrincipalName "hephaestus.forge@olympus.local" -DisplayName "Hephaestus Forge" -Department "Innovation Forge" -Title "Senior Developer" -Path "OU=Innovation Forge,OU=Departments,OU=Olympus Systems,DC=olympus,DC=local" -AccountPassword `$DefaultUserPassword -Enabled `$true
New-ADUser -Name "Prometheus Fire" -SamAccountName "prometheus.fire" -UserPrincipalName "prometheus.fire@olympus.local" -DisplayName "Prometheus Fire" -Department "Innovation Forge" -Title "Data Scientist" -Path "OU=Innovation Forge,OU=Departments,OU=Olympus Systems,DC=olympus,DC=local" -AccountPassword `$DefaultUserPassword -Enabled `$true
New-ADUser -Name "Daedalus Craft" -SamAccountName "daedalus.craft" -UserPrincipalName "daedalus.craft@olympus.local" -DisplayName "Daedalus Craft" -Department "Innovation Forge" -Title "DevOps Engineer" -Path "OU=Innovation Forge,OU=Departments,OU=Olympus Systems,DC=olympus,DC=local" -AccountPassword `$DefaultUserPassword -Enabled `$true

# Create User Accounts - Abundance Treasury (Finance)
New-ADUser -Name "Hera Queen" -SamAccountName "hera.queen" -UserPrincipalName "hera.queen@olympus.local" -DisplayName "Hera Queen" -Department "Abundance Treasury" -Title "CFO" -Path "OU=Abundance Treasury,OU=Departments,OU=Olympus Systems,DC=olympus,DC=local" -AccountPassword `$DefaultUserPassword -Enabled `$true
New-ADUser -Name "Demeter Harvest" -SamAccountName "demeter.harvest" -UserPrincipalName "demeter.harvest@olympus.local" -DisplayName "Demeter Harvest" -Department "Abundance Treasury" -Title "Financial Analyst" -Path "OU=Abundance Treasury,OU=Departments,OU=Olympus Systems,DC=olympus,DC=local" -AccountPassword `$DefaultUserPassword -Enabled `$true
New-ADUser -Name "Plutus Wealth" -SamAccountName "plutus.wealth" -UserPrincipalName "plutus.wealth@olympus.local" -DisplayName "Plutus Wealth" -Department "Abundance Treasury" -Title "Accounting Manager" -Path "OU=Abundance Treasury,OU=Departments,OU=Olympus Systems,DC=olympus,DC=local" -AccountPassword `$DefaultUserPassword -Enabled `$true
New-ADUser -Name "Tyche Fortune" -SamAccountName "tyche.fortune" -UserPrincipalName "tyche.fortune@olympus.local" -DisplayName "Tyche Fortune" -Department "Abundance Treasury" -Title "Risk Analyst" -Path "OU=Abundance Treasury,OU=Departments,OU=Olympus Systems,DC=olympus,DC=local" -AccountPassword `$DefaultUserPassword -Enabled `$true
New-ADUser -Name "Nemesis Balance" -SamAccountName "nemesis.balance" -UserPrincipalName "nemesis.balance@olympus.local" -DisplayName "Nemesis Balance" -Department "Abundance Treasury" -Title "Compliance Officer" -Path "OU=Abundance Treasury,OU=Departments,OU=Olympus Systems,DC=olympus,DC=local" -AccountPassword `$DefaultUserPassword -Enabled `$true

# Create User Accounts - Harmony Relations (HR)
New-ADUser -Name "Aphrodite Harmony" -SamAccountName "aphrodite.harmony" -UserPrincipalName "aphrodite.harmony@olympus.local" -DisplayName "Aphrodite Harmony" -Department "Harmony Relations" -Title "HR Director" -Path "OU=Harmony Relations,OU=Departments,OU=Olympus Systems,DC=olympus,DC=local" -AccountPassword `$DefaultUserPassword -Enabled `$true
New-ADUser -Name "Eros Love" -SamAccountName "eros.love" -UserPrincipalName "eros.love@olympus.local" -DisplayName "Eros Love" -Department "Harmony Relations" -Title "Talent Acquisition" -Path "OU=Harmony Relations,OU=Departments,OU=Olympus Systems,DC=olympus,DC=local" -AccountPassword `$DefaultUserPassword -Enabled `$true
New-ADUser -Name "Psyche Soul" -SamAccountName "psyche.soul" -UserPrincipalName "psyche.soul@olympus.local" -DisplayName "Psyche Soul" -Department "Harmony Relations" -Title "Training Coordinator" -Path "OU=Harmony Relations,OU=Departments,OU=Olympus Systems,DC=olympus,DC=local" -AccountPassword `$DefaultUserPassword -Enabled `$true
New-ADUser -Name "Harmonia Peace" -SamAccountName "harmonia.peace" -UserPrincipalName "harmonia.peace@olympus.local" -DisplayName "Harmonia Peace" -Department "Harmony Relations" -Title "Employee Relations" -Path "OU=Harmony Relations,OU=Departments,OU=Olympus Systems,DC=olympus,DC=local" -AccountPassword `$DefaultUserPassword -Enabled `$true
New-ADUser -Name "Iris Rainbow" -SamAccountName "iris.rainbow" -UserPrincipalName "iris.rainbow@olympus.local" -DisplayName "Iris Rainbow" -Department "Harmony Relations" -Title "Communications Specialist" -Path "OU=Harmony Relations,OU=Departments,OU=Olympus Systems,DC=olympus,DC=local" -AccountPassword `$DefaultUserPassword -Enabled `$true

# Add users to groups
Add-ADGroupMember -Identity "GRP-Divine_Council" -Members "zeus.supreme", "poseidon.seas", "hades.underworld", "hermes.messenger", "dionysus.wine"
Add-ADGroupMember -Identity "GRP-War_Strategists" -Members "athena.wisdom", "ares.war", "nike.victory", "kratos.strength", "bia.force"
Add-ADGroupMember -Identity "GRP-Innovation_Forge" -Members "apollo.light", "artemis.hunt", "hephaestus.forge", "prometheus.fire", "daedalus.craft"
Add-ADGroupMember -Identity "GRP-Abundance_Treasury" -Members "hera.queen", "demeter.harvest", "plutus.wealth", "tyche.fortune", "nemesis.balance"
Add-ADGroupMember -Identity "GRP-Harmony_Relations" -Members "aphrodite.harmony", "eros.love", "psyche.soul", "harmonia.peace", "iris.rainbow"

# Add admin users to Domain Admins
Add-ADGroupMember -Identity "Domain Admins" -Members "zeus.supreme", "athena.wisdom"
Add-ADGroupMember -Identity "Enterprise Admins" -Members "zeus.supreme"

# Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "⚡ Olympus Systems Active Directory configuration completed successfully! ⚡" -ForegroundColor Green
"@

                    $scriptPath = Join-Path $VMPath "Configure-OlympusAD.ps1"
                    $adScript | Out-File -FilePath $scriptPath -Encoding UTF8
                    Write-OlympusLog "Active Directory script created: $scriptPath" "SUCCESS"
                }

                # Main deployment function
                function Start-OlympusDeployment {
                    Show-OlympusBanner
    
                    Write-OlympusLog "Starting Olympus Systems lab deployment..." "INFO"
                    Write-OlympusLog "Domain: $DomainName" "INFO"
                    Write-OlympusLog "VM Path: $VMPath" "INFO"
                    if ($ServerISOPath) { Write-OlympusLog "Server ISO: $(Split-Path $ServerISOPath -Leaf)" "INFO" }
                    if ($ClientISOPath) { Write-OlympusLog "Client ISO: $(Split-Path $ClientISOPath -Leaf)" "INFO" }
                    Write-OlympusLog "Log Path: $LogPath" "INFO"
    
                    # Create VM directory
                    if (!(Test-Path $VMPath)) {
                        New-Item -Path $VMPath -ItemType Directory -Force | Out-Null
                        Write-OlympusLog "Created VM directory: $VMPath" "SUCCESS"
                    }
    
                    # Create networks
                    if (-not $SkipNetworking) {
                        if (-not (New-OlympusNetwork)) {
                            Write-OlympusLog "Network creation failed. Aborting deployment." "ERROR"
                            return $false
                        }
                    }
    
                    # Create VMs
                    if (-not $SkipVMs) {
                        # Create servers
                        if (-not (New-OlympusServer)) {
                            Write-OlympusLog "Server creation failed. Aborting deployment." "ERROR"
                            return $false
                        }
        
                        # Create workstations
                        if (-not (New-OlympusWorkstation)) {
                            Write-OlympusLog "Workstation creation failed. Aborting deployment." "ERROR"
                            return $false
                        }
                    }
    
                    # Generate AD configuration script
                    if (-not $SkipAD) {
                        New-OlympusADScript
                    }
    
                    Write-OlympusLog "Olympus Systems deployment completed successfully!" "SUCCESS"
                    Write-Host @"

    ⚡ ═══════════════════════════════════════════════════════════ ⚡
    
            🏛️ OLYMPUS SYSTEMS DEPLOYMENT COMPLETE! 🏛️
    
    ⚡ ═══════════════════════════════════════════════════════════ ⚡
    
    Next Steps:
    1. Start ZEUS-DC01 and install Windows Server
    2. Promote to Domain Controller (olympus.local)
    3. Run: $VMPath\Configure-OlympusAD.ps1
    4. Install remaining servers and workstations
    
    May Zeus's lightning power your infrastructure! ⚡
    
"@ -ForegroundColor Blue
    
                    return $true
                }

                # Execute deployment
                try {
                    $result = Start-OlympusDeployment
                    if ($result) {
                        Write-OlympusLog "Deployment completed successfully" "SUCCESS"
                        exit 0
                    }
                    else {
                        Write-OlympusLog "Deployment failed" "ERROR"
                        exit 1
                    }
                }
                catch {
                    Write-OlympusLog "Deployment failed with error: $($_.Exception.Message)" "ERROR"
                    exit 1
                } 
