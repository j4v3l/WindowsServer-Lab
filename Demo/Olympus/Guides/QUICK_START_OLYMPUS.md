# 🚀 **OLYMPUS SYSTEMS** - Quick Start Guide

## ⚡ **Deploy the Most Divine Windows Server Lab in 3 Steps!**

### 🎯 **What You'll Get**

- **25 Virtual Machines** (5 servers + 20 workstations)
- **Greek mythology-themed company** with realistic org structure
- **Complete Windows Server environment** with all features
- **Automated deployment** with professional scripts
- **Divine demonstrations** showcasing every capability

---

## 📋 **Prerequisites**

### **⚡ Tested & Optimized Hardware**

**This lab was designed and tested on:**

- **CPU**: AMD Ryzen 7900X (12 cores, 24 threads)
- **RAM**: 64GB DDR5
- **Storage**: 1TB NVMe SSD
- **GPU**: NVIDIA RTX 5070 (12GB VRAM)
- **OS**: Windows 11 Pro with Hyper-V

### **💪 Performance Capabilities**

With the above specs, you can run:

- **35+ VMs simultaneously**
- **Enhanced VM specifications** (larger RAM allocations)
- **Parallel operations** without performance impact
- **30-60 minute deployment** time

### **⚠️ Minimum Requirements for Others**

- **32GB RAM** (minimum 16GB, 64GB recommended)
- **1TB+ NVMe storage**
- **8+ CPU cores** (12+ recommended)
- **Windows 10/11 Pro or Enterprise**
- **Dedicated GPU** (recommended for multiple VMs)

### **Software Requirements**

- **Hyper-V enabled**
- **Windows Server 2019/2022 ISO**
- **Windows 10/11 ISO** (for workstations)

---

## 🚀 **Step 1: Enable Hyper-V**

```powershell
# Run as Administrator
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -All

# Restart when prompted
Restart-Computer
```

---

## ⚡ **Step 2: Deploy Olympus Systems**

```powershell
# Navigate to your WindowsServer project
cd "C:\path\to\WindowsServer"

# RECOMMENDED: Deploy with separate ISOs (this creates 25 VMs with enhanced specs!)
# You'll be prompted for secure passwords during deployment
.\Demo\Olympus\Scripts\Deploy-OlympusLab.ps1 -VMPath "C:\VMs\Olympus" -ServerISOPath "C:\ISOs\en-us_windows_server_2025_x64_dvd_b7ec10f3.iso" -ClientISOPath "C:\ISOs\en-us_windows_10_consumer_editions_version_22h2_x64_dvd_8da72ab3.iso"

# Or deploy with custom settings
.\Demo\Olympus\Scripts\Deploy-OlympusLab.ps1 -DomainName "olympus.local" -VMPath "D:\VMs\Olympus" -ServerISOPath "D:\ISOs\WindowsServer2025.iso" -ClientISOPath "D:\ISOs\Windows10.iso"

# LEGACY: Single ISO mode (backward compatibility)
.\Demo\Olympus\Scripts\Deploy-OlympusLab.ps1 -VMPath "C:\VMs\Olympus" -ISOPath "C:\ISOs\WindowsServer.iso"

# 💡 Performance Tip: Store VMs on your 1TB NVMe for best performance!
# Total RAM allocation: ~90GB (well within your 64GB + swap capabilities)
```

### **🔒 Security Password Requirements**

During deployment, you'll be prompted for:

1. **Safe Mode Password** (DSRM Recovery)

   - Used for domain controller recovery operations
   - Must meet complexity requirements (8+ chars, mixed case, numbers, symbols)
   - Keep this password secure and documented

2. **Default User Password** (All 25 Greek Mythology Users)
   - Applied to all Divine Council, War Strategists, Innovation Forge, Abundance Treasury, and Harmony Relations user accounts
   - Users will be required to change password on first login
   - Must meet domain password policy requirements

**Security Benefits:**

- ✅ No hardcoded passwords in any scripts
- ✅ Secure password entry using PowerShell SecureString
- ✅ Runtime validation ensures password compliance
- ✅ Zero critical security vulnerabilities (PSScriptAnalyzer validated)

---

## ⚙️ **Step 3: Configure Your Divine Lab**

### **Phase 1: Install Operating Systems**

1. **Start ZEUS-DC01** (Primary Domain Controller)
2. **Install Windows Server 2019/2022**
3. **Configure as Domain Controller**:
   - Domain: `olympus.local`
   - Safe Mode Password: Use the same secure password you entered during deployment

### **Phase 2: Run AD Configuration**

```powershell
# On ZEUS-DC01, run the generated script:
C:\VMs\Olympus\Configure-OlympusAD.ps1
```

### **Phase 3: Install Other Systems**

- **HERA-DC02**: Secondary Domain Controller
- **HERMES-FS01**: File Server
- **APOLLO-WEB01**: Web Server
- **ATHENA-SEC01**: Security Server
- **All Workstations**: Windows 10/11

---

## 🎭 **Meet Your Greek Mythology Team**

### **🏢 Organizational Structure**

#### **Divine Council** (IT Operations)

