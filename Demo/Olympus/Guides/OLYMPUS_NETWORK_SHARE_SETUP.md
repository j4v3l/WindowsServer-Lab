# 🏛️ Olympus Systems Network Share Setup Guide

## 🎯 Overview

This guide provides step-by-step instructions for setting up network shares in the **Olympus Systems** Windows Server lab environment. Follow these Greek mythology-themed instructions to configure divine file sharing services for your corporate domain.

---

## 📋 Prerequisites

- **HERMES-FS01** file server deployed and domain-joined
- **olympus.local** Active Directory domain configured
- Administrative privileges on the file server
- Network connectivity between servers and clients

---

## 🔧 **Method 1: GUI-Based Network Share Setup**

### **Step 1: Install File Server Role on HERMES-FS01**

1. **Connect to HERMES-FS01** via RDP or console
2. **Open Server Manager**
3. **Click "Add roles and features"**
4. **Select "Role-based or feature-based installation"**
5. **Choose HERMES-FS01**
6. **Expand "File and Storage Services"**
7. **Check "File Server"**
8. **Check "DFS Namespaces"** (for advanced divine features)
9. **Complete the installation wizard**

### **Step 2: Create Olympus Divine Directories**

1. **Open File Explorer** on HERMES-FS01
2. **Navigate to C:\ drive**
3. **Create main folder**: `C:\Olympus-Shares`
4. **Create divine department subfolders**:
   ```
   C:\Olympus-Shares\Divine_Council
   C:\Olympus-Shares\War_Strategists
   C:\Olympus-Shares\Innovation_Forge
   C:\Olympus-Shares\Abundance_Treasury
   C:\Olympus-Shares\Harmony_Relations
   C:\Olympus-Shares\Divine_Archives
   C:\Olympus-Shares\Sacred_Software
   C:\Olympus-Shares\AI_ML_Projects
   ```

### **Step 3: Configure NTFS Permissions for Divine Departments**

For each divine department folder:

1. **Right-click the folder** → **Properties**
2. **Go to "Security" tab**
3. **Click "Edit"**
4. **Click "Add"**
5. **Enter the Olympus group** (e.g., `OLYMPUS\GRP-Divine_Council`)
6. **Set permissions**:
   - **Full Control**: For divine department groups
   - **Read**: For Domain Users (if needed)
7. **Click "OK"**

### **Step 4: Create Olympus Divine Network Shares**

1. **Right-click each department folder**
2. **Select "Properties"**
3. **Go to "Sharing" tab**
4. **Click "Advanced Sharing"**
5. **Check "Share this folder"**
6. **Set divine-themed share names**:
   - Divine_Council → `Zeus-Command`
   - War_Strategists → `Ares-Strategy`
   - Innovation_Forge → `Hephaestus-Innovation`
   - Abundance_Treasury → `Demeter-Treasury`
   - Harmony_Relations → `Aphrodite-Relations`
7. **Click "Permissions"**
8. **Configure share permissions**:
   - **Remove "Everyone"** (divine security practice)
   - **Add department group** with "Full Control"
9. **Click "OK" twice**

---

## 💻 **Method 2: PowerShell-Based Olympus Share Setup**

### **Step 1: Create Olympus Divine Directory Structure**

```powershell
# Connect to HERMES-FS01 and run as Administrator

# Create main Olympus shares directory
New-Item -Path "C:\Olympus-Shares" -ItemType Directory -Force

# Create divine department directories
$olympusDepartments = @(
    "Divine_Council",
    "War_Strategists",
    "Innovation_Forge",
    "Abundance_Treasury",
    "Harmony_Relations",
    "Divine_Archives",
    "Sacred_Software",
    "AI_ML_Projects"
)

foreach ($dept in $olympusDepartments) {
    New-Item -Path "C:\Olympus-Shares\$dept" -ItemType Directory -Force
    Write-Host "Created divine directory: C:\Olympus-Shares\$dept" -ForegroundColor Gold
}
```

### **Step 2: Set NTFS Permissions for Divine Groups**

