# 🏰 Asgard Technologies Network Share Setup Guide

## 🎯 Overview

This guide provides step-by-step instructions for setting up network shares in the **Asgard Technologies** Windows Server lab environment. Follow these Norse mythology-themed instructions to configure file sharing services for your corporate domain.

---

## 📋 Prerequisites

- **HEIMDALL-FS01** file server deployed and domain-joined
- **asgard.local** Active Directory domain configured
- Administrative privileges on the file server
- Network connectivity between servers and clients

---

## 🔧 **Method 1: GUI-Based Network Share Setup**

### **Step 1: Install File Server Role on HEIMDALL-FS01**

1. **Connect to HEIMDALL-FS01** via RDP or console
2. **Open Server Manager**
3. **Click "Add roles and features"**
4. **Select "Role-based or feature-based installation"**
5. **Choose HEIMDALL-FS01**
6. **Expand "File and Storage Services"**
7. **Check "File Server"**
8. **Check "DFS Namespaces"** (for advanced features)
9. **Complete the installation wizard**

### **Step 2: Create Asgard Department Directories**

1. **Open File Explorer** on HEIMDALL-FS01
2. **Navigate to C:\ drive**
3. **Create main folder**: `C:\Asgard-Shares`
4. **Create department subfolders**:
   ```
   C:\Asgard-Shares\IT_Operations
   C:\Asgard-Shares\Cybersecurity
   C:\Asgard-Shares\Research_Development
   C:\Asgard-Shares\Finance_Admin
   C:\Asgard-Shares\Human_Resources
   C:\Asgard-Shares\Public
   C:\Asgard-Shares\Software
   ```

### **Step 3: Configure NTFS Permissions for Norse Departments**

For each department folder:

1. **Right-click the folder** → **Properties**
2. **Go to "Security" tab**
3. **Click "Edit"**
4. **Click "Add"**
5. **Enter the Asgard group** (e.g., `ASGARD\GRP-IT_Operations`)
6. **Set permissions**:
   - **Full Control**: For department groups
   - **Read**: For Domain Users (if needed)
7. **Click "OK"**

### **Step 4: Create Asgard Network Shares**

1. **Right-click each department folder**
2. **Select "Properties"**
3. **Go to "Sharing" tab**
4. **Click "Advanced Sharing"**
5. **Check "Share this folder"**
6. **Set Norse-themed share names**:
   - IT_Operations → `Midgard-IT`
   - Cybersecurity → `Valhalla-Security`
   - Research_Development → `Alfheim-Research`
   - Finance_Admin → `Asgard-Treasury`
   - Human_Resources → `Frigg-HR`
7. **Click "Permissions"**
8. **Configure share permissions**:
   - **Remove "Everyone"** (security best practice)
   - **Add department group** with "Full Control"
9. **Click "OK" twice**

---

## 💻 **Method 2: PowerShell-Based Asgard Share Setup**

### **Step 1: Create Asgard Directory Structure**

```powershell
# Connect to HEIMDALL-FS01 and run as Administrator

# Create main Asgard shares directory
New-Item -Path "C:\Asgard-Shares" -ItemType Directory -Force

# Create department directories with Norse themes
$asgardDepartments = @(
    "IT_Operations",
    "Cybersecurity",
    "Research_Development",
    "Finance_Admin",
    "Human_Resources",
    "Public",
    "Software"
)

foreach ($dept in $asgardDepartments) {
    New-Item -Path "C:\Asgard-Shares\$dept" -ItemType Directory -Force
    Write-Host "Created Asgard directory: C:\Asgard-Shares\$dept" -ForegroundColor Green
}
```

### **Step 2: Set NTFS Permissions for Asgard Groups**

```powershell
# Function to set NTFS permissions
function Set-AsgardNTFSPermissions {
    param(
        [string]$Path,
        [string]$Group,
        [string]$Permission = "FullControl"
    )

    $acl = Get-Acl $Path
    $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($Group, $Permission, "ContainerInherit,ObjectInherit", "None", "Allow")
    $acl.SetAccessRule($accessRule)
    Set-Acl $Path $acl
    Write-Host "Set $Permission permission for $Group on $Path" -ForegroundColor Green
}

# Apply permissions for each Asgard department
$asgardPermissions = @(
    @{Name = "IT_Operations"; Group = "ASGARD\GRP-IT_Operations"},
    @{Name = "Cybersecurity"; Group = "ASGARD\GRP-Cybersecurity"},
    @{Name = "Research_Development"; Group = "ASGARD\GRP-Research_Development"},
    @{Name = "Finance_Admin"; Group = "ASGARD\GRP-Finance_Admin"},
    @{Name = "Human_Resources"; Group = "ASGARD\GRP-Human_Resources"}
)

foreach ($dept in $asgardPermissions) {
    $path = "C:\Asgard-Shares\$($dept.Name)"
    Set-AsgardNTFSPermissions -Path $path -Group $dept.Group -Permission "FullControl"
}
```

