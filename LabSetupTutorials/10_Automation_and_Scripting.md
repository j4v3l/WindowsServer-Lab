# 🤖 Windows Server Automation and Scripting Guide

## 🎯 What You'll Learn

- PowerShell scripting fundamentals
- Task automation
- Scheduled tasks and jobs
- Advanced automation techniques

## 📋 Prerequisites

- Working Windows Server environment
- Basic PowerShell knowledge
- Administrative access
- Completed previous guides

## 📝 PowerShell Scripting Fundamentals

### 1. Basic Script Structure

1. **Script Template**

   ```powershell
   # Script: ServerMaintenance.ps1
   [CmdletBinding()]
   param(
       [Parameter(Mandatory=$true)]
       [string]$ServerName,
       
       [Parameter(Mandatory=$false)]
       [int]$LogRetentionDays = 30
   )

   # Error handling
   $ErrorActionPreference = "Stop"

   # Logging function
   function Write-Log {
       param($Message)
       $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
       "$timestamp - $Message" | Out-File -FilePath "C:\Logs\Maintenance.log" -Append
   }

   # Main script logic
   try {
       Write-Log "Starting maintenance on $ServerName"
       # Your code here
   }
   catch {
       Write-Log "Error: $_"
       throw
   }
   ```

2. **Best Practices**
   - Use parameters
   - Implement error handling
   - Add logging
   - Include comments

### 2. Common Scripting Tasks

1. **File Operations**

   ```powershell
   # Create directory structure
   $directories = @(
       "C:\Logs",
       "C:\Backups",
       "C:\Scripts"
   )
   
   foreach ($dir in $directories) {
       if (-not (Test-Path $dir)) {
           New-Item -Path $dir -ItemType Directory
       }
   }
   ```

2. **Service Management**

   ```powershell
   # Check and restart services
   $services = @("Spooler", "PrintNotify")
   
   foreach ($service in $services) {
       $svc = Get-Service -Name $service
       if ($svc.Status -ne "Running") {
           Start-Service -Name $service
           Write-Log "Started service: $service"
       }
   }
   ```

## ⚙️ Task Automation

### 1. Scheduled Tasks

1. **Create Basic Task**

   ```powershell
   $action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
                                   -Argument "-File C:\Scripts\Maintenance.ps1"
   $trigger = New-ScheduledTaskTrigger -Daily -At 2AM
   $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable
   
   Register-ScheduledTask -TaskName "ServerMaintenance" `
                         -Action $action `
                         -Trigger $trigger `
                         -Settings $settings
   ```

2. **Advanced Task Configuration**

   ```powershell
   # Create task with multiple triggers
   $triggers = @(
       (New-ScheduledTaskTrigger -Daily -At 2AM),
       (New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 3AM)
   )
   
   $action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
                                   -Argument "-File C:\Scripts\WeeklyMaintenance.ps1"
   
   Register-ScheduledTask -TaskName "WeeklyMaintenance" `
                         -Action $action `
                         -Trigger $triggers `
                         -Settings $settings
   ```

### 2. Background Jobs

1. **Start Background Job**

   ```powershell
   $job = Start-Job -ScriptBlock {
       Get-Process | Where-Object CPU -gt 10
   }
   ```

2. **Monitor Job Status**

   ```powershell
   # Check job status
   Get-Job -Id $job.Id | Select-Object State, HasMoreData
   
   # Get job results
   Receive-Job -Id $job.Id
   ```

## 🔄 Advanced Automation

### 1. Remote Management

1. **Remote Session**

   ```powershell
   # Create remote session
   $session = New-PSSession -ComputerName "Server01"
   
   # Execute command remotely
   Invoke-Command -Session $session -ScriptBlock {
       Get-Service | Where-Object Status -eq "Stopped"
   }
   ```

2. **Remote File Operations**

   ```powershell
   # Copy files to remote server
   Copy-Item -Path "C:\Scripts\*" -Destination "\\Server01\C$\Scripts" -Recurse
   ```

### 2. Active Directory Automation