```powershell
# Function to set divine NTFS permissions
function Set-OlympusNTFSPermissions {
    param(
        [string]$Path,
        [string]$Group,
        [string]$Permission = "FullControl"
    )

    $acl = Get-Acl $Path
    $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($Group, $Permission, "ContainerInherit,ObjectInherit", "None", "Allow")
    $acl.SetAccessRule($accessRule)
    Set-Acl $Path $acl
    Write-Host "Granted divine $Permission to $Group on $Path" -ForegroundColor Gold
}

# Apply permissions for each divine department
$olympusPermissions = @(
    @{Name = "Divine_Council"; Group = "OLYMPUS\GRP-Divine_Council"},
    @{Name = "War_Strategists"; Group = "OLYMPUS\GRP-War_Strategists"},
    @{Name = "Innovation_Forge"; Group = "OLYMPUS\GRP-Innovation_Forge"},
    @{Name = "Abundance_Treasury"; Group = "OLYMPUS\GRP-Abundance_Treasury"},
    @{Name = "Harmony_Relations"; Group = "OLYMPUS\GRP-Harmony_Relations"}
)

foreach ($dept in $olympusPermissions) {
    $path = "C:\Olympus-Shares\$($dept.Name)"
    Set-OlympusNTFSPermissions -Path $path -Group $dept.Group -Permission "FullControl"
}
```

### **Step 3: Create Divine SMB Shares with Greek Names**

```powershell
# Create divine department shares with Greek mythology theme
$olympusShares = @(
    @{Name = "Zeus-Command"; Path = "C:\Olympus-Shares\Divine_Council"; Group = "OLYMPUS\GRP-Divine_Council"; Description = "Divine Council - Zeus's Command Center"},
    @{Name = "Ares-Strategy"; Path = "C:\Olympus-Shares\War_Strategists"; Group = "OLYMPUS\GRP-War_Strategists"; Description = "War Strategies - Ares's Battle Plans"},
    @{Name = "Hephaestus-Innovation"; Path = "C:\Olympus-Shares\Innovation_Forge"; Group = "OLYMPUS\GRP-Innovation_Forge"; Description = "Innovation Forge - Hephaestus's Workshop"},
    @{Name = "Demeter-Treasury"; Path = "C:\Olympus-Shares\Abundance_Treasury"; Group = "OLYMPUS\GRP-Abundance_Treasury"; Description = "Abundance Treasury - Demeter's Wealth"},
    @{Name = "Aphrodite-Relations"; Path = "C:\Olympus-Shares\Harmony_Relations"; Group = "OLYMPUS\GRP-Harmony_Relations"; Description = "Harmony Relations - Aphrodite's Diplomacy"}
)

foreach ($share in $olympusShares) {
    try {
        New-SmbShare -Name $share.Name `
                     -Path $share.Path `
                     -FullAccess $share.Group `
                     -Description $share.Description `
                     -FolderEnumerationMode AccessBased

        Write-Host "Created divine share: $($share.Name) at $($share.Path)" -ForegroundColor Gold
    }
    catch {
        Write-Warning "Failed to create divine share $($share.Name) : $($_.Exception.Message)"
    }
}
```

### **Step 4: Create Public Divine Shares**

```powershell
# Create public share for all citizens of Olympus
New-SmbShare -Name "Olympus-Archives" `
             -Path "C:\Olympus-Shares\Divine_Archives" `
             -ReadAccess "OLYMPUS\Domain Users" `
             -Description "Divine Archives - Knowledge for all citizens of Olympus"

# Create sacred software repository
New-SmbShare -Name "Apollo-Software" `
             -Path "C:\Olympus-Shares\Sacred_Software" `
             -ReadAccess "OLYMPUS\Domain Users" `
             -ChangeAccess "OLYMPUS\GRP-Divine_Council" `
             -Description "Sacred Software - Apollo's digital enlightenment"

# Create AI/ML projects share for innovation
New-SmbShare -Name "Athena-AI" `
             -Path "C:\Olympus-Shares\AI_ML_Projects" `
             -FullAccess "OLYMPUS\GRP-Innovation_Forge" `
             -ReadAccess "OLYMPUS\GRP-Divine_Council" `
             -Description "AI & ML Projects - Athena's wisdom algorithms"

