# 👥 Managing Users and Computers in Active Directory

## 🎯 What You'll Learn

- How to create and manage user accounts
- How to add computers to your domain
- Best practices for organizing users and computers
- Basic security settings

## 📋 Prerequisites

- A working Windows Server domain (from [01_Setup_Lab_Environment.md](01_Setup_Lab_Environment.md))
- Logged in as a domain administrator

## 👤 Part 1: Creating User Accounts

### Understanding User Accounts

Think of user accounts like digital ID cards. Each user needs one to:

- Log into computers
- Access shared resources
- Send emails
- Use network services

### Step 1: Create Organizational Units (OUs)

OUs are like folders that help organize your users and computers.

1. Open Active Directory Users and Computers:

   - Press `Windows + R`
   - Type `dsa.msc`
   - Press Enter

2. Create these OUs (right-click your domain → New → Organizational Unit):

   ```
   IT
   HR
   Sales
   Interns
   ```

### Step 2: Create a User Account

Let's create a user account for John in the IT department:

1. Right-click the IT OU → New → User
2. Fill in these fields:

   ```
   First name: John
   Last name: Smith
   User logon name: john.smith
   ```

3. Click Next
4. Set a secure password:

   ```
   Password: [Enter a secure password meeting domain policy]
   Check: "User must change password at next logon"
   ```

   **Password Requirements:**

   - At least 8 characters (or as configured in domain policy)
   - Mix of uppercase, lowercase, numbers, and symbols
   - Not based on username or dictionary words

5. Click Finish

### Step 3: User Account Properties

Right-click the user → Properties to set:

- Email address
- Phone number
- Department
- Manager
- Profile path
- Home directory

## 💻 Part 2: Managing Computers

### Understanding Computer Accounts

Computer accounts are like user accounts for machines. They help:

- Track which computers are in your domain
- Apply security policies
- Manage software updates

### Step 1: Add a Computer to the Domain

1. On the client computer:
   - Press `Windows + R`
   - Type `sysdm.cpl`
   - Press Enter
2. Go to "Computer Name" tab
3. Click "Change"
4. Select "Domain"
5. Enter your domain name: `lab.local`
6. Enter domain admin credentials when prompted
7. Restart the computer

### Step 2: Create Computer Accounts in AD

1. In Active Directory Users and Computers:
   - Right-click the appropriate OU
   - New → Computer
2. Enter computer name (e.g., `CL-JOHN-PC`)
3. Click OK

## 🔒 Part 3: Security Best Practices

### Password Policies

1. Open Group Policy Management:
   - Press `Windows + R`
   - Type `gpmc.msc`
   - Press Enter
2. Navigate to: Default Domain Policy
3. Edit → Computer Configuration → Policies → Windows Settings → Security Settings → Account Policies → Password Policy
4. Set these recommended values:

   ```
   Minimum password length: 12
   Password complexity: Enabled
   Maximum password age: 90 days
   ```

### Account Lockout

1. In the same Group Policy:
   - Account Lockout Policy
2. Set these values:

   ```
   Account lockout threshold: 5 attempts
   Account lockout duration: 30 minutes
   Reset account lockout counter: 30 minutes
   ```

## 📝 Example: Creating Multiple Users

Here's a PowerShell script to create multiple users (save as `Create-Users.ps1`):

**EXECUTION CONTEXT: Run INSIDE Windows Server VM (Domain Controller)**  
**ACCESS METHOD: RDP, Console, or PowerShell Direct to Domain Controller VM**  
**PREREQUISITES: Domain Administrator rights, Active Directory module**

```powershell
# Create IT Users with secure password prompts
$SecurePassword = Read-Host -AsSecureString -Prompt "Enter default password for new users"

New-ADUser -Name "John Smith" -GivenName "John" -Surname "Smith" `
    -SamAccountName "john.smith" -UserPrincipalName "john.smith@lab.local" `
    -Path "OU=IT,DC=lab,DC=local" -AccountPassword $SecurePassword `
    -Enabled $true -ChangePasswordAtLogon $true

New-ADUser -Name "Sarah Johnson" -GivenName "Sarah" -Surname "Johnson" `
    -SamAccountName "sarah.johnson" -UserPrincipalName "sarah.johnson@lab.local" `
    -Path "OU=IT,DC=lab,DC=local" -AccountPassword $SecurePassword `
    -Enabled $true -ChangePasswordAtLogon $true
```

**Security Benefits:**

- ✅ No hardcoded passwords in scripts
- ✅ Password entered securely as SecureString
- ✅ Can reuse secure password for multiple user creation
- ✅ Follows PowerShell security best practices

## 🎯 Common Tasks

### Reset a User's Password

1. Right-click the user → Reset Password
2. Enter new password
3. Check "User must change password at next logon"

### Disable a User Account

1. Right-click the user → Disable Account
2. Confirm the action

### Move a User to Different OU

1. Right-click the user → Move
2. Select the target OU
3. Click OK

## ❓ Troubleshooting

### User Can't Log In?

1. Check if account is enabled
2. Verify password hasn't expired
3. Check if account is locked
4. Verify user is in correct OU

### Computer Can't Join Domain?

1. Check network connectivity
2. Verify DNS settings
3. Ensure computer name is unique
4. Check domain admin credentials

## 📚 Next Steps

- Learn about managing groups in [03_AD_Groups_Management.md](03_AD_Groups_Management.md)
- Understand Group Policy in [04_GPO_Creation_and_Linking.md](04_GPO_Creation_and_Linking.md)
- Need help? Check [05_Troubleshooting.md](05_Troubleshooting.md)