- **zeus.supreme** - CEO & Domain Admin
- **poseidon.seas** - Senior Systems Engineer
- **hades.underworld** - Database Administrator
- **hermes.messenger** - Network Administrator
- **dionysus.wine** - Junior Developer

#### **War Strategists** (Cybersecurity)

- **athena.wisdom** - CTO & CISO
- **ares.war** - Security Operations Manager
- **nike.victory** - Incident Response Lead
- **kratos.strength** - Penetration Tester
- **bia.force** - SOC Analyst

#### **Innovation Forge** (Research & Development)

- **apollo.light** - Head of Innovation
- **artemis.hunt** - AI Research Scientist
- **hephaestus.forge** - Senior Developer
- **prometheus.fire** - Data Scientist
- **daedalus.craft** - DevOps Engineer

#### **Abundance Treasury** (Finance & Administration)

- **hera.queen** - CFO
- **demeter.harvest** - Financial Analyst
- **plutus.wealth** - Accounting Manager
- **tyche.fortune** - Risk Analyst
- **nemesis.balance** - Compliance Officer

#### **Harmony Relations** (Human Resources)

- **aphrodite.harmony** - HR Director
- **eros.love** - Talent Acquisition
- **psyche.soul** - Training Coordinator
- **harmonia.peace** - Employee Relations
- **iris.rainbow** - Communications Specialist

---

## 🌐 **Network Architecture**

### **IP Address Scheme**

```
Production Network:    10.0.10.0/24   (Servers)
Management Network:    10.0.100.0/24  (Admin access)
Client Networks:       10.0.20.0/22   (Workstations)
DMZ Network:          10.0.50.0/24   (External services)
```

### **Key Server IPs**

```
ZEUS-DC01:     10.0.10.10  (Primary DC)
HERA-DC02:     10.0.10.11  (Secondary DC)
HERMES-FS01:   10.0.10.20  (File Server)
APOLLO-WEB01:  10.0.10.30  (Web Server)
ATHENA-SEC01:  10.0.10.40  (Security Server)
```

---

## 🎯 **Divine Demo Scenarios**

### **⚡ Scenario 1: New Employee Onboarding**

```powershell
# Create new user for Innovation Forge department
New-ADUser -Name "Icarus Soaring" -SamAccountName "icarus.soaring" -Department "Innovation_Forge"

# Add to innovation team
Add-ADGroupMember -Identity "GRP-Innovation_Team" -Members "icarus.soaring"

# Create workstation
New-OlympusVM -VMName "ICARUS-WS01" -Memory 4GB -Networks @("OLYMPUS-Clients")
```

### **🛡️ Scenario 2: Security Incident Response**

```powershell
# Simulate security breach
# Disable compromised account
Disable-ADAccount -Identity "dionysus.wine"

# Enable audit logging
Enable-OlympusAuditing -Domain "olympus.local"

# Generate security report
Get-OlympusSecurityReport -Path "C:\Reports\Incident-$(Get-Date -Format 'yyyyMMdd').html"
```

### **🔥 Scenario 3: Cloud Migration**

```powershell
# Deploy Azure Arc agents
Install-OlympusAzureArc -Servers @("ZEUS-DC01", "HERA-DC02", "ATHENA-SEC01")

# Configure hybrid identity
Enable-OlympusHybridAAD -Domain "olympus.local"

# Setup Site-to-Site VPN
New-OlympusVPN -AzureGateway "olympus-gateway" -LocalGateway "10.0.10.1"
```

### **🧠 Scenario 4: AI/ML Development**

```powershell
# Setup Machine Learning environment
Install-OlympusMLServices -Server "APOLLO-WEB01"

# Deploy data science workstations
New-OlympusDataScienceVM -Count 3 -Memory 8GB -GPU $true

# Configure Jupyter Hub
Enable-OlympusJupyterHub -Domain "ml.olympus.local"
```

### **📊 Scenario 5: Business Intelligence**

```powershell
# Deploy Power BI Report Server
Install-OlympusPowerBI -Server "APOLLO-WEB01"

# Setup data warehouse
New-OlympusDataWarehouse -Server "HERA-DC02" -Size "500GB"

# Configure automated reporting
Enable-OlympusReporting -Schedule "Daily" -Recipients @("hera.queen@olympus.local")
```

---

## 🌟 **Advanced Features**

### **🔧 Automation & Scripting**

```powershell
# Automated VM lifecycle management
Start-OlympusVMSchedule -Morning "08:00" -Evening "18:00"

# Automated backup rotation
Enable-OlympusBackupRotation -RetentionDays 30

# Performance monitoring alerts
Set-OlympusMonitoring -CPUThreshold 80 -MemoryThreshold 85
```

### **☁️ Cloud Integration**

```powershell
# Azure AD sync configuration
Enable-OlympusAADSync -SyncInterval 30

# Azure Backup integration
Enable-OlympusAzureBackup -Vault "olympus-backup-vault"

# Azure Monitor integration
Enable-OlympusAzureMonitor -Workspace "olympus-loganalytics"
```

### **🔐 Security Hardening**