Write-Host "Created divine public and specialized shares" -ForegroundColor Gold
```

---

## 🏛️ **Method 3: Advanced Olympus Configuration with DFS**

### **Step 1: Set Up Olympus DFS Namespace**

```powershell
# Install DFS features on HERMES-FS01
Install-WindowsFeature -Name FS-DFS-Namespace, FS-DFS-Replication -IncludeManagementTools

# Create Olympus DFS namespace
New-DfsnRoot -TargetPath "\\HERMES-FS01\OlympusDFS" -Type DomainV2 -Path "\\olympus.local\divine"

# Add DFS folders with divine names
$dfsLinks = @(
    @{DFSPath = "\\olympus.local\divine\zeus"; SharePath = "\\HERMES-FS01\Zeus-Command"},
    @{DFSPath = "\\olympus.local\divine\ares"; SharePath = "\\HERMES-FS01\Ares-Strategy"},
    @{DFSPath = "\\olympus.local\divine\hephaestus"; SharePath = "\\HERMES-FS01\Hephaestus-Innovation"},
    @{DFSPath = "\\olympus.local\divine\demeter"; SharePath = "\\HERMES-FS01\Demeter-Treasury"},
    @{DFSPath = "\\olympus.local\divine\aphrodite"; SharePath = "\\HERMES-FS01\Aphrodite-Relations"},
    @{DFSPath = "\\olympus.local\divine\apollo"; SharePath = "\\HERMES-FS01\Apollo-Software"},
    @{DFSPath = "\\olympus.local\divine\athena"; SharePath = "\\HERMES-FS01\Athena-AI"}
)

foreach ($link in $dfsLinks) {
    New-DfsnFolder -Path $link.DFSPath -TargetPath $link.SharePath
    Write-Host "Created divine DFS link: $($link.DFSPath) -> $($link.SharePath)" -ForegroundColor Gold
}
```

### **Step 2: Configure Divine Share Caching**

```powershell
# Configure offline files caching for optimal divine performance
Set-SmbShare -Name "Zeus-Command" -CachingMode None  # Command center - always live
Set-SmbShare -Name "Ares-Strategy" -CachingMode None  # Strategy - real-time access
Set-SmbShare -Name "Hephaestus-Innovation" -CachingMode Documents  # Innovation files
Set-SmbShare -Name "Demeter-Treasury" -CachingMode None  # Financial data - no cache
Set-SmbShare -Name "Aphrodite-Relations" -CachingMode Manual  # Relations documents
Set-SmbShare -Name "Olympus-Archives" -CachingMode Manual  # Public archives
Set-SmbShare -Name "Apollo-Software" -CachingMode Programs  # Software repository
Set-SmbShare -Name "Athena-AI" -CachingMode BranchCache  # AI/ML projects
```

---

## 🧪 **Testing Olympus Divine Network Shares**

### **Step 1: Verify Shares from HERMES-FS01**

```powershell
# List all divine SMB shares
Get-SmbShare | Where-Object {$_.Name -like "*Zeus*" -or $_.Name -like "*Ares*" -or $_.Name -like "*Hephaestus*" -or $_.Name -like "*Olympus*" -or $_.Name -like "*Apollo*" -or $_.Name -like "*Athena*"}

# Check specific divine share permissions
Get-SmbShareAccess -Name "Zeus-Command"
Get-SmbShareAccess -Name "Ares-Strategy"
Get-SmbShareAccess -Name "Athena-AI"

# Test local divine connectivity
Test-Path "\\localhost\Zeus-Command"
Test-Path "\\localhost\Hephaestus-Innovation"
```

### **Step 2: Test from Olympus Divine Workstations**

```powershell
# Test from any Olympus workstation
# Test network connectivity to HERMES-FS01
Test-NetConnection -ComputerName "HERMES-FS01" -Port 445
Test-NetConnection -ComputerName "hermes-fs01.olympus.local" -Port 445