1. **User Management**

   ```powershell
   # Create multiple users
   $users = Import-Csv "C:\Scripts\NewUsers.csv"
   
   foreach ($user in $users) {
       New-ADUser -Name $user.Name `
                  -SamAccountName $user.SamAccountName `
                  -Department $user.Department `
                  -Enabled $true
   }
   ```

2. **Group Management**

   ```powershell
   # Add users to groups
   $groupMembers = Import-Csv "C:\Scripts\GroupMembers.csv"
   
   foreach ($member in $groupMembers) {
       Add-ADGroupMember -Identity $member.Group `
                        -Members $member.User
   }
   ```

## 📊 Monitoring and Reporting

### 1. Performance Monitoring

1. **Create Performance Report**

   ```powershell
   # Collect performance data
   $perfData = Get-Counter -Counter "\Processor(_Total)\% Processor Time" `
                          -SampleInterval 1 `
                          -MaxSamples 60
   
   # Export to CSV
   $perfData | Export-Csv -Path "C:\Reports\Performance.csv"
   ```

2. **Disk Space Monitoring**

   ```powershell
   # Check disk space
   Get-WmiObject Win32_LogicalDisk | 
   Where-Object {$_.DriveType -eq 3} | 
   Select-Object DeviceID, 
               @{Name="FreeSpace(GB)";Expression={$_.FreeSpace/1GB}},
               @{Name="TotalSize(GB)";Expression={$_.Size/1GB}}
   ```

### 2. Automated Reporting

1. **Create HTML Report**

   ```powershell
   # Generate HTML report
   $report = @"
   <html>
   <body>
   <h1>Server Status Report</h1>
   <p>Generated: $(Get-Date)</p>
   <h2>Services Status</h2>
   $(Get-Service | ConvertTo-Html)
   </body>
   </html>
   "@
   
   $report | Out-File "C:\Reports\ServerStatus.html"
   ```

2. **Email Report**

   ```powershell
   # Send report via email
   $smtpServer = "smtp.company.com"
   $from = "reports@company.com"
   $to = "admin@company.com"
   
   Send-MailMessage -SmtpServer $smtpServer `
                   -From $from `
                   -To $to `
                   -Subject "Server Status Report" `
                   -BodyAsHtml `
                   -Body $report
   ```

## 🛠️ Script Management

### 1. Version Control

1. **Script Organization**

   ```
   C:\Scripts
   ├── Production
   │   ├── Maintenance
   │   ├── Monitoring
   │   └── Reporting
   ├── Development
   └── Archive
   ```

2. **Documentation**

   ```powershell
   # Add script documentation
   <#
   .SYNOPSIS
       Server maintenance script
   .DESCRIPTION
       Performs routine maintenance tasks
   .PARAMETER ServerName
       Target server name
   .EXAMPLE
       .\Maintenance.ps1 -ServerName "Server01"
   #>
   ```

### 2. Error Handling

1. **Try-Catch Blocks**

   ```powershell
   try {
       # Attempt operation
       Get-Service -Name "NonExistentService"
   }
   catch {
       # Log error
       Write-Log "Error: $_"
       # Take alternative action
   }
   ```

2. **Error Logging**

   ```powershell
   # Log errors to file
   $Error | ForEach-Object {
       "$(Get-Date) - $($_.Exception.Message)" | 
       Out-File "C:\Logs\Errors.log" -Append
   }
   ```

## 🎯 Best Practices

### 1. Script Development

- Use consistent naming
- Implement error handling
- Add logging
- Document code

### 2. Automation

- Test in development
- Use version control
- Monitor execution
- Review logs

### 3. Security

- Use least privilege
- Secure credentials
- Validate input
- Audit access

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

## 🔗 Additional Resources

- [PowerShell Documentation](https://docs.microsoft.com/en-us/powershell/)
- [Windows Server Automation](https://docs.microsoft.com/en-us/windows-server/administration/windows-commands/windows-commands)
- [PowerShell Gallery](https://www.powershellgallery.com/)
