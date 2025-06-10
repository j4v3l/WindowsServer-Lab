# 🚀 Setting Up Your First Windows Server Lab Environment

## 🎯 What You'll Learn

- How to set up a virtual machine for Windows Server
- Basic Windows Server installation
- Setting up Active Directory (AD) - the heart of Windows networking
- Creating your first domain

## 📋 Prerequisites

Before we begin, make sure you have:

1. A computer with at least 8GB RAM and 100GB free disk space
2. One of these virtualization programs installed:
   - [VMware Workstation Player](https://www.vmware.com/products/workstation-player.html) (Free)
   - [VirtualBox](https://www.virtualbox.org/) (Free)
   - [Hyper-V](https://docs.microsoft.com/en-us/virtualization/hyper-v-on-windows/quick-start/enable-hyper-v) (Free with Windows Pro)
3. Windows Server ISO file (2019 or 2022 recommended)
   - You can download a trial version from [Microsoft's website](https://www.microsoft.com/en-us/evalcenter/evaluate-windows-server-2019)

## 🖥️ Step 1: Create Your Virtual Machine

Think of a virtual machine (VM) as a computer within your computer. Here's how to create one:

### For Hyper-V Users (Recommended for Windows Pro/Enterprise)

1. Open **Hyper-V Manager** (search for it in Start Menu)
2. Click "New" → "Virtual Machine" in the Actions pane
3. Follow the New Virtual Machine Wizard:
   - Name: `DC1-LAB`
   - Generation: **Generation 2** (for better performance)
   - Memory: 4096 MB (4GB) with Dynamic Memory enabled
   - Network: Select your lab network switch (see [Hyper-V Setup Guide](16_Hyper-V_Setup_and_Configuration.md))
   - Hard disk: Create new, 80 GB, Dynamic expanding
   - Installation: Attach your Windows Server ISO

### For VirtualBox/VMware Users

1. Open your virtualization program
2. Click "New" or "Create Virtual Machine"
3. Set these recommended settings:
   - Name: `DC1` (DC stands for Domain Controller)
   - Type: Microsoft Windows
   - Version: Windows Server 2019 (64-bit)
   - Memory: 4096 MB (4GB)
   - Hard disk: 60 GB
   - Processors: 2

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

### For Hyper-V Labs

If you followed the [Hyper-V Setup Guide](16_Hyper-V_Setup_and_Configuration.md), your VM should have two network adapters:

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

### For VirtualBox/VMware Labs

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

## 🤖 Automated Setup Alternative

Instead of manual setup, you can use our automated PowerShell scripts:

### Using the Lab Setup Scripts

```powershell
# Navigate to the Scripts directory
cd Scripts

# Run the automated lab setup (you'll be prompted for passwords)
.\Lab_Setup.ps1

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
