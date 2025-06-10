# Module Integrity Test Script
# This script validates the PowerShell module structure and consistency

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$ModulePath = $PSScriptRoot

Write-Host "🔍 Testing WindowsServerLab Module Integrity..." -ForegroundColor Cyan

# Test 1: Manifest file exists and is valid
Write-Host "`n1. Testing module manifest..." -ForegroundColor Yellow
$manifestPath = Join-Path $ModulePath "WindowsServerLab.psd1"
if (Test-Path $manifestPath) {
    try {
        $manifest = Test-ModuleManifest -Path $manifestPath -ErrorAction Stop
        Write-Host "   ✅ Manifest is valid" -ForegroundColor Green
        Write-Host "   📦 Module: $($manifest.Name) v$($manifest.Version)" -ForegroundColor Cyan
    } catch {
        Write-Host "   ❌ Manifest validation failed: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "   ❌ Manifest file not found" -ForegroundColor Red
    exit 1
}

# Test 2: Module file exists
Write-Host "`n2. Testing module file..." -ForegroundColor Yellow
$modulePath = Join-Path $ModulePath "WindowsServerLab.psm1"
if (Test-Path $modulePath) {
    Write-Host "   ✅ Module file exists" -ForegroundColor Green
} else {
    Write-Host "   ❌ Module file not found" -ForegroundColor Red
    exit 1
}

# Test 3: All files listed in manifest exist
Write-Host "`n3. Testing file list integrity..." -ForegroundColor Yellow
$missingFiles = @()
foreach ($file in $manifest.FileList) {
    $filePath = Join-Path $ModulePath $file
    if (-not (Test-Path $filePath)) {
        $missingFiles += $file
    }
}

if ($missingFiles.Count -eq 0) {
    Write-Host "   ✅ All listed files exist ($($manifest.FileList.Count) files)" -ForegroundColor Green
} else {
    Write-Host "   ❌ Missing files:" -ForegroundColor Red
    foreach ($file in $missingFiles) {
        Write-Host "      - $file" -ForegroundColor Red
    }
    exit 1
}

# Test 4: Try to import the module
Write-Host "`n4. Testing module import..." -ForegroundColor Yellow
try {
    # Remove if already loaded
    if (Get-Module WindowsServerLab) {
        Remove-Module WindowsServerLab -Force
    }
    
    # Import the module
    Import-Module $manifestPath -Force -ErrorAction Stop
    Write-Host "   ✅ Module imported successfully" -ForegroundColor Green
    
    # Test exported functions
    $exportedFunctions = Get-Command -Module WindowsServerLab -CommandType Function
    Write-Host "   📋 Exported functions: $($exportedFunctions.Count)" -ForegroundColor Cyan
    
    foreach ($func in $exportedFunctions) {
        Write-Host "      - $($func.Name)" -ForegroundColor Gray
    }
    
} catch {
    Write-Host "   ❌ Module import failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test 5: Compare exported functions with manifest
Write-Host "`n5. Testing function export consistency..." -ForegroundColor Yellow
$manifestFunctions = $manifest.ExportedFunctions.Keys | Sort-Object
$actualFunctions = (Get-Command -Module WindowsServerLab -CommandType Function).Name | Sort-Object

$comparison = Compare-Object $manifestFunctions $actualFunctions
if ($comparison) {
    Write-Host "   ⚠️  Function export inconsistencies found:" -ForegroundColor Yellow
    foreach ($diff in $comparison) {
        if ($diff.SideIndicator -eq "<=") {
            Write-Host "      - Manifest lists but not exported: $($diff.InputObject)" -ForegroundColor Red
        } else {
            Write-Host "      - Exported but not in manifest: $($diff.InputObject)" -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "   ✅ Function exports match manifest" -ForegroundColor Green
}

# Test 6: Test function help
Write-Host "`n6. Testing function help documentation..." -ForegroundColor Yellow
$functionsWithoutHelp = @()
foreach ($func in $exportedFunctions) {
    $help = Get-Help $func.Name -ErrorAction SilentlyContinue
    if (-not $help.Synopsis -or $help.Synopsis -like "*$($func.Name)*") {
        $functionsWithoutHelp += $func.Name
    }
}

if ($functionsWithoutHelp.Count -eq 0) {
    Write-Host "   ✅ All functions have help documentation" -ForegroundColor Green
} else {
    Write-Host "   ⚠️  Functions missing proper help:" -ForegroundColor Yellow
    foreach ($func in $functionsWithoutHelp) {
        Write-Host "      - $func" -ForegroundColor Yellow
    }
}

# Test 7: Validate script syntax
Write-Host "`n7. Testing PowerShell script syntax..." -ForegroundColor Yellow
$scriptsWithErrors = @()
foreach ($file in $manifest.FileList) {
    if ($file -like "*.ps1") {
        $filePath = Join-Path $ModulePath $file
        try {
            $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $filePath -Raw), [ref]$null)
        } catch {
            $scriptsWithErrors += @{
                File = $file
                Error = $_.Exception.Message
            }
        }
    }
}

if ($scriptsWithErrors.Count -eq 0) {
    Write-Host "   ✅ All PowerShell scripts have valid syntax" -ForegroundColor Green
} else {
    Write-Host "   ❌ Scripts with syntax errors:" -ForegroundColor Red
    foreach ($script in $scriptsWithErrors) {
        Write-Host "      - $($script.File): $($script.Error)" -ForegroundColor Red
    }
    exit 1
}

# Summary
Write-Host "`n🎉 Module integrity test completed!" -ForegroundColor Green
Write-Host "   📦 Module: WindowsServerLab v$($manifest.Version)" -ForegroundColor Cyan
Write-Host "   📋 Functions: $($exportedFunctions.Count)" -ForegroundColor Cyan
Write-Host "   📄 Files: $($manifest.FileList.Count)" -ForegroundColor Cyan
Write-Host "   ✅ Ready for use!" -ForegroundColor Green

# Clean up
Remove-Module WindowsServerLab -Force -ErrorAction SilentlyContinue 