### **Step 3: Create Asgard SMB Shares with Norse Names**

```powershell
# Create department shares with Norse mythology theme
$asgardShares = @(
    @{Name = "Midgard-IT"; Path = "C:\Asgard-Shares\IT_Operations"; Group = "ASGARD\GRP-IT_Operations"; Description = "IT Operations - Connecting all Nine Realms"},
    @{Name = "Valhalla-Security"; Path = "C:\Asgard-Shares\Cybersecurity"; Group = "ASGARD\GRP-Cybersecurity"; Description = "Cybersecurity - Defending Asgard"},
    @{Name = "Alfheim-Research"; Path = "C:\Asgard-Shares\Research_Development"; Group = "ASGARD\GRP-Research_Development"; Description = "R&D - Innovation of the Light Elves"},
    @{Name = "Asgard-Treasury"; Path = "C:\Asgard-Shares\Finance_Admin"; Group = "ASGARD\GRP-Finance_Admin"; Description = "Finance - Treasures of Asgard"},
    @{Name = "Frigg-HR"; Path = "C:\Asgard-Shares\Human_Resources"; Group = "ASGARD\GRP-Human_Resources"; Description = "Human Resources - Wisdom of Frigg"}
)

foreach ($share in $asgardShares) {
    try {
        New-SmbShare -Name $share.Name `
                     -Path $share.Path `
                     -FullAccess $share.Group `
                     -Description $share.Description `
                     -FolderEnumerationMode AccessBased

        Write-Host "Created Asgard share: $($share.Name) at $($share.Path)" -ForegroundColor Green
    }
    catch {
        Write-Warning "Failed to create share $($share.Name) : $($_.Exception.Message)"
    }
}
```

### **Step 4: Create Public Asgard Shares**

```powershell
# Create public share for all Asgard citizens
New-SmbShare -Name "Asgard-Public" `
             -Path "C:\Asgard-Shares\Public" `
             -ReadAccess "ASGARD\Domain Users" `
             -Description "Public realm for all citizens of Asgard"

# Create software repository
New-SmbShare -Name "Bifrost-Software" `
             -Path "C:\Asgard-Shares\Software" `
             -ReadAccess "ASGARD\Domain Users" `
             -ChangeAccess "ASGARD\GRP-IT_Operations" `
             -Description "Software repository - Bridge to digital realms"

Write-Host "Created Asgard public and software shares" -ForegroundColor Green
```

---

## 🌈 **Method 3: Advanced Asgard Configuration with DFS**

### **Step 1: Set Up Asgard DFS Namespace**

```powershell
# Install DFS features on HEIMDALL-FS01
Install-WindowsFeature -Name FS-DFS-Namespace, FS-DFS-Replication -IncludeManagementTools

# Create Asgard DFS namespace
New-DfsnRoot -TargetPath "\\HEIMDALL-FS01\AsgardDFS" -Type DomainV2 -Path "\\asgard.local\realms"

# Add DFS folders with Norse names
$dfsLinks = @(
    @{DFSPath = "\\asgard.local\realms\midgard"; SharePath = "\\HEIMDALL-FS01\Midgard-IT"},
    @{DFSPath = "\\asgard.local\realms\valhalla"; SharePath = "\\HEIMDALL-FS01\Valhalla-Security"},
    @{DFSPath = "\\asgard.local\realms\alfheim"; SharePath = "\\HEIMDALL-FS01\Alfheim-Research"},
    @{DFSPath = "\\asgard.local\realms\treasury"; SharePath = "\\HEIMDALL-FS01\Asgard-Treasury"},
    @{DFSPath = "\\asgard.local\realms\frigg"; SharePath = "\\HEIMDALL-FS01\Frigg-HR"}
)