# Test divine share access
Test-Path "\\HERMES-FS01\Zeus-Command"
Test-Path "\\HERMES-FS01\Ares-Strategy"
Test-Path "\\HERMES-FS01\Olympus-Archives"
Test-Path "\\HERMES-FS01\Athena-AI"

# Test divine DFS namespace access
Test-Path "\\olympus.local\divine\zeus"
Test-Path "\\olympus.local\divine\athena"
```

### **Step 3: Divine User Access Testing**

```powershell
# Test as different divine users
# From Divine Council workstation as Zeus Skyfather
net use Z: \\HERMES-FS01\Zeus-Command

# From War Strategy workstation as Ares Warlord
net use A: \\HERMES-FS01\Ares-Strategy

# From Innovation workstation as Hephaestus Creator
net use H: \\HERMES-FS01\Hephaestus-Innovation

# From AI workstation as Athena Wisdom
net use T: \\HERMES-FS01\Athena-AI
```

---

## 🛡️ **Olympus Divine Security Configuration**

### **Step 1: Enable SMB Security for Olympus Domain**

```powershell
# Run on HERMES-FS01 and all Olympus domain controllers
# Enable divine SMB signing for enhanced security
Set-SmbServerConfiguration -RequireSecuritySignature $true -Force
Set-SmbClientConfiguration -RequireSecuritySignature $true -Force

# Disable SMB v1 (ancient protocol - security vulnerability)
Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart

Write-Host "Olympus divine SMB security hardening completed" -ForegroundColor Gold
```

### **Step 2: Configure Divine File Access Auditing**

```powershell
# Enable comprehensive auditing for divine shares
auditpol /set /subcategory:"File Share" /success:enable /failure:enable
auditpol /set /subcategory:"File System" /success:enable /failure:enable
auditpol /set /subcategory:"Handle Manipulation" /success:enable /failure:enable

# Configure specific auditing for sensitive divine shares
$sensitiveShares = @("Zeus-Command", "Ares-Strategy", "Demeter-Treasury")
foreach ($share in $sensitiveShares) {
    $sharePath = (Get-SmbShare -Name $share).Path
    # Configure SACL for divine auditing
    icacls $sharePath /setintegritylevel H
    Write-Host "Enhanced auditing enabled for divine share: $share" -ForegroundColor Gold
}
```

### **Step 3: Implement Divine Access Controls**

```powershell
# Create divine security groups for enhanced access control
$divineSecurityGroups = @(
    "GRP-Divine_Administrators",
    "GRP-Sacred_Auditors",
    "GRP-AI_Researchers"
)

