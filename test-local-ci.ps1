#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Local CI/CD test script that mimics the GitHub Actions workflow
.DESCRIPTION
    This script runs the same validation steps as our GitHub Actions CI/CD workflow
    but locally without requiring Docker or Act. Perfect for quick validation.
.EXAMPLE
    ./test-local-ci.ps1
#>

[CmdletBinding()]
param()

# Using Write-Host for colored user output`n    Write-Host "🔍 Starting Local CI/CD Validation..." -ForegroundColor Cyan
# Using Write-Host for colored user output`n    Write-Host "================================================" -ForegroundColor Cyan

# Track overall success
$overallSuccess = $true

#region PSScriptAnalyzer Validation
# Using Write-Host for colored user output`n    Write-Host "`n📝 Step 1: PowerShell Script Analysis" -ForegroundColor Yellow

# Check if PSScriptAnalyzer is installed
try {
    Import-Module PSScriptAnalyzer -ErrorAction Stop
    # Using Write-Host for colored user output`n    Write-Host "✅ PSScriptAnalyzer is available" -ForegroundColor Green
}
catch {
    # Using Write-Host for colored user output`n    Write-Host "❌ PSScriptAnalyzer not found. Installing..." -ForegroundColor Red
    try {
        Install-Module -Name PSScriptAnalyzer -Force -SkipPublisherCheck -Scope CurrentUser
        # Using Write-Host for colored user output`n    Write-Host "✅ PSScriptAnalyzer installed successfully" -ForegroundColor Green
    }
    catch {
        # Using Write-Host for colored user output`n    Write-Host "❌ Failed to install PSScriptAnalyzer: $($_.Exception.Message)" -ForegroundColor Red
        $overallSuccess = $false
    }
}

if ($overallSuccess) {
    $scripts = Get-ChildItem -Path . -Recurse -Include "*.ps1", "*.psm1", "*.psd1" | Where-Object {
        $_.FullName -notlike "*\.git\*" -and $_.FullName -notlike "*\node_modules\*"
    }
    
    # Using Write-Host for colored user output`n    Write-Host "Found $($scripts.Count) PowerShell files to analyze" -ForegroundColor Cyan
    
    $totalIssues = 0
    $criticalErrors = 0
    
    foreach ($script in $scripts) {
        # Using Write-Host for colored user output`n    Write-Host "  Analyzing: $($script.Name)" -ForegroundColor White
        try {
            $issues = Invoke-ScriptAnalyzer -Path $script.FullName -Severity @('Error', 'Warning') -ErrorAction Stop
            
            if ($issues) {
                $totalIssues += $issues.Count
                $errors = $issues | Where-Object { $_.Severity -eq 'Error' }
                $criticalErrors += $errors.Count
                
                # Using Write-Host for colored user output`n    Write-Host "    Issues found: $($issues.Count) (Errors: $($errors.Count))" -ForegroundColor $(if ($errors.Count -gt 0) { 'Red' } else { 'Yellow' })
                
                foreach ($issue in $issues) {
                    $color = if ($issue.Severity -eq 'Error') { 'Red' } else { 'Yellow' }
                    # Using Write-Host for colored user output`n    Write-Host "      [$($issue.Severity)] Line $($issue.Line): $($issue.Message)" -ForegroundColor $color
                }
            }
            else {
                # Using Write-Host for colored user output`n    Write-Host "    ✅ No issues found" -ForegroundColor Green
            }
        }
        catch {
            # Using Write-Host for colored user output`n    Write-Host "    ❌ Analysis failed: $($_.Exception.Message)" -ForegroundColor Red
            $overallSuccess = $false
        }
    }
    
    # Using Write-Host for colored user output`n    Write-Host "`nPSScriptAnalyzer Summary:" -ForegroundColor Cyan
    Write-Information "  Total files analyzed: $($scripts.Count)" -InformationAction Continue
    Write-Information "  Total issues: $totalIssues" -InformationAction Continue
    Write-Information "  Critical errors: $criticalErrors" -InformationAction Continue
    
    if ($criticalErrors -gt 0) {
        Write-Host "❌ Critical errors found - CI would fail" -ForegroundColor Red
        $overallSuccess = $false
    }
    elseif ($totalIssues -gt 0) {
        Write-Host "⚠️  Warnings found but no critical errors - CI would pass" -ForegroundColor Yellow
    }
    else {
        # Using Write-Host for colored user output`n    Write-Host "✅ All scripts passed analysis!" -ForegroundColor Green
    }
}
#endregion

#region Module Integrity Test
# Using Write-Host for colored user output`n    Write-Host "`n🔧 Step 2: Module Integrity Test" -ForegroundColor Yellow