foreach ($link in $dfsLinks) {
    New-DfsnFolder -Path $link.DFSPath -TargetPath $link.SharePath
    Write-Host "Created DFS link: $($link.DFSPath) -> $($link.SharePath)" -ForegroundColor Green
}
```

### **Step 2: Configure Asgard Share Caching**

```powershell
# Configure offline files caching for better performance
Set-SmbShare -Name "Midgard-IT" -CachingMode BranchCache
Set-SmbShare -Name "Valhalla-Security" -CachingMode None  # Security shares - no caching
Set-SmbShare -Name "Alfheim-Research" -CachingMode Documents
Set-SmbShare -Name "Asgard-Public" -CachingMode Manual
Set-SmbShare -Name "Bifrost-Software" -CachingMode Programs
```

---

## 🧪 **Testing Asgard Network Shares**

### **Step 1: Verify Shares from HEIMDALL-FS01**

```powershell
# List all Asgard SMB shares
Get-SmbShare | Where-Object {$_.Name -like "*Asgard*" -or $_.Name -like "*Midgard*" -or $_.Name -like "*Valhalla*"}

# Check specific share permissions
Get-SmbShareAccess -Name "Midgard-IT"
Get-SmbShareAccess -Name "Valhalla-Security"

# Test local connectivity
Test-Path "\\localhost\Midgard-IT"
Test-Path "\\localhost\Valhalla-Security"
```

### **Step 2: Test from Asgard Client Workstations**

```powershell
# Test from any Asgard workstation
# Test network connectivity to HEIMDALL-FS01
Test-NetConnection -ComputerName "HEIMDALL-FS01" -Port 445
Test-NetConnection -ComputerName "heimdall-fs01.asgard.local" -Port 445

# Test share access with Norse names
Test-Path "\\HEIMDALL-FS01\Midgard-IT"
Test-Path "\\HEIMDALL-FS01\Valhalla-Security"
Test-Path "\\HEIMDALL-FS01\Asgard-Public"

# Test DFS namespace access
Test-Path "\\asgard.local\realms\midgard"
Test-Path "\\asgard.local\realms\valhalla"
```

### **Step 3: User Access Testing**

```powershell
# Test as different Asgard users
# From IT workstation as Odin Allfather
net use M: \\HEIMDALL-FS01\Midgard-IT

# From Security workstation as Heimdall Guardian
net use V: \\HEIMDALL-FS01\Valhalla-Security

# From R&D workstation as Loki Innovator
net use A: \\HEIMDALL-FS01\Alfheim-Research
```

---

## 🛡️ **Asgard Security Configuration**

### **Step 1: Enable SMB Security for Asgard Domain**

```powershell
# Run on HEIMDALL-FS01 and all Asgard domain controllers
# Enable SMB signing for enhanced security
Set-SmbServerConfiguration -RequireSecuritySignature $true -Force
Set-SmbClientConfiguration -RequireSecuritySignature $true -Force

# Disable SMB v1 (security vulnerability)
Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart

Write-Host "Asgard SMB security hardening completed" -ForegroundColor Green
```

### **Step 2: Configure Asgard File Access Auditing**

```powershell
# Enable comprehensive auditing for Asgard shares
auditpol /set /subcategory:"File Share" /success:enable /failure:enable
auditpol /set /subcategory:"File System" /success:enable /failure:enable
auditpol /set /subcategory:"Handle Manipulation" /success:enable /failure:enable

