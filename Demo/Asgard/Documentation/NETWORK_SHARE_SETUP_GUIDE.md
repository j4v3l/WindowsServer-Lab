# 📁 Windows Server Network Share Setup Guide

## 🎯 Overview

This guide provides comprehensive step-by-step instructions for setting up network shares in your Windows Server lab environment. Whether you're using the Asgard Technologies or Olympus Systems demo, these instructions will help you configure file sharing services.

---

## 📋 Prerequisites

- Windows Server 2019/2022 with File Server role installed
- Active Directory domain configured
- Administrative privileges on the file server
- Network connectivity between servers and clients

---

## 🔧 **Method 1: GUI-Based Network Share Setup**

### **Step 1: Install File Server Role**

1. **Open Server Manager**
2. **Click "Add roles and features"**
3. **Select "Role-based or feature-based installation"**
4. **Choose your file server**
5. **Expand "File and Storage Services"**
6. **Check "File Server"**
7. **Complete the installation wizard**

### **Step 2: Create Share Directories**

1. **Open File Explorer** on your file server
2. **Navigate to C:\ drive**
3. **Create a new folder**: `C:\Shares`
4. **Create department subfolders**:
   ```
   C:\Shares\IT
   C:\Shares\HR
   C:\Shares\Sales
   C:\Shares\Finance
   C:\Shares\Marketing
   ```

### **Step 3: Configure NTFS Permissions**

For each department folder:

1. **Right-click the folder** → **Properties**
2. **Go to "Security" tab**
3. **Click "Edit"**
4. **Click "Add"**
5. **Type the department group** (e.g., `GRP-IT`)
6. **Set permissions**:
   - **Full Control**: For department groups
   - **Read**: For Everyone (if needed)
7. **Click "OK"**

### **Step 4: Create Network Shares**

1. **Right-click each department folder**
2. **Select "Properties"**
3. **Go to "Sharing" tab**
4. **Click "Advanced Sharing"**
5. **Check "Share this folder"**
6. **Set share name** (e.g., "IT", "HR")
7. **Click "Permissions"**
8. **Configure share permissions**:
   - **Remove "Everyone"** (if not needed)
   - **Add department group** with "Full Control"
9. **Click "OK" twice**

### **Step 5: Test Share Access**

1. **From a client machine**, press **Win + R**
2. **Type**: `\\FileServerName\ShareName`
3. **Example**: `\\HEIMDALL-FS01\IT`
4. **Verify access** with appropriate credentials

---

## 💻 **Method 2: PowerShell-Based Network Share Setup**

### **Step 1: Create Directory Structure**

```powershell
# Create main shares directory
New-Item -Path "C:\Shares" -ItemType Directory -Force

# Create department directories
$departments = @("IT", "HR", "Sales", "Finance", "Marketing")
foreach ($dept in $departments) {
    New-Item -Path "C:\Shares\$dept" -ItemType Directory -Force
    Write-Host "Created directory: C:\Shares\$dept" -ForegroundColor Green
}
```

### **Step 2: Set NTFS Permissions**

```powershell
# Function to set NTFS permissions
function Set-NTFSPermissions {
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

# Apply permissions for each department
$departments = @(
    @{Name = "IT"; Group = "ASGARD\GRP-IT_Operations"},
    @{Name = "HR"; Group = "ASGARD\GRP-Human_Resources"},
    @{Name = "Sales"; Group = "ASGARD\GRP-Research_Development"},
    @{Name = "Finance"; Group = "ASGARD\GRP-Finance_Admin"},
    @{Name = "Marketing"; Group = "ASGARD\GRP-Cybersecurity"}
)

foreach ($dept in $departments) {
    $path = "C:\Shares\$($dept.Name)"
    Set-NTFSPermissions -Path $path -Group $dept.Group -Permission "FullControl"
}
```

### **Step 3: Create SMB Shares**

```powershell
# Create SMB shares for each department
foreach ($dept in $departments) {
    $shareName = $dept.Name
    $sharePath = "C:\Shares\$($dept.Name)"
    $groupName = $dept.Group

    try {
        New-SmbShare -Name $shareName `
                     -Path $sharePath `
                     -FullAccess $groupName `
                     -Description "$($dept.Name) Department Share" `
                     -FolderEnumerationMode AccessBased

        Write-Host "Created share: $shareName at $sharePath" -ForegroundColor Green
    }
    catch {
        Write-Warning "Failed to create share $shareName : $($_.Exception.Message)"
    }
}
```

