# 🚀 Setting Up Your First Windows Server Lab Environment

## 🎯 What You'll Learn

- How to set up a virtual machine for Windows Server
- Basic Windows Server installation
- Setting up Active Directory (AD) - the heart of Windows networking
- Creating your first domain

## 📋 Prerequisites

Before we begin, make sure you have:

1. **Proxmox VE server** with at least 16GB RAM and 500GB free disk space
2. **Proxmox VE 8.0+** installed and configured
   - Access to the Proxmox web interface (<https://your-proxmox-ip:8006>)
   - Network connectivity configured
   - Basic storage configuration completed
3. **Windows Server ISO file** (2019, 2022, or 2025 recommended)
   - You can download a trial version from [Microsoft's website](https://www.microsoft.com/en-us/evalcenter/evaluate-windows-server-2019)
4. **VirtIO drivers ISO** for optimal Windows performance on Proxmox

## 🖥️ Step 1: Create Your Virtual Machine

Think of a virtual machine (VM) as a computer within your Proxmox server. Here's how to create one:

### Creating DC1-LAB (Domain Controller) in Proxmox

1. **Access Proxmox Web Interface**
   - Open browser and navigate to `https://your-proxmox-ip:8006`
   - Login with your Proxmox credentials

2. **Click "Create VM"** in the top-right corner

3. **General Settings**:

   ```
   VM ID: 100
   Name: DC1-LAB
   Resource Pool: (leave default)
   ```

4. **OS Settings**:

   ```
   Use CD/DVD disc image file (iso): ✓
   Storage: local
   ISO image: Select your Windows Server ISO
   Type: Microsoft Windows
   Version: 10/2016/2019/2022/2025 (win10)
   ```

5. **System Settings**:

   ```
   Graphic card: Default
   Machine: q35
   BIOS: OVMF (UEFI) - Recommended for Windows
   EFI Storage: local-lvm
   Pre-Enroll keys: ✓
   SCSI Controller: VirtIO SCSI single
   Qemu Agent: ✓ (for better integration)
   ```

6. **Hard Disk**:

   ```
   Storage: local-lvm
   Disk size (GB): 80
   Cache: Write back (for better performance)
   Discard: ✓
   SSD emulation: ✓ (if using SSD storage)
   ```

7. **CPU**:

   ```
   Sockets: 1
   Cores: 4
   Type: host (for best performance)
   ```

8. **Memory**:

   ```
   Memory (MB): 4096
   Ballooning: ✓ (for dynamic memory)
   ```

9. **Network**:

   ```
   Bridge: vmbr0 (or your configured bridge)
   Model: VirtIO (paravirtualized - best performance)
   ```

10. **Confirm** settings and create the VM

## 💿 Step 2: Install Windows Server

1. Start your new VM
2. When prompted, select your Windows Server ISO file
3. Follow these installation steps:

   ```
   Language: English
   Time format: Your local time
   Keyboard: Your local keyboard
   ```

4. Click "Install Now"
5. Choose "Windows Server 2019 Standard (Desktop Experience)"
   - Desktop Experience gives you a graphical interface like regular Windows

## 🌐 Step 3: Configure Network Settings

### For Proxmox VE Labs

If you followed the [Proxmox VE Setup Guide](16_Proxmox_Setup_and_Configuration.md), your VM should have two network adapters:

1. **External Adapter** (for internet access):

   - IP Address: 192.168.1.100 (or your network range)
   - Subnet Mask: 255.255.255.0
   - Default Gateway: 192.168.1.1 (your router)
   - DNS Server: 192.168.1.100 (same as IP address)

2. **Management Adapter** (for lab management):
   - IP Address: 192.168.100.10
   - Subnet Mask: 255.255.255.0
   - Default Gateway: 192.168.100.1
   - DNS Server: 192.168.100.10 (same as IP address)

### For Alternative Virtualization Platforms

1. After installation, press `Windows + X` and select "Network Connections"
2. Right-click your network adapter and select "Properties"
3. Select "Internet Protocol Version 4 (TCP/IPv4)" and click "Properties"
4. Enter these settings (adjust if your network is different):

   ```
   IP Address: 192.168.1.100
   Subnet Mask: 255.255.255.0
   Default Gateway: 192.168.1.1
   DNS Server: 192.168.1.100 (same as IP address)
   ```

## 🏗️ Step 4: Install Active Directory

Active Directory is like a phone book for your network - it keeps track of all users, computers, and settings.

1. Open "Server Manager" (it opens automatically after installation)
2. Click "Add roles and features"
3. Click "Next" until you reach "Server Roles"
4. Check "Active Directory Domain Services"
5. Click "Add Features" when prompted
6. Click "Next" through the wizard
7. Click "Install"
8. Wait for installation to complete
9. Click "Promote this server to a domain controller"

## 🎪 Step 5: Create Your First Domain

1. In the "Active Directory Domain Services Configuration Wizard":
   - Select "Add a new forest"
   - Enter your domain name: `lab.local`
   - Click "Next"
2. Set a Directory Services Restore Mode (DSRM) password:
   - This is like a master key for your domain
   - Use a strong password and write it down securely
   - **Important**: This password is required when using the automated lab scripts
   - Requirements: At least 8 characters with complexity (uppercase, lowercase, numbers, symbols)
3. Click "Next" through the remaining steps
4. Click "Install"
5. The server will restart automatically

## ✅ Step 6: Verify Everything Works

1. After restart, log in with your domain credentials
2. Press `Windows + R`, type `dsa.msc`, and press Enter
   - This opens Active Directory Users and Computers
3. You should see your domain (`lab.local`) with these folders:
   - Builtin
   - Computers
   - Domain Controllers
   - Users

## 🎉 Congratulations

You've just set up your first Windows Server domain! This is the foundation for:

- Managing users and computers
- Setting up security policies
- Creating shared resources
- And much more!

## 🤖 Automated Setup Alternatives

Instead of manual setup, you have several options:

### Epic Demo Environments (Recommended)

For a complete, realistic Windows Server lab experience:

- **🏰 [Asgard Technologies Demo](../Demo/README.md)**: 25-VM Norse mythology enterprise

  - Automated deployment: [Quick Start Guide](../Demo/Asgard/Guides/QUICK_START_ASGARD.md)
  - Manual step-by-step: [Manual Setup Guide](../Demo/Asgard/MANUAL_SETUP_ASGARD.md)

- **⚡ [Olympus Systems Demo](../Demo/Olympus/README.md)**: 25-VM Greek mythology enterprise with advanced features
  - Automated deployment: [Quick Start Guide](../Demo/Olympus/Guides/QUICK_START_OLYMPUS.md)
  - Manual step-by-step: [Manual Setup Guide](../Demo/Olympus/MANUAL_SETUP_OLYMPUS.md)

### Basic Lab Setup Scripts

For a simple lab setup:

```powershell
# Navigate to the Scripts directory
cd Scripts

# Run the automated lab setup (you'll be prompted for passwords)
.\Lab-FinishSetup.ps1

# Or run individual components
.\Create-LabUsers.ps1          # Creates users and groups
.\Lab-FinishSetup.ps1          # Completes post-installation setup
```

### Password Requirements for Automated Scripts

When using the automated scripts, you'll be prompted for:

1. **Safe Mode Password** (same as DSRM password above)

   - Used for domain controller recovery
   - Must meet complexity requirements

2. **Default User Password** (for newly created accounts)
   - Applied to all lab user accounts
   - Users will be prompted to change on first login
   - Must meet domain password policy

### Security Benefits

- 🔒 **No hardcoded passwords** in any scripts
- 🔐 **Secure password entry** using PowerShell's SecureString
- ✅ **Runtime validation** ensures passwords meet requirements
- 🛡️ **Security audit compliant** (0 critical vulnerabilities)

## 📚 Next Steps

- Learn how to create users and computers in [02_Manage_Users_Computers_AD.md](02_Manage_Users_Computers_AD.md)
- Understand how to manage groups in [03_AD_Groups_Management.md](03_AD_Groups_Management.md)
- Learn about Group Policy in [04_GPO_Creation_and_Linking.md](04_GPO_Creation_and_Linking.md)

## ❓ Common Issues and Solutions

1. **Can't connect to the internet?**

   - Check your network adapter settings
   - Make sure your IP settings are correct

2. **Installation fails?**

   - Make sure you have enough disk space
   - Verify your ISO file isn't corrupted

3. **Can't promote to domain controller?**
   - Check if you have a static IP address
   - Make sure DNS is pointing to your server's IP

Need help? Check out [05_Troubleshooting.md](05_Troubleshooting.md) for more detailed solutions!