if (Test-Path "Scripts/Test-ModuleIntegrity.ps1") {
    try {
        Push-Location Scripts
        # Using Write-Host for colored user output`n    Write-Host "Running module integrity test..." -ForegroundColor Cyan
        
        $result = .\Test-ModuleIntegrity.ps1 2>&1
        if ($LASTEXITCODE -eq 0) {
            # Using Write-Host for colored user output`n    Write-Host "✅ Module integrity test passed!" -ForegroundColor Green
        }
        else {
            # Using Write-Host for colored user output`n    Write-Host "❌ Module integrity test failed!" -ForegroundColor Red
            # Using Write-Host for colored user output`n    Write-Host $result -ForegroundColor Red
            $overallSuccess = $false
        }
    }
    catch {
        # Using Write-Host for colored user output`n    Write-Host "❌ Module integrity test failed: $($_.Exception.Message)" -ForegroundColor Red
        $overallSuccess = $false
    }
    finally {
        Pop-Location
    }
}
else {
    # Using Write-Host for colored user output`n    Write-Host "⚠️  Module integrity test script not found, skipping..." -ForegroundColor Yellow
}
#endregion

#region Documentation Validation
# Using Write-Host for colored user output`n    Write-Host "`n📚 Step 3: Documentation Validation" -ForegroundColor Yellow

$requiredDocs = @('README.md', 'CHANGELOG.md', 'LICENSE', 'CONTRIBUTING.md')
$githubDocs = @('.github/CODE_OF_CONDUCT.md', '.github/SECURITY.md', '.github/SUPPORT.md')
$missingDocs = @()

# Using Write-Host for colored user output`n    Write-Host "Checking required documentation files..." -ForegroundColor Cyan
foreach ($doc in $requiredDocs) {
    if (Test-Path $doc) {
        # Using Write-Host for colored user output`n    Write-Host "  ✅ Found: $doc" -ForegroundColor Green
    }
    else {
        $missingDocs += $doc
        # Using Write-Host for colored user output`n    Write-Host "  ❌ Missing: $doc" -ForegroundColor Red
    }
}

# Using Write-Host for colored user output`n    Write-Host "Checking community documentation files..." -ForegroundColor Cyan
foreach ($doc in $githubDocs) {
    if (Test-Path $doc) {
        # Using Write-Host for colored user output`n    Write-Host "  ✅ Found: $doc" -ForegroundColor Green
    }
    else {
        # Using Write-Host for colored user output`n    Write-Host "  ⚠️  Missing: $doc" -ForegroundColor Yellow
    }
}

if ($missingDocs.Count -gt 0) {
    Write-Host "❌ Missing critical documentation files: $($missingDocs -join ', ')" -ForegroundColor Red
    $overallSuccess = $false
}
else {
    # Using Write-Host for colored user output`n    Write-Host "✅ All required documentation present!" -ForegroundColor Green
}
#endregion

#region GitHub Templates Validation
# Using Write-Host for colored user output`n    Write-Host "`n🎯 Step 4: GitHub Templates Validation" -ForegroundColor Yellow

$templatePaths = @(
    '.github/ISSUE_TEMPLATE/bug_report.yml',
    '.github/ISSUE_TEMPLATE/feature_request.yml',
    '.github/ISSUE_TEMPLATE/question.yml',
    '.github/ISSUE_TEMPLATE/config.yml',
    '.github/pull_request_template.md',
    '.github/workflows/ci.yml',
    '.github/workflows/release.yml',
    '.github/workflows/docs.yml'
)

$missingTemplates = @()
foreach ($template in $templatePaths) {
    if (Test-Path $template) {
        # Using Write-Host for colored user output`n    Write-Host "  ✅ Found: $template" -ForegroundColor Green
    }
    else {
        $missingTemplates += $template
        # Using Write-Host for colored user output`n    Write-Host "  ❌ Missing: $template" -ForegroundColor Red
    }
}

if ($missingTemplates.Count -eq 0) {
    # Using Write-Host for colored user output`n    Write-Host "✅ All GitHub templates present!" -ForegroundColor Green
}
else {
    # Using Write-Host for colored user output`n    Write-Host "❌ Missing templates: $($missingTemplates.Count)" -ForegroundColor Red
    $overallSuccess = $false
}
#endregion

#region Final Summary
Write-Information "`n" -InformationAction Continue + "="*50 -ForegroundColor Cyan
# Using Write-Host for colored user output`n    Write-Host "🎯 Final CI/CD Validation Summary" -ForegroundColor Cyan
Write-Information "=" -InformationAction Continue*50 -ForegroundColor Cyan

if ($overallSuccess) {
    # Using Write-Host for colored user output`n    Write-Host "✅ ALL CHECKS PASSED! 🎉" -ForegroundColor Green
    # Using Write-Host for colored user output`n    Write-Host "   Your code is ready for GitHub Actions CI/CD" -ForegroundColor Green
    # Using Write-Host for colored user output`n    Write-Host "   The workflows should run successfully" -ForegroundColor Green
    exit 0
}
else {
    # Using Write-Host for colored user output`n    Write-Host "❌ SOME CHECKS FAILED! 💥" -ForegroundColor Red
    # Using Write-Host for colored user output`n    Write-Host "   Please fix the issues above before committing" -ForegroundColor Red
    # Using Write-Host for colored user output`n    Write-Host "   The GitHub Actions CI/CD may fail" -ForegroundColor Red
    exit 1
}
#endregion 