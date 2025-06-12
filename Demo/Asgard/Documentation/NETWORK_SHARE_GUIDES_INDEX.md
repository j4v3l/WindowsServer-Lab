# 📁 Network Share Setup Guides Index

## 🎯 Overview

This index provides links to all available network share setup guides for the Windows Server Lab project. Choose the guide that matches your demo environment or use the generic guide for custom setups.

---

## 🏰 **Demo-Specific Guides**

### **Asgard Technologies Demo**

**🔗 [Asgard Network Share Setup Guide](../Guides/ASGARD_NETWORK_SHARE_SETUP.md)**

Norse mythology-themed network share setup for the Asgard Technologies corporate environment.

**Features:**

- HEIMDALL-FS01 file server configuration
- Norse-themed share names (Midgard-IT, Valhalla-Security, etc.)
- Asgard domain integration (asgard.local)
- Department-specific permissions for GRP-\* groups
- DFS namespace with realm-based paths

**Best for:** Enterprise scenarios with 25 VMs, Norse mythology theme

---

### **Olympus Systems Demo**

**🔗 [Olympus Network Share Setup Guide](../Olympus/Guides/OLYMPUS_NETWORK_SHARE_SETUP.md)**

Greek mythology-themed network share setup for the Olympus Systems divine corporate environment.

**Features:**

- HERMES-FS01 divine file server configuration
- Greek mythology-themed share names (Zeus-Command, Athena-AI, etc.)
- Olympus domain integration (olympus.local)
- Divine department permissions for divine GRP-\* groups
- Advanced AI/ML project shares
- Cloud integration preparation

**Best for:** Advanced scenarios with AI/ML features, Greek mythology theme

---

## 📚 **Generic Guides**

### **General Network Share Setup**

**🔗 [Generic Network Share Setup Guide](NETWORK_SHARE_SETUP_GUIDE.md)**

Comprehensive, non-themed network share setup guide for custom environments.

**Features:**

- Framework-agnostic instructions
- Multiple setup methods (GUI, PowerShell, Advanced)
- Security best practices
- Troubleshooting guidance
- Customizable for any domain

**Best for:** Custom lab environments, educational purposes, non-themed setups

---

## 🔧 **Quick Reference**

| Demo Environment        | File Server   | Domain        | Share Theme     | Guide Link                                                        |
| ----------------------- | ------------- | ------------- | --------------- | ----------------------------------------------------------------- |
| **Asgard Technologies** | HEIMDALL-FS01 | asgard.local  | Norse Mythology | [Asgard Guide](../Guides/ASGARD_NETWORK_SHARE_SETUP.md)           |
| **Olympus Systems**     | HERMES-FS01   | olympus.local | Greek Mythology | [Olympus Guide](../Olympus/Guides/OLYMPUS_NETWORK_SHARE_SETUP.md) |
| **Custom/Generic**      | Your Server   | your.domain   | Generic         | [Generic Guide](NETWORK_SHARE_SETUP_GUIDE.md)                     |

---

## 🎯 **Choosing the Right Guide**

### **Use Asgard Guide If:**

- You're deploying the Asgard Technologies demo
- You want Norse mythology-themed names
- You're using HEIMDALL-FS01 as file server
- You have asgard.local domain

### **Use Olympus Guide If:**

- You're deploying the Olympus Systems demo
- You want Greek mythology-themed names
- You're using HERMES-FS01 as file server
- You have olympus.local domain
- You need AI/ML specialized shares

### **Use Generic Guide If:**

- You're creating a custom lab environment
- You want to understand the underlying concepts
- You're adapting to your own naming convention
- You're teaching/learning Windows Server concepts

---

## 📋 **Common Features Across All Guides**

All network share setup guides include:

- ✅ **Step-by-step instructions** for GUI and PowerShell methods
- ✅ **NTFS permissions configuration** for proper security
- ✅ **SMB share creation** with appropriate access controls
- ✅ **Testing and verification** procedures
- ✅ **Security hardening** (SMB signing, auditing)
- ✅ **Troubleshooting guidance** for common issues
- ✅ **Advanced features** (DFS, access-based enumeration)

---

## 🛠️ **Prerequisites**

Before using any guide, ensure you have:

- Windows Server 2019/2022/2025 deployed
- Active Directory domain configured
- File Server role available
- Administrative privileges
- Network connectivity between servers and clients

---

## 🔗 **Related Resources**

- [Lab Setup Tutorials](../../LabSetupTutorials/)
- [Active Directory Groups Management](../../LabSetupTutorials/03_AD_Groups_Management.md)
- [Security Hardening Guide](../../LabSetupTutorials/09_Security_Hardening.md)
- [Troubleshooting Guide](../../LabSetupTutorials/05_Troubleshooting.md)

---

**📚 Choose your mythology and begin your epic file sharing journey!** 🚀
