# Asgard Network Validation Script
# This script validates the Asgard Technologies lab network configuration

[CmdletBinding()]
param(
  [switch]$Fix
)

function Write-TestResult {
  param(
    [string]$TestName,
    [string]$Result,
    [string]$Details,
    [string]$Color = "White"
  )
    
  $status = if ($Result -eq "PASS") { "✅" } else { "❌" }
  Write-Host "$status $TestName - $Details" -ForegroundColor $Color
}

function Test-AsgardNetworkConfiguration {
  Write-Host "`n🏰 ASGARD TECHNOLOGIES - Network Configuration Test" -ForegroundColor Magenta
  Write-Host "================================================================" -ForegroundColor Magenta
    
  $totalTests = 0
  $passedTests = 0
  $failedTests = 0
    
  # Test virtual switch configuration
  Write-Host "`n🔗 Virtual Switch Tests:" -ForegroundColor Yellow
  $expectedSwitches = @{
    "ASGARD-Production" = "Internal"
    "ASGARD-Management" = "Internal" 
    "ASGARD-Clients"    = "Internal"
    "ASGARD-DMZ"        = "Private"
  }
    
  foreach ($switchName in $expectedSwitches.Keys) {
    $totalTests++
    $expectedType = $expectedSwitches[$switchName]
    $vmSwitch = Get-VMSwitch -Name $switchName -ErrorAction SilentlyContinue
        
    if ($vmSwitch) {
      if ($vmSwitch.SwitchType -eq $expectedType) {
        Write-TestResult -TestName "Switch $switchName" -Result "PASS" -Details "Type: $($vmSwitch.SwitchType)" -Color "Green"
        $passedTests++
      }
      else {
        Write-TestResult -TestName "Switch $switchName" -Result "FAIL" -Details "Expected: $expectedType, Found: $($vmSwitch.SwitchType)" -Color "Red"
        $failedTests++
      }
    }
    else {
      Write-TestResult -TestName "Switch $switchName" -Result "FAIL" -Details "Switch not found" -Color "Red"
      $failedTests++
    }
  }
    
  # Test virtual adapter IP configuration
  Write-Host "`n🌐 Network Adapter IP Tests:" -ForegroundColor Yellow
  $expectedIPs = @{
    "vEthernet (ASGARD-Production)" = "10.0.10.1"
    "vEthernet (ASGARD-Management)" = "10.0.100.1"
    "vEthernet (ASGARD-Clients)"    = "10.0.20.1"
  }
    
  foreach ($adapterName in $expectedIPs.Keys) {
    $totalTests++
    $expectedIP = $expectedIPs[$adapterName]
    $adapter = Get-NetAdapter -Name $adapterName -ErrorAction SilentlyContinue
        
    if ($adapter) {
      $ipConfig = Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
      if ($ipConfig -and $ipConfig.IPAddress -eq $expectedIP) {
        Write-TestResult -TestName "IP $adapterName" -Result "PASS" -Details "IP: $($ipConfig.IPAddress)" -Color "Green"
        $passedTests++
      }
      else {
        $actualIP = if ($ipConfig) { $ipConfig.IPAddress } else { "None" }
        Write-TestResult -TestName "IP $adapterName" -Result "FAIL" -Details "Expected: $expectedIP, Found: $actualIP" -Color "Red"
        $failedTests++
      }
    }
    else {
      Write-TestResult -TestName "IP $adapterName" -Result "FAIL" -Details "Adapter not found" -Color "Red"
      $failedTests++
    }
  }
    
  # Test IP forwarding
  Write-Host "`n🔄 IP Forwarding Tests:" -ForegroundColor Yellow
  $interfaces = Get-NetIPInterface | Where-Object { $_.InterfaceAlias -like "*ASGARD*" -and $_.AddressFamily -eq "IPv4" }
    
  foreach ($interface in $interfaces) {
    $totalTests++
    if ($interface.Forwarding -eq "Enabled") {
      Write-TestResult -TestName "IP Forwarding $($interface.InterfaceAlias)" -Result "PASS" -Details "Enabled" -Color "Green"
      $passedTests++
    }
    else {
      Write-TestResult -TestName "IP Forwarding $($interface.InterfaceAlias)" -Result "FAIL" -Details "Disabled" -Color "Red"
      $failedTests++
    }
  }
    
  # Test NAT configuration
  Write-Host "`n🌍 NAT Configuration Tests:" -ForegroundColor Yellow
  $totalTests++
  $nat = Get-NetNat -Name "ASGARD-NAT" -ErrorAction SilentlyContinue
  if ($nat) {
    Write-TestResult -TestName "NAT Configuration" -Result "PASS" -Details "Prefix: $($nat.InternalIPInterfaceAddressPrefix)" -Color "Green"
    $passedTests++
  }
  else {
    Write-TestResult -TestName "NAT Configuration" -Result "FAIL" -Details "ASGARD-NAT not found" -Color "Red"
    $failedTests++
  }
    
  # Test gateway connectivity
  Write-Host "`n🚪 Gateway Connectivity Tests:" -ForegroundColor Yellow
  $gateways = @("10.0.10.1", "10.0.20.1", "10.0.100.1")
    
  foreach ($gateway in $gateways) {
    $totalTests++
    $ping = Test-NetConnection -ComputerName $gateway -InformationLevel Quiet -WarningAction SilentlyContinue
    if ($ping) {
      Write-TestResult -TestName "Gateway $gateway" -Result "PASS" -Details "Responding to ping" -Color "Green"
      $passedTests++
    }
    else {
      Write-TestResult -TestName "Gateway $gateway" -Result "FAIL" -Details "Not responding" -Color "Red"
      $failedTests++
    }
  }
    
  # Test VM network configuration
  Write-Host "`n💻 VM Network Tests:" -ForegroundColor Yellow
  $vms = Get-VM | Where-Object { $_.Name -like "*ASGARD*" -or $_.Name -like "*ODIN*" -or $_.Name -like "*FRIGG*" -or $_.Name -like "*HEIMDALL*" -or $_.Name -like "*BALDER*" -or $_.Name -like "*VIDAR*" -or $_.Name -like "*FREYA*" }
    
  foreach ($vm in $vms) {
    $totalTests++
    $networkAdapters = Get-VMNetworkAdapter -VMName $vm.Name -ErrorAction SilentlyContinue
    $connectedAdapters = $networkAdapters | Where-Object { $_.Connected -eq $true }
        
    if ($connectedAdapters.Count -gt 0) {
      Write-TestResult -TestName "VM $($vm.Name) Network" -Result "PASS" -Details "$($connectedAdapters.Count) adapter(s) connected" -Color "Green"
      $passedTests++
    }
    else {
      Write-TestResult -TestName "VM $($vm.Name) Network" -Result "FAIL" -Details "No connected adapters" -Color "Red"
      $failedTests++
    }
  }
    
  # Summary
  Write-Host "`n📊 Test Summary:" -ForegroundColor Cyan
  Write-Host "================================================================" -ForegroundColor Cyan
  Write-Host "Total Tests: $totalTests" -ForegroundColor White
  Write-Host "Passed: $passedTests" -ForegroundColor Green
  Write-Host "Failed: $failedTests" -ForegroundColor Red
    
  $successRate = [math]::Round(($passedTests / $totalTests) * 100, 1)
  Write-Host "Success Rate: $successRate%" -ForegroundColor $(if ($successRate -ge 80) { "Green" } else { "Yellow" })
    
  if ($failedTests -eq 0) {
    Write-Host "`n🎉 All network tests passed! Asgard network is ready." -ForegroundColor Green
  }
  else {
    Write-Host "`n⚠️  Some tests failed. Check configuration and run Deploy-AsgardLab.ps1 with -Force if needed." -ForegroundColor Yellow
  }
    
  return @{
    TotalTests  = $totalTests
    PassedTests = $passedTests
    FailedTests = $failedTests
    SuccessRate = $successRate
  }
}

