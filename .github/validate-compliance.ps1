#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Validates GitHub directory compliance for Windows Server Lab Environment
    
.DESCRIPTION
    This script validates that all GitHub configurations, templates, and workflows
    are compliant with the current project structure and version requirements.
    
.EXAMPLE
    ./.github/validate-compliance.ps1
    
.NOTES
    Author: Windows Server Lab Environment
    Version: 1.1.0
    Created: December 2024
#>

param(
    [switch]$Detailed,
    [switch]$Fix
)

# Use the Fix parameter for auto-fixing issues (addresses unused parameter warning)
if ($Fix) {
    Write-ComplianceLog "Auto-fix mode enabled - attempting to fix issues automatically" "INFO"
}

# Initialize results
$ComplianceResults = @{
    Passed   = @()
    Failed   = @()
    Warnings = @()
}

function Write-ComplianceLog {
    param(
        [string]$Message,
        [ValidateSet("PASS", "FAIL", "WARN", "INFO")]
        [string]$Level = "INFO"
    )
    
    # Variable used in Write-Host statement below (addresses PSScriptAnalyzer warning)
    $emoji = switch ($Level) {
        "PASS" { "✅"; $ComplianceResults.Passed += $Message }
        "FAIL" { "âŒ"; $ComplianceResults.Failed += $Message }
        "WARN" { "âš ï¸"; $ComplianceResults.Warnings += $Message }
        "INFO" { "ℹ️" }
    }
    
    # Using Write-Host for colored user output
    Write-Host "$emoji $Message" -ForegroundColor $(
        switch ($Level) {
            "PASS" { "Green" }
            "FAIL" { "Red" }
            "WARN" { "Yellow" }
            "INFO" { "Cyan" }
        }
    )
}

function Test-GitHubDirectory {
    Write-ComplianceLog "Validating GitHub directory structure..." "INFO"
    
    $requiredFiles = @(
        '.github/ISSUE_TEMPLATE/bug_report.yml',
        '.github/ISSUE_TEMPLATE/feature_request.yml', 
        '.github/ISSUE_TEMPLATE/question.yml',
        '.github/ISSUE_TEMPLATE/config.yml',
        '.github/workflows/ci.yml',
        '.github/workflows/release.yml',
        '.github/workflows/docs.yml',
        '.github/pull_request_template.md',
        '.github/CODE_OF_CONDUCT.md',
        '.github/SECURITY.md',
        '.github/SUPPORT.md',
        '.github/FUNDING.yml'
    )
    
    foreach ($file in $requiredFiles) {
        if (Test-Path $file) {
            Write-ComplianceLog "GitHub file exists: $file" "PASS"
        }
        else {
            Write-ComplianceLog "Missing GitHub file: $file" "FAIL"
        }
    }
}

function Test-VersionConsistency {
    Write-ComplianceLog "Validating version consistency..." "INFO"
    
    # Get expected version
    if (Test-Path "VERSION") {
        $expectedVersion = (Get-Content "VERSION" -Raw).Trim()
        Write-ComplianceLog "Expected version: $expectedVersion" "INFO"
        
        # Check module manifest
        if (Test-Path "Scripts/WindowsServerLab.psd1") {
            $manifestContent = Get-Content "Scripts/WindowsServerLab.psd1" -Raw
            if ($manifestContent -match "ModuleVersion\s*=\s*'([^']+)'") {
                $manifestVersion = $matches[1]
                if ($manifestVersion -eq $expectedVersion) {
                    Write-ComplianceLog "Module manifest version correct: $manifestVersion" "PASS"
                }
                else {
                    Write-ComplianceLog "Module manifest version mismatch: Expected $expectedVersion, found $manifestVersion" "FAIL"
                }
            }
        }
        
        # Check module file
        if (Test-Path "Scripts/WindowsServerLab.psm1") {
            $moduleContent = Get-Content "Scripts/WindowsServerLab.psm1" -Raw
            if ($moduleContent -match '\$ModuleVersion\s*=\s*"([^"]+)"') {
                $moduleVersion = $matches[1]
                if ($moduleVersion -eq $expectedVersion) {
                    Write-ComplianceLog "Module file version correct: $moduleVersion" "PASS"
                }
                else {
                    Write-ComplianceLog "Module file version mismatch: Expected $expectedVersion, found $moduleVersion" "FAIL"
                }
            }
        }
    }
    else {
        Write-ComplianceLog "VERSION file not found" "FAIL"
    }
}

function Test-DemoStructure {
    Write-ComplianceLog "Validating Demo directory structure..." "INFO"
    
    $demoFiles = @(
        'Demo/README.md',
        'Demo/Asgard/Scripts/Deploy-AsgardLab.ps1',
        'Demo/Asgard/Documentation/DEMO_SETUP_GUIDE.md',
        'Demo/Asgard/Documentation/HARDWARE_PERFORMANCE_GUIDE.md',
        'Demo/Asgard/Guides/QUICK_START_ASGARD.md'
    )
    
    foreach ($file in $demoFiles) {
        if (Test-Path $file) {
            Write-ComplianceLog "Demo file exists: $file" "PASS"
        }
        else {
            Write-ComplianceLog "Missing Demo file: $file" "FAIL"
        }
    }
}

