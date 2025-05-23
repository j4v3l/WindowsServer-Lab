# 👥 Managing Groups in Active Directory

## 🎯 What You'll Learn

- How to create and manage security groups
- Understanding group types and scopes
- Best practices for group organization
- How to use groups for permissions

## 📋 Prerequisites

- A working Windows Server domain (from [01_Setup_Lab_Environment.md](01_Setup_Lab_Environment.md))
- Basic understanding of users and computers (from [02_Manage_Users_Computers_AD.md](02_Manage_Users_Computers_AD.md))

## 🔍 Understanding Groups

### What are Groups?

Think of groups like clubs in your organization:

- They help manage permissions for multiple users at once
- Make it easier to control access to resources
- Help organize users by department or role

### Types of Groups

1. **Security Groups** (Most Common)
   - Used for permissions and access control
   - Can be used for email distribution
   - Example: "IT_Staff" group for IT department access

2. **Distribution Groups**
   - Used only for email distribution
   - Cannot be used for permissions
   - Example: "All_Employees" for company-wide emails

### Group Scopes

1. **Domain Local**
   - Can contain users from any domain
   - Used for resources in the same domain
   - Example: "Printer_Access" for local printer permissions

2. **Global**
   - Can contain users from same domain only
   - Used to organize users by department
   - Example: "IT_Staff" for all IT department users

3. **Universal**
   - Can contain users from any domain
   - Used in multi-domain environments
   - Example: "Enterprise_Admins" for cross-domain administration

## 🛠️ Creating and Managing Groups

### Step 1: Create a Security Group

1. Open Active Directory Users and Computers:
   - Press `Windows + R`
   - Type `dsa.msc`
   - Press Enter

2. Navigate to the appropriate OU (e.g., IT)
3. Right-click → New → Group
4. Fill in these fields:

   ```
   Group name: IT_Staff
   Group scope: Global
   Group type: Security
   ```

5. Click OK

### Step 2: Add Users to the Group

1. Right-click the group → Properties
2. Go to "Members" tab
3. Click "Add"
4. Type user names or click "Advanced" to search
5. Click OK

## 📝 Example: Creating Department Groups

Here's a PowerShell script to create department groups (save as `Create-Groups.ps1`):

```powershell
# Create department groups
$departments = @("IT", "HR", "Sales", "Finance")

foreach ($dept in $departments) {
    $groupName = "GRP-$dept"
    $ouPath = "OU=$dept,DC=lab,DC=local"
    
    # Create the group
    New-ADGroup -Name $groupName `
                -GroupScope Global `
                -GroupCategory Security `
                -Path $ouPath
    
    # Add users from that OU to the group
    Get-ADUser -Filter * -SearchBase $ouPath | ForEach-Object {
        Add-ADGroupMember -Identity $groupName -Members $_
    }
}
```

## 🔒 Using Groups for Permissions

### Example 1: Shared Folder Access

1. Create a shared folder
2. Right-click → Properties → Security
3. Click "Edit" → "Add"
4. Type the group name (e.g., "IT_Staff")
5. Set permissions:

   ```
   IT_Staff: Modify
   Everyone: Read
   ```

### Example 2: Printer Access

1. Open Printer Properties
2. Go to Security tab
3. Add group and set permissions:

   ```
   IT_Staff: Print, Manage Documents
   Sales_Staff: Print
   ```

## 📋 Best Practices

### Naming Conventions

Use clear, consistent names:

- Department groups: `GRP-IT`, `GRP-HR`
- Resource access: `ACC-Printer1`, `ACC-SharedFolder1`
- Role-based: `ROLE-Administrators`, `ROLE-PowerUsers`

### Group Organization

1. Create a logical structure:

   ```
   Groups
   ├── Department
   │   ├── IT
   │   ├── HR
   │   └── Sales
   ├── Resource Access
   │   ├── Printers
   │   └── Shared Folders
   └── Roles
       ├── Administrators
       └── Power Users
   ```

2. Use nested groups when appropriate:
   - Create a "Managers" group
   - Add department manager groups to it

## 🎯 Common Tasks

### Add Multiple Users to a Group

1. Select multiple users in AD
2. Right-click → Add to a group
3. Enter group name
4. Click OK

### Remove Users from a Group

1. Open group properties
2. Select users in "Members" tab
3. Click "Remove"
4. Confirm

### Find Group Members

1. Right-click group → Properties
2. Go to "Members" tab
3. Or use PowerShell:

   ```powershell
   Get-ADGroupMember -Identity "IT_Staff"
   ```

## ❓ Troubleshooting

### User Can't Access Resource?

1. Check if user is in correct group
2. Verify group has proper permissions
3. Check if permissions are inherited
4. Look for deny permissions

### Group Changes Not Taking Effect?

1. Wait for replication (usually 15 minutes)
2. Check if user has logged out and back in
3. Verify group scope is correct
4. Check for conflicting permissions

## 📚 Next Steps

- Learn about Group Policy in [04_GPO_Creation_and_Linking.md](04_GPO_Creation_and_Linking.md)
- Need help? Check [05_Troubleshooting.md](05_Troubleshooting.md)
