# 🏛️ **WINDOWS SERVER LAB DEMOS**

# 🚨 **CRITICAL SECURITY WARNING**

**⚠️ IMPORTANT:** This environment contains DEFAULT CONFIGURATIONS that are NOT suitable for production use. Before any deployment:

1. **Change ALL default passwords** - Never use demo passwords in production
2. **Implement production security policies** - Review SECURITY_HARDENING_GUIDE.md
3. **Complete security assessment** - Run SECURITY_VALIDATION_SCRIPT.ps1
4. **Review all configurations** - Ensure proper network isolation and access controls

**🔒 SECURITY NOTE:** All deployment scripts now require secure password entry - no credentials are hardcoded.

---

Welcome to the comprehensive Windows Server Lab demonstration environments! This directory contains two complete enterprise lab setups that showcase the full capabilities of the Windows Server Lab project.

## 🛠️ **CRITICAL UPDATE: v1.3.1 Network Fixes Applied!**

**🎉 GOOD NEWS**: Both Asgard and Olympus demos now have resolved networking issues that were causing domain join failures:

- **✅ Fixed Virtual Switch Configuration**: Proper Internal switches prevent IP conflicts
- **✅ Fixed IP Forwarding**: Cross-network routing now works correctly
- **✅ Fixed User Passwords**: Lab accounts no longer expire unexpectedly
- **✅ Added Network Validation**: New testing scripts validate network configuration before deployment

**Result**: Domain joins and network connectivity now work reliably on first deployment!

---

## 🎯 **Available Demo Environments**

### **🏰 [Asgard Technologies](Asgard/README.md)**

**Norse Mythology Enterprise - 25 Virtual Machines**

- **Theme**: Norse mythology with Odin, Thor, Loki, and the Nine Realms
- **Domain**: `asgard.local`
- **Features**: Traditional enterprise setup with comprehensive Windows Server features
- **Perfect for**: Learning, demonstrations, and standard enterprise scenarios
- **Quick Start**: [Asgard Quick Start Guide](Asgard/Guides/QUICK_START_ASGARD.md)
- **Manual Setup**: [Asgard Manual Setup Guide](Asgard/MANUAL_SETUP_ASGARD.md)

### **⚡ [Olympus Systems](Olympus/README.md)**

**Greek Mythology Enterprise - 25 Virtual Machines + Advanced Features**

- **Theme**: Greek mythology with Zeus, Athena, Apollo, and Mount Olympus
- **Domain**: `olympus.local`
- **Features**: Advanced enterprise setup with cloud integration, AI/ML capabilities
- **Perfect for**: Advanced scenarios, cloud hybrid demonstrations, AI/ML workloads
- **Quick Start**: [Olympus Quick Start Guide](Olympus/Guides/QUICK_START_OLYMPUS.md)
- **Manual Setup**: [Olympus Manual Setup Guide](Olympus/MANUAL_SETUP_OLYMPUS.md)

---

## 🚀 **Quick Start Guide**

### **For Standard Enterprise Demo (Asgard)**

```powershell
cd Demo/Asgard/Scripts
.\Deploy-AsgardLab.ps1 -VMPath "C:\VMs\Asgard" -ISOPath "C:\path\to\WindowsServer.iso"
```

### **For Advanced Enterprise Demo (Olympus)**

```powershell
cd Demo/Olympus/Scripts
.\Deploy-OlympusLab.ps1 -VMPath "C:\VMs\Olympus" -ISOPath "C:\path\to\WindowsServer.iso"
```

---

## 🔧 **Windows 11 OOBE Network Bypass (NEW!)**

**Critical Feature for Lab Deployment**: Both demo environments now include comprehensive Windows 11 OOBE (Out-of-Box Experience) network bypass capabilities to ensure smooth client VM setup without Microsoft account requirements.

### **Quick OOBE Bypass Command**

```cmd
# During Windows 11 setup, press Shift+F10 and run:
OOBE\BYPASSNRO
```

This command bypasses network requirements and allows direct local account creation for seamless domain joining in both lab environments.

**Benefits:**

- ✅ Skip forced Microsoft account creation
- ✅ Create local accounts for domain joining
- ✅ Avoid network dependency during setup
- ✅ Streamlined lab deployment process

## 📋 **Demo Comparison**

| Feature                    | Asgard Technologies | Olympus Systems |
| -------------------------- | ------------------- | --------------- |
| **Virtual Machines**       | 25 VMs              | 25 VMs          |
| **Mythology Theme**        | Norse               | Greek           |
| **Domain Name**            | asgard.local        | olympus.local   |
| **Enterprise Features**    | ✅ Complete         | ✅ Complete     |
| **Windows 11 OOBE Bypass** | ✅ Included         | ✅ Included     |
| **Cloud Integration**      | 🔶 Basic            | ✅ Advanced     |
| **AI/ML Capabilities**     | ❌                  | ✅ Full Suite   |
| **Security Suite**         | ✅ Standard         | ✅ Advanced     |
| **Deployment Time**        | 30-60 min           | 45-90 min       |
| **Hardware Requirements**  | 32GB RAM            | 64GB RAM        |