# Configure specific auditing for sensitive shares
$sensitiveShares = @("Valhalla-Security", "Asgard-Treasury")
foreach ($share in $sensitiveShares) {
    $sharePath = (Get-SmbShare -Name $share).Path
    # Configure SACL for auditing
    icacls $sharePath /setintegritylevel H
}
```

---

## 🛠️ **Troubleshooting Asgard Shares**

### **Issue 1: Cannot Access Norse-Named Shares**

**Symptoms**: "Network path not found" for Asgard shares

**Solutions**:

1. **Check HEIMDALL-FS01 connectivity**: `ping HEIMDALL-FS01`
2. **Verify DNS resolution**: `nslookup heimdall-fs01.asgard.local`
3. **Test SMB port**: `Test-NetConnection -ComputerName HEIMDALL-FS01 -Port 445`
4. **Check share names**: `Get-SmbShare` on HEIMDALL-FS01

### **Issue 2: Asgard Group Access Denied**

**Symptoms**: "Access is denied" for department users

**Solutions**:

1. **Verify user is in correct Asgard group**: `Get-ADUser username -Properties MemberOf`
2. **Check group membership**: `net user username /domain`
3. **Verify share permissions**: `Get-SmbShareAccess -Name "Midgard-IT"`
4. **Test with domain admin**: Confirm share works with Administrator

### **Issue 3: DFS Namespace Issues**

**Symptoms**: Cannot access `\\asgard.local\realms` paths

**Solutions**:

1. **Check DFS service**: `Get-Service -Name "DFS*"`
2. **Verify DFS configuration**: `Get-DfsnRoot`
3. **Test DFS links**: `Get-DfsnFolder -Path "\\asgard.local\realms\*"`

---

## 📊 **Asgard Share Monitoring**

### **PowerShell Monitoring Script**

```powershell
# Asgard-ShareMonitor.ps1
function Get-AsgardShareStatus {
    Write-Host "=== ASGARD TECHNOLOGIES SHARE STATUS ===" -ForegroundColor Cyan

    # Check HEIMDALL-FS01 connectivity
    $fsServer = "HEIMDALL-FS01"
    $connectivity = Test-NetConnection -ComputerName $fsServer -Port 445 -WarningAction SilentlyContinue

    if ($connectivity.TcpTestSucceeded) {
        Write-Host "✅ HEIMDALL-FS01 is accessible" -ForegroundColor Green

        # List Asgard shares
        $asgardShares = Get-SmbShare | Where-Object {$_.Name -like "*Asgard*" -or $_.Name -like "*Midgard*" -or $_.Name -like "*Valhalla*" -or $_.Name -like "*Alfheim*" -or $_.Name -like "*Frigg*" -or $_.Name -like "*Bifrost*"}

        Write-Host "`n🏰 Active Asgard Shares:" -ForegroundColor Yellow
        $asgardShares | Format-Table Name, Path, Description -AutoSize

        # Check DFS namespace
        try {
            $dfsRoots = Get-DfsnRoot -ErrorAction SilentlyContinue
            if ($dfsRoots) {
                Write-Host "🌈 DFS Namespace Status:" -ForegroundColor Yellow
                $dfsRoots | Format-Table Path, State -AutoSize
            }
        }
        catch {
            Write-Host "⚠️ DFS not configured or accessible" -ForegroundColor Yellow
        }
    } else {
        Write-Host "❌ HEIMDALL-FS01 is not accessible" -ForegroundColor Red
    }
}

# Run the monitoring function
Get-AsgardShareStatus
```

---

## 📚 **Asgard User Access Examples**

### **Department Access Patterns**

```powershell
# IT Operations (Odin.Allfather, Thor.Thunderer)
# Access: Midgard-IT (Full Control), Asgard-Public (Read), Bifrost-Software (Change)

# Cybersecurity (Heimdall.Guardian, Tyr.Warrior)
# Access: Valhalla-Security (Full Control), Asgard-Public (Read)

# Research & Development (Loki.Innovator, Freya.Researcher)
# Access: Alfheim-Research (Full Control), Asgard-Public (Read), Bifrost-Software (Read)

# Finance & Admin (Baldr.Administrator, Frigg.Manager)
# Access: Asgard-Treasury (Full Control), Asgard-Public (Read)

# Human Resources (Sif.Coordinator, Vidar.Specialist)
# Access: Frigg-HR (Full Control), Asgard-Public (Read)
```

---

## ✅ **Asgard Network Shares Verification Checklist**

After completing the Asgard network share setup:

- [ ] **HEIMDALL-FS01** file server role installed
- [ ] **Asgard department directories** created with proper structure
- [ ] **NTFS permissions** applied for all GRP-\* groups
- [ ] **Norse-themed SMB shares** created and accessible
- [ ] **Department groups** have appropriate access levels
- [ ] **Client connectivity** tested from workstations in each department
- [ ] **SMB security** enabled (signing, SMB v1 disabled)
- [ ] **DFS namespace** configured for realm-based access
- [ ] **Access-based enumeration** enabled on all shares
- [ ] **Auditing** configured for security and compliance
- [ ] **Share documentation** updated with Norse theme

---

## 🔗 **Related Asgard Resources**

- [Asgard Technologies Demo Overview](../README.md)
- [Asgard Manual Setup Guide](../MANUAL_SETUP_ASGARD.md)
- [Asgard Quick Start Guide](QUICK_START_ASGARD.md)
- [Active Directory Groups Management](../../../LabSetupTutorials/03_AD_Groups_Management.md)

---

**⚡ May the Allfather guide your file sharing journey through the Nine Realms of Asgard Technologies!** 🏰

_By Odin's beard, your network shares shall be as mighty as Mjolnir and as reliable as the Rainbow Bridge!_
