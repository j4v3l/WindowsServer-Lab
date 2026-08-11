# 📝 Windows Server Naming Conventions Guide

## 🎯 What You'll Learn

- User account naming standards
- Computer naming conventions
- Server naming standards
- Group Policy naming rules
- Best practices for naming

## 📋 Prerequisites

- Basic understanding of Windows Server
- Knowledge of Active Directory
- Understanding of organizational structure

## 👤 User Account Naming

### 1. Standard User Accounts

1. **Format Options**

   ```
   FirstName.LastName        # John.Smith
   FirstInitialLastName      # JSmith
   LastNameFirstInitial      # SmithJ
   FirstName_LastName        # John_Smith
   ```

2. **Examples**

   ```
   john.smith@company.com
   jsmith@company.com
   smithj@company.com
   john_smith@company.com
   ```

3. **Best Practices**
   - Use consistent format
   - Avoid special characters
   - Keep it professional
   - Consider email compatibility

### 2. Administrative Accounts

1. **Format**

   ```
   admin.FirstName           # admin.John
   admin_FirstName           # admin_John
   FirstName.admin           # John.admin
   ```

2. **Examples**

   ```
   admin.john@company.com
   admin_john@company.com
   john.admin@company.com
   ```

## 💻 Computer Naming

### 1. Workstations

1. **Format Options**

   ```
   Location-Dept-Number      # NYC-FIN-001
   Dept-Location-Number      # FIN-NYC-001
   Location-Number           # NYC-001
   ```

2. **Examples**

   ```
   NYC-FIN-001
   LON-HR-042
   CHI-IT-123
   ```

### 2. Laptops

1. **Format**

   ```
   Location-LT-Number        # NYC-LT-001
   Dept-LT-Number           # FIN-LT-001
   ```

2. **Examples**

   ```
   NYC-LT-001
   LON-LT-042
   CHI-LT-123
   ```

## 🖥️ Server Naming

### 1. Physical Servers

1. **Format Options**

   ```
   Location-SRV-Role-Number  # NYC-SRV-DC-01
   Role-Location-Number      # DC-NYC-01
   Location-Role-Number      # NYC-DC-01
   ```

2. **Examples**

   ```
   NYC-SRV-DC-01
   LON-SRV-FS-01
   CHI-SRV-SQL-01
   ```

### 2. Virtual Servers

1. **Format**

   ```
   Location-VM-Role-Number   # NYC-VM-DC-01
   Role-VM-Location-Number   # DC-VM-NYC-01
   ```

2. **Examples**

   ```
   NYC-VM-DC-01
   LON-VM-FS-01
   CHI-VM-SQL-01
   ```

## 🔧 Group Policy Naming

### 1. Standard Policies

1. **Format Options**

   ```
   GPO-Role-Description      # GPO-Security-Baseline
   Role-Description          # Security-Baseline
   Description-Role          # Baseline-Security
   ```

2. **Examples**

   ```
   GPO-Security-Baseline
   GPO-Desktop-Standard
   GPO-Software-Deployment
   ```

### 2. Department Policies

1. **Format**

   ```
   GPO-Dept-Description      # GPO-FIN-Printers
   Dept-Description          # FIN-Printers
   ```

2. **Examples**

   ```
   GPO-FIN-Printers
   GPO-HR-Software
   GPO-IT-Security
   ```

## 📁 File Share Naming

### 1. Department Shares

1. **Format**

   ```
   Dept-ShareName            # FIN-Reports
   ShareName-Dept            # Reports-FIN
   ```

2. **Examples**

   ```
   FIN-Reports
   HR-Documents
   IT-Software
   ```

### 2. Project Shares

1. **Format**

   ```
   Project-ShareName         # ProjectX-Docs
   ShareName-Project         # Docs-ProjectX
   ```

2. **Examples**

   ```
   ProjectX-Docs
   ProjectY-Resources
   ProjectZ-Data
   ```

## 🔒 Security Group Naming

### 1. Access Groups

1. **Format**

   ```
   Access-Resource           # Access-FinanceShare
   Resource-Access           # FinanceShare-Access
   ```

2. **Examples**

   ```
   Access-FinanceShare
   Access-HRDatabase
   Access-ITSoftware
   ```

### 2. Department Groups

1. **Format**

   ```
   Dept-GroupName            # FIN-Users
   GroupName-Dept            # Users-FIN
   ```

2. **Examples**

   ```
   FIN-Users
   HR-Users
   IT-Users
   ```

## 📊 OU Structure Naming

### 1. Standard OUs

1. **Format**

   ```
   Location-Dept             # NYC-Finance
   Dept-Location             # Finance-NYC
   ```

2. **Examples**

   ```
   NYC-Finance
   LON-HR
   CHI-IT
   ```

### 2. Special OUs

1. **Format**

   ```
   Special-Purpose           # Service-Accounts
   Purpose-Special           # Accounts-Service
   ```

2. **Examples**

   ```
   Service-Accounts
   Admin-Accounts
   Test-Users
   ```

## 🎯 Best Practices

### 1. General Rules

- Use consistent format
- Avoid special characters
- Keep names descriptive
- Consider length limits
- Use standard separators

### 2. Documentation

- Document naming standards
- Maintain naming registry
- Regular review process
- Update as needed

### 3. Implementation

- Start with new objects
- Plan migration strategy
- Test naming patterns
- Monitor compliance

## 📚 Next Steps

- Review previous guides:
  - [01_Setup_Lab_Environment.md](01_Setup_Lab_Environment.md)
  - [02_Manage_Users_Computers_AD.md](02_Manage_Users_Computers_AD.md)
  - [03_AD_Groups_Management.md](03_AD_Groups_Management.md)
  - [04_GPO_Creation_and_Linking.md](04_GPO_Creation_and_Linking.md)
  - [05_Troubleshooting.md](05_Troubleshooting.md)
  - [06_Monitoring_and_Maintenance.md](06_Monitoring_and_Maintenance.md)
  - [07_Lab_Scenarios.md](07_Lab_Scenarios.md)
  - [08_Common_Mistakes.md](08_Common_Mistakes.md)
  - [09_Security_Hardening.md](09_Security_Hardening.md)
  - [10_Automation_and_Scripting.md](10_Automation_and_Scripting.md)

## 🔗 Additional Resources

- [Microsoft Naming Conventions](https://docs.microsoft.com/en-us/windows-server/identity/ad-ds/plan/selecting-the-forest-root-domain)
- [Active Directory security best practices](https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/plan/security-best-practices/best-practices-for-securing-active-directory)
- [Windows Server Documentation](https://docs.microsoft.com/en-us/windows-server/)