foreach ($group in $divineSecurityGroups) {
    try {
        New-ADGroup -Name $group -GroupScope Global -GroupCategory Security -Path "OU=Divine Security,DC=olympus,DC=local"
        Write-Host "Created divine security group: $group" -ForegroundColor Gold
    }
    catch {
        Write-Warning "Divine group $group may already exist: $($_.Exception.Message)"
    }
}
```

---

## 🛠️ **Troubleshooting Olympus Divine Shares**

### **Issue 1: Cannot Access Divine-Named Shares**

**Symptoms**: "Network path not found" for Olympus divine shares

**Solutions**:

1. **Check HERMES-FS01 connectivity**: `ping HERMES-FS01`
2. **Verify divine DNS resolution**: `nslookup hermes-fs01.olympus.local`
3. **Test SMB port**: `Test-NetConnection -ComputerName HERMES-FS01 -Port 445`
4. **Check divine share names**: `Get-SmbShare | Where-Object {$_.Name -like "*Zeus*" -or $_.Name -like "*Ares*"}`

### **Issue 2: Divine Group Access Denied**

**Symptoms**: "Access is denied" for divine users

**Solutions**:

1. **Verify user is in correct divine group**: `Get-ADUser username -Properties MemberOf`
2. **Check divine group membership**: `net user username /domain`
3. **Verify divine share permissions**: `Get-SmbShareAccess -Name "Zeus-Command"`
4. **Test with domain admin**: Confirm share works with Administrator

### **Issue 3: DFS Divine Namespace Issues**

**Symptoms**: Cannot access `\\olympus.local\divine` paths

**Solutions**:

1. **Check DFS service**: `Get-Service -Name "DFS*"`
2. **Verify divine DFS configuration**: `Get-DfsnRoot`
3. **Test divine DFS links**: `Get-DfsnFolder -Path "\\olympus.local\divine\*"`

### **Issue 4: AI/ML Share Performance Issues**

**Symptoms**: Slow access to Athena-AI share with large datasets

**Solutions**:

1. **Enable SMB Multichannel**: `Set-SmbServerConfiguration -EnableMultiChannel $true`
2. **Configure large file optimization**: `Set-SmbShare -Name "Athena-AI" -CachingMode BranchCache`
3. **Check network bandwidth**: Monitor network utilization during transfers

---

## 📊 **Olympus Divine Share Monitoring**

### **PowerShell Divine Monitoring Script**

```powershell
# Olympus-DivineShareMonitor.ps1
function Get-OlympusDivineShareStatus {
    Write-Host "=== OLYMPUS SYSTEMS DIVINE SHARE STATUS ===" -ForegroundColor Cyan
    Write-Host "🏛️ By the power of Zeus, monitoring divine shares..." -ForegroundColor Gold

    # Check HERMES-FS01 divine connectivity
    $fsServer = "HERMES-FS01"
    $connectivity = Test-NetConnection -ComputerName $fsServer -Port 445 -WarningAction SilentlyContinue

    if ($connectivity.TcpTestSucceeded) {
        Write-Host "✅ HERMES-FS01 divine messenger is accessible" -ForegroundColor Green

        # List divine shares
        $divineShares = Get-SmbShare | Where-Object {
            $_.Name -like "*Zeus*" -or $_.Name -like "*Ares*" -or $_.Name -like "*Hephaestus*" -or
            $_.Name -like "*Demeter*" -or $_.Name -like "*Aphrodite*" -or $_.Name -like "*Apollo*" -or
            $_.Name -like "*Athena*" -or $_.Name -like "*Olympus*"
        }

        Write-Host "`n🏛️ Active Divine Shares:" -ForegroundColor Yellow
        $divineShares | Format-Table Name, Path, Description -AutoSize

        # Check divine DFS namespace
        try {
            $dfsRoots = Get-DfsnRoot -ErrorAction SilentlyContinue | Where-Object {$_.Path -like "*divine*"}
            if ($dfsRoots) {
                Write-Host "🌟 Divine DFS Namespace Status:" -ForegroundColor Yellow
                $dfsRoots | Format-Table Path, State -AutoSize
            }
        }
        catch {
            Write-Host "⚠️ Divine DFS not configured or accessible" -ForegroundColor Yellow
        }

        # Check AI/ML share special status
        try {
            $aiShare = Get-SmbShare -Name "Athena-AI" -ErrorAction SilentlyContinue
            if ($aiShare) {
                Write-Host "🤖 Athena's AI Share Status: ACTIVE" -ForegroundColor Magenta
                $aiConnections = Get-SmbOpenFile | Where-Object {$_.ShareRelativePath -like "*AI*"}
                Write-Host "Active AI connections: $($aiConnections.Count)" -ForegroundColor Magenta
            }
        }
        catch {
            Write-Host "⚠️ Athena's AI share not accessible" -ForegroundColor Yellow
        }
    } else {
        Write-Host "❌ HERMES-FS01 divine messenger is not accessible" -ForegroundColor Red
        Write-Host "⚠️ The gods are displeased! Check your network connection." -ForegroundColor Red
    }
}

# Run the divine monitoring function
Get-OlympusDivineShareStatus
```

---

## 📚 **Divine User Access Examples**

### **Divine Department Access Patterns**

```powershell
# Divine Council (Zeus.Skyfather, Hera.Queen)
# Access: Zeus-Command (Full Control), Olympus-Archives (Read), Apollo-Software (Change)