### **Step 4: Create Public and Software Shares**

```powershell
# Create public share
New-Item -Path "C:\Shares\Public" -ItemType Directory -Force
New-SmbShare -Name "Public" `
             -Path "C:\Shares\Public" `
             -ReadAccess "Domain Users" `
             -Description "Public file share for all users"

# Create software repository share
New-Item -Path "C:\Shares\Software" -ItemType Directory -Force
New-SmbShare -Name "Software" `
             -Path "C:\Shares\Software" `
             -ReadAccess "Domain Users" `
             -ChangeAccess "ASGARD\GRP-IT_Operations" `
             -Description "Software repository for company applications"

Write-Host "Created public and software shares" -ForegroundColor Green
```

---

## 🔍 **Method 3: Advanced Share Configuration**

### **Step 1: Enable Access-Based Enumeration**

```powershell
# Enable access-based enumeration for existing shares
Get-SmbShare | Where-Object {$_.Name -notlike "*$"} | ForEach-Object {
    Set-SmbShare -Name $_.Name -FolderEnumerationMode AccessBased -Confirm:$false
}
```

### **Step 2: Configure Share Caching**

```powershell
# Configure offline files caching
Set-SmbShare -Name "IT" -CachingMode BranchCache
Set-SmbShare -Name "Public" -CachingMode Manual
Set-SmbShare -Name "Software" -CachingMode Programs
```

### **Step 3: Set Up DFS Namespace**

```powershell
# Install DFS features (if not already installed)
Install-WindowsFeature -Name FS-DFS-Namespace, FS-DFS-Replication -IncludeManagementTools

# Create DFS namespace
New-DfsnRoot -TargetPath "\\HEIMDALL-FS01\DFS" -Type DomainV2 -Path "\\asgard.local\shares"

# Add DFS folders pointing to shares
New-DfsnFolder -Path "\\asgard.local\shares\IT" -TargetPath "\\HEIMDALL-FS01\IT"
New-DfsnFolder -Path "\\asgard.local\shares\HR" -TargetPath "\\HEIMDALL-FS01\HR"
New-DfsnFolder -Path "\\asgard.local\shares\Public" -TargetPath "\\HEIMDALL-FS01\Public"
```

---

## 🧪 **Testing and Verification**

### **Step 1: Verify Shares from Server**

```powershell
# List all SMB shares
Get-SmbShare

# Check share permissions
Get-SmbShareAccess -Name "IT"

# Test share connectivity
Test-Path "\\localhost\IT"
```

### **Step 2: Test from Client Machines**

```powershell
# Test network connectivity to file server
Test-NetConnection -ComputerName "HEIMDALL-FS01" -Port 445

# Test share access
Test-Path "\\HEIMDALL-FS01\IT"

# Map network drive
New-PSDrive -Name "I" -PSProvider FileSystem -Root "\\HEIMDALL-FS01\IT" -Persist
```

### **Step 3: Verify Permissions**

```cmd
# Using net use command
net use \\HEIMDALL-FS01\IT

# Check effective permissions
icacls "\\HEIMDALL-FS01\IT"
```

---

## 🔒 **Security Best Practices**

### **1. Permission Management**

- **Use groups instead of individual users** for share permissions
- **Apply least privilege principle** - only grant necessary access
- **Regularly audit permissions** using access reports

### **2. SMB Security**

```powershell
# Enable SMB signing (run on both server and clients)
Set-SmbServerConfiguration -RequireSecuritySignature $true
Set-SmbClientConfiguration -RequireSecuritySignature $true