# Quick connectivity test function
function Test-AsgardConnectivity {
  Write-Host "`n🔍 Quick Connectivity Test:" -ForegroundColor Cyan
    
  $tests = @(
    @{Name = "Production Gateway"; Target = "10.0.10.1" },
    @{Name = "Client Gateway"; Target = "10.0.20.1" },
    @{Name = "Management Gateway"; Target = "10.0.100.1" }
  )
    
  foreach ($test in $tests) {
    $result = Test-NetConnection -ComputerName $test.Target -InformationLevel Quiet -WarningAction SilentlyContinue
    $status = if ($result) { "✅" } else { "❌" }
    $color = if ($result) { "Green" } else { "Red" }
    Write-Host "$status $($test.Name) ($($test.Target))" -ForegroundColor $color
  }
}

# Main execution
if ($Fix) {
  Write-Host "🔧 Auto-fix mode not implemented yet. Please run Deploy-AsgardLab.ps1 with -Force to recreate network." -ForegroundColor Yellow
}
else {
  $results = Test-AsgardNetworkConfiguration
    
  if ($results.FailedTests -gt 0) {
    Write-Host "`nTo fix issues, run:" -ForegroundColor Yellow
    Write-Host "  .\Deploy-AsgardLab.ps1 -NetworkOnly -Force" -ForegroundColor White
    Write-Host "  .\Test-AsgardNetwork.ps1" -ForegroundColor White
  }
}

# Run quick connectivity test if not in Fix mode
if (-not $Fix) {
  Test-AsgardConnectivity
} 