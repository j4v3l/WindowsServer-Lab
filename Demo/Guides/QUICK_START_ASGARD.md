# 🚀 **ASGARD TECHNOLOGIES** - Quick Start Guide

## ⚡ **Deploy the Most Epic Windows Server Lab in 3 Steps!**

### 🎯 **What You'll Get**

- **25 Virtual Machines** (5 servers + 20 workstations)
- **Norse mythology-themed company** with realistic org structure
- **Complete Windows Server environment** with all features
- **Automated deployment** with professional scripts
- **Epic demonstrations** showcasing every capability

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

## 🏰 **Step 2: Deploy Asgard Technologies**

```powershell
# Navigate to your WindowsServer project
cd "C:\path\to\WindowsServer"

# Deploy the complete environment (this creates 25 VMs with enhanced specs!)
# You'll be prompted for secure passwords during deployment
.\Scripts\Deploy-AsgardLab.ps1 -VMPath "C:\VMs\Asgard" -ISOPath "C:\path\to\WindowsServer.iso"

# Or deploy with custom settings
.\Scripts\Deploy-AsgardLab.ps1 -DomainName "asgard.local" -VMPath "D:\VMs\Asgard" -ISOPath "D:\ISOs\WinServer2022.iso"

# 💡 Performance Tip: Store VMs on your 1TB NVMe for best performance!
# Total RAM allocation: ~90GB (well within your 64GB + swap capabilities)
```

### **🔒 Security Password Requirements**

During deployment, you'll be prompted for:

1. **Safe Mode Password** (DSRM Recovery)

   - Used for domain controller recovery operations
   - Must meet complexity requirements (8+ chars, mixed case, numbers, symbols)
   - Keep this password secure and documented

2. **Default User Password** (All 25 Norse Users)
   - Applied to all mythology-themed user accounts
   - Users will be required to change password on first login
   - Must meet domain password policy requirements

**Security Benefits:**

- ✅ No hardcoded passwords in any scripts
- ✅ Secure password entry using PowerShell SecureString
- ✅ Runtime validation ensures password compliance
- ✅ Zero critical security vulnerabilities (PSScriptAnalyzer validated)

---

## ⚙️ **Step 3: Configure Your Epic Lab**

### **Phase 1: Install Operating Systems**

1. **Start ODIN-DC01** (Primary Domain Controller)
2. **Install Windows Server 2019/2022**
3. **Configure as Domain Controller**:
   - Domain: `asgard.local`
   - Safe Mode Password: Use the same secure password you entered during deployment

### **Phase 2: Run AD Configuration**

```powershell
# On ODIN-DC01, run the generated script:
C:\VMs\Asgard\Configure-AsgardAD.ps1
```

### **Phase 3: Install Other Systems**

- **FRIGG-DC02**: Secondary Domain Controller
- **HEIMDALL-FS01**: File Server
- **BALDER-WEB01**: Web Server
- **VIDAR-SEC01**: Security Server
- **All Workstations**: Windows 10/11

---

## 🎭 **Meet Your Norse Mythology Team**

### **🏢 Organizational Structure**

#### **IT Operations** (Odin's Realm)

- **odin.allfather** - CTO & Domain Admin
- **thor.thunderer** - Senior Systems Engineer
- **loki.trickster** - Junior Developer (Intern)
- **hermod.messenger** - Network Administrator
- **tyr.brave** - Security Analyst

#### **Cybersecurity** (Heimdall's Watch)

- **heimdall.guardian** - CISO
- **mimir.wise** - Threat Intelligence Analyst
- **huginn.raven** - SOC Analyst I
- **muninn.memory** - SOC Analyst II
- **fenrir.wolf** - Penetration Tester

#### **Research & Development** (Freya's Workshop)

- **freya.seidr** - Head of R&D
- **njord.wind** - AI Research Scientist
- **frey.prosperity** - Quantum Computing Lead
- **jormungandr.serpent** - Data Scientist
- **sleipnir.swift** - DevOps Engineer

#### **Finance & Administration** (Frigg's Treasury)

- **frigg.queen** - CFO
- **eir.healer** - Financial Analyst
- **saga.storyteller** - Compliance Officer
- **var.oath** - Legal Counsel
- **forseti.justice** - Audit Manager

#### **Human Resources** (Sif's Domain)

- **sif.golden** - HR Director
- **idun.eternal** - Talent Acquisition
- **bragi.poet** - Training Coordinator
- **hel.half** - Benefits Administrator
- **sigyn.faithful** - Employee Relations

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
ODIN-DC01:     10.0.10.10  (Primary DC)
FRIGG-DC02:    10.0.10.11  (Secondary DC)
HEIMDALL-FS01: 10.0.10.20  (File Server)
BALDER-WEB01:  10.0.10.30  (Web Server)
VIDAR-SEC01:   10.0.10.40  (Security Server)
```

---

## 🎯 **Epic Demo Scenarios**

### **🔥 Scenario 1: New Employee Onboarding**

```powershell
# Create new user for R&D department
New-ADUser -Name "Baldr Lightbringer" -SamAccountName "baldr.light" -Department "Research_Development"