```powershell
# Apply security baselines
Apply-OlympusSecurityBaseline -Profile "Enterprise"

# Enable advanced threat protection
Enable-OlympusATP -AllServers

# Configure conditional access
Set-OlympusConditionalAccess -RequireMFA $true
```

---

## 🎨 **Visual Customization**

### **Desktop Themes**

Each department gets custom desktop themes:

- **Divine Council**: Lightning and clouds
- **War Strategists**: Shields and weapons
- **Innovation Forge**: Gears and blueprints
- **Abundance Treasury**: Gold and abundance
- **Harmony Relations**: Hearts and rainbows

### **Network Naming**

```powershell
# Custom network names with Greek theming
OLYMPUS-Production   # Mount Olympus peak
OLYMPUS-Management   # Divine council chamber
OLYMPUS-Clients      # Mortal realm
OLYMPUS-DMZ         # Gateway to Olympus
```

---

## 📈 **Performance Optimization**

### **VM Resource Scaling**

```powershell
# Dynamic resource allocation based on workload
Set-OlympusAutoScale -EnableCPUScaling -EnableMemoryScaling

# Workstation performance profiles
Set-OlympusWorkstationProfile -Profile "Developer" -Memory 8GB -CPU 4
Set-OlympusWorkstationProfile -Profile "Standard" -Memory 4GB -CPU 2
```

### **Storage Optimization**

```powershell
# Enable storage deduplication
Enable-OlympusDeduplication -Servers @("HERMES-FS01")

# Configure storage tiering
Set-OlympusStorageTiering -HotTier "SSD" -ColdTier "HDD"
```

---

## 🔬 **Testing & Validation**

### **Deployment Validation**

```powershell
# Run comprehensive deployment tests
Test-OlympusDeployment -FullValidation

# Network connectivity tests
Test-OlympusNetworking -IncludeExternal

# Performance benchmarks
Start-OlympusPerformanceTest -Duration 30
```

### **Security Validation**

```powershell
# Security assessment
Start-OlympusSecurityScan -ComplianceReport

# Penetration testing simulation
Start-OlympusPenTest -Scenario "External Attack"
```

---

## 🎓 **Learning Resources**

### **Interactive Tutorials**

- **PowerShell Automation** - Learn advanced scripting
- **Azure Integration** - Hybrid cloud management
- **Security Best Practices** - Enterprise security
- **Performance Tuning** - Optimization techniques

### **Certification Paths**

- **Microsoft Certified: Windows Server Hybrid Administrator**
- **Microsoft Certified: Azure Administrator**
- **Microsoft Certified: Security Operations Analyst**

---

## 🚨 **Troubleshooting**

### **Common Issues**

#### **VM Won't Start**

```powershell
# Check VM configuration
Get-VM -Name "ZEUS-DC01" | Format-List

# Verify network adapters
Get-VMNetworkAdapter -VMName "ZEUS-DC01"

# Check available resources
Get-VMHost | Select-Object MemoryCapacity, LogicalProcessorCount
```

#### **Network Connectivity Issues**

```powershell
# Test network switches
Get-VMSwitch | Test-NetConnection

# Verify IP configuration
Get-VMNetworkAdapter | Get-VMNetworkAdapterIPAddress
```

#### **Performance Issues**

```powershell
# Monitor resource usage
Get-Counter "\Hyper-V Hypervisor\Logical Processors"
Get-Counter "\Memory\Available MBytes"

# Check VM resource allocation
Get-VM | Select-Object Name, MemoryAssigned, CPUUsage
```

---

## 🎉 **Success Validation**

### **Deployment Complete Checklist**

- ✅ All 25 VMs created and running
- ✅ Domain controller configured (olympus.local)
- ✅ All users and groups created
- ✅ Network connectivity verified
- ✅ File shares accessible
- ✅ Web services running
- ✅ Security monitoring active
- ✅ Backup systems operational

### **Final Steps**

```powershell
# Generate deployment report
New-OlympusDeploymentReport -Path "C:\Reports\Olympus-Deployment-$(Get-Date -Format 'yyyyMMdd').html"

# Create system snapshot
Checkpoint-VM -Name "ZEUS-DC01" -SnapshotName "Production-Ready"

# Schedule maintenance tasks
Register-OlympusMaintenanceSchedule -Weekly
```

---

## 🏛️ **Welcome to Digital Olympus!**

Congratulations! Your **Olympus Systems** lab is now ready. You've successfully deployed:

- **🏛️ A complete Greek mythology-themed enterprise**
- **⚡ 25 virtual machines with divine names**
- **🌟 Modern cloud and AI capabilities**
- **🔐 Enterprise-grade security**
- **🚀 Automated management tools**

**May Zeus's lightning power your servers and Athena's wisdom guide your administration!** ⚡🏛️

---

## 📞 **Support Resources**

- **Documentation**: [Complete Setup Guide](../Documentation/DEMO_SETUP_GUIDE.md)
- **Performance**: [Hardware Optimization Guide](../Documentation/HARDWARE_PERFORMANCE_GUIDE.md)
- **Community**: GitHub Issues and Discussions
- **Updates**: Check for new features and improvements

**⚡ Ascend to greatness with Olympus Systems! ⚡**
