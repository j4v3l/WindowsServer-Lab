# Module Integrity Test Script
# This script validates the PowerShell module structure and consistency

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$ModulePath = $PSScriptRoot

# Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "Testing WindowsServerLab Module Integrity..." -ForegroundColor Cyan

# Test 1: Manifest file exists and is valid
# Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "`n1. Testing module manifest..." -ForegroundColor Yellow
$manifestPath = Join-Path $ModulePath "WindowsServerLab.psd1"
if (Test-Path $manifestPath) {
    try {
        $manifest = Test-ModuleManifest -Path $manifestPath -ErrorAction Stop
        # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "   [OK] Manifest is valid" -ForegroundColor Green
        # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "   Module: $($manifest.Name) v$($manifest.Version)" -ForegroundColor Cyan
    }
    catch {
        # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "   [ERROR] Manifest validation failed: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}
else {
    # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "   [ERROR] Manifest file not found" -ForegroundColor Red
    exit 1
}

# Test 2: Module file exists
# Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "`n2. Testing module file..." -ForegroundColor Yellow
$moduleFilePath = Join-Path $ModulePath "WindowsServerLab.psm1"
if (Test-Path $moduleFilePath) {
    # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "   [OK] Module file exists" -ForegroundColor Green
}
else {
    # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "   [ERROR] Module file not found" -ForegroundColor Red
    exit 1
}

# Test 3: All files listed in manifest exist
# Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "`n3. Testing file list integrity..." -ForegroundColor Yellow
$missingFiles = @()
foreach ($file in $manifest.FileList) {
    # The manifest returns absolute paths, so use them directly
    if (-not (Test-Path $file)) {
        $missingFiles += $file
        # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "   Missing: $file" -ForegroundColor Red
    }
    else {
        $fileName = Split-Path $file -Leaf
        # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "   Found: $fileName" -ForegroundColor Gray
    }
}

if ($missingFiles.Count -eq 0) {
    # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "   [OK] All listed files exist ($($manifest.FileList.Count) files)" -ForegroundColor Green
}
else {
    # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "   [ERROR] Missing files:" -ForegroundColor Red
    foreach ($file in $missingFiles) {
        Write-Host "      - $file" -ForegroundColor Red
    }
    exit 1
}

# Test 4: Try to import the module
# Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "`n4. Testing module import..." -ForegroundColor Yellow
try {
    # Remove if already loaded
    if (Get-Module WindowsServerLab) {
        Remove-Module WindowsServerLab -Force
    }
    
    # Import the module
    Import-Module $manifestPath -Force -ErrorAction Stop
    # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "   [OK] Module imported successfully" -ForegroundColor Green
    
    # Test exported functions
    $exportedFunctions = Get-Command -Module WindowsServerLab -CommandType Function
    # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "   Exported functions: $($exportedFunctions.Count)" -ForegroundColor Cyan
    
    foreach ($func in $exportedFunctions) {
        Write-Host "      - $($func.Name)" -ForegroundColor Gray
    }
}
catch {
    # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "   [ERROR] Module import failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test 5: Compare exported functions with manifest
# Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "`n5. Testing function export consistency..." -ForegroundColor Yellow
$manifestFunctions = $manifest.ExportedFunctions.Keys | Sort-Object
$actualFunctions = (Get-Command -Module WindowsServerLab -CommandType Function).Name | Sort-Object

$comparison = Compare-Object $manifestFunctions $actualFunctions
if ($comparison) {
    # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "   [WARNING] Function export inconsistencies found:" -ForegroundColor Yellow
    foreach ($diff in $comparison) {
        if ($diff.SideIndicator -eq "<=") {
            Write-Host "      - Manifest lists but not exported: $($diff.InputObject)" -ForegroundColor Red
        }
        else {
            Write-Host "      - Exported but not in manifest: $($diff.InputObject)" -ForegroundColor Yellow
        }
    }
}
else {
    # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "   [OK] Function exports match manifest" -ForegroundColor Green
}

# Test 6: Test function help
# Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "`n6. Testing function help documentation..." -ForegroundColor Yellow
$functionsWithoutHelp = @()
foreach ($func in $exportedFunctions) {
    $help = Get-Help $func.Name -ErrorAction SilentlyContinue
    if (-not $help.Synopsis -or $help.Synopsis -like "*$($func.Name)*") {
        $functionsWithoutHelp += $func.Name
    }
}

if ($functionsWithoutHelp.Count -eq 0) {
    # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "   [OK] All functions have help documentation" -ForegroundColor Green
}
else {
    # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "   [WARNING] Functions missing proper help:" -ForegroundColor Yellow
    foreach ($func in $functionsWithoutHelp) {
        Write-Host "      - $func" -ForegroundColor Yellow
    }
}

# Test 7: Validate script syntax
# Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "`n7. Testing PowerShell script syntax..." -ForegroundColor Yellow
$scriptsWithErrors = @()
foreach ($file in $manifest.FileList) {
    if ($file -like "*.ps1") {
        # The manifest returns absolute paths, so use them directly
        try {
            $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $file -Raw), [ref]$null)
        }
        catch {
            $scriptsWithErrors += @{
                File  = $file
                Error = $_.Exception.Message
            }
        }
    }
}

if ($scriptsWithErrors.Count -eq 0) {
    # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "   [OK] All PowerShell scripts have valid syntax" -ForegroundColor Green
}
else {
    # Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "   [ERROR] Scripts with syntax errors:" -ForegroundColor Red
    foreach ($script in $scriptsWithErrors) {
        Write-Host "      - $($script.File): $($script.Error)" -ForegroundColor Red
    }
    exit 1
}

# Summary
# Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "`nModule integrity test completed!" -ForegroundColor Green
# Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "   Module: WindowsServerLab v$($manifest.Version)" -ForegroundColor Cyan
# Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "   Functions: $($exportedFunctions.Count)" -ForegroundColor Cyan
# Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "   Files: $($manifest.FileList.Count)" -ForegroundColor Cyan
# Using Write-Host for colored user output`n    # Using Write-Host for colored user output`n    Write-Host "   Ready for use!" -ForegroundColor Green

# Clean up
Remove-Module WindowsServerLab -Force -ErrorAction SilentlyContinue 