# Add to research team
Add-ADGroupMember -Identity "GRP-Research_Team" -Members "baldr.light"

# Create workstation
New-AsgardVM -VMName "BALDR-WS01" -Memory 4GB -Networks @("ASGARD-Clients")
```

### **⚔️ Scenario 2: Security Incident Response**

```powershell
# Simulate security breach
# Disable compromised account
Disable-ADAccount -Identity "loki.trickster"

# Generate incident report
Get-EventLog -LogName Security -EntryType FailureAudit | Export-Csv "SecurityIncident.csv"

# Implement containment policies
New-GPO -Name "Emergency-Lockdown" | New-GPLink -Target "OU=Departments,OU=Asgard Technologies,DC=asgard,DC=local"
```

### **🛡️ Scenario 3: Compliance Audit**

```powershell
# Generate compliance reports
Get-ADUser -Filter * -Properties * | Export-Csv "UserAudit.csv"
Get-ADGroup -Filter * | Export-Csv "GroupAudit.csv"
Get-ADComputer -Filter * | Export-Csv "ComputerAudit.csv"
```

---

## 🎮 **Management Commands**

### **VM Management**

```powershell
# Start all Asgard VMs
Get-VM | Where-Object {$_.Name -like "*ASGARD*" -or $_.Name -like "*ODIN*" -or $_.Name -like "*THOR*"} | Start-VM

# Stop all VMs
Get-VM | Where-Object {$_.Name -like "*ASGARD*" -or $_.Name -like "*ODIN*" -or $_.Name -like "*THOR*"} | Stop-VM

# Get VM status
Get-VM | Where-Object {$_.Name -like "*ASGARD*" -or $_.Name -like "*ODIN*" -or $_.Name -like "*THOR*"} | Select-Object Name, State, Status
```

### **Network Diagnostics**

```powershell
# Check virtual switches
Get-VMSwitch | Where-Object {$_.Name -like "ASGARD*"}

# Test connectivity
Test-NetConnection -ComputerName "10.0.10.10" -Port 3389
```

---

## 🏆 **Success Metrics**

### **You'll Know It's Working When:**

- ✅ **25 VMs created** and running
- ✅ **asgard.local domain** is functional
- ✅ **25 users** can log in to their workstations
- ✅ **Department file shares** are accessible
- ✅ **Group policies** are applied correctly
- ✅ **DNS/DHCP** services are operational
- ✅ **All demo scenarios** work perfectly

---

## 🆘 **Troubleshooting**

### **Common Issues**

#### **Not Enough Memory**

```powershell
# Scale down the environment
.\Scripts\Deploy-AsgardLab.ps1 -SkipVMs  # Networks only
# Then manually create fewer VMs
```

#### **Network Issues**

```powershell
# Check Hyper-V switches
Get-VMSwitch
Get-NetAdapter | Where-Object {$_.Name -like "*vEthernet*"}
```

#### **Domain Issues**

```powershell
# Check domain controller
Test-ComputerSecureChannel -Verbose
nltest /dclist:asgard.local
```

---

## 🎊 **Congratulations!**

You've successfully deployed **Asgard Technologies** - the most epic Windows Server lab environment ever created!

### **What You've Accomplished:**

- 🏰 **Built a Norse mythology-themed enterprise**
- ⚡ **Deployed 25 virtual machines** with enhanced specifications
- 🔐 **Configured enterprise-grade security**
- 🌐 **Set up professional networking**
- 👥 **Created realistic organizational structure**
- 🎯 **Enabled comprehensive demo scenarios**
- 💪 **Maximized your Ryzen 7900X + 64GB RAM** performance
- 🚀 **Achieved 30-60 minute deployment** on high-end hardware

### **Next Steps:**

1. **Explore the lab** with the demo scenarios
2. **Practice Windows Server skills** with real-world tasks
3. **Customize the environment** for your specific needs
4. **Share your epic lab** with the community!

---

## 📚 **Documentation**

- **Complete Setup Guide**: `DEMO_SETUP_GUIDE.md`
- **Lab Tutorials**: `LabSetupTutorials/`
- **Management Scripts**: `Scripts/`
- **Troubleshooting**: `LabSetupTutorials/05_Troubleshooting.md`

---

**🏰 Welcome to Asgard Technologies - Where IT Meets Legend! ⚡**

_"In the halls of Asgard, every server tells a story, every user has a purpose, and every network connection is a bridge between realms."_
