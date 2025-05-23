# 🎛️ Group Policy Objects (GPOs) in Active Directory

## 🎯 What You'll Learn

- What Group Policy Objects are and why they're important
- How to create and manage GPOs
- How to link GPOs to OUs
- Common GPO settings and best practices

## 📋 Prerequisites

- A working Windows Server domain (from [01_Setup_Lab_Environment.md](01_Setup_Lab_Environment.md))
- Basic understanding of OUs and groups (from [02_Manage_Users_Computers_AD.md](02_Manage_Users_Computers_AD.md) and [03_AD_Groups_Management.md](03_AD_Groups_Management.md))

## 🔍 Understanding Group Policy

### What are GPOs?

Think of Group Policy Objects like rules for your network:

- They control how computers and users behave
- They help enforce security settings
- They can automate software installation
- They can customize the user experience

### Types of GPOs

1. **Computer Configuration**
   - Applies to computers regardless of who logs in
   - Examples:
     - Security settings
     - Software installation
     - Windows updates

2. **User Configuration**
   - Applies to users regardless of which computer they use
   - Examples:
     - Desktop settings
     - Start menu layout
     - Printer connections

## 🛠️ Creating and Managing GPOs

### Step 1: Open Group Policy Management

1. Press `Windows + R`
2. Type `gpmc.msc`
3. Press Enter

### Step 2: Create a New GPO

1. Right-click "Group Policy Objects"
2. Select "New"
3. Enter a name (e.g., "IT_Desktop_Settings")
4. Click OK

### Step 3: Edit the GPO

1. Right-click the new GPO
2. Select "Edit"
3. Navigate to desired settings:

   ```
   Computer Configuration
   └── Policies
       ├── Windows Settings
       │   ├── Security Settings
       │   └── Scripts
       └── Administrative Templates
           ├── Windows Components
           └── System
   ```

## 📝 Example: Common GPO Settings

### 1. Password Policy

1. Navigate to:

   ```
   Computer Configuration
   └── Policies
       └── Windows Settings
           └── Security Settings
               └── Account Policies
                   └── Password Policy
   ```

2. Configure:

   ```
   Minimum password length: 12
   Password complexity: Enabled
   Maximum password age: 90 days
   ```

### 2. Desktop Settings

1. Navigate to:

   ```
   User Configuration
   └── Policies
       └── Administrative Templates
           └── Desktop
   ```

2. Configure:

   ```
   Remove Recycle Bin: Disabled
   Hide Desktop Icons: Enabled
   ```

### 3. Security Settings

1. Navigate to:

   ```
   Computer Configuration
   └── Policies
       └── Windows Settings
           └── Security Settings
   ```

2. Configure:

   ```
   Account lockout threshold: 5 attempts
   Account lockout duration: 30 minutes
   ```

## 🔗 Linking GPOs to OUs

### Step 1: Link a GPO

1. Right-click the target OU
2. Select "Link an Existing GPO"
3. Choose your GPO
4. Click OK

### Step 2: Set Link Order

1. Select the OU
2. Go to "Linked Group Policy Objects" tab
3. Use "Move Up" and "Move Down" to set priority
   - Higher in list = higher priority

### Step 3: Set Inheritance

1. Right-click the OU
2. Select "Block Inheritance" if needed
   - This prevents GPOs from parent OUs

## 📋 Best Practices

### GPO Organization

1. Use clear naming conventions:

   ```
   GPO_IT_Security
   GPO_HR_Desktop
   GPO_Sales_Printers
   ```

2. Create a logical structure:

   ```
   Group Policy Objects
   ├── Security
   │   ├── Password Policy
   │   └── Account Lockout
   ├── Desktop
   │   ├── IT Settings
   │   └── HR Settings
   └── Software
       ├── Office Settings
       └── Browser Settings
   ```

### Testing GPOs

1. Create a test OU
2. Link GPO to test OU
3. Add test computer/user
4. Verify settings apply correctly
5. Move to production if successful

## 🎯 Common Tasks

### Update a GPO

1. Right-click GPO → Edit
2. Make changes
3. Close Group Policy Editor
   - Changes save automatically

### Disable a GPO

1. Right-click GPO → GPO Status
2. Choose:
   - "All settings disabled"
   - "Computer configuration disabled"
   - "User configuration disabled"

### Remove a GPO Link

1. Select the OU
2. Go to "Linked Group Policy Objects"
3. Right-click GPO → Delete
4. Choose "Remove the link"

## ❓ Troubleshooting

### GPO Not Applying?

1. Check if GPO is linked to correct OU
2. Verify inheritance is not blocked
3. Check if GPO is enabled
4. Look for conflicting GPOs
5. Run `gpupdate /force` on client

### GPO Takes Too Long?

1. Check GPO size
2. Look for slow network links
3. Verify DNS is working
4. Check for replication issues

## 📚 Next Steps

- Need help? Check [05_Troubleshooting.md](05_Troubleshooting.md)
- Review previous guides:
  - [01_Setup_Lab_Environment.md](01_Setup_Lab_Environment.md)
  - [02_Manage_Users_Computers_AD.md](02_Manage_Users_Computers_AD.md)
  - [03_AD_Groups_Management.md](03_AD_Groups_Management.md)