# War Strategists (Ares.Warlord, Athena.Wisdom)
# Access: Ares-Strategy (Full Control), Zeus-Command (Read), Olympus-Archives (Read)

# Innovation Forge (Hephaestus.Creator, Dionysus.Innovator)
# Access: Hephaestus-Innovation (Full Control), Athena-AI (Full Control), Apollo-Software (Read)

# Abundance Treasury (Demeter.Provider, Hermes.Messenger)
# Access: Demeter-Treasury (Full Control), Zeus-Command (Read), Olympus-Archives (Read)

# Harmony Relations (Aphrodite.Diplomat, Apollo.Communicator)
# Access: Aphrodite-Relations (Full Control), Olympus-Archives (Change), Apollo-Software (Read)
```

### **Special Divine Shares Access**

```powershell
# AI/ML Researchers (Athena.Wisdom, Prometheus.Researcher)
# Access: Athena-AI (Full Control), Hephaestus-Innovation (Change), Apollo-Software (Read)

# Divine Administrators (Zeus.Skyfather, Hermes.Messenger)
# Access: ALL shares (Full Control), Special monitoring privileges

# Sacred Auditors (Themis.Justice, Nemesis.Retribution)
# Access: ALL shares (Read), Special auditing privileges
```

---

## 🔮 **Advanced Divine Features**

### **AI/ML Dataset Management**

```powershell
# Create specialized AI/ML subdirectories
$aiDirectories = @(
    "Machine_Learning_Models",
    "Training_Datasets",
    "Neural_Networks",
    "Deep_Learning_Projects",
    "Computer_Vision",
    "Natural_Language_Processing"
)

foreach ($dir in $aiDirectories) {
    New-Item -Path "C:\Olympus-Shares\AI_ML_Projects\$dir" -ItemType Directory -Force
    Write-Host "Created AI directory: $dir" -ForegroundColor Magenta
}

# Set special permissions for AI researchers
Set-SmbShare -Name "Athena-AI" -EncryptData $true  # Encrypt AI data in transit
```

### **Cloud Integration Preparation**

```powershell
# Prepare shares for cloud synchronization
$cloudShares = @("Zeus-Command", "Olympus-Archives", "Apollo-Software")

foreach ($share in $cloudShares) {
    # Configure for cloud sync
    Set-SmbShare -Name $share -CompressData $true
    Write-Host "Configured $share for cloud integration" -ForegroundColor Cyan
}
```

---

## ✅ **Olympus Divine Network Shares Verification Checklist**

After completing the Olympus divine network share setup:

- [ ] **HERMES-FS01** divine file server role installed
- [ ] **Olympus divine directories** created with proper Mount Olympus structure
- [ ] **NTFS permissions** applied for all divine GRP-\* groups
- [ ] **Greek mythology-themed SMB shares** created and accessible
- [ ] **Divine department groups** have appropriate access levels
- [ ] **Client connectivity** tested from workstations in each divine department
- [ ] **SMB divine security** enabled (signing, SMB v1 disabled)
- [ ] **DFS divine namespace** configured for god-based access
- [ ] **Access-based enumeration** enabled on all divine shares
- [ ] **Divine auditing** configured for security and compliance
- [ ] **AI/ML specialized shares** configured for innovation projects
- [ ] **Cloud integration** prepared for hybrid divine operations
- [ ] **Divine monitoring scripts** implemented and tested

---

## 🔗 **Related Divine Resources**

- [Olympus Systems Demo Overview](../README.md)
- [Olympus Manual Setup Guide](../MANUAL_SETUP_OLYMPUS.md)
- [Olympus Quick Start Guide](QUICK_START_OLYMPUS.md)
- [Active Directory Groups Management](../../../LabSetupTutorials/03_AD_Groups_Management.md)

---

**⚡ May Zeus bless your divine file sharing journey across Mount Olympus!** 🏛️

_By the wisdom of Athena and the craftsmanship of Hephaestus, your divine network shares shall be as eternal as the gods themselves!_

**🌟 The Olympian gods smile upon your IT endeavors! 🌟**