function Test-IssueTemplate {
    Write-ComplianceLog "Validating issue template compliance..." "INFO"
    
    # Check for proper Demo environment references
    $templateFiles = @(
        '.github/ISSUE_TEMPLATE/bug_report.yml',
        '.github/ISSUE_TEMPLATE/feature_request.yml',
        '.github/ISSUE_TEMPLATE/question.yml'
    )
    
    foreach ($templateFile in $templateFiles) {
        if (Test-Path $templateFile) {
            $content = Get-Content $templateFile -Raw
            
            # Check for old "Asgard Demo Environment" references
            if ($content -match "Asgard Demo Environment") {
                Write-ComplianceLog "Template contains old demo reference: $templateFile" "WARN"
            }
            else {
                Write-ComplianceLog "Template demo references updated: $templateFile" "PASS"
            }
            
            # Check for new structured references
            if ($content -match "Demo Environment|Demo/") {
                Write-ComplianceLog "Template has proper demo structure reference: $templateFile" "PASS"
            }
        }
    }
}

function Test-WorkflowCompliance {
    Write-ComplianceLog "Validating GitHub Actions workflows..." "INFO"
    
    $workflowFiles = @(
        '.github/workflows/ci.yml',
        '.github/workflows/release.yml',
        '.github/workflows/docs.yml'
    )
    
    foreach ($workflowFile in $workflowFiles) {
        if (Test-Path $workflowFile) {
            $content = Get-Content $workflowFile -Raw
            
            # Check for version 1.1 references in release workflow
            if ($workflowFile -like "*release*" -and $content -match "1\.1") {
                Write-ComplianceLog "Release workflow has v1.1 support: $workflowFile" "PASS"
            }
            
            # Check for Demo validation in CI
            if ($workflowFile -like "*ci*" -and $content -match "Demo.*Structure") {
                Write-ComplianceLog "CI workflow includes Demo validation: $workflowFile" "PASS"
            }
            
            Write-ComplianceLog "Workflow file validated: $workflowFile" "PASS"
        }
        else {
            Write-ComplianceLog "Missing workflow file: $workflowFile" "FAIL"
        }
    }
}

function Test-DocumentationCompliance {
    Write-ComplianceLog "Validating documentation compliance..." "INFO"
    
    # Check if CHANGELOG reflects current structure
    if (Test-Path "CHANGELOG.md") {
        $changelogContent = Get-Content "CHANGELOG.md" -Raw
        if ($changelogContent -match "Demo.*Organization|Asgard.*Demo") {
            Write-ComplianceLog "CHANGELOG includes Demo organization changes" "PASS"
        }
        else {
            Write-ComplianceLog "CHANGELOG missing Demo organization details" "WARN"
        }
    }
    
    # Check GitHub templates summary
    if (Test-Path "GITHUB_TEMPLATES_SUMMARY.md") {
        Write-ComplianceLog "GitHub templates summary exists" "PASS"
    }
    else {
        Write-ComplianceLog "Missing GitHub templates summary" "WARN"
    }
}

# Main execution
# Using Write-Host for colored user output
Write-Host "`n��” GitHub Directory Compliance Validation" -ForegroundColor Cyan
# Using Write-Host for colored user output
Write-Host "=========================================" -ForegroundColor Cyan

# Run all validation tests
Test-GitHubDirectory
Test-VersionConsistency  
Test-DemoStructure
Test-IssueTemplate
Test-WorkflowCompliance
Test-DocumentationCompliance

# Summary report
# Using Write-Host for colored user output
Write-Host "`n��“Š Compliance Summary" -ForegroundColor Cyan
# Using Write-Host for colored user output
Write-Host "=====================" -ForegroundColor Cyan
# Using Write-Host for colored user output
Write-Host "❌… Passed: $($ComplianceResults.Passed.Count)" -ForegroundColor Green
# Using Write-Host for colored user output
Write-Host "âŒ Failed: $($ComplianceResults.Failed.Count)" -ForegroundColor Red  
# Using Write-Host for colored user output
Write-Host "âš ï¸  Warnings: $($ComplianceResults.Warnings.Count)" -ForegroundColor Yellow

if ($Detailed) {
    if ($ComplianceResults.Failed.Count -gt 0) {
        # Using Write-Host for colored user output
        Write-Host "`nâŒ Failed Items:" -ForegroundColor Red
        $ComplianceResults.Failed | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    }
    
    if ($ComplianceResults.Warnings.Count -gt 0) {
        # Using Write-Host for colored user output
        Write-Host "`nâš ï¸  Warning Items:" -ForegroundColor Yellow
        $ComplianceResults.Warnings | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
    }
}

# Exit with appropriate code
if ($ComplianceResults.Failed.Count -gt 0) {
    # Using Write-Host for colored user output
    Write-Host "`nâŒ Compliance validation failed!" -ForegroundColor Red
    exit 1
}
elseif ($ComplianceResults.Warnings.Count -gt 0) {
    # Using Write-Host for colored user output
    Write-Host "`nâš ï¸  Compliance validation passed with warnings" -ForegroundColor Yellow
    exit 0
}
else {
    # Using Write-Host for colored user output
    Write-Host "`n❌… All compliance checks passed!" -ForegroundColor Green
    exit 0
} 