---

## 🛡️ **Advanced Security Features**

Both demos include comprehensive security features:

- **100+ Group Policy Objects** for enterprise security
- **Advanced threat protection** and monitoring
- **Compliance frameworks** (CIS, NIST, ISO 27001)
- **Security auditing** and reporting
- **Interactive security demonstrations**

Access advanced security features in both environments:

```powershell
# For Asgard
cd Demo/Asgard/Scripts
.\Deploy-AdvancedSecurityDemo.ps1 -DemoType "Asgard"

# For Olympus
cd Demo/Olympus/Scripts
.\Deploy-AdvancedSecurityDemo.ps1 -DemoType "Olympus"
```

---

## 📚 **Documentation Structure**

Each demo environment includes comprehensive documentation:

```
Demo/
├── README.md                        # This file - Demo environments overview
├── Asgard/                          # Norse mythology enterprise demo
│   ├── README.md                    # Asgard demo overview and features
│   ├── MANUAL_SETUP_ASGARD.md      # Step-by-step manual deployment
│   ├── Scripts/                     # Asgard deployment automation
│   │   ├── Deploy-AsgardLab.ps1     # Main Asgard deployment script
│   │   └── Deploy-AdvancedSecurityDemo.ps1  # Asgard security demo
│   ├── Guides/                      # Asgard quick start guides
│   │   ├── QUICK_START_ASGARD.md    # 30-minute Asgard deployment
│   │   ├── ASGARD_NETWORK_SHARE_SETUP.md  # Network shares setup
│   │   └── ADVANCED_SECURITY_QUICK_START.md  # Security features guide
│   └── Documentation/               # Asgard technical documentation
│       ├── DEMO_SETUP_GUIDE.md      # Complete Asgard setup guide
│       ├── HARDWARE_PERFORMANCE_GUIDE.md  # Performance optimization
│       └── NETWORK_SHARE_SETUP_GUIDE.md   # Network configuration
└── Olympus/                         # Greek mythology enterprise demo
    ├── README.md                    # Olympus demo overview and features
    ├── MANUAL_SETUP_OLYMPUS.md     # Step-by-step manual deployment
    ├── Scripts/                     # Olympus deployment automation
    │   ├── Deploy-OlympusLab.ps1    # Main Olympus deployment script
    │   └── Deploy-AdvancedSecurityDemo.ps1  # Olympus security demo
    ├── Guides/                      # Olympus quick start guides
    │   ├── QUICK_START_OLYMPUS.md   # 30-minute Olympus deployment
    │   └── OLYMPUS_NETWORK_SHARE_SETUP.md  # Network shares setup
    └── Documentation/               # Olympus technical documentation
        ├── DEMO_SETUP_GUIDE.md     # Complete Olympus setup guide
        └── HARDWARE_PERFORMANCE_GUIDE.md  # Performance optimization
```

---

## 🎓 **Learning Paths**

### **Beginner Path**

1. Start with [Asgard Technologies](Asgard/README.md)
2. Use the [Quick Start Guide](Asgard/Guides/QUICK_START_ASGARD.md)
3. Explore the basic lab tutorials in [LabSetupTutorials](../LabSetupTutorials/)

### **Advanced Path**

1. Begin with [Olympus Systems](Olympus/README.md)
2. Use the [Advanced Manual Setup](Olympus/MANUAL_SETUP_OLYMPUS.md)
3. Explore cloud integration and AI/ML features

### **Security Focus**

1. Deploy either environment
2. Run the advanced security demos
3. Study the enterprise security implementations

---

## 🔧 **System Requirements**

### **Minimum Requirements**

- **CPU**: 8 cores
- **RAM**: 32GB (Asgard) / 64GB (Olympus)
- **Storage**: 500GB SSD
- **OS**: Windows Server 2022 on Proxmox VE

### **Recommended Hardware**

- **CPU**: 12+ cores (AMD Ryzen 7900X or Intel equivalent)
- **RAM**: 64GB+ DDR5
- **Storage**: 1TB+ NVMe SSD
- **GPU**: Dedicated GPU for Olympus AI/ML features

---

## 🌟 **Choose Your Adventure**

**Ready for Standard Enterprise?** → [Start with Asgard Technologies](Asgard/README.md)  
**Want Advanced Features?** → [Explore Olympus Systems](Olympus/README.md)  
**Need Help Deciding?** → Both environments offer unique value!

---

## 📞 **Support and Resources**

- **Main Project**: [Windows Server Lab Repository](../README.md)
- **Tutorials**: [Lab Setup Tutorials](../LabSetupTutorials/)
- **Scripts**: [Management Scripts](../Scripts/)
- **Issues**: [GitHub Issues](https://github.com/YourRepo/WindowsServer-Lab/issues)

---

**🏛️ Welcome to the most comprehensive Windows Server lab demonstrations available! Choose your mythology and begin your enterprise journey! ⚡**