# Disable SMB v1 (security risk)
Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol
```

### **3. Monitoring and Auditing**

```powershell
# Enable file access auditing
auditpol /set /subcategory:"File Share" /success:enable /failure:enable
auditpol /set /subcategory:"File System" /success:enable /failure:enable
```

---

## 🛠️ **Troubleshooting Common Issues**

### **Issue 1: Cannot Access Share**

**Symptoms**: "Network path not found" error

**Solutions**:

1. **Check network connectivity**: `ping HEIMDALL-FS01`
2. **Verify DNS resolution**: `nslookup HEIMDALL-FS01`
3. **Test SMB port**: `Test-NetConnection -ComputerName HEIMDALL-FS01 -Port 445`
4. **Check Windows Firewall**: Ensure "File and Printer Sharing" is enabled

### **Issue 2: Access Denied**

**Symptoms**: "Access is denied" when accessing share

**Solutions**:

1. **Check user group membership**: `whoami /groups`
2. **Verify share permissions**: `Get-SmbShareAccess -Name "ShareName"`
3. **Check NTFS permissions**: `icacls "C:\Shares\ShareName"`
4. **Ensure user is in correct AD group**

### **Issue 3: Slow File Access**

**Symptoms**: Files take long time to open from share

**Solutions**:

1. **Check network bandwidth**: `Test-NetConnection -ComputerName server -DiagnoseRouting`
2. **Configure offline files**: Enable caching for frequently accessed files
3. **Optimize SMB**: `Set-SmbServerConfiguration -EnableMultiChannel $true`

---

## 📚 **Demo-Specific Share Configurations**

### **For Asgard Technologies Demo**

```powershell
# Asgard-specific share creation
$asgardShares = @(
    @{Name = "IT_Operations"; Path = "C:\Shares\IT_Operations"; Group = "GRP-IT_Operations"},
    @{Name = "Cybersecurity"; Path = "C:\Shares\Cybersecurity"; Group = "GRP-Cybersecurity"},
    @{Name = "Research_Development"; Path = "C:\Shares\Research_Development"; Group = "GRP-Research_Development"},
    @{Name = "Finance_Admin"; Path = "C:\Shares\Finance_Admin"; Group = "GRP-Finance_Admin"},
    @{Name = "Human_Resources"; Path = "C:\Shares\Human_Resources"; Group = "GRP-Human_Resources"}
)

foreach ($share in $asgardShares) {
    New-Item -Path $share.Path -ItemType Directory -Force
    New-SmbShare -Name $share.Name -Path $share.Path -FullAccess "ASGARD\$($share.Group)"
}
```

### **For Olympus Systems Demo**

```powershell
# Olympus-specific share creation
$olympusShares = @(
    @{Name = "Divine Council"; Path = "C:\Shares\Divine Council"; Group = "GRP-Divine Council"},
    @{Name = "War Strategists"; Path = "C:\Shares\War Strategists"; Group = "GRP-War Strategists"},
    @{Name = "Innovation Forge"; Path = "C:\Shares\Innovation Forge"; Group = "GRP-Innovation Forge"},
    @{Name = "Abundance Treasury"; Path = "C:\Shares\Abundance Treasury"; Group = "GRP-Abundance Treasury"},
    @{Name = "Harmony Relations"; Path = "C:\Shares\Harmony Relations"; Group = "GRP-Harmony Relations"}
)

foreach ($share in $olympusShares) {
    New-Item -Path $share.Path -ItemType Directory -Force
    New-SmbShare -Name $share.Name -Path $share.Path -FullAccess "OLYMPUS\$($share.Group)"
}
```

---

## ✅ **Verification Checklist**

After completing the network share setup:

- [ ] **File server role** installed and configured
- [ ] **Share directories** created with proper structure
- [ ] **NTFS permissions** applied correctly
- [ ] **SMB shares** created and accessible
- [ ] **Department groups** have appropriate access
- [ ] **Client connectivity** tested from multiple workstations
- [ ] **Security settings** implemented (SMB signing, auditing)
- [ ] **DFS namespace** configured (if using advanced setup)
- [ ] **Access-based enumeration** enabled
- [ ] **Share documentation** updated

---

## 🔗 **Related Resources**

- [Active Directory Groups Management](../../../LabSetupTutorials/03_AD_Groups_Management.md)
- [Additional Servers Setup](../../../LabSetupTutorials/13_Additional_Servers_Setup.md)
- [Security Hardening](../../../LabSetupTutorials/09_Security_Hardening.md)
- [Troubleshooting Guide](../../../LabSetupTutorials/05_Troubleshooting.md)

---

**🎯 Pro Tip**: Always test share access from different user accounts and client machines to ensure permissions are working correctly. Use both GUI and command-line methods to verify functionality.
