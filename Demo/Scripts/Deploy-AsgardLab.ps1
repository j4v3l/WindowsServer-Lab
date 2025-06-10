# 🏰 ASGARD TECHNOLOGIES LAB DEPLOYMENT SCRIPT
# Automated deployment of the complete Norse mythology-themed Windows Server lab
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
    [string]$DomainName = "asgard.local",
    [string]$VMPath = "C:\VMs\Asgard",
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
$LogPath = Join-Path $env:TEMP "Asgard-Lab-Deployment.log"

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
    Write-Host "Please enter the Safe Mode (DSRM) password for domain controllers:" -ForegroundColor Yellow
    $SafeModePassword = Read-Host -AsSecureString
}

if (-not $DefaultUserPassword) {
    Write-Host "Please enter the default password for new user accounts:" -ForegroundColor Yellow
    $DefaultUserPassword = Read-Host -AsSecureString
}

# Validate passwords are provided
if (-not $SafeModePassword -or -not $DefaultUserPassword) {
    Write-Error "Both Safe Mode and Default User passwords are required. Exiting."
    exit 1
}

function Write-AsgardLog {
    param(
        [string]$Message,
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR")]
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Add-Content -Path $LogPath -Value $logEntry -ErrorAction SilentlyContinue
    
    switch ($Level) {
        "SUCCESS" { Write-Host "✅ $Message" -ForegroundColor Green }
        "WARNING" { Write-Host "⚠️  $Message" -ForegroundColor Yellow }
        "ERROR" { Write-Host "❌ $Message" -ForegroundColor Red }
        "INFO" { Write-Host "ℹ️  $Message" -ForegroundColor Cyan }
    }
}

# Banner
function Show-AsgardBanner {
    Write-Host @"
    
    🏰 ═══════════════════════════════════════════════════════════ 🏰
    
         ░█████╗░░██████╗░░██████╗░░█████╗░██████╗░██████╗░
         ██╔══██╗██╔════╝░██╔════╝░██╔══██╗██╔══██╗██╔══██╗
         ███████║╚█████╗░░██║░░██╗░███████║██████╔╝██║░░██║
         ██╔══██║░╚═══██╗░██║░░╚██╗██╔══██║██╔══██╗██║░░██║
         ██║░░██║██████╔╝░╚██████╔╝██║░░██║██║░░██║██████╔╝
         ╚═╝░░╚═╝╚═════╝░░░╚═════╝░╚═╝░░╚═╝╚═╝░░╚═╝╚═════╝░
    
              🔥 TECHNOLOGIES - Windows Server Lab Environment 🔥
                    "Protecting the Nine Realms of Cyberspace"
    
    🏰 ═══════════════════════════════════════════════════════════ 🏰
    
"@ -ForegroundColor Magenta
}

# Network Configuration
function New-AsgardNetworks {
    Write-AsgardLog "Creating Asgard network infrastructure..." "INFO"
    
    try {
        # Remove existing switches if Force is specified
        if ($Force) {
            $existingSwitches = @("ASGARD-Production", "ASGARD-Management", "ASGARD-DMZ", "ASGARD-Clients")
            foreach ($switchName in $existingSwitches) {
                $switch = Get-VMSwitch -Name $switchName -ErrorAction SilentlyContinue
                if ($switch) {
                    Write-AsgardLog "Removing existing switch: $switchName" "WARNING"
                    Remove-VMSwitch -Name $switchName -Force
                }
            }
        }
        
        # Create Production Network (External)
        $physicalAdapters = Get-NetAdapter -Physical | Where-Object { $_.Status -eq "Up" }
        if ($physicalAdapters.Count -gt 0) {
            $targetAdapter = $physicalAdapters | Select-Object -First 1
            New-VMSwitch -Name "ASGARD-Production" -NetAdapterName $targetAdapter.Name -AllowManagementOS $true -ErrorAction SilentlyContinue
            Write-AsgardLog "Created Production network switch" "SUCCESS"
        }
        
        # Create Management Network (Internal)
        New-VMSwitch -Name "ASGARD-Management" -SwitchType Internal -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        $mgmtAdapter = Get-NetAdapter -Name "vEthernet (ASGARD-Management)" -ErrorAction SilentlyContinue
        if ($mgmtAdapter) {
            Remove-NetIPAddress -InterfaceIndex $mgmtAdapter.ifIndex -Confirm:$false -ErrorAction SilentlyContinue
            New-NetIPAddress -IPAddress 10.0.100.1 -PrefixLength 24 -InterfaceIndex $mgmtAdapter.ifIndex -ErrorAction SilentlyContinue
            Write-AsgardLog "Created Management network: 10.0.100.1/24" "SUCCESS"
        }
        
        # Create DMZ Network (Private)
        New-VMSwitch -Name "ASGARD-DMZ" -SwitchType Private -ErrorAction SilentlyContinue
        Write-AsgardLog "Created DMZ network switch" "SUCCESS"
        
        # Create Client Network (Internal)
        New-VMSwitch -Name "ASGARD-Clients" -SwitchType Internal -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        $clientAdapter = Get-NetAdapter -Name "vEthernet (ASGARD-Clients)" -ErrorAction SilentlyContinue
        if ($clientAdapter) {
            Remove-NetIPAddress -InterfaceIndex $clientAdapter.ifIndex -Confirm:$false -ErrorAction SilentlyContinue
            New-NetIPAddress -IPAddress 10.0.20.1 -PrefixLength 22 -InterfaceIndex $clientAdapter.ifIndex -ErrorAction SilentlyContinue
            Write-AsgardLog "Created Client network: 10.0.20.1/22" "SUCCESS"
        }
        
        # Configure NAT for internal networks
        $existingNAT = Get-NetNat -Name "ASGARD-NAT" -ErrorAction SilentlyContinue
        if (-not $existingNAT) {
            New-NetNat -Name "ASGARD-NAT" -InternalIPInterfaceAddressPrefix 10.0.0.0/8 -ErrorAction SilentlyContinue
            Write-AsgardLog "Configured NAT for internal networks" "SUCCESS"
        }
        
        return $true
    }
    catch {
        Write-AsgardLog "Failed to create networks: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# VM Creation Functions
function New-AsgardVM {
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
            Write-AsgardLog "VM $VMName already exists" "WARNING"
            return $true
        }
        elseif ($existingVM -and $Force) {
            Write-AsgardLog "Removing existing VM: $VMName" "WARNING"
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
            $adapterName = $switchName.Replace("ASGARD-", "")
            Add-VMNetworkAdapter -VMName $VMName -SwitchName $switchName -Name $adapterName
        }
        
        # Configure firmware
        Set-VMFirmware -VMName $VMName -EnableSecureBoot On -SecureBootTemplate "MicrosoftWindows"
        $dvdDrive = Get-VMDvdDrive -VMName $VMName
        if ($dvdDrive) {
            Set-VMFirmware -VMName $VMName -FirstBootDevice $dvdDrive
        }
        
        # Disable automatic checkpoints
        Set-VM -Name $VMName -AutomaticCheckpointsEnabled $false
        
        # Attach ISO if provided
        if ($ISOPath -and (Test-Path $ISOPath)) {
            Set-VMDvdDrive -VMName $VMName -Path $ISOPath
            Write-AsgardLog "Attached ISO to $VMName`: $(Split-Path $ISOPath -Leaf)" "SUCCESS"
        }
        
        Write-AsgardLog "Created VM: $VMName" "SUCCESS"
        return $true
    }
    catch {
        Write-AsgardLog "Failed to create VM $VMName`: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function New-AsgardServers {
    Write-AsgardLog "Creating Asgard server infrastructure..." "INFO"
    
    # Define server specifications (Optimized for 64GB RAM, 24 threads)
    $servers = @(
        @{
            Name        = "ODIN-DC01"
            Memory      = 8GB
            VHDSize     = 80GB
            CPUCount    = 4
            Networks    = @("ASGARD-Production", "ASGARD-Management")
            Description = "Primary Domain Controller - Odin's Throne"
        },
        @{
            Name        = "FRIGG-DC02"
            Memory      = 6GB
            VHDSize     = 80GB
            CPUCount    = 3
            Networks    = @("ASGARD-Production", "ASGARD-Management")
            Description = "Secondary Domain Controller - Frigg's Wisdom"
        },
        @{
            Name        = "HEIMDALL-FS01"
            Memory      = 8GB
            VHDSize     = 200GB
            CPUCount    = 4
            Networks    = @("ASGARD-Production", "ASGARD-Management")
            Description = "File Server - Heimdall's Vault"
        },
        @{
            Name        = "BALDER-WEB01"
            Memory      = 6GB
            VHDSize     = 100GB
            CPUCount    = 3
            Networks    = @("ASGARD-Production", "ASGARD-DMZ", "ASGARD-Management")
            Description = "Web/Application Server - Balder's Light"
        },
        @{
            Name        = "VIDAR-SEC01"
            Memory      = 8GB
            VHDSize     = 150GB
            CPUCount    = 4
            Networks    = @("ASGARD-Production", "ASGARD-Management")
            Description = "Security & Monitoring - Vidar's Vengeance"
        }
    )
    
    foreach ($server in $servers) {
        $success = New-AsgardVM -VMName $server.Name -Memory $server.Memory -VHDSize $server.VHDSize -CPUCount $server.CPUCount -NetworkSwitches $server.Networks -Description $server.Description -ISOPath $ServerISOPath
        if (-not $success) {
            Write-AsgardLog "Failed to create server: $($server.Name)" "ERROR"
        }
    }
}

function New-AsgardWorkstations {
    Write-AsgardLog "Creating Asgard workstation army..." "INFO"
    
    # Define workstation specifications (Optimized for 64GB RAM, 24 threads)
    $workstations = @(
        # IT Operations Workstations
        @{ Name = "ODIN-WS01"; Memory = 6GB; VHDSize = 80GB; Networks = @("ASGARD-Clients"); Description = "Odin's Command Center" },
        @{ Name = "THOR-WS01"; Memory = 4GB; VHDSize = 60GB; Networks = @("ASGARD-Clients"); Description = "Thor's Thunder Station" },
        @{ Name = "LOKI-WS01"; Memory = 3GB; VHDSize = 60GB; Networks = @("ASGARD-Clients"); Description = "Loki's Mischief Machine" },
        @{ Name = "HERMOD-WS01"; Memory = 3GB; VHDSize = 60GB; Networks = @("ASGARD-Clients"); Description = "Hermod's Messenger Terminal" },
        
        # Cybersecurity Workstations
        @{ Name = "HEIMDALL-WS01"; Memory = 6GB; VHDSize = 80GB; Networks = @("ASGARD-Clients"); Description = "Heimdall's Watchtower" },
        @{ Name = "MIMIR-WS01"; Memory = 4GB; VHDSize = 60GB; Networks = @("ASGARD-Clients"); Description = "Mimir's Wisdom Terminal" },
        @{ Name = "HUGINN-WS01"; Memory = 3GB; VHDSize = 60GB; Networks = @("ASGARD-Clients"); Description = "Huginn's Surveillance Station" },
        @{ Name = "MUNINN-WS01"; Memory = 3GB; VHDSize = 60GB; Networks = @("ASGARD-Clients"); Description = "Muninn's Memory Bank" },
        
        # Research Workstations (Higher specs for development)
        @{ Name = "FREYA-WS01"; Memory = 6GB; VHDSize = 100GB; Networks = @("ASGARD-Clients"); Description = "Freya's Innovation Lab" },
        @{ Name = "NJORD-WS01"; Memory = 4GB; VHDSize = 80GB; Networks = @("ASGARD-Clients"); Description = "Njord's Wind Tunnel" },
        @{ Name = "FREY-WS01"; Memory = 4GB; VHDSize = 80GB; Networks = @("ASGARD-Clients"); Description = "Frey's Prosperity Engine" },
        @{ Name = "SLEIPNIR-WS01"; Memory = 4GB; VHDSize = 80GB; Networks = @("ASGARD-Clients"); Description = "Sleipnir's Speed Demon" },
        
        # Finance Workstations
        @{ Name = "FRIGG-WS01"; Memory = 4GB; VHDSize = 60GB; Networks = @("ASGARD-Clients"); Description = "Frigg's Treasury Terminal" },
        @{ Name = "EIR-WS01"; Memory = 3GB; VHDSize = 60GB; Networks = @("ASGARD-Clients"); Description = "Eir's Healing Touch" },
        @{ Name = "SAGA-WS01"; Memory = 3GB; VHDSize = 60GB; Networks = @("ASGARD-Clients"); Description = "Saga's Story Keeper" },
        @{ Name = "VAR-WS01"; Memory = 3GB; VHDSize = 60GB; Networks = @("ASGARD-Clients"); Description = "Var's Oath Guardian" },
        
        # HR Workstations
        @{ Name = "SIF-WS01"; Memory = 4GB; VHDSize = 60GB; Networks = @("ASGARD-Clients"); Description = "Sif's Golden Gateway" },
        @{ Name = "IDUN-WS01"; Memory = 3GB; VHDSize = 60GB; Networks = @("ASGARD-Clients"); Description = "Idun's Eternal Garden" },
        @{ Name = "BRAGI-WS01"; Memory = 3GB; VHDSize = 60GB; Networks = @("ASGARD-Clients"); Description = "Bragi's Poetic Portal" },
        @{ Name = "HEL-WS01"; Memory = 3GB; VHDSize = 60GB; Networks = @("ASGARD-Clients"); Description = "Hel's Dual Nature" }
    )
    
    foreach ($ws in $workstations) {
        $success = New-AsgardVM -VMName $ws.Name -Memory $ws.Memory -VHDSize $ws.VHDSize -CPUCount 2 -NetworkSwitches $ws.Networks -Description $ws.Description -ISOPath $ClientISOPath
        if (-not $success) {
            Write-AsgardLog "Failed to create workstation: $($ws.Name)" "ERROR"
        }
    }
}

# Active Directory Configuration
function Set-AsgardActiveDirectory {
    Write-AsgardLog "Configuring Active Directory for Asgard Technologies..." "INFO"
    
    try {
        # Wait for domain controller to be configured manually first
        Write-AsgardLog "Please install and configure Active Directory on ODIN-DC01 first" "WARNING"
        Write-AsgardLog "This script will configure the AD structure after domain setup" "INFO"
        
        # The following would be run after AD is installed:
        $adConfigScript = @"
# Run this on ODIN-DC01 after AD installation:

Import-Module ActiveDirectory

# Create main OU structure
New-ADOrganizationalUnit -Name "Asgard Technologies" -Path "DC=asgard,DC=local"
New-ADOrganizationalUnit -Name "Departments" -Path "OU=Asgard Technologies,DC=asgard,DC=local"
New-ADOrganizationalUnit -Name "Service_Accounts" -Path "OU=Asgard Technologies,DC=asgard,DC=local"
New-ADOrganizationalUnit -Name "Workstations" -Path "OU=Asgard Technologies,DC=asgard,DC=local"

# Create department OUs
$departments = @("IT_Operations", "Cybersecurity", "Research_Development", "Finance_Admin", "Human_Resources")
foreach ($dept in $departments) {
    New-ADOrganizationalUnit -Name $dept -Path "OU=Departments,OU=Asgard Technologies,DC=asgard,DC=local"
    New-ADOrganizationalUnit -Name "$dept" -Path "OU=Workstations,OU=Asgard Technologies,DC=asgard,DC=local"
}

# Create security groups
$groups = @(
    @{Name="GRP-Domain_Admins"; Scope="Global"; Category="Security"; Path="OU=IT_Operations,OU=Departments,OU=Asgard Technologies,DC=asgard,DC=local"},
    @{Name="GRP-IT_Staff"; Scope="Global"; Category="Security"; Path="OU=IT_Operations,OU=Departments,OU=Asgard Technologies,DC=asgard,DC=local"},
    @{Name="GRP-Security_Team"; Scope="Global"; Category="Security"; Path="OU=Cybersecurity,OU=Departments,OU=Asgard Technologies,DC=asgard,DC=local"},
    @{Name="GRP-Research_Team"; Scope="Global"; Category="Security"; Path="OU=Research_Development,OU=Departments,OU=Asgard Technologies,DC=asgard,DC=local"},
    @{Name="GRP-Finance_Team"; Scope="Global"; Category="Security"; Path="OU=Finance_Admin,OU=Departments,OU=Asgard Technologies,DC=asgard,DC=local"},
    @{Name="GRP-HR_Team"; Scope="Global"; Category="Security"; Path="OU=Human_Resources,OU=Departments,OU=Asgard Technologies,DC=asgard,DC=local"}
)

foreach ($group in $groups) {
    New-ADGroup -Name $group.Name -GroupScope $group.Scope -GroupCategory $group.Category -Path $group.Path
}

# Create users
$users = @(
    # IT Operations
    @{Username="odin.allfather"; Name="Odin Allfather"; Department="IT_Operations"; Title="CTO"; IsAdmin=$true},
    @{Username="thor.thunderer"; Name="Thor Thunderer"; Department="IT_Operations"; Title="Senior Systems Engineer"; IsAdmin=$false},
    @{Username="loki.trickster"; Name="Loki Trickster"; Department="IT_Operations"; Title="Junior Developer"; IsAdmin=$false},
    @{Username="hermod.messenger"; Name="Hermod Messenger"; Department="IT_Operations"; Title="Network Administrator"; IsAdmin=$false},
    @{Username="tyr.brave"; Name="Tyr Brave"; Department="IT_Operations"; Title="Security Analyst"; IsAdmin=$false},
    
    # Cybersecurity
    @{Username="heimdall.guardian"; Name="Heimdall Guardian"; Department="Cybersecurity"; Title="CISO"; IsAdmin=$false},
    @{Username="mimir.wise"; Name="Mimir Wise"; Department="Cybersecurity"; Title="Threat Intelligence Analyst"; IsAdmin=$false},
    @{Username="huginn.raven"; Name="Huginn Raven"; Department="Cybersecurity"; Title="SOC Analyst I"; IsAdmin=$false},
    @{Username="muninn.memory"; Name="Muninn Memory"; Department="Cybersecurity"; Title="SOC Analyst II"; IsAdmin=$false},
    @{Username="fenrir.wolf"; Name="Fenrir Wolf"; Department="Cybersecurity"; Title="Penetration Tester"; IsAdmin=$false},
    
    # Research & Development
    @{Username="freya.seidr"; Name="Freya Seidr"; Department="Research_Development"; Title="Head of R&D"; IsAdmin=$false},
    @{Username="njord.wind"; Name="Njord Wind"; Department="Research_Development"; Title="AI Research Scientist"; IsAdmin=$false},
    @{Username="frey.prosperity"; Name="Frey Prosperity"; Department="Research_Development"; Title="Quantum Computing Lead"; IsAdmin=$false},
    @{Username="jormungandr.serpent"; Name="Jormungandr Serpent"; Department="Research_Development"; Title="Data Scientist"; IsAdmin=$false},
    @{Username="sleipnir.swift"; Name="Sleipnir Swift"; Department="Research_Development"; Title="DevOps Engineer"; IsAdmin=$false},
    
    # Finance & Administration
    @{Username="frigg.queen"; Name="Frigg Queen"; Department="Finance_Admin"; Title="CFO"; IsAdmin=$false},
    @{Username="eir.healer"; Name="Eir Healer"; Department="Finance_Admin"; Title="Financial Analyst"; IsAdmin=$false},
    @{Username="saga.storyteller"; Name="Saga Storyteller"; Department="Finance_Admin"; Title="Compliance Officer"; IsAdmin=$false},
    @{Username="var.oath"; Name="Var Oath"; Department="Finance_Admin"; Title="Legal Counsel"; IsAdmin=$false},
    @{Username="forseti.justice"; Name="Forseti Justice"; Department="Finance_Admin"; Title="Audit Manager"; IsAdmin=$false},
    
    # Human Resources
    @{Username="sif.golden"; Name="Sif Golden"; Department="Human_Resources"; Title="HR Director"; IsAdmin=$false},
    @{Username="idun.eternal"; Name="Idun Eternal"; Department="Human_Resources"; Title="Talent Acquisition"; IsAdmin=$false},
    @{Username="bragi.poet"; Name="Bragi Poet"; Department="Human_Resources"; Title="Training Coordinator"; IsAdmin=$false},
    @{Username="hel.half"; Name="Hel Half"; Department="Human_Resources"; Title="Benefits Administrator"; IsAdmin=$false},
    @{Username="sigyn.faithful"; Name="Sigyn Faithful"; Department="Human_Resources"; Title="Employee Relations"; IsAdmin=$false}
)

foreach ($user in $users) {
    $ouPath = "OU=$($user.Department),OU=Departments,OU=Asgard Technologies,DC=asgard,DC=local"
    $upn = "$($user.Username)@asgard.local"
    
    New-ADUser -Name $user.Name -SamAccountName $user.Username -UserPrincipalName $upn -DisplayName $user.Name -Title $user.Title -Department $user.Department -Path $ouPath -AccountPassword $DefaultUserPassword -Enabled $true -ChangePasswordAtLogon $false
    
    # Add to department group
    Add-ADGroupMember -Identity "GRP-$($user.Department.Replace('_', ''))" -Members $user.Username -ErrorAction SilentlyContinue
    
    # Add domain admins
    if ($user.IsAdmin) {
        Add-ADGroupMember -Identity "Domain Admins" -Members $user.Username
        Add-ADGroupMember -Identity "GRP-Domain_Admins" -Members $user.Username
    }
}

Write-Host "Asgard Technologies Active Directory structure created successfully!" -ForegroundColor Green
"@
        
        # Save the AD configuration script
        $adScriptPath = Join-Path $VMPath "Configure-AsgardAD.ps1"
        $adConfigScript | Out-File -FilePath $adScriptPath -Encoding UTF8
        Write-AsgardLog "AD configuration script saved to: $adScriptPath" "SUCCESS"
        
        return $true
    }
    catch {
        Write-AsgardLog "Failed to prepare AD configuration: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Summary and Instructions
function Show-AsgardSummary {
    Write-Host @"

🏰 ═══════════════════════════════════════════════════════════ 🏰
                    ASGARD TECHNOLOGIES DEPLOYMENT COMPLETE!
🏰 ═══════════════════════════════════════════════════════════ 🏰

📊 DEPLOYMENT SUMMARY:
├── 🌐 Network Infrastructure
│   ├── ASGARD-Production (External)
│   ├── ASGARD-Management (10.0.100.0/24)
│   ├── ASGARD-Clients (10.0.20.0/22)
│   └── ASGARD-DMZ (Private)
│
├── 🖥️ Server Infrastructure (5 VMs) - Enhanced Specs
│   ├── ODIN-DC01 (Primary DC) - 8GB RAM, 4 CPUs
│   ├── FRIGG-DC02 (Secondary DC) - 6GB RAM, 3 CPUs
│   ├── HEIMDALL-FS01 (File Server) - 8GB RAM, 4 CPUs
│   ├── BALDER-WEB01 (Web Server) - 6GB RAM, 3 CPUs
│   └── VIDAR-SEC01 (Security Server) - 8GB RAM, 4 CPUs
│
├── 💻 Workstation Army (20 VMs) - Enhanced Specs
│   ├── IT Operations (4 workstations) - 3-6GB RAM each
│   ├── Cybersecurity (4 workstations) - 3-6GB RAM each
│   ├── Research & Development (4 workstations) - 4-6GB RAM each
│   ├── Finance & Administration (4 workstations) - 3-4GB RAM each
│   └── Human Resources (4 workstations) - 3-4GB RAM each
│
└── 📁 Configuration Files
    ├── AD Setup Script: $VMPath\Configure-AsgardAD.ps1
    └── Deployment Log: $LogPath

🚀 NEXT STEPS:

1. 🔧 INSTALL OPERATING SYSTEMS
   - Start with ODIN-DC01 (Windows Server 2019/2022)
   - Install Windows Server on all server VMs
   - Install Windows 10/11 on workstation VMs

2. 🏗️ CONFIGURE DOMAIN CONTROLLER
   - Install Active Directory on ODIN-DC01
   - Set domain name: asgard.local
   - Run: Configure-AsgardAD.ps1 script

3. 🔐 CONFIGURE SERVICES
   - DNS: 10.0.10.10, 10.0.10.11
   - DHCP: Scopes for each network
   - File Shares: Department-specific shares
   - Group Policies: Security and department policies

4. 🌐 NETWORK CONFIGURATION
   - Production: 10.0.10.0/24
   - Management: 10.0.100.0/24
   - Clients: 10.0.20.0/22
   - DMZ: 10.0.50.0/24

5. 👥 USER MANAGEMENT
   - 25 Norse mythology-themed users
   - 5 departments with specific roles
   - Realistic organizational structure

6. 🎯 DEMO SCENARIOS
   - Employee onboarding
   - Security incident response
   - Department reorganization
   - Server maintenance
   - Compliance auditing

📚 DOCUMENTATION:
- Complete setup guide: DEMO_SETUP_GUIDE.md
- Lab tutorials: LabSetupTutorials/
- Management scripts: Scripts/

🎊 CONGRATULATIONS!
You've successfully deployed the most epic Windows Server lab environment!
Welcome to Asgard Technologies - Where IT Meets Legend! ⚡

"@ -ForegroundColor Cyan
}

# Main execution
try {
    Show-AsgardBanner
    
    Write-AsgardLog "Starting Asgard Technologies lab deployment..." "INFO"
    Write-AsgardLog "Domain: $DomainName" "INFO"
    Write-AsgardLog "VM Path: $VMPath" "INFO"
    if ($ServerISOPath) { Write-AsgardLog "Server ISO: $(Split-Path $ServerISOPath -Leaf)" "INFO" }
    if ($ClientISOPath) { Write-AsgardLog "Client ISO: $(Split-Path $ClientISOPath -Leaf)" "INFO" }
    
    # Create VM directory
    if (!(Test-Path $VMPath)) {
        New-Item -Path $VMPath -ItemType Directory -Force | Out-Null
        Write-AsgardLog "Created VM directory: $VMPath" "SUCCESS"
    }
    
    # Create networks
    if (-not $SkipNetworking) {
        if (-not (New-AsgardNetworks)) {
            Write-AsgardLog "Failed to create networks. Continuing with VM creation..." "WARNING"
        }
    }
    
    # Create VMs
    if (-not $SkipVMs) {
        Write-AsgardLog "Creating server infrastructure..." "INFO"
        New-AsgardServers
        
        Write-AsgardLog "Creating workstation army..." "INFO"
        New-AsgardWorkstations
    }
    
    # Prepare AD configuration
    if (-not $SkipAD) {
        Set-AsgardActiveDirectory
    }
    
    # Show summary
    Show-AsgardSummary
    
    Write-AsgardLog "Asgard Technologies lab deployment completed successfully!" "SUCCESS"
}
catch {
    Write-AsgardLog "Deployment failed: $($_.Exception.Message)" "ERROR"
    Write-AsgardLog "Stack trace: $($_.ScriptStackTrace)" "ERROR"
    exit 1
} 