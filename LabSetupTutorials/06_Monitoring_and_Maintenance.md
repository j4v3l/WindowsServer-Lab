# 📊 Monitoring and Maintenance in Windows Server

## 🎯 What You'll Learn

- How to monitor server performance
- Regular maintenance tasks
- Backup and recovery procedures
- Update management
- Log analysis

## 📋 Prerequisites

- A working Windows Server domain (from [01_Setup_Lab_Environment.md](01_Setup_Lab_Environment.md))
- Basic understanding of Windows Server administration

## 🔍 Performance Monitoring

### 1. Task Manager

1. Press `Ctrl + Shift + Esc`
2. Check these tabs:
   - Performance (CPU, Memory, Disk, Network)
   - Processes (running applications)
   - Services (background services)

### 2. Resource Monitor

1. Press `Windows + R`
2. Type `resmon`
3. Monitor:
   - CPU usage
   - Memory usage
   - Disk activity
   - Network activity

### 3. Performance Monitor

1. Press `Windows + R`
2. Type `perfmon`
3. Create Data Collector Sets:

   ```
   System
   ├── Processor
   │   ├── % Processor Time
   │   └── Interrupts/sec
   ├── Memory
   │   ├── Available MBytes
   │   └── Pages/sec
   ├── Disk
   │   ├── % Disk Time
   │   └── Disk Queue Length
   └── Network
       ├── Bytes Total/sec
       └── Current Bandwidth
   ```

## 🔧 Regular Maintenance Tasks

### 1. Daily Tasks

- Check event logs
- Monitor disk space
- Verify backup status
- Check service status

### 2. Weekly Tasks

- Review performance logs
- Check security updates
- Verify DNS records
- Test backup restoration

### 3. Monthly Tasks

- Update Windows Server
- Review user accounts
- Check group memberships
- Verify GPO settings

## 💾 Backup and Recovery

### 1. Windows Server Backup

1. Install Windows Server Backup:

   ```powershell
   Install-WindowsFeature -Name Windows-Server-Backup
   ```

2. Configure backup schedule:
   - System State
   - Active Directory
   - System Reserved
   - C: Drive

### 2. Active Directory Backup

1. Create System State backup:

   ```powershell
   wbadmin start systemstatebackup -backuptarget:E:
   ```

2. Verify backup:

   ```powershell
   wbadmin get versions
   ```

### 3. Recovery Procedures

1. System State Recovery:

   ```powershell
   wbadmin start systemstaterecovery -version:MM/DD/YYYY-HH:MM
   ```

2. Active Directory Recovery:
   - Boot into Directory Services Restore Mode
   - Use `ntdsutil` for recovery

## 🔄 Update Management

### 1. Windows Update

1. Configure Windows Update:
   - Press `Windows + R`
   - Type `wuapp`
   - Set update schedule

2. Check for updates:

   ```powershell
   Get-WindowsUpdate
   Install-WindowsUpdate
   ```

### 3. WSUS (Windows Server Update Services)

1. Install WSUS:

   ```powershell
   Install-WindowsFeature -Name UpdateServices
   ```

2. Configure:
   - Products and classifications
   - Update schedule
   - Approval rules

## 📝 Log Analysis

### 1. Event Viewer

1. Press `Windows + R`
2. Type `eventvwr.msc`
3. Check these logs:

   ```
   Windows Logs
   ├── Application
   ├── Security
   ├── Setup
   └── System
   ```

### 2. PowerShell Log Analysis

```powershell
# Get recent errors
Get-EventLog -LogName System -EntryType Error -Newest 10

# Get failed login attempts
Get-EventLog -LogName Security -InstanceId 4625 -Newest 10

# Export logs to CSV
Get-EventLog -LogName System -Newest 100 | Export-Csv -Path "C:\Logs\SystemLogs.csv"
```

## 🔒 Security Monitoring

### 1. Windows Defender

1. Check status:

   ```powershell
   Get-MpComputerStatus
   ```

2. Run scan:

   ```powershell
   Start-MpScan -ScanType QuickScan
   ```

### 2. Firewall Monitoring

1. Check rules:

   ```powershell
   Get-NetFirewallRule | Where-Object Enabled -eq True
   ```

2. Monitor connections:

   ```powershell
   Get-NetTCPConnection | Where-Object State -eq Established
   ```

## 📊 Performance Optimization

### 1. Disk Optimization

1. Run defragmentation:

   ```powershell
   Optimize-Volume -DriveLetter C -Defrag
   ```

2. Check disk health:

   ```powershell
   Get-PhysicalDisk | Select-Object FriendlyName, HealthStatus
   ```

### 2. Memory Management

1. Check page file:

   ```powershell
   Get-CimInstance -ClassName Win32_PageFileSetting
   ```

2. Optimize services:

   ```powershell
   Get-Service | Where-Object StartType -eq Automatic
   ```

## 🎯 Best Practices

### 1. Documentation

- Keep maintenance logs
- Document all changes
- Track performance metrics
- Record backup status

### 2. Monitoring

- Set up alerts
- Create baselines
- Monitor trends
- Review reports

### 3. Security

- Regular security scans
- Update management
- Access control review
- Security log analysis

## ❓ Troubleshooting

### Performance Issues

1. Check resource usage
2. Review event logs
3. Analyze performance data
4. Optimize settings

### Backup Failures

1. Verify disk space
2. Check permissions
3. Review backup logs
4. Test recovery

## 📚 Next Steps

- Review previous guides:
  - [01_Setup_Lab_Environment.md](01_Setup_Lab_Environment.md)
  - [02_Manage_Users_Computers_AD.md](02_Manage_Users_Computers_AD.md)
  - [03_AD_Groups_Management.md](03_AD_Groups_Management.md)
  - [04_GPO_Creation_and_Linking.md](04_GPO_Creation_and_Linking.md)
  - [05_Troubleshooting.md](05_Troubleshooting.md)

## 🔗 Additional Resources

- [Microsoft Performance Monitor Guide](https://docs.microsoft.com/en-us/windows-server/administration/performance-tuning/)
- [Windows Server Backup Documentation](https://docs.microsoft.com/en-us/windows-server/administration/windows-server-backup/)
- [WSUS Documentation](https://docs.microsoft.com/en-us/windows-server/administration/windows-server-update-services/